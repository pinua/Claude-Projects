# ============================================================
# КОНСТРУКТОР КАРКАСНОГО БУДИНКУ / Frame House Constructor
# Розмір: 4500 × 10000 мм
# Конструкція: I-joist підлога, каркасні стіни, двосхилий дах 35°
#
# ЗАПУСК у SketchUp:
#   Window → Ruby Console → load 'C:/path/to/frame_house.rb'
#   або Extensions → Execute Script
# ============================================================

# ── Допоміжні методи ────────────────────────────────────────

# Прямокутний брус: початок (x,y,z), розміри (dx,dy,dz)
def fh_box(ents, x, y, z, dx, dy, dz, layer = nil)
  return if dx <= 0 || dy <= 0 || dz <= 0
  g = ents.add_group
  g.layer = layer if layer
  pts = [
    Geom::Point3d.new(x,    y,    z),
    Geom::Point3d.new(x+dx, y,    z),
    Geom::Point3d.new(x+dx, y+dy, z),
    Geom::Point3d.new(x,    y+dy, z)
  ]
  f = g.entities.add_face(pts)
  return g unless f
  f.reverse! if f.normal.z < 0
  f.pushpull(dz)
  g
end

# I-joist уздовж осі X: переріз у площині YZ
# x0..x0+len — проліт, ij_fw×ij_h — ширина×висота
def fh_ij_x(ents, x0, y0, z0, len, h, fw, fh, wt, layer = nil)
  return if len <= 0
  wx = (fw - wt) / 2.0
  fh_box(ents, x0, y0,    z0,        len, fw, fh,         layer) # нижня полка
  fh_box(ents, x0, y0+wx, z0+fh,     len, wt, h - 2.0*fh, layer) # стінка
  fh_box(ents, x0, y0,    z0+h-fh,   len, fw, fh,         layer) # верхня полка
end

# I-joist уздовж осі Y: переріз у площині XZ
def fh_ij_y(ents, x0, y0, z0, len, h, fw, fh, wt, layer = nil)
  return if len <= 0
  wx = (fw - wt) / 2.0
  fh_box(ents, x0,    y0, z0,        fw, len, fh,         layer)
  fh_box(ents, x0+wx, y0, z0+fh,     wt, len, h - 2.0*fh, layer)
  fh_box(ents, x0,    y0, z0+h-fh,   fw, len, fh,         layer)
end

# Стійки вздовж X-стіни: крайні кутові + регулярні
def fh_studs_x(ents, x0, y0, z0, wall_len, stud_h, lt, lw, sp, layer)
  fh_box(ents, x0, y0, z0, lt, lw, stud_h, layer)            # кутова стійка start
  sx = x0 + sp
  while sx < x0 + wall_len - lt - 0.001.mm
    fh_box(ents, sx, y0, z0, lt, lw, stud_h, layer)
    sx += sp
  end
  fh_box(ents, x0 + wall_len - lt, y0, z0, lt, lw, stud_h, layer) # кутова стійка end
end

# Стійки вздовж Y-стіни
def fh_studs_y(ents, x0, y0, z0, wall_len, stud_h, lt, lw, sp, layer)
  fh_box(ents, x0, y0, z0, lw, lt, stud_h, layer)
  sy = y0 + sp
  while sy < y0 + wall_len - lt - 0.001.mm
    fh_box(ents, x0, sy, z0, lw, lt, stud_h, layer)
    sy += sp
  end
  fh_box(ents, x0, y0 + wall_len - lt, z0, lw, lt, stud_h, layer)
end

def fh_get_layer(model, name)
  model.layers[name] || model.layers.add(name)
end

# ── Головна функція ──────────────────────────────────────────

