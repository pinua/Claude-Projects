# ============================================================
# КОНСТРУКТОР КАРКАСНОГО БУДИНКУ — SI-MODULAR стиль
# Дерев'яний двутавр (Timber I-joist) для стін та даху
# Розмір: 4500 × 10000 мм  |  Основа: бетонна площадка
# Дах: двосхилий 35°
# ============================================================
# ЗАПУСК:  Window → Ruby Console → load 'C:/path/frame_house.rb'
# ============================================================

# ── ДОПОМІЖНІ МЕТОДИ ────────────────────────────────────────

# Прямокутний брус (LVL обв'язки, коник)
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

# Вертикальна двутаврова стійка для X-стіни (глибина в напрямку Y)
#   x0, y0    — позиція стійки (зовнішня полка)
#   z0        — низ стійки
#   h         — висота стійки
#   d         — глибина двутавра (= товщина стіни)
#   ff        — ширина полки (видима лиця стійки, вздовж X)
#   fd        — глибина полки (вздовж Y)
#   wt        — товщина стінки (вздовж X)
def fh_stud_x(ents, x0, y0, z0, h, d, ff, fd, wt, layer = nil)
  wx = (ff - wt) / 2.0
  fh_box(ents, x0, y0,           z0, ff, fd,       h, layer) # зовнішня полка
  fh_box(ents, x0 + wx, y0 + fd, z0, wt, d - 2*fd, h, layer) # стінка
  fh_box(ents, x0, y0 + d - fd,  z0, ff, fd,       h, layer) # внутрішня полка
end

# Вертикальна двутаврова стійка для Y-стіни (глибина в напрямку X)
def fh_stud_y(ents, x0, y0, z0, h, d, ff, fd, wt, layer = nil)
  wy = (ff - wt) / 2.0
  fh_box(ents, x0,           y0, z0, fd,       ff, h, layer) # зовнішня полка
  fh_box(ents, x0 + fd,      y0 + wy, z0, d - 2*fd, wt, h, layer) # стінка
  fh_box(ents, x0 + d - fd,  y0, z0, fd,       ff, h, layer) # внутрішня полка
end

# Ряд стійок уздовж X-стіни (з кутовими)
def fh_studs_row_x(ents, x0, y0, z0, wall_len, h, d, ff, fd, wt, sp, layer)
  fh_stud_x(ents, x0, y0, z0, h, d, ff, fd, wt, layer)           # кутова start
  sx = x0 + sp
  while sx + ff <= x0 + wall_len - ff - 0.001.mm
    fh_stud_x(ents, sx, y0, z0, h, d, ff, fd, wt, layer)
    sx += sp
  end
  fh_stud_x(ents, x0 + wall_len - ff, y0, z0, h, d, ff, fd, wt, layer) # кутова end
end

# Ряд стійок уздовж Y-стіни (з кутовими)
def fh_studs_row_y(ents, x0, y0, z0, wall_len, h, d, ff, fd, wt, sp, layer)
  fh_stud_y(ents, x0, y0, z0, h, d, ff, fd, wt, layer)
  sy = y0 + sp
  while sy + ff <= y0 + wall_len - ff - 0.001.mm
    fh_stud_y(ents, x0, sy, z0, h, d, ff, fd, wt, layer)
    sy += sp
  end
  fh_stud_y(ents, x0, y0 + wall_len - ff, z0, h, d, ff, fd, wt, layer)
end

