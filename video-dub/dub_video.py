#!/usr/bin/env python3
"""
dub_video.py - Redub a video from Russian to Ukrainian.

Pipeline:
  1. (optional) download source video via yt-dlp
  2. extract audio, transcribe with faster-whisper (Russian, with timestamps)
  3. machine-translate each segment to Ukrainian, dump to an editable file
  4. (after you review/edit the translation) synthesize Ukrainian speech per
     segment with edge-tts, time-stretch each clip to fit its original slot
  5. mux the new audio track back onto the original video

Run in two phases so you can proofread the Ukrainian text before it's
spoken out loud - machine translation + TTS without a human check almost
always sounds unnatural:

    python dub_video.py transcribe --input my_video.mp4 --workdir work
    #  -> edit work/segments.uk.json (or work/segments.uk.srt) by hand
    python dub_video.py dub --workdir work --output my_video.uk.mp4

Or run everything in one shot with --auto (skips the manual review step):

    python dub_video.py all --url "https://www.youtube.com/watch?v=..." \
        --workdir work --output my_video.uk.mp4 --auto
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

VOICES = {
    "female": "uk-UA-PolinaNeural",
    "male": "uk-UA-OstapNeural",
}


def run(cmd, **kw):
    print("$", " ".join(str(c) for c in cmd))
    subprocess.run(cmd, check=True, **kw)


def require(binary):
    if shutil.which(binary) is None:
        sys.exit(f"'{binary}' not found on PATH. See README.md for setup.")


# --------------------------------------------------------------------------
# Step 1: fetch the source video
# --------------------------------------------------------------------------
def download_video(url: str, workdir: Path) -> Path:
    require("yt-dlp")
    out_template = str(workdir / "source.%(ext)s")
    run([
        "yt-dlp", "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b",
        "--merge-output-format", "mp4",
        "-o", out_template, url,
    ])
    matches = list(workdir.glob("source.*"))
    if not matches:
        sys.exit("yt-dlp finished but no source.* file was produced.")
    return matches[0]


# --------------------------------------------------------------------------
# Step 2: extract audio + transcribe (Russian)
# --------------------------------------------------------------------------
def extract_audio(video_path: Path, workdir: Path) -> Path:
    require("ffmpeg")
    audio_path = workdir / "source_audio.wav"
    run([
        "ffmpeg", "-y", "-i", str(video_path),
        "-ac", "1", "-ar", "16000", "-vn", str(audio_path),
    ])
    return audio_path


def transcribe(audio_path: Path, model_size: str):
    from faster_whisper import WhisperModel

    print(f"Loading faster-whisper model '{model_size}' ...")
    model = WhisperModel(model_size, compute_type="int8")
    segments, _ = model.transcribe(str(audio_path), language="ru", vad_filter=True)
    result = []
    for seg in segments:
        text = seg.text.strip()
        if not text:
            continue
        result.append({"start": seg.start, "end": seg.end, "ru": text})
        print(f"  [{seg.start:7.2f} - {seg.end:7.2f}] {text}")
    return result


# --------------------------------------------------------------------------
# Step 3: machine translation (rough draft - please review by hand)
# --------------------------------------------------------------------------
def translate_segments(segments):
    from deep_translator import GoogleTranslator

    translator = GoogleTranslator(source="ru", target="uk")
    for seg in segments:
        seg["uk"] = translator.translate(seg["ru"])
    return segments


def write_review_files(segments, workdir: Path):
    json_path = workdir / "segments.uk.json"
    json_path.write_text(json.dumps(segments, ensure_ascii=False, indent=2), encoding="utf-8")

    srt_path = workdir / "segments.uk.srt"
    lines = []
    for i, seg in enumerate(segments, 1):
        lines.append(str(i))
        lines.append(f"{_srt_ts(seg['start'])} --> {_srt_ts(seg['end'])}")
        lines.append(seg["uk"])
        lines.append("")
    srt_path.write_text("\n".join(lines), encoding="utf-8")

    print(f"\nWrote {json_path} and {srt_path}.")
    print("Review/edit the 'uk' field (or the .srt) before running the 'dub' phase.")


def _srt_ts(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


# --------------------------------------------------------------------------
# Step 4: synthesize Ukrainian speech per segment, fit to original timing
# --------------------------------------------------------------------------
def atempo_chain(factor: float) -> str:
    """ffmpeg's atempo filter only accepts 0.5-2.0; chain instances for
    factors outside that range."""
    filters = []
    f = factor
    if f <= 0:
        return "atempo=1.0"
    while f < 0.5 or f > 2.0:
        step = 2.0 if f > 2.0 else 0.5
        filters.append(f"atempo={step}")
        f /= step
    filters.append(f"atempo={f:.4f}")
    return ",".join(filters)


def synth_segment(text: str, voice: str, out_path: Path):
    import edge_tts

    async def _run():
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(str(out_path))

    import asyncio
    asyncio.run(_run())


def duration_of(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())


def build_dubbed_track(segments, voice: str, total_duration: float, workdir: Path) -> Path:
    from pydub import AudioSegment

    raw_dir = workdir / "tts_raw"
    fit_dir = workdir / "tts_fit"
    raw_dir.mkdir(exist_ok=True)
    fit_dir.mkdir(exist_ok=True)

    track = AudioSegment.silent(duration=int(total_duration * 1000) + 1000)

    for i, seg in enumerate(segments):
        text = seg.get("uk", "").strip()
        if not text:
            continue
        raw_path = raw_dir / f"{i:04d}.mp3"
        fit_path = fit_dir / f"{i:04d}.wav"
        synth_segment(text, voice, raw_path)

        slot = seg["end"] - seg["start"]
        spoken = duration_of(raw_path)
        factor = spoken / slot if slot > 0 else 1.0
        # Only speed up if the dub overruns its slot; don't slow down
        # (silence is a less jarring gap-filler than artificially slow speech).
        factor = max(factor, 1.0)
        run([
            "ffmpeg", "-y", "-i", str(raw_path),
            "-filter:a", atempo_chain(factor),
            str(fit_path),
        ])

        clip = AudioSegment.from_file(fit_path)
        pos_ms = int(seg["start"] * 1000)
        track = track.overlay(clip, position=pos_ms)

    dubbed_path = workdir / "dubbed_track.wav"
    track.export(dubbed_path, format="wav")
    return dubbed_path


# --------------------------------------------------------------------------
# Step 5: mux back onto the original video
# --------------------------------------------------------------------------
def mux(video_path: Path, dubbed_audio: Path, output_path: Path,
        original_audio: Path = None, background_db: float = None):
    require("ffmpeg")
    if original_audio and background_db is not None:
        run([
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-i", str(dubbed_audio),
            "-i", str(original_audio),
            "-filter_complex",
            f"[2:a]volume={background_db}dB[bg];[1:a][bg]amix=inputs=2:duration=first[aout]",
            "-map", "0:v:0", "-map", "[aout]",
            "-c:v", "copy", "-shortest", str(output_path),
        ])
    else:
        run([
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-i", str(dubbed_audio),
            "-map", "0:v:0", "-map", "1:a:0",
            "-c:v", "copy", "-shortest", str(output_path),
        ])
    print(f"\nDone: {output_path}")


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def cmd_transcribe(args):
    workdir = Path(args.workdir)
    workdir.mkdir(parents=True, exist_ok=True)

    video_path = Path(args.input) if args.input else download_video(args.url, workdir)
    (workdir / "video_path.txt").write_text(str(video_path), encoding="utf-8")

    audio_path = extract_audio(video_path, workdir)
    segments = transcribe(audio_path, args.whisper_model)
    segments = translate_segments(segments)
    write_review_files(segments, workdir)


def cmd_dub(args):
    workdir = Path(args.workdir)
    video_path = Path((workdir / "video_path.txt").read_text(encoding="utf-8").strip())
    segments = json.loads((workdir / "segments.uk.json").read_text(encoding="utf-8"))

    total_duration = duration_of(video_path)
    voice = VOICES.get(args.voice, args.voice)
    dubbed_audio = build_dubbed_track(segments, voice, total_duration, workdir)

    original_audio = None
    if args.keep_background is not None:
        original_audio = extract_audio(video_path, workdir)

    mux(video_path, dubbed_audio, Path(args.output),
        original_audio=original_audio, background_db=args.keep_background)


def cmd_all(args):
    cmd_transcribe(args)
    if not args.auto:
        print("\n--auto not set: stopping after transcription so you can review")
        print(f"the Ukrainian text in {Path(args.workdir) / 'segments.uk.json'}.")
        print("Then run: python dub_video.py dub --workdir "
              f"{args.workdir} --output {args.output}")
        return
    cmd_dub(args)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="phase", required=True)

    def add_common(sp):
        sp.add_argument("--workdir", default="work", help="working directory for intermediate files")

    def add_source(sp):
        sp.add_argument("--url", help="YouTube (or any yt-dlp-supported) URL")
        sp.add_argument("--input", help="path to a local video file instead of --url")

    def add_output(sp):
        sp.add_argument("--output", default="dubbed.mp4", help="path for the final dubbed video")

    def add_voice(sp):
        sp.add_argument("--voice", default="female",
                         help="'female' (uk-UA-PolinaNeural), 'male' (uk-UA-OstapNeural), "
                              "or any edge-tts voice id")

    p_tr = sub.add_parser("transcribe", help="download/extract audio, transcribe, machine-translate")
    add_common(p_tr)
    add_source(p_tr)
    p_tr.add_argument("--whisper-model", default="medium",
                       help="faster-whisper model size: tiny/base/small/medium/large-v3")
    p_tr.set_defaults(func=cmd_transcribe)

    p_dub = sub.add_parser("dub", help="synthesize Ukrainian audio and mux onto the video")
    add_common(p_dub)
    add_output(p_dub)
    add_voice(p_dub)
    p_dub.add_argument("--keep-background", type=float, default=None,
                        help="also mix in the original audio at this many dB "
                             "(negative, e.g. -20) to preserve music/SFX; "
                             "note this will also leave the original Russian "
                             "voice audible underneath")
    p_dub.set_defaults(func=cmd_dub)

    p_all = sub.add_parser("all", help="run transcribe then dub back-to-back")
    add_common(p_all)
    add_source(p_all)
    add_output(p_all)
    add_voice(p_all)
    p_all.add_argument("--whisper-model", default="medium")
    p_all.add_argument("--keep-background", type=float, default=None)
    p_all.add_argument("--auto", action="store_true",
                        help="skip the manual translation-review pause")
    p_all.set_defaults(func=cmd_all)

    args = p.parse_args()
    if getattr(args, "url", None) is None and getattr(args, "input", None) is None and args.phase in ("transcribe", "all"):
        p.error("one of --url or --input is required")
    args.func(args)


if __name__ == "__main__":
    main()
