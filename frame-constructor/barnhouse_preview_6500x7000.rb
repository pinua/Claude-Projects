# ============================================================
#  BARNHOUSE 6500 × 7000 мм  — платформний каркас
#  Стійка: 2500 мм  |  Нижня обв.: 100×200  |  Верхня: 50×150
#  + металеві кріплення (куточки/joist hangers)
#  + горизонтальний блокінг між стійками на середині
#  + п'яточки + крокви 50×200, кут 35°
# ============================================================
#  ЗАПУСК: вставити весь код у Ruby Console і натиснути Enter
# ============================================================

require 'sketchup'

model = Sketchup.active_model
model.start_operation('Barnhouse 6500x7000 v3', true)
ents = model.entities
lyrs = model.layers

# ── ПАРАМЕТРИ ───────────────────────────────────────────────
OW      = 6500.mm   # ширина X
OL      = 7000.mm   # довжина Y

STUD_H  = 2500.mm   # висота стійки (чиста, без плит)
BP_H    = 100.mm    # висота нижньої обв'язки
BP_D    = 200.mm    # глибина нижньої обв'язки

SW      = 50.mm     # ширина стійки вздовж стіни
SD      = 150.mm    # глибина стійки вглиб стіни
SP      = 600.mm    # шаг стійок ц/ц

TP_H    = 50.mm     # висота верхньої обв'язки
TP_D    = 150.mm    # глибина верхньої обв'язки

JW      = 50.mm     # ширина лаги
JH      = 200.mm    # висота лаги
CT      = 2.mm      # товщина металу кріплень
CA      = 50.mm     # висота куточка-кріплення
CB      = 60.mm     # довжина основи куточка

HEEL_H  = 50.mm     # висота п'яточки
RW      = 50.mm     # ширина кроквини
RH      = 200.mm    # висота кроквини
PITCH_DEG = 35.0
SLAB_H  = 200.mm

# ── РОЗРАХУНКИ ──────────────────────────────────────────────
stud_z   = BP_H.to_f                     # низ стійок
tp_z     = (BP_H + STUD_H).to_f          # низ верхньої обв'язки
wh       = BP_H + STUD_H + TP_H          # загальна висота (100+2500+50=2650)
mid_z    = BP_H + STUD_H / 2.0 - SW / 2.0  # середина для блокінгу

pitch      = PITCH_DEG * Math::PI / 180.0
heel_z_r   = wh + HEEL_H                 # крокви стартують від верху п'яточок
rise       = (OW / 2.0) * Math.tan(pitch)
ridge_z    = heel_z_r + rise
rafter_run = OW / 2.0
rlen       = Math.sqrt(rafter_run**2 + rise**2)
cos_p      = rafter_run / rlen
sin_p      = rise / rlen

# ── ШАРИ ────────────────────────────────────────────────────
def get_layer(lyrs, name)
  lyrs[name] || lyrs.add(name)
end
l_slab  = get_layer(lyrs, '00 Бетон')
l_joist = get_layer(lyrs, '01 Лаги 50x200')
l_bp    = get_layer(lyrs, '02 Нижня обв. 100x200')
l_conn  = get_layer(lyrs, '03 Кріплення металеві')
l_corn  = get_layer(lyrs, '04 Кутові стійки 100x150')
l_stud  = get_layer(lyrs, '05 Стійки 50x150')
l_blk   = get_layer(lyrs, '06 Блокінг 50x150')
l_tp    = get_layer(lyrs, '07 Верхня обв. 50x150')
l_heel  = get_layer(lyrs, "08 П'яточки")
l_raft  = get_layer(lyrs, '09 Крокви 50x200')
l_ridge = get_layer(lyrs, '10 Коньок 50x200')

# ── HELPER: box ─────────────────────────────────────────────
def bx(ents, x, y, z, dx, dy, dz, layer)
  return if [dx, dy, dz].any? { |v| v.abs < 0.5.mm }
  g = ents.add_group
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

