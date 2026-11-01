extends SceneTree
## Sahip: A. Prompt 6: BuildPanel × / Esc ile seçimin gerçek tuş olaylarıyla bırakılması. Çalıştırma: <godot> --path . --script res://scripts/world/dev/test_deselect_real.gd
var fails := 0
func _initialize():
	_run.call_deferred()
func check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  FAIL ") + m)
	if not c: fails += 1
func click_at(p: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev, true)
		await physics_frame
		await process_frame
func key(k: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = pressed
		root.push_input(ev, true)
		await process_frame
func _run():
	print("çözünürlük ", root.get_visible_rect().size, " pencere ", DisplayServer.window_get_size())
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/main/Game.tscn")
	await create_timer(2.0).timeout
	var city = current_scene.get_node("CityWorld")
	var panel = current_scene.get_node("UI/BuildPanel")
	for id in [&"O01", &"U04", &"C02"]:
		var plot = city.find_plot(id)
		await click_at(root.get_camera_3d().unproject_position(plot.global_position))
		await create_timer(1.2).timeout
		check(panel.visible and plot.highlight_state() == &"selected", "%s seçildi, panel açık" % id)
		var sp: Vector2 = root.get_camera_3d().unproject_position(plot.global_position)
		var pr: Rect2 = panel.get_global_rect()
		check(not pr.has_point(sp), "%s panelin arkasında kalmadı (arsa %s, panel x≥%.0f)" % [id, sp.round(), pr.position.x])
		await key(KEY_ESCAPE)
		await create_timer(0.3).timeout
		check(not panel.visible and plot.highlight_state() != &"selected", "%s Esc → panel kapandı, vurgu kalktı" % id)
	var u01 = city.find_plot(&"U01")
	await click_at(root.get_camera_3d().unproject_position(u01.global_position))
	await create_timer(1.2).timeout
	var close_btn: Button = panel.find_child("*Close*", true, false)
	if close_btn == null:
		for b in panel.find_children("*", "Button", true, false):
			if b.text.strip_edges() in ["×", "x", "X", "✕"]:
				close_btn = b
	check(close_btn != null, "panelde kapat düğmesi bulundu")
	if close_btn:
		await click_at(close_btn.get_global_rect().get_center())
		await create_timer(0.3).timeout
		check(not panel.visible and u01.highlight_state() != &"selected", "× düğmesi → panel kapandı, vurgu kalktı")
	print("SONUÇ: " + ("TAMAM" if fails == 0 else "%d HATA" % fails))
	quit(fails)
