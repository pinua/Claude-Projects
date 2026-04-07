# ============================================================
#  BARNHOUSE FRAME — 6500 × 7000 мм, висота 2500 мм
#  Система: стійки 50×150 @ 600мм + кроквяні ферми (трикут.)
#  1 поверх, двосхилий дах, стиль barnhouse
# ============================================================
#  ЗАПУСК: Window → Ruby Console
#    load 'C:/path/barnhouse_preview_6500x7000.rb'
# ============================================================

require 'sketchup'

model = Sketchup.active_model
model.start_operation('Barnhouse 6500x7000', true)
ents  = model.entities
lyrs  = model.layers

# ── ПАРАМЕТРИ ───────────────────────────────────────────────
OW     = 6500.mm   # ширина (X)
OL     = 7000.mm   # довжина (Y)
WH     = 2500.mm   # висота по верху подвійної верхньої плити

# Стійки / плити  50 × 150 мм
SW     = 50.mm     # ширина (вздовж стіни)
SD     = 150.mm    # глибина (вглиб стіни)
SP     = 600.mm    # шаг стійок ц/ц

# Ферма
PITCH_DEG = 35.0
RAFTER_W  = 50.mm
RAFTER_H  = 150.mm
CHORD_W   = 50.mm
CHORD_H   = 150.mm

# Фундаментна плита
SLAB_H  = 200.mm

# Шари
l_slab  = lyrs['00 Фундамент']       || lyrs.add('00 Фундамент')
l_floor = lyrs['01 Лаги підлоги']    || lyrs.add('01 Лаги підлоги')
l_wall  = lyrs['02 Стійки/Плити']    || lyrs.add('02 Стійки/Плити')
l_truss = lyrs['03 Ферми даху']      || lyrs.add('03 Ферми даху')
l_ridge = lyrs['04 Коньок']          || lyrs.add('04 Коньок')

pitch  = PITCH_DEG * Math::PI / 180.0
half   = OW / 2.0
rise   = half * Math.tan(pitch)
ridge_z = WH + rise
rlen    = Math.sqrt(half**2 + rise**2)   # довжина кроквини

# ── HELPER: box ─────────────────────────────────────────────
def bx(ents, x, y, z, dx, dy, dz, layer)
  return if [dx,dy,dz].any?{|v| v.abs < 0.5.mm }
  g = ents.add_group; g.layer = layer
  pts = [Geom::Point3d.new(x,y,z), Geom::Point3d.new(x+dx,y,z),
         Geom::Point3d.new(x+dx,y+dy,z), Geom::Point3d.new(x,y+dy,z)]
  f = g.entities.add_face(pts)
  return unless f
  f.reverse! if f.normal.z < 0
  f.pushpull(dz); g
end

# ── 0. ФУНДАМЕНТНА ПЛИТА ─────────────────────────────────────
bx(ents, 0, 0, -SLAB_H, OW, OL, SLAB_H, l_slab)

# ── 1. ЛАГИ ПІДЛОГИ  50×200 @ 600мм ─────────────────────────
jh = 200.mm; jw = 50.mm
joist_span = OW - 2*SD
y = 0.0
while y <= OL + 0.5.mm
  bx(ents, SD, y - jw/2, 0, joist_span, jw, jh, l_floor)
  y += SP
end

# ──────────────────────────────────────────────────────────────
# 2. СТІНИ
#    Нижня плита (bottom plate):   50×150, Z=jh
#    Стійки:                       50×150, від Z=jh+SW до Z=WH-SW*2
#    Подвійна верхня плита (top):  2 × 50×150 зверху
# ──────────────────────────────────────────────────────────────
bp_z  = jh               # низ нижньої плити
bp_h  = SW               # висота плити = 50мм
stud_z = bp_z + bp_h     # низ стійок
tp_h  = SW * 2           # подвійна верхня плита = 100мм
stud_h = WH - stud_z - tp_h   # висота стійки

# -- X-стіни (ширина OW, глибина SD по Y) --
[0, OL - SD].each do |yw|
  # Нижня плита
  bx(ents, 0, yw, bp_z, OW, SD, bp_h, l_wall)
  # Верхня плита (подвійна)
  bx(ents, 0, yw, WH - tp_h, OW, SD, tp_h, l_wall)
  # Стійки
  x = 0.0
  while x <= OW + 0.5.mm
    bx(ents, x - SW/2, yw, stud_z, SW, SD, stud_h, l_wall)
    x += SP
  end
  # Кутові стійки примусово
  [0, OW - SW].each{|cx| bx(ents, cx, yw, stud_z, SW, SD, stud_h, l_wall)}
end

# -- Y-стіни (довжина OL, глибина SD по X) --
[0, OW - SD].each do |xw|
  # Нижня плита
  bx(ents, xw, SD, bp_z, SD, OL - 2*SD, bp_h, l_wall)
  # Верхня плита (подвійна)
  bx(ents, xw, SD, WH - tp_h, SD, OL - 2*SD, tp_h, l_wall)
  # Стійки
  y = SP
  while y < OL - SP + 0.5.mm
    bx(ents, xw, y - SW/2, stud_z, SD, SW, stud_h, l_wall)
    y += SP
  end
