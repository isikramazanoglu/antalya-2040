extends SceneTree
## Sahip: B. Uçtan uca: MainMenu → Game, gerçek fare tıklamasıyla arsa seçimi (A), UI ile inşaat (B), krizler ve efektler.
## Pencere gerektirir (headless değil): <godot> --path . --script res://tests/test_e2e_game.gd
var f := 0
var log_lines: Array = []
var fails := 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c: fails += 1


func _click_plot(id: String) -> void:
	var plot: Node3D = current_scene.get_node("CityWorld/Plots/" + id)
	var pos := root.get_camera_3d().unproject_position(plot.global_position)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)  # konum viewport (1920x1080) koordinatında

func _ui(name: String) -> Node:
	return current_scene.get_node("UI").find_child(name, true, false)

func _build_via_ui(card_index_name: String) -> void:
	var panel := current_scene.get_node("UI/BuildPanel")
	for card in panel.find_child("Cards", true, false).get_children():
		for label in card.find_children("*", "Label", true, false):
			if label.text.begins_with(card_index_name):
				card.pressed.emit()
	await process_frame
	panel.find_child("BuildButton", true, false).pressed.emit()

func _process(_d: float) -> bool:
	f += 1
	var bus = root.get_node("EventBus")
	var gs = root.get_node("GameState")
	match f:
		5: current_scene.get_node("%NewGameButton").pressed.emit()
		20:
			_check(current_scene.name == "Game", "MainMenu → Game")
			bus.plot_selected.connect(func(p, k, e): log_lines.append(["sel", p, k, e]))
			_click_plot("O01")
		24:
			_check(log_lines.size() > 0 and log_lines[-1][1] == &"O01" and log_lines[-1][2] == &"open", "fare tıklaması O01 seçti (plot_selected)")
			_check(current_scene.get_node("UI/BuildPanel").visible, "BuildPanel açıldı")
			_build_via_ui("Güneş")
		30:
			_check(gs.get_building_on(&"O01") == &"solar_plant", "güneş tesisi inşa edildi")
			var anchor = current_scene.get_node("CityWorld/Plots/O01").find_child("BuildingAnchor", true, false)
			_check(anchor != null and anchor.get_child_count() > 0, "şehirde bina sahnesi oluştu")
			_click_plot("U01")
		34:
			_build_via_ui("Yeşil")
		40:
			_click_plot("U02")
		44:
			_build_via_ui("İklim serinleme")
		70:
			_check(gs.plots.size() == 3, "3 bina (güneş, park, serinleme merkezi)")
			bus.crisis_started.connect(func(id, r, s): log_lines.append(["crisis", id, r, s]))
			for i in 3:
				bus.end_turn_requested.emit(); bus.report_closed.emit()
			bus.end_turn_requested.emit()
		75:
			_check(gs.phase == &"crisis" and _ui("EventPanel").visible, "2043 sıcak hava krizi, panel açık")
		121:
			_click_plot("U03")
			_check(log_lines.filter(func(l): return l[0] == "sel" and l[1] == &"U03").is_empty(), "kriz sırasında arsa seçilemiyor")
			bus.crisis_response_chosen.emit(&"heatwave", &"open_cooling")
		125:
			_check(gs.phase == &"report", "kriz sonrası rapor")
			bus.report_closed.emit()
			bus.crisis_started.connect(func(id, _r, _s): if id != &"coastal_flood": bus.crisis_response_chosen.emit(id, &"do_nothing"))
			while gs.stats.year < 2049:
				bus.end_turn_requested.emit(); bus.report_closed.emit()
			bus.end_turn_requested.emit()
		190:
			_check(gs.phase == &"crisis", "2049 kıyı taşkını krizi")
			print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
			quit(1 if fails else 0)
			return true
	return false