# ── HELPER: L-куточок (кріплення) ──
# orientation: :x_wall або :y_wall
# side: :front (y=0) або :back (y=OL), :left (x=0) або :right (x=OW)
def metal_l(ents, x, y, z, orient, side, sw, sd, ca, cb, ct, layer)
  case orient
  when :x_wall
    # стійка орієнтована вздовж X, кріплення на задній/передній стіні
    if side == :front   # y = 0 стіна, куточок всередині (y+sd сторона)
      bx(ents, x - sw/2, y + sd,          z, sw, ct, ca, layer)  # вертик.
      bx(ents, x - sw/2, y + sd,          z - ct, sw, cb, ct, layer)  # горизонт.
    else                # y = OL стіна
      bx(ents, x - sw/2, y - sd - ct,     z, sw, ct, ca, layer)
      bx(ents, x - sw/2, y - sd - cb,     z - ct, sw, cb, ct, layer)
    end
  when :y_wall
    if side == :left    # x = 0 стіна, куточок всередині (x+sd сторона)
      bx(ents, x + sd,          y - sw/2, z, ct, sw, ca, layer)
      bx(ents, x + sd,          y - sw/2, z - ct, cb, sw, ct, layer)
    else                # x = OW стіна
      bx(ents, x - sd - ct,     y - sw/2, z, ct, sw, ca, layer)
      bx(ents, x - sd - cb,     y - sw/2, z - ct, cb, sw, ct, layer)
    end
  end
end

# ── 0. БЕТОННА ПЛИТА ─────────────────────────────────────────
bx(ents, 0, 0, -SLAB_H, OW, OL, SLAB_H, l_slab)

# ── 1. ЛАГИ ПІДЛОГИ 50×200 + JOIST HANGERS ──────────────────
joist_x    = BP_D
joist_span = OW - 2 * BP_D

y = SP
while y < OL - SP + 0.5.mm
  bx(ents, joist_x, y - JW / 2, 0, joist_span, JW, JH, l_joist)

  # Joist hanger — ліворуч (вертикальна планка + сідло)
  bx(ents, joist_x - CT, y - JW / 2 - CT, 0, CT, JW + 2 * CT, JH, l_conn)
  bx(ents, joist_x,      y - JW / 2 - CT, 0, CB, JW + 2 * CT, CT, l_conn)

  # Joist hanger — праворуч
  bx(ents, joist_x + joist_span,      y - JW / 2 - CT, 0, CT, JW + 2 * CT, JH, l_conn)
  bx(ents, joist_x + joist_span - CB, y - JW / 2 - CT, 0, CB, JW + 2 * CT, CT, l_conn)

  # Солідний блокінг між лагами (на середині прольоту)
  mid_x = joist_x + joist_span / 2 - JW / 2
  bx(ents, mid_x, y - JW / 2, 0, JW, JW, JH, l_blk)

  y += SP
end

# ── 2. НИЖНЯ ОБВ'ЯЗКА 100×200 ────────────────────────────────
bx(ents, 0,        0,        0, OW, BP_D, BP_H, l_bp)
bx(ents, 0,        OL - BP_D, 0, OW, BP_D, BP_H, l_bp)
bx(ents, 0,        BP_D,      0, BP_D, OL - 2 * BP_D, BP_H, l_bp)
bx(ents, OW - BP_D, BP_D,     0, BP_D, OL - 2 * BP_D, BP_H, l_bp)

# ── 3. КУТОВІ СТІЙКИ 100×150 ─────────────────────────────────
[
  [0,            0,        :x_wall, :front],
  [OW - SW * 2,  0,        :x_wall, :front],
  [0,            OL - SD,  :x_wall, :back],
  [OW - SW * 2,  OL - SD,  :x_wall, :back]
].each do |cx, cy, orient, side|
  bx(ents, cx, cy, stud_z, SW * 2, SD, STUD_H, l_corn)
  metal_l(ents, cx + SW/2, cy, stud_z, orient, side, SW*2, SD, CA, CB, CT, l_conn)
end

# ── 4. СТІЙКИ X-СТІН (торцеві, y=0 та y=OL) ─────────────────
[[0, :front], [OL - SD, :back]].each do |yw, side|
  x = SP
  while x < OW - SW + 0.5.mm
    bx(ents, x - SW / 2, yw, stud_z, SW, SD, STUD_H, l_stud)
    metal_l(ents, x, yw, stud_z, :x_wall, side, SW, SD, CA, CB, CT, l_conn)
    x += SP
  end
end

# ── 5. СТІЙКИ Y-СТІН (поздовжні, x=0 та x=OW) ───────────────
[[0, :left], [OW - SD, :right]].each do |xw, side|
  y = BP_D + SP
  while y < OL - BP_D - SW / 2 + 0.5.mm
    bx(ents, xw, y - SW / 2, stud_z, SD, SW, STUD_H, l_stud)
    metal_l(ents, xw, y, stud_z, :y_wall, side, SW, SD, CA, CB, CT, l_conn)
    y += SP
  end
end

