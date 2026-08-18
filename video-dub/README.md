# video-dub

Redub your own video from Russian to Ukrainian: transcribe, translate,
synthesize a natural Ukrainian voice, and mux it back onto the original
video. Runs on **your own machine** (not in a cloud sandbox), since it
needs unrestricted access to YouTube and to the TTS voice service.

Use this only on videos you own or otherwise have the rights to redub.

## Setup

Requires Python 3.9+ and [ffmpeg](https://ffmpeg.org/download.html) on your `PATH`.

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Usage

### 1. Transcribe + rough translation

```bash
python dub_video.py transcribe --url "https://www.youtube.com/watch?v=..." --workdir work
# or, if you already have the file locally:
python dub_video.py transcribe --input my_video.mp4 --workdir work
```

This downloads (or reads) the video, transcribes the Russian audio with
timestamps, and writes a rough machine translation to:

- `work/segments.uk.json`
- `work/segments.uk.srt`

### 2. Review the Ukrainian text (recommended)

Open `work/segments.uk.json` (or the `.srt`) and read through the `uk`
field for each segment. Machine translation plus text-to-speech, without a
human pass, tends to produce phrasing that's grammatically fine but doesn't
sound like a real person talking. Fix idioms, tone, names, numbers, etc.
here before moving on — this step is what makes the final dub sound
natural rather than robotic.

### 3. Synthesize the dub and produce the final video

```bash
python dub_video.py dub --workdir work --output my_video.uk.mp4
```

By default this fully replaces the original audio track. If the video has
background music/sound effects you want to keep, use:

```bash
python dub_video.py dub --workdir work --output my_video.uk.mp4 --keep-background -20
```

Note: `--keep-background` mixes in the *entire* original audio (including
the original Russian voice) at a lower volume — there's no vocal
separation here. It's meant for videos where the spoken part is easy to
duck under music, not a clean voice swap.

### All-in-one

```bash
python dub_video.py all --url "https://www.youtube.com/watch?v=..." \
    --workdir work --output my_video.uk.mp4 --auto
```

`--auto` skips the manual-review pause in step 2 and goes straight from
machine translation to synthesis — faster, but expect rougher phrasing.
Omit `--auto` and the command stops after transcription so you can review.

## Voices

`--voice female` (default) uses `uk-UA-PolinaNeural`; `--voice male` uses
`uk-UA-OstapNeural`. You can also pass any other
[edge-tts](https://github.com/rany2/edge-tts) voice id directly, e.g.
`--voice uk-UA-PolinaNeural`.

`edge-tts` talks to the same (free, unofficial) neural voice service as
Microsoft Edge's "Read aloud" feature. It requires internet access and has
no official support guarantee. If you need a supported/commercial-grade
option, swap `synth_segment()` in `dub_video.py` for Azure Cognitive
Services Speech, Google Cloud TTS, or ElevenLabs (all offer natural
Ukrainian voices) — you'll need an API key for any of those.

## Notes / limitations

- Whisper's Russian transcription and the timestamps it produces aren't
  perfect, especially on noisy audio or fast speech — spot-check the
  transcript too, not just the translation.
- Each dubbed segment is time-stretched to fit within its original slot
  if it runs long (never slowed down, to avoid unnaturally draggy speech);
  short segments just leave a small gap of silence.
- `--whisper-model` defaults to `medium` (good accuracy/speed balance on
  CPU). Use `large-v3` for the best accuracy if you have a GPU, or
  `small`/`base` for a much faster draft pass.