end

# ──────────────────────────────────────────────────────────────
# 3. КРОКВЯНІ ФЕРМИ @ 600мм
#    Нижній пояс (bottom chord): 50×150 горизонтально
#    Ліва / права кроквина:      50×150 під кутом
#    Бабка (king post):          50×150 вертикально по центру
#    Підкоси (webs):             50×100 діагонально
# ──────────────────────────────────────────────────────────────
cos_p = half  / rlen
sin_p = rise  / rlen

def truss(ents, y0, ow, wh, ridge_z, cos_p, sin_p, rlen, rw, rh, layer)
  tw = rw; th = rh
  half = ow / 2.0
  rise = ridge_z - wh

  # Нижній пояс
  g = ents.add_group; g.layer = layer
  pts = [Geom::Point3d.new(0, y0, wh), Geom::Point3d.new(ow, y0, wh),
         Geom::Point3d.new(ow, y0+tw, wh), Geom::Point3d.new(0, y0+tw, wh)]
  f = g.entities.add_face(pts); f.reverse! if f && f.normal.z < 0
  f.pushpull(-th) if f   # вниз

  # Ліва кроквина — переріз у XZ, pushpull по Y
  dx_d =  sin_p * th
  dz_d = -cos_p * th
  gl = ents.add_group; gl.layer = layer; ge = gl.entities
  p0 = Geom::Point3d.new(0,             y0, wh)
  p1 = Geom::Point3d.new(dx_d,          y0, wh + dz_d)
  p2 = Geom::Point3d.new(dx_d + cos_p*rlen, y0, wh + dz_d + sin_p*rlen)
  p3 = Geom::Point3d.new(cos_p*rlen,    y0, wh + sin_p*rlen)
  fl = ge.add_face([p0,p1,p2,p3])
  fl.reverse! if fl && fl.normal.y > 0
  fl.pushpull(tw) if fl

  # Права кроквина
  gr = ents.add_group; gr.layer = layer; ge2 = gr.entities
  p0r = Geom::Point3d.new(ow,                    y0, wh)
  p1r = Geom::Point3d.new(ow - dx_d,             y0, wh + dz_d)
  p2r = Geom::Point3d.new(ow - dx_d - cos_p*rlen, y0, wh + dz_d + sin_p*rlen)
  p3r = Geom::Point3d.new(ow - cos_p*rlen,       y0, wh + sin_p*rlen)
  fr = ge2.add_face([p0r,p1r,p2r,p3r])
  fr.reverse! if fr && fr.normal.y < 0
  fr.pushpull(tw) if fr

  # Бабка (king post) — центр, від нижнього поясу до конька
  gk = ents.add_group; gk.layer = layer
  ptsk = [Geom::Point3d.new(half - tw/2, y0, wh - th),
          Geom::Point3d.new(half + tw/2, y0, wh - th),
          Geom::Point3d.new(half + tw/2, y0+tw, wh - th),
          Geom::Point3d.new(half - tw/2, y0+tw, wh - th)]
  fk = gk.entities.add_face(ptsk)
  fk.reverse! if fk && fk.normal.z < 0
  fk.pushpull(ridge_z - wh + th) if fk

  # Підкоси (queen posts) — на чверть прольоту
  [half/2, ow - half/2].each do |qx|
    gq = ents.add_group; gq.layer = layer
    ptsq = [Geom::Point3d.new(qx - tw/2, y0, wh - th),
            Geom::Point3d.new(qx + tw/2, y0, wh - th),
            Geom::Point3d.new(qx + tw/2, y0+tw, wh - th),
            Geom::Point3d.new(qx - tw/2, y0+tw, wh - th)]
    fq = gq.entities.add_face(ptsq)
    fq.reverse! if fq && fq.normal.z < 0
    # Висота до кроквини в цій точці
    qz = if qx <= half
      wh + (qx / half) * rise
    else
      wh + ((ow - qx) / half) * rise
    end
    fq.pushpull(qz - (wh - th)) if fq
  end
end

# Ферми на кожному кроці
y = 0.0
while y <= OL + 0.5.mm
  truss(ents, y - RAFTER_W/2,
        OW, WH, ridge_z, cos_p, sin_p, rlen,
        RAFTER_W, RAFTER_H, l_truss)
  y += SP
end

# ── 4. КОНЬОК — 50×200 по Y, центр X ──────────────────────
bx(ents, OW/2 - 25.mm, 0, ridge_z, 50.mm, OL, 200.mm, l_ridge)

model.commit_operation

puts "=== Barnhouse 6500×7000 готовий! ==="
puts "Висота стіни: #{WH}мм  |  Коньок: #{ridge_z.round}мм"
puts "Кут: #{PITCH_DEG}°  |  Кроквина: #{rlen.round}мм"
puts "Ферм: #{(OL/SP).ceil + 1}"
