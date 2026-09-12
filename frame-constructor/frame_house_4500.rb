# ============================================================
#  КАРКАСНИЙ БУДИНОК 4500 × 10000 мм  —  1 поверх, 2-схилий дах
#  Система: стійки NO_100×200 + рейки Stoika_50×150
#  Стиль: 7_10.skp (прямокутний брус)
# ============================================================
#  ЗАПУСК:
#    Window → Ruby Console → load 'C:/path/frame_house_4500.rb'
# ============================================================

require 'sketchup'

# ── ПАРАМЕТРИ ───────────────────────────────────────────────
OW   = 4500.mm   # ширина (X)  — зовнішній габарит
OL   = 10000.mm  # довжина (Y) — зовнішній габарит
WH   = 2500.mm   # висота стіни

# Стійки NO_100×200  (100 — вздовж стіни, 200 — вглиб стіни)
POST_W = 100.mm
POST_D = 200.mm

# Рейки Stoika_50×150  (50 — висота, 150 — вглиб стіни)
RAIL_H = 50.mm
RAIL_D = 150.mm

# Лаги підлоги Laga_50×200
JOIST_W = 50.mm
JOIST_H = 200.mm

# Крокви Krokva_50×200
RAFTER_W = 50.mm
RAFTER_H = 200.mm

# Коньок Konek_50×200 (подвійний)
RIDGE_W = 50.mm
RIDGE_H = 200.mm

# Шаг стійок та лаг (по центру)
SP   = 600.mm   # 600 мм ц/ц

# Крок рейок по висоті
RAIL_SP = 635.mm  # з/з

# Кут нахилу даху
PITCH_DEG = 35.0

# ── HELPER ──────────────────────────────────────────────────
def fhb(ents, x, y, z, dx, dy, dz, layer)
  return if [dx, dy, dz].any? { |v| v.abs < 0.1.mm }
  g  = ents.add_group
  g.layer = layer
  pts = [
    Geom::Point3d.new(x,      y,      z),
    Geom::Point3d.new(x + dx, y,      z),
    Geom::Point3d.new(x + dx, y + dy, z),
    Geom::Point3d.new(x,      y + dy, z)
  ]
  f = g.entities.add_face(pts)
  return g unless f
  f.reverse! if f.normal.z < 0
  f.pushpull(dz)
  g
end

# ── ОСНОВНИЙ СКРИПТ ─────────────────────────────────────────
model = Sketchup.active_model
model.start_operation('Frame House 4500x10000', true)
ents  = model.entities
lyrs  = model.layers

# Шари / теги
l_post  = lyrs['01 Стійки NO_100x200']  || lyrs.add('01 Стійки NO_100x200')
l_rail  = lyrs['02 Рейки Stoika_50x150']|| lyrs.add('02 Рейки Stoika_50x150')
l_blk   = lyrs['03 Блокінг 50x150/200'] || lyrs.add('03 Блокінг 50x150/200')
l_floor = lyrs['04 Лаги Laga_50x200']   || lyrs.add('04 Лаги Laga_50x200')
l_roof  = lyrs['05 Крокви Krokva_50x200']|| lyrs.add('05 Крокви Krokva_50x200')
l_ridge = lyrs['06 Коньок Konek_50x200']|| lyrs.add('06 Коньок Konek_50x200')

pitch = PITCH_DEG * Math::PI / 180.0

# ──────────────────────────────────────────────────────────
# 1. ЛАГИ ПІДЛОГИ — span по X всередині стін
#    Y шаг = SP, від y=0 до y=OL
# ──────────────────────────────────────────────────────────
joist_span = OW - 2 * POST_D   # внутрішній проліт
joist_x    = POST_D             # починається за внутрішнім краєм стійки

y = 0.0
while y <= OL + 0.1.mm
  fhb(ents, joist_x, y - JOIST_W / 2.0, 0, joist_span, JOIST_W, JOIST_H, l_floor)
  y += SP
end

# ──────────────────────────────────────────────────────────
# 2. СТІНИ
#    X-стіни: y=0  та  y=OL  (ширина OW)
#    Y-стіни: x=0  та  x=OW  (довжина OL)
# ──────────────────────────────────────────────────────────

# Рівні рейок по висоті (від верху лаги)
floor_top = JOIST_H
rail_levels = []
z = floor_top
while z < WH - RAIL_H
  rail_levels << z
  z += RAIL_SP
end
# Верхня обв'язка (подвійна) — дві рейки нагорі
rail_levels << (WH - 2 * RAIL_H)
rail_levels << (WH - RAIL_H)
rail_levels.uniq!.sort!

# ── 2a. X-стіни (стійки вздовж X) ──
[0, OL].each do |yw|
  # Координати: POST_D вглиб = вздовж Y
  # Стійки від x=0 до x=OW з кроком SP
  x = 0.0
  while x <= OW + 0.1.mm
    fhb(ents, x - POST_W / 2.0, yw, floor_top,
        POST_W, POST_D, WH - floor_top, l_post)
    x += SP
  end
  # примусово куток OW
  fhb(ents, OW - POST_W / 2.0, yw, floor_top,
      POST_W, POST_D, WH - floor_top, l_post) if (OW % SP).abs > 1.mm

  # Рейки по висоті (суцільні по всій ширині)
  rail_levels.each do |zr|
    fhb(ents, 0, yw, zr, OW, RAIL_D, RAIL_H, l_rail)
  end
