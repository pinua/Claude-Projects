# ============================================================
#  BARNHOUSE FRAME — 6500 × 7000 мм, висота 2500 мм
#  Нижня обв'язка:  100 × 200 мм
#  Верхня обв'язка: 50  × 150 мм
#  Стійки:          50  × 150 мм @ 600 мм ц/ц
#  Стельові балки:  50  × 150 мм (через ширину)
#  П'яточки:        100 × 50 × 50 мм (опора крокв)
#  Крокви:          50  × 150 мм @ 600 мм, кут 35°
#  Коньок:          50  × 200 мм
# ============================================================
#  ЗАПУСК: Window → Ruby Console
#    load 'C:/path/barnhouse_preview_6500x7000.rb'
# ============================================================

require 'sketchup'

model = Sketchup.active_model
model.start_operation('Barnhouse 6500x7000', true)
ents = model.entities
lyrs = model.layers

# ── ПАРАМЕТРИ ───────────────────────────────────────────────
OW   = 6500.mm    # ширина (X), торцева стіна
OL   = 7000.mm    # довжина (Y), поздовжня стіна
WH   = 2500.mm    # висота від підлоги до верху верхньої обв.

BP_H = 100.mm     # висота нижньої обв'язки
BP_D = 200.mm     # глибина нижньої обв'язки (вглиб стіни)

SW   = 50.mm      # ширина стійки (уздовж стіни)
SD   = 150.mm     # глибина стійки (вглиб стіни)
SP   = 600.mm     # шаг стійок ц/ц

TP_H = 50.mm      # висота верхньої обв'язки
TP_D = 150.mm     # глибина верхньої обв'язки

CJ_W = 50.mm      # ширина стельової балки
CJ_H = 150.mm     # висота стельової балки

HEEL_H = 50.mm    # висота п'яточки
HEEL_D = 100.mm   # глибина п'яточки

RW   = 50.mm      # ширина кроквини
RH   = 150.mm     # висота кроквини (перпендикулярно осі)

SLAB_H   = 200.mm
JOIST_W  = 50.mm
JOIST_H  = 200.mm

PITCH_DEG = 35.0

# ── РОЗРАХУНКИ ──────────────────────────────────────────────
stud_z  = BP_H.to_f
stud_h  = WH - BP_H - TP_H   # 2350 мм
tp_z    = (WH - TP_H).to_f

pitch      = PITCH_DEG * Math::PI / 180.0
heel_z     = WH + HEEL_H      # крокви сидять на п'яточці
rafter_run = OW / 2.0         # горизонтальний проліт від стіни до конька
rise       = rafter_run * Math.tan(pitch)
ridge_z    = heel_z + rise
rlen       = Math.sqrt(rafter_run**2 + rise**2)
cos_p      = rafter_run / rlen
sin_p      = rise / rlen

# ── ШАРИ ────────────────────────────────────────────────────
l_slab  = lyrs['00 Фундамент']           || lyrs.add('00 Фундамент')
l_joist = lyrs['01 Лаги 50x200']         || lyrs.add('01 Лаги 50x200')
l_bp    = lyrs['02 Нижня обв. 100x200']  || lyrs.add('02 Нижня обв. 100x200')
l_corn  = lyrs['03 Кутові стійки 100x150']|| lyrs.add('03 Кутові стійки 100x150')
l_stud  = lyrs['04 Стійки 50x150']       || lyrs.add('04 Стійки 50x150')
l_tp    = lyrs['05 Верхня обв. 50x150']  || lyrs.add('05 Верхня обв. 50x150')
l_cj    = lyrs['06 Стельові балки 50x150']|| lyrs.add('06 Стельові балки 50x150')
l_heel  = lyrs["07 П'яточки"]            || lyrs.add("07 П'яточки")
l_raft  = lyrs['08 Крокви 50x150']       || lyrs.add('08 Крокви 50x150')
l_ridge = lyrs['09 Коньок 50x200']       || lyrs.add('09 Коньок 50x200')

# ── HELPER ──────────────────────────────────────────────────
def bx(ents, x, y, z, dx, dy, dz, layer)
  return if [dx, dy, dz].any? { |v| v.abs < 0.5.mm }
  g   = ents.add_group
  g.layer = layer
  pts = [Geom::Point3d.new(x,      y,      z),
         Geom::Point3d.new(x + dx, y,      z),
         Geom::Point3d.new(x + dx, y + dy, z),
         Geom::Point3d.new(x,      y + dy, z)]
  f = g.entities.add_face(pts)
  return unless f
  f.reverse! if f.normal.z < 0
  f.pushpull(dz)
  g
end

# ── 0. ФУНДАМЕНТНА ПЛИТА ─────────────────────────────────────
bx(ents, 0, 0, -SLAB_H, OW, OL, SLAB_H, l_slab)

# ── 1. ЛАГИ ПІДЛОГИ 50×200 @ 600 мм (по X, крок по Y) ──────
y = 0.0
while y <= OL + 0.5.mm
  bx(ents, BP_D, y - JOIST_W / 2, 0, OW - 2 * BP_D, JOIST_W, JOIST_H, l_joist)
  y += SP
end

# ── 2. НИЖНЯ ОБВ'ЯЗКА 100×200 ────────────────────────────────
# Торцеві стіни (y=0, y=OL): повна ширина OW
bx(ents, 0, 0,        0, OW, BP_D, BP_H, l_bp)
bx(ents, 0, OL - BP_D, 0, OW, BP_D, BP_H, l_bp)
# Поздовжні стіни (x=0, x=OW): між торцями
bx(ents, 0,        BP_D, 0, BP_D, OL - 2 * BP_D, BP_H, l_bp)
bx(ents, OW - BP_D, BP_D, 0, BP_D, OL - 2 * BP_D, BP_H, l_bp)

