# ============================================================
# ЕКСПОРТ МОДЕЛІ SKETCHUP → ТЕКСТ
# Виводить всі групи/компоненти з розмірами та позиціями
#
# ЗАПУСК: Window → Ruby Console → load 'C:/path/export_model.rb'
# Результат з'явиться в Ruby Console — скопіюй і надішли
# ============================================================

def su_export_model
  model   = Sketchup.active_model
  out     = []
  units   = model.options['UnitsOptions']['LengthUnit']
  unit_lbl = %w[in ft mm cm m][units] rescue 'mm'

  out << "================================================"
  out << "SKETCHUP MODEL EXPORT"
  out << "Файл:    #{model.path.empty? ? '(не збережено)' : File.basename(model.path)}"
  out << "Одиниці: #{unit_lbl}"
  out << "================================================"

  # Межі всієї моделі
  bb = model.bounds
  out << ""
  out << "ЗАГАЛЬНІ ГАБАРИТИ:"
  out << "  X (ширина): #{bb.width.to_mm.round(1)} мм"
  out << "  Y (глибина): #{bb.depth.to_mm.round(1)} мм"
  out << "  Z (висота):  #{bb.height.to_mm.round(1)} мм"

  # Рекурсивна функція обходу груп
  def dump_entities(ents, out, indent = 0, index = [0])
    ents.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

      index[0] += 1
      pad  = '  ' * indent
      name = e.is_a?(Sketchup::Group) ? (e.name.empty? ? "(group)" : e.name) : e.definition.name
      type = e.is_a?(Sketchup::Group) ? 'GROUP' : 'COMPONENT'

      # Трансформація → позиція та розміри
      t  = e.transformation
      bb = e.bounds

      ox = t.origin.x.to_mm.round(1)
      oy = t.origin.y.to_mm.round(1)
      oz = t.origin.z.to_mm.round(1)

      sx = bb.width.to_mm.round(1)
      sy = bb.depth.to_mm.round(1)
      sz = bb.height.to_mm.round(1)

      layer = e.layer ? e.layer.name : '—'

      out << ""
      out << "#{pad}[#{index[0]}] #{type}: #{name}"
      out << "#{pad}    Шар:    #{layer}"
      out << "#{pad}    Позиція (мм): X=#{ox}  Y=#{oy}  Z=#{oz}"
      out << "#{pad}    Розмір  (мм): W=#{sx}  D=#{sy}  H=#{sz}"

      # Рекурсія в підгрупи
      sub_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
      has_sub  = sub_ents.any? { |s| s.is_a?(Sketchup::Group) || s.is_a?(Sketchup::ComponentInstance) }
      dump_entities(sub_ents, out, indent + 1, index) if has_sub
    end
  end

  out << ""
  out << "================================================"
  out << "ЕЛЕМЕНТИ МОДЕЛІ:"
  out << "================================================"

  idx = [0]
  dump_entities(model.active_entities, out, 0, idx)

  out << ""
  out << "================================================"
  out << "Всього елементів верхнього рівня: #{idx[0]}"
  out << "================================================"

  # Виводимо в консоль
  text = out.join("\n")
  puts text

  # Також зберігаємо у файл поруч з моделлю (або на Desktop)
  save_path = if !model.path.empty?
    File.join(File.dirname(model.path), 'model_export.txt')
  else
    File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Desktop', 'model_export.txt')
  end

  begin
    File.write(save_path, text, encoding: 'UTF-8')
    UI.messagebox(
      "Експорт завершено!\n\n" \
      "Елементів знайдено: #{idx[0]}\n\n" \
      "Файл збережено:\n#{save_path}\n\n" \
      "Також результат є в Ruby Console."
    )
  rescue => e
    UI.messagebox("Дані є в Ruby Console.\n(Файл не вдалось зберегти: #{e.message})")
  end
end

su_export_model