def build_frame_house
  model = Sketchup.active_model
  model.start_operation('Frame House Constructor', true)

  begin
    ents = model.active_entities

    # ════════════════════════════════════════════
    # ПАРАМЕТРИ / PARAMETERS
    # ════════════════════════════════════════════

    ow = 4500.mm    # ширина по зовнішньому каркасу (X)
    ol = 10000.mm   # довжина (Y)
    wh = 2700.mm    # висота стін (від підлоги до верху подвійної обв'язки)

    lt = 45.mm      # товщина дошки (мм)
    lw = 145.mm     # ширина дошки (мм)  — товщина стіни

    ij_h  = 200.mm  # висота I-joist
    ij_fh = 38.mm   # товщина полки (flange)
    ij_fw = 45.mm   # ширина полки
    ij_wt = 9.mm    # товщина стінки (web)

    joist_sp  = 600.mm   # крок підлогових балок
    stud_sp   = 600.mm   # крок стійок
    rafter_sp = 600.mm   # крок крокв

    pitch_deg = 35.0
    pitch_rad = pitch_deg * Math::PI / 180.0
    sin_p = Math.sin(pitch_rad)
    cos_p = Math.cos(pitch_rad)
    tan_p = Math.tan(pitch_rad)

    # ════════════════════════════════════════════
    # ВЕРТИКАЛЬНІ РІВНІ / LEVELS
    # ════════════════════════════════════════════

    z_floor  = 0.mm              # низ підлогових балок
    z_wall   = z_floor + ij_h    # верх підлоги = низ стін
    stud_h   = wh - 3.0 * lt    # висота стійок (3 плити: 1 нижня + 2 верхні)
    z_top    = z_wall + wh       # верх подвійної верхньої обв'язки
    ridge_h  = (ow / 2.0) * tan_p  # висота конька над верхньою обв'язкою
    z_ridge  = z_top + ridge_h   # абсолютна висота конька
    rafter_len = (ow / 2.0) / cos_p  # довжина крокви

    # ════════════════════════════════════════════
    # ШАРИ / TAGS
    # ════════════════════════════════════════════

    l_floor = fh_get_layer(model, '01 Підлогові балки')
    l_walls = fh_get_layer(model, '02 Стіни')
    l_roof  = fh_get_layer(model, '03 Дах')

    # ════════════════════════════════════════════
    # 1. ПІДЛОГА / FLOOR SYSTEM
    # ════════════════════════════════════════════
    #
    # I-joists:  проліт уздовж X (4500мм), крок 600мм уздовж Y
    # Rim board: суцільний LVL по боках X=−lt та X=ow

    joist_positions = [0.mm]
    yp = joist_sp
    while yp < ol - ij_fw - 0.001.mm
      joist_positions << yp
      yp += joist_sp
    end
    joist_positions << (ol - ij_fw)  # остання (rim) балка

    joist_positions.each do |y_pos|
      fh_ij_x(ents, 0, y_pos, z_floor, ow, ij_h, ij_fw, ij_fh, ij_wt, l_floor)
    end

    # Бокові обв'язки (rim / band joist) — суцільний LVL, та сама глибина
    fh_box(ents, -lt, 0, z_floor, lt, ol, ij_h, l_floor)  # ліва
    fh_box(ents,  ow, 0, z_floor, lt, ol, ij_h, l_floor)  # права

    # ════════════════════════════════════════════
    # 2. СТІНИ / WALL FRAMING
    # ════════════════════════════════════════════
    #
    # Передня (y=0) та задня (y=ol−lw) — уздовж X, повна ширина ow
    # Ліва  (x=0)  та права (x=ow−lw) — уздовж Y, між торцевими стінами

    [0, ol - lw].each do |wy|                               # торцеві стіни (X)
      fh_box(ents, 0, wy, z_wall,                  ow, lw, lt,     l_walls) # нижня обв'язка
      fh_studs_x(ents, 0, wy, z_wall + lt,         ow, stud_h, lt, lw, stud_sp, l_walls)
      fh_box(ents, 0, wy, z_wall + lt + stud_h,    ow, lw, lt,     l_walls) # верхня обв'язка 1
      fh_box(ents, 0, wy, z_wall + lt + stud_h + lt, ow, lw, lt,   l_walls) # верхня обв'язка 2
    end

    side_y0 = lw                    # бокові стіни починаються після торцевих
    side_len = ol - 2.0 * lw

    [0, ow - lw].each do |wx|                               # бокові стіни (Y)
      fh_box(ents, wx, side_y0, z_wall,                  lw, side_len, lt,     l_walls)
      fh_studs_y(ents, wx, side_y0, z_wall + lt,         side_len, stud_h, lt, lw, stud_sp, l_walls)
      fh_box(ents, wx, side_y0, z_wall + lt + stud_h,    lw, side_len, lt,     l_walls)
      fh_box(ents, wx, side_y0, z_wall + lt + stud_h + lt, lw, side_len, lt,   l_walls)
    end

    # ════════════════════════════════════════════
    # 3. ДАХ / ROOF FRAMING
    # ════════════════════════════════════════════
    #
    # Коник (ridge board): 45×145мм по всій довжині
    # Крокви (rafters):    45×145мм, крок 600мм
    #   Ліві — від x=0, z=z_top  до  x=ow/2, z=z_ridge
    #   Праві — від x=ow, z=z_top до  x=ow/2, z=z_ridge

    ridge_x = ow / 2.0 - lt / 2.0
    fh_box(ents, ridge_x, 0, z_ridge, lt, ol, lw, l_roof)

    # Вектори глибини крокви (⊥ до осі крокви в площині XZ)
    # Ліва крокв: вісь = (cos_p, 0, sin_p)  → глибина = (sin_p, 0, −cos_p)
    # Права крокв: вісь = (−cos_p, 0, sin_p) → глибина = (−sin_p, 0, −cos_p)
    dxl =  sin_p * lw;  dzl = -cos_p * lw
    dxr = -sin_p * lw;  dzr = -cos_p * lw

    ry = 0.mm
    while ry <= ol + 0.001.mm

      # ── Ліва крокв ──
      gl = ents.add_group
      gl.layer = l_roof
      fl = gl.entities.add_face(
        Geom::Point3d.new(0,   ry,      z_top),
        Geom::Point3d.new(0,   ry + lt, z_top),
        Geom::Point3d.new(dxl, ry + lt, z_top + dzl),
        Geom::Point3d.new(dxl, ry,      z_top + dzl)
      )
      if fl
        fl.reverse! if fl.normal.dot(Geom::Vector3d.new(cos_p, 0, sin_p)) < 0
        fl.pushpull(rafter_len)
      end

      # ── Права крокв ──
      gr = ents.add_group
      gr.layer = l_roof
      fr = gr.entities.add_face(
        Geom::Point3d.new(ow,        ry,      z_top),
        Geom::Point3d.new(ow,        ry + lt, z_top),
        Geom::Point3d.new(ow + dxr,  ry + lt, z_top + dzr),
        Geom::Point3d.new(ow + dxr,  ry,      z_top + dzr)
      )
      if fr
        fr.reverse! if fr.normal.dot(Geom::Vector3d.new(-cos_p, 0, sin_p)) < 0
        fr.pushpull(rafter_len)
      end

      ry += rafter_sp
    end

    # ════════════════════════════════════════════
    # СПЕЦИФІКАЦІЯ / BILL OF MATERIALS
    # ════════════════════════════════════════════

    n_joists      = joist_positions.size
    n_rafters     = ((ol / rafter_sp) / 1.mm).round + 1   # пар
    n_studs_end   = 2 * (((ow / stud_sp) / 1.mm).floor + 1) * 2   # торцеві стіни × 2
    n_studs_side  = 2 * (((side_len / stud_sp) / 1.mm).floor + 1) * 2  # бокові стіни × 2

    puts "\n" + "="*50
    puts "  СПЕЦИФІКАЦІЯ МАТЕРІАЛІВ / BILL OF MATERIALS"
    puts "="*50
    puts "  Будинок: #{(ow / 1.mm / 1000.0).round(2)} × #{(ol / 1.mm / 1000.0).round(2)} м"
    puts "  Висота стін: #{(wh / 1.mm / 1000.0).round(2)} м"
    puts "  Кут даху: #{pitch_deg}°  Висота конька: #{(z_ridge / 1.mm / 1000.0).round(2)} м від підлоги"
    puts ""
    puts "  ПІДЛОГА:"
    puts "    I-joist 45/9/45×200 L=#{(ow/1.mm/1000.0).round(2)}м:   #{n_joists} шт"
    puts "    Rim board 45×200 L=#{(ol/1.mm/1000.0).round(2)}м:       2 шт"
    puts ""
    puts "  СТІНИ (45×145мм):"
    puts "    Нижня обв'язка:  #{((2*ow + 2*side_len)/1.mm/1000.0).round(2)} м.п."
    puts "    Подвійна верхня: #{(2*(2*ow + 2*side_len)/1.mm/1000.0).round(2)} м.п."
    puts "    Стійки L=#{(stud_h/1.mm/1000.0).round(2)}м — торцеві стіни: ~#{n_studs_end} шт"
    puts "    Стійки L=#{(stud_h/1.mm/1000.0).round(2)}м — бокові стіни:  ~#{n_studs_side} шт"
    puts ""
    puts "  ДАХ (45×145мм):"
    puts "    Коник L=#{(ol/1.mm/1000.0).round(2)}м:                    1 шт"
    puts "    Крокви L=#{(rafter_len/1.mm/1000.0).round(2)}м:             #{n_rafters * 2} шт  (#{n_rafters} пар)"
    puts "="*50
    puts ""

    model.commit_operation
    UI.messagebox(
      "Frame House побудовано!\n\n" \
      "Розміри: 4500 × 10000 мм\n" \
      "Висота конька: #{(z_ridge/1.mm/1000.0).round(2)} м\n\n" \
      "Специфікацію дивіться у Ruby Console.\n" \
      "Шари: 01 Підлогові балки | 02 Стіни | 03 Дах"
    )

  rescue => err
    model.abort_operation
    UI.messagebox("Помилка побудови:\n#{err.message}\n\n#{err.backtrace[0..3].join("\n")}")
  end
end

build_frame_house