# ── 3. КУТОВІ СТІЙКИ 100×150 ─────────────────────────────────
# (дві стійки 50×150 разом утворюють кутовий вузол)
[
  [0,        0],
  [OW - SW * 2, 0],
  [0,        OL - SD],
  [OW - SW * 2, OL - SD]
].each do |cx, cy|
  bx(ents, cx, cy, stud_z, SW * 2, SD, stud_h, l_corn)
end

# ── 4. СТІЙКИ 50×150 @ 600 мм ────────────────────────────────
# Торцеві стіни (y=0, y=OL-SD), стійки по X
[0, OL - SD].each do |yw|
  x = SP
  while x < OW - SW + 0.5.mm
    bx(ents, x - SW / 2, yw, stud_z, SW, SD, stud_h, l_stud)
    x += SP
  end
end

# Поздовжні стіни (x=0, x=OW-SD), стійки по Y
[0, OW - SD].each do |xw|
  y = BP_D + SP
  while y < OL - BP_D - SW / 2 + 0.5.mm
    bx(ents, xw, y - SW / 2, stud_z, SD, SW, stud_h, l_stud)
    y += SP
  end
end

# ── 5. ВЕРХНЯ ОБВ'ЯЗКА 50×150 ────────────────────────────────
bx(ents, 0, 0,         tp_z, OW, TP_D, TP_H, l_tp)
bx(ents, 0, OL - TP_D, tp_z, OW, TP_D, TP_H, l_tp)
bx(ents, 0,        TP_D, tp_z, TP_D, OL - 2 * TP_D, TP_H, l_tp)
bx(ents, OW - TP_D, TP_D, tp_z, TP_D, OL - 2 * TP_D, TP_H, l_tp)

# ── 6. СТЕЛЬОВІ БАЛКИ 50×150 (по X, крок по Y) ───────────────
cj_span = OW - 2 * TP_D
y = SP
while y < OL - SP + 0.5.mm
  bx(ents, TP_D, y - CJ_W / 2, WH, cj_span, CJ_W, CJ_H, l_cj)
  y += SP
end

# ── 7. П'ЯТОЧКИ 100×50×50 на верхній обв'язці ────────────────
# На поздовжніх стінах (x=0 і x=OW-TP_D), у місцях кроквин
y = 0.0
while y <= OL + 0.5.mm
  bx(ents, 0,        y - RW / 2, WH, HEEL_D, RW, HEEL_H, l_heel)
  bx(ents, OW - HEEL_D, y - RW / 2, WH, HEEL_D, RW, HEEL_H, l_heel)
  y += SP
end

# ── 8. КРОКВИ 50×150 @ 600 мм, кут 35° ──────────────────────
# Переріз у площині XZ, pushpull по Y (ширина RW)
dx_d =  sin_p * RH   # вектор глибини кроквини (перпендикуляр)
dz_d = -cos_p * RH

y = 0.0
while y <= OL + 0.5.mm
  y0 = y - RW / 2.0

  # Ліва кроква: від (0, y0, heel_z) до (OW/2, y0, ridge_z)
  gl = ents.add_group; gl.layer = l_raft; ge = gl.entities
  p0 = Geom::Point3d.new(0,                      y0, heel_z)
  p1 = Geom::Point3d.new(dx_d,                   y0, heel_z + dz_d)
  p2 = Geom::Point3d.new(dx_d + cos_p * rlen,    y0, heel_z + dz_d + sin_p * rlen)
  p3 = Geom::Point3d.new(cos_p * rlen,            y0, heel_z + sin_p * rlen)
  fl = ge.add_face([p0, p1, p2, p3])
  fl.reverse! if fl && fl.normal.y > 0
  fl.pushpull(RW) if fl

  # Права кроква: дзеркало по X від OW
  gr = ents.add_group; gr.layer = l_raft; ge2 = gr.entities
  p0r = Geom::Point3d.new(OW,                      y0, heel_z)
  p1r = Geom::Point3d.new(OW - dx_d,               y0, heel_z + dz_d)
  p2r = Geom::Point3d.new(OW - dx_d - cos_p * rlen, y0, heel_z + dz_d + sin_p * rlen)
  p3r = Geom::Point3d.new(OW - cos_p * rlen,         y0, heel_z + sin_p * rlen)
  fr = ge2.add_face([p0r, p1r, p2r, p3r])
  fr.reverse! if fr && fr.normal.y < 0
  fr.pushpull(RW) if fr

  y += SP
end

# ── 9. КОНЬОК 50×200 ─────────────────────────────────────────
bx(ents, OW / 2.0 - 25.mm, 0, ridge_z, 50.mm, OL, 200.mm, l_ridge)

model.commit_operation

puts "=== Barnhouse 6500×7000 готовий! ==="
puts "Нижня обв.: #{BP_H.to_i}×#{BP_D.to_i}  |  Верхня обв.: #{TP_H.to_i}×#{TP_D.to_i}"
puts "Стійки: #{SW.to_i}×#{SD.to_i} @ #{SP.to_i}мм  |  Висота: #{WH.to_i}мм"
puts "Конек: Z=#{ridge_z.round}мм  |  Кут: #{PITCH_DEG}°"
