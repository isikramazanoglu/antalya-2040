class_name BarChart
extends Control
## Sahip: B. Yatay sütun grafik (oransal dağılım). _draw() ile çizer; harici eklenti yok.

## Her öğe: {"label": String, "value": float, "color": Color}
var bars: Array = []
var suffix := ""


func set_data(new_bars: Array, value_suffix := "") -> void:
	bars = new_bars
	suffix = value_suffix
	custom_minimum_size.y = maxf(40.0, bars.size() * 30.0 + 6.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var top := 0.0
	for v in bars:
		top = maxf(top, v.value)
	if bars.is_empty() or top <= 0.0:
		draw_string(font, Vector2(4, 22), "Henüz veri yok", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.6))
		return
	var label_w := 150.0
	var value_w := 70.0
	var bar_w := size.x - label_w - value_w - 8.0
	for i in bars.size():
		var b: Dictionary = bars[i]
		var y := i * 30.0 + 4.0
		draw_string(font, Vector2(0, y + 17), b.label, HORIZONTAL_ALIGNMENT_LEFT, label_w - 8, 15, Color(1, 1, 1, 0.85))
		draw_rect(Rect2(label_w, y + 4, bar_w, 16), Color(1, 1, 1, 0.06))
		draw_rect(Rect2(label_w, y + 4, bar_w * b.value / top, 16), b.color)
		draw_string(font, Vector2(label_w + bar_w + 8, y + 17), "%d%s" % [roundi(b.value), suffix], HORIZONTAL_ALIGNMENT_LEFT, value_w, 15, Color(1, 1, 1, 0.85))