# Похила двутаврова крокв (I-joist rafter) через pushpull перпендикулярної грані
#   x0, ry, z0        — початкова точка (нижня-зовнішня кутова)
#   rlen              — довжина крокви
#   fw                — ширина полки (вздовж Y = товщина крокви)
#   h, fh, wt         — висота / висота полки / товщина стінки
#   ax, az            — одиничний вектор осі крокви (X та Z компоненти)
#   dx, dz            — одиничний вектор глибини (⊥ осі в площині XZ)
#   layer
def fh_ij_rafter(ents, x0, ry, z0, rlen, fw, h, fh, wt, ax, az, dx, dz, layer)
  web_h = h - 2.0 * fh
  wyo   = (fw - wt) / 2.0
  exp   = Geom::Vector3d.new(ax, 0, az)

  # ── Нижня полка
  d1x = dx * fh;  d1z = dz * fh
  g1 = ents.add_group; g1.layer = layer
  f = g1.entities.add_face(
    Geom::Point3d.new(x0,       ry,      z0),
    Geom::Point3d.new(x0,       ry + fw, z0),
    Geom::Point3d.new(x0 + d1x, ry + fw, z0 + d1z),
    Geom::Point3d.new(x0 + d1x, ry,      z0 + d1z)
  )
  if f; f.reverse! if f.normal.dot(exp) < 0; f.pushpull(rlen); end

  # ── Стінка
  x1 = x0 + d1x;  z1 = z0 + d1z
  d2x = dx * web_h; d2z = dz * web_h
  g2 = ents.add_group; g2.layer = layer
  f = g2.entities.add_face(
    Geom::Point3d.new(x1,       ry + wyo,      z1),
    Geom::Point3d.new(x1,       ry + wyo + wt, z1),
    Geom::Point3d.new(x1 + d2x, ry + wyo + wt, z1 + d2z),
    Geom::Point3d.new(x1 + d2x, ry + wyo,      z1 + d2z)
  )
  if f; f.reverse! if f.normal.dot(exp) < 0; f.pushpull(rlen); end

  # ── Верхня полка
  x2 = x1 + d2x;  z2 = z1 + d2z
  g3 = ents.add_group; g3.layer = layer
  f = g3.entities.add_face(
    Geom::Point3d.new(x2,       ry,      z2),
    Geom::Point3d.new(x2,       ry + fw, z2),
    Geom::Point3d.new(x2 + d1x, ry + fw, z2 + d1z),
    Geom::Point3d.new(x2 + d1x, ry,      z2 + d1z)
  )
  if f; f.reverse! if f.normal.dot(exp) < 0; f.pushpull(rlen); end
end

def fh_get_layer(model, name)
  model.layers[name] || model.layers.add(name)
end

# ── ГОЛОВНА ФУНКЦІЯ ──────────────────────────────────────────