end

# ── 2b. Y-стіни (стійки вздовж Y) ──
[0, OW].each do |xw|
  # POST_D вглиб = вздовж X
  post_x = (xw == 0) ? 0 : xw - POST_D
  y = 0.0
  while y <= OL + 0.1.mm
    fhb(ents, post_x, y - POST_W / 2.0, floor_top,
        POST_D, POST_W, WH - floor_top, l_post)
    y += SP
  end
  fhb(ents, post_x, OL - POST_W / 2.0, floor_top,
      POST_D, POST_W, WH - floor_top, l_post) if (OL % SP).abs > 1.mm

  # Рейки по висоті (суцільні по всій довжині)
  rail_levels.each do |zr|
    rx = (xw == 0) ? 0 : xw - RAIL_D
    fhb(ents, rx, 0, zr, RAIL_D, OL, RAIL_H, l_rail)
  end
end

# ──────────────────────────────────────────────────────────
# 3. ДАХ — Крокви + Коньок
#    Конек по центру X=OW/2, Z = WH + (OW/2 - POST_D)*tan(pitch)
#    Крокви Krokva_50×200, шаг SP по Y
# ──────────────────────────────────────────────────────────
ridge_z     = WH + (OW / 2.0 - POST_D) * Math.tan(pitch)
half_run    = OW / 2.0 - POST_D           # горизонтальний проліт від стіни до конька
rafter_len  = Math.sqrt(half_run**2 + (ridge_z - WH)**2)

cos_p = half_run  / rafter_len
sin_p = (ridge_z - WH) / rafter_len

# Коньок: дві паралельні дошки 50×200 по Y
fhb(ents, OW / 2.0 - RIDGE_W,     0, ridge_z, RIDGE_W, OL, RIDGE_H, l_ridge)
fhb(ents, OW / 2.0,               0, ridge_z, RIDGE_W, OL, RIDGE_H, l_ridge)

# Крокви
y = 0.0
while y <= OL + 0.1.mm
  y0 = y - RAFTER_W / 2.0

  # Ліва кроква (від x=POST_D до x=OW/2, нахил вліво-вгору)
  # Малюємо перерізну грань у XZ площині, потім pushpull по Y
  g_left = ents.add_group
  g_left.layer = l_roof
  ge = g_left.entities

  # Точки перерізу (за годинниковою)
  # Нижній лівий кут кроквини — зовнішній, нижній
  bx = POST_D.to_f
  bz = WH.to_f
  # Вектор вздовж кроквини: (cos_p, 0, sin_p)
  # Вектор перпендикулярно вглиб перерізу (= товщина 200 по нормалі до осі)
  # depth вектор = (sin_p, 0, -cos_p) * RAFTER_H
  dx_d =  sin_p * RAFTER_H
  dz_d = -cos_p * RAFTER_H

  p0 = Geom::Point3d.new(bx,            y0,                0)
  p1 = Geom::Point3d.new(bx + dx_d,     y0,                dz_d)
  p2 = Geom::Point3d.new(bx + dx_d + cos_p * rafter_len, y0, dz_d + sin_p * rafter_len)
  p3 = Geom::Point3d.new(bx + cos_p * rafter_len,        y0, sin_p * rafter_len)

  # Зсуваємо p0/p3 по Z до рівня WH
  p0 = Geom::Point3d.new(bx,                              y0, bz)
  p1 = Geom::Point3d.new(bx + dx_d,                       y0, bz + dz_d)
  p2 = Geom::Point3d.new(bx + dx_d + cos_p * rafter_len, y0, bz + dz_d + sin_p * rafter_len)
  p3 = Geom::Point3d.new(bx + cos_p * rafter_len,        y0, bz + sin_p * rafter_len)

  f = ge.add_face([p0, p1, p2, p3])
  if f
    f.reverse! if f.normal.y > 0
    f.pushpull(RAFTER_W)
  end

  # Права кроква (дзеркало по X)
  g_right = ents.add_group
  g_right.layer = l_roof
  ge2 = g_right.entities

  bx2 = OW - POST_D
  p0r = Geom::Point3d.new(bx2,                               y0, bz)
  p1r = Geom::Point3d.new(bx2 - dx_d,                        y0, bz + dz_d)
  p2r = Geom::Point3d.new(bx2 - dx_d - cos_p * rafter_len,  y0, bz + dz_d + sin_p * rafter_len)
  p3r = Geom::Point3d.new(bx2 - cos_p * rafter_len,         y0, bz + sin_p * rafter_len)

  f2 = ge2.add_face([p0r, p1r, p2r, p3r])
  if f2
    f2.reverse! if f2.normal.y < 0
    f2.pushpull(RAFTER_W)
  end

  y += SP
end

model.commit_operation
puts "=== Готово! 4500x10000 одноповерховий будинок ==="
puts "Конек: Z = #{(ridge_z / 25.4).round(1)} in / #{ridge_z.round} mm"
puts "Кут: #{PITCH_DEG}°  |  Проліт кроквини: #{rafter_len.round} mm"