# ── 6. ГОРИЗОНТАЛЬНИЙ БЛОКІНГ МІЖ СТІЙКАМИ (середина) ────────
gap = SP - SW

# X-стіни
[[0, :x_wall], [OL - SD, :x_wall]].each do |yw, _|
  x = SP
  while x < OW - SW
    bx(ents, x + SW / 2, yw, mid_z, gap, SD, SW, l_blk)
    x += SP
  end
end

# Y-стіни
[[0, :y_wall], [OW - SD, :y_wall]].each do |xw, _|
  y = BP_D + SP
  while y < OL - BP_D - SW / 2
    bx(ents, xw, y + SW / 2, mid_z, SD, gap, SW, l_blk) if gap > 1.mm
    y += SP
  end
end

# ── 7. ВЕРХНЯ ОБВ'ЯЗКА 50×150 ────────────────────────────────
bx(ents, 0,        0,         tp_z, OW, TP_D, TP_H, l_tp)
bx(ents, 0,        OL - TP_D, tp_z, OW, TP_D, TP_H, l_tp)
bx(ents, 0,        TP_D,      tp_z, TP_D, OL - 2 * TP_D, TP_H, l_tp)
bx(ents, OW - TP_D, TP_D,     tp_z, TP_D, OL - 2 * TP_D, TP_H, l_tp)

# ── 8. П'ЯТОЧКИ (рафтер-сідла) ───────────────────────────────
y = 0.0
while y <= OL + 0.5.mm
  bx(ents, 0,           y - RW / 2, wh, TP_D, RW, HEEL_H, l_heel)
  bx(ents, OW - TP_D,   y - RW / 2, wh, TP_D, RW, HEEL_H, l_heel)
  # Металева скоба кроквини на п'яточці
  bx(ents, 0,           y - RW / 2 - CT, wh, CT, RW + 2 * CT, HEEL_H + CA, l_conn)
  bx(ents, OW - CT,     y - RW / 2 - CT, wh, CT, RW + 2 * CT, HEEL_H + CA, l_conn)
  y += SP
end

# ── 9. КРОКВИ 50×200 @ 600мм, кут 35° ───────────────────────
dx_d =  sin_p * RH
dz_d = -cos_p * RH

y = 0.0
while y <= OL + 0.5.mm
  y0 = y - RW / 2.0

  # Ліва кроква
  gl = ents.add_group; gl.layer = l_raft; ge = gl.entities
  p0 = Geom::Point3d.new(0,                      y0, heel_z_r)
  p1 = Geom::Point3d.new(dx_d,                   y0, heel_z_r + dz_d)
  p2 = Geom::Point3d.new(dx_d + cos_p * rlen,    y0, heel_z_r + dz_d + sin_p * rlen)
  p3 = Geom::Point3d.new(cos_p * rlen,            y0, heel_z_r + sin_p * rlen)
  fl = ge.add_face([p0, p1, p2, p3])
  fl.reverse! if fl && fl.normal.y > 0
  fl.pushpull(RW) if fl

  # Права кроква (дзеркало по X)
  gr = ents.add_group; gr.layer = l_raft; ge2 = gr.entities
  p0r = Geom::Point3d.new(OW,                        y0, heel_z_r)
  p1r = Geom::Point3d.new(OW - dx_d,                 y0, heel_z_r + dz_d)
  p2r = Geom::Point3d.new(OW - dx_d - cos_p * rlen,  y0, heel_z_r + dz_d + sin_p * rlen)
  p3r = Geom::Point3d.new(OW - cos_p * rlen,          y0, heel_z_r + sin_p * rlen)
  fr = ge2.add_face([p0r, p1r, p2r, p3r])
  fr.reverse! if fr && fr.normal.y < 0
  fr.pushpull(RW) if fr

  # Металева конькова скоба (ridge strap)
  bx(ents, OW / 2 - CT / 2, y0, ridge_z - 100.mm, CT, RW, 100.mm, l_conn)

  y += SP
end

# ── 10. КОНЬОК — подвійний 50×200 ────────────────────────────
bx(ents, OW / 2 - RW,  0, ridge_z, RW, OL, RH, l_ridge)
bx(ents, OW / 2,        0, ridge_z, RW, OL, RH, l_ridge)

model.commit_operation

puts "=== Barnhouse 6500×7000 готовий! ==="
puts "Стійка:  #{STUD_H.to_i} мм (чиста)"
puts "Загальна висота до верху обв.: #{wh.to_i} мм"
puts "Конек Z = #{ridge_z.round} мм від підлоги"
puts "Кут даху: #{PITCH_DEG}°"