def build_frame_house
  model = Sketchup.active_model
  model.start_operation('Frame House SI-style', true)

  begin
    ents = model.active_entities

    # ════════════════════════════════════════════
    # ПАРАМЕТРИ / PARAMETERS
    # ════════════════════════════════════════════

    ow = 4500.mm    # зовнішня ширина (X)
    ol = 10000.mm   # зовнішня довжина (Y)
    wh = 2700.mm    # висота стін (від плити до верху подвійної обв'язки)

    # Двутаврова стійка (wall I-joist stud)
    ws_d  = 150.mm  # глибина двутавра = товщина стіни  ← 150мм
    ws_ff = 45.mm   # ширина полки (видима лиця)
    ws_fd = 38.mm   # глибина полки  (2×38=76, web=150-76=74мм)
    ws_wt = 9.mm    # товщина стінки

    # LVL обв'язки (plates)
    lt = 45.mm      # товщина плити

    # Двутаврова крокв (roof I-joist rafter)
    rf_h  = 200.mm  # загальна глибина  ← 200мм
    rf_fh = 38.mm   # висота полки
    rf_fw = 45.mm   # ширина (вздовж гребня = товщина крокви)
    rf_wt = 9.mm    # товщина стінки

    stud_sp   = 600.mm   # крок стійок по центру  ← 600мм c/c
    rafter_sp = 600.mm   # крок крокв по центру   ← 600мм c/c

    pitch_deg = 35.0
    pitch_rad = pitch_deg * Math::PI / 180.0
    sin_p = Math.sin(pitch_rad)
    cos_p = Math.cos(pitch_rad)
    tan_p = Math.tan(pitch_rad)

    # ════════════════════════════════════════════
    # РІВНІ / LEVELS  (основа = Z = 0)
    # ════════════════════════════════════════════

    z0    = 0.mm               # бетонна плита
    stud_h = wh - 3.0 * lt    # чиста висота стійок (3 плити: 1+2)
    z_top  = wh                # верх подвійної верхньої обв'язки
    ridge_h   = (ow / 2.0) * tan_p
    z_ridge   = z_top + ridge_h
    rafter_len = (ow / 2.0) / cos_p

    # ════════════════════════════════════════════
    # ШАРИ / TAGS
    # ════════════════════════════════════════════

    l_walls = fh_get_layer(model, '01 Стіни — двутавр')
    l_plate = fh_get_layer(model, '02 Обв\'язки — LVL')
    l_roof  = fh_get_layer(model, '03 Дах — двутавр')

    # ════════════════════════════════════════════
    # 1. СТІНИ / WALL FRAMING
    # ════════════════════════════════════════════
    #
    # Торцеві стіни (X): y = 0  та  y = ol − ws_d
    # Бокові стіни (Y):  x = 0  та  x = ow − ws_d
    #   між торцевими: від y = ws_d до y = ol − ws_d
    #
    # Кожна стіна:
    #   [a] Нижня LVL обв'язка   z = 0     висота lt
    #   [b] I-joist стійки       z = lt    висота stud_h
    #   [c] Верхня LVL обв'язка  z = lt+stud_h       висота lt
    #   [d] Подвійна верхня LVL  z = lt+stud_h+lt    висота lt

    z_stud  = lt                       # низ стійок
    z_tp1   = lt + stud_h              # низ верхньої обв'язки 1
    z_tp2   = lt + stud_h + lt         # низ верхньої обв'язки 2

    # — Торцеві стіни (вздовж X) ———————————————
    [0.mm, ol - ws_d].each do |wy|
      # LVL плити (нижня + 2 верхні)
      fh_box(ents, 0, wy, z0,   ow, ws_d, lt,  l_plate)   # нижня
      fh_box(ents, 0, wy, z_tp1, ow, ws_d, lt, l_plate)   # верхня 1
      fh_box(ents, 0, wy, z_tp2, ow, ws_d, lt, l_plate)   # верхня 2
      # I-joist стійки
      fh_studs_row_x(ents, 0, wy, z_stud, ow, stud_h,
                     ws_d, ws_ff, ws_fd, ws_wt, stud_sp, l_walls)
    end

    # — Бокові стіни (вздовж Y) ————————————————
    # Між торцевими стінами: y від ws_d до ol−ws_d
    side_y0  = ws_d
    side_len = ol - 2.0 * ws_d

    [0.mm, ow - ws_d].each do |wx|
      fh_box(ents, wx, side_y0, z0,    ws_d, side_len, lt, l_plate)
      fh_box(ents, wx, side_y0, z_tp1, ws_d, side_len, lt, l_plate)
      fh_box(ents, wx, side_y0, z_tp2, ws_d, side_len, lt, l_plate)
      fh_studs_row_y(ents, wx, side_y0, z_stud, side_len, stud_h,
                     ws_d, ws_ff, ws_fd, ws_wt, stud_sp, l_walls)
    end

    # ════════════════════════════════════════════
    # 2. ДАХ / ROOF FRAMING
    # ════════════════════════════════════════════
    #
    # Коник: LVL 45×145мм  по центру, вздовж Y
    # Крокви: I-joist 45fw/9web/200h  крок 600мм
    #   Ліві:  від (0,   ry, z_top) → (ow/2, ry, z_ridge)
    #   Праві: від (ow,  ry, z_top) → (ow/2, ry, z_ridge)

    # Коник (ridge board) — LVL 45×145мм
    ridge_board_w = 145.mm
    ridge_x = ow / 2.0 - lt / 2.0
    fh_box(ents, ridge_x, 0, z_ridge, lt, ol, ridge_board_w, l_roof)

    # Вектори осі та глибини крокв у площині XZ
    # Ліва  крокв: вісь → (+cos_p, 0, +sin_p), глибина → (+sin_p, 0, −cos_p)
    # Права крокв: вісь → (−cos_p, 0, +sin_p), глибина → (−sin_p, 0, −cos_p)
    l_ax = cos_p;  l_az = sin_p;  l_dx = sin_p;  l_dz = -cos_p
    r_ax = -cos_p; r_az = sin_p;  r_dx = -sin_p; r_dz = -cos_p

    ry = 0.mm
    while ry <= ol + 0.001.mm
      # Ліва крокв — починається на лівій стіні (x=0)
      fh_ij_rafter(ents, 0.mm,  ry, z_top, rafter_len,
                   rf_fw, rf_h, rf_fh, rf_wt,
                   l_ax, l_az, l_dx * rf_h, l_dz * rf_h, l_roof)

      # Права крокв — починається на правій стіні (x=ow)
      fh_ij_rafter(ents, ow,    ry, z_top, rafter_len,
                   rf_fw, rf_h, rf_fh, rf_wt,
                   r_ax, r_az, r_dx * rf_h, r_dz * rf_h, l_roof)

      ry += rafter_sp
    end

    # ════════════════════════════════════════════
    # СПЕЦИФІКАЦІЯ / BILL OF MATERIALS
    # ════════════════════════════════════════════

    n_rafters = ((ol / rafter_sp) / 1.mm).round + 1

    # Підрахунок стійок
    n_studs_end  = 2 * (((ow / stud_sp) / 1.mm).floor + 1) # на одну торцеву стіну
    n_studs_side = 2 * (((side_len / stud_sp) / 1.mm).floor + 1) # на одну бокову
    n_studs_total = 2 * n_studs_end + 2 * n_studs_side

    # Метри погонні обв'язок
    lm_plates = (3.0 * (2 * ow + 2 * side_len)) / 1.mm / 1000.0  # 3 плити × периметр

    puts "\n" + "="*54
    puts "  СПЕЦИФІКАЦІЯ / BILL OF MATERIALS"
    puts "  SI-MODULAR стиль — дерев'яний двутавр"
    puts "="*54
    puts "  Розмір: #{(ow/1.mm/1000.0).round(2)} × #{(ol/1.mm/1000.0).round(2)} м"
    puts "  Висота стін: #{(wh/1.mm/1000.0).round(2)} м  (стійки #{(stud_h/1.mm/1000.0).round(2)} м)"
    puts "  Кут даху: #{pitch_deg}°"
    puts "  Висота конька: #{(z_ridge/1.mm/1000.0).round(2)} м від підлоги"
    puts "  Довжина крокви: #{(rafter_len/1.mm/1000.0).round(2)} м"
    puts "-"*54
    puts "  СТІНИ (двутавр I-200 / 45-9-45):"
    puts "    Стійки L=#{(stud_h/1.mm/1000.0).round(2)}м, крок 600мм: #{n_studs_total} шт"
    puts "      — торцеві стіни (×2): #{n_studs_end} шт кожна"
    puts "      — бокові стіни (×2):  #{n_studs_side} шт кожна"
    puts "  ОБВЯЗКИ (LVL 45×200мм):"
    puts "    Нижня + подвійна верхня: #{lm_plates.round(1)} м.п."
    puts "-"*54
    puts "  ДАХ:"
    puts "    Коник LVL 45×145мм L=#{(ol/1.mm/1000.0).round(2)}м: 1 шт"
    puts "    Крокви I-200 L=#{(rafter_len/1.mm/1000.0).round(2)}м: #{n_rafters*2} шт (#{n_rafters} пар)"
    puts "="*54
    puts ""

    model.commit_operation
    UI.messagebox(
      "Каркасний будинок побудовано!\n\n" \
      "#{(ow/1.mm/1000.0).round(2)} × #{(ol/1.mm/1000.0).round(2)} м  |  Дах #{pitch_deg}°\n" \
      "Стіни: I-joist 200мм  (товщина стіни)\n" \
      "Крокви: I-joist 200мм\n" \
      "Висота конька: #{(z_ridge/1.mm/1000.0).round(2)} м\n\n" \
      "Специфікація — Ruby Console\n" \
      "Шари: 01 Стіни | 02 Обв'язки | 03 Дах"
    )

  rescue => err
    model.abort_operation
    UI.messagebox("Помилка:\n#{err.message}\n\n#{err.backtrace[0..4].join("\n")}")
  end
end

build_frame_house
