class_name LineChart
extends Control
## Sahip: B. Basit çizgi grafik. Godot'ta hazır grafik node'u yok; _draw() ile çizer.

## Her öğe: {"name": String, "color": Color, "values": PackedFloat32Array}
var series: Array = []
var x_labels: PackedStringArray = PackedStringArray()
var y_suffix := ""

const PAD_LEFT := 56.0
const PAD_BOTTOM := 28.0
const PAD_TOP := 28.0


func set_data(new_series: Array, labels: PackedStringArray, suffix := "") -> void:
	series = new_series
	x_labels = labels
	y_suffix = suffix
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var area := Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - 12.0, size.y - PAD_TOP - PAD_BOTTOM)
	draw_rect(area, Color(1, 1, 1, 0.04))
	var lo := INF
	var hi := -INF
	var count := 0
	for s in series:
		for v in s.values:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		count = maxi(count, s.values.size())
	if count == 0:
		draw_string(font, area.position + Vector2(12, 28), "Henüz veri yok", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
		return
	if is_equal_approx(lo, hi):
		lo -= 1.0
		hi += 1.0

	for i in 3:
		var t := i / 2.0
		var y := area.end.y - t * area.size.y
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(1, 1, 1, 0.08))
		draw_string(font, Vector2(4, y + 5), "%d%s" % [roundi(lerpf(lo, hi, t)), y_suffix], HORIZONTAL_ALIGNMENT_LEFT, PAD_LEFT - 8, 13, Color(1, 1, 1, 0.6))
	if x_labels.size() > 0:
		draw_string(font, Vector2(area.position.x, size.y - 8), x_labels[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(area.end.x - 60, size.y - 8), x_labels[-1], HORIZONTAL_ALIGNMENT_RIGHT, 60, 13, Color(1, 1, 1, 0.6))

	var legend_x := area.position.x
	for s in series:
		var points := PackedVector2Array()
		for i in s.values.size():
			var x: float = area.position.x + (area.size.x * i / maxf(count - 1, 1))
			var y: float = area.end.y - (s.values[i] - lo) / (hi - lo) * area.size.y
			points.append(Vector2(x, y))
		if points.size() == 1:
			draw_circle(points[0], 4.0, s.color)
		else:
			draw_polyline(points, s.color, 2.5, true)
		draw_rect(Rect2(legend_x, 8, 12, 12), s.color)
		draw_string(font, Vector2(legend_x + 16, 19), s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		legend_x += 24 + font.get_string_size(s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
