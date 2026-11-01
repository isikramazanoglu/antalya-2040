extends SceneTree
## Sahip: B. Prompt 10C: gerçek oyuncu gibi tam oyun. Menü → Game, fare tıklamasıyla arsa, UI düğmeleriyle inşaat, yıl,
## kriz müdahalesi ve rapor; İklim Laboratuvarı sekmeleri; 2052 final raporu. Kriz anında FPS ölçer (vsync kapalı).
## Pencere gerektirir: <godot> --path . --resolution 1280x720 --script res://tests/test_playthrough.gd
var f := 0
var step := 0
var wait := 0
var fails := 0
var fps_samples: Array = []
var bus: Node
var gs: Node

func _log_rej(p, b, r) -> void:
	print("     RED %s %s %s" % [p, b, r])

func _initialize() -> void:
	change_scene_to_file("res://scenes/main/MainMenu.tscn")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c: fails += 1

func _ui(n: String) -> Node:
	return current_scene.get_node("UI").find_child(n, true, false)

func _click(pos: Vector2) -> void:
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = p; e.position = pos; e.global_position = pos
		root.push_input(e, true)

func _click_control(c: Control) -> void:
	_click(c.get_global_rect().get_center())

func _click_plot(id: String) -> void:
	_click(root.get_camera_3d().unproject_position(current_scene.get_node("CityWorld/Plots/" + id).global_position))

func _pick(name_start: String) -> void:
	for card in _ui("BuildPanel").find_child("Cards", true, false).get_children():
		for l in card.find_children("*", "Label", true, false):
			if l.text.begins_with(name_start):
				var scroll: ScrollContainer = card.get_parent().get_parent()
				scroll.ensure_control_visible(card)
				await process_frame
				await process_frame
				var c: Vector2 = card.get_global_rect().get_center()
				_click_control(card)
				return
	print("  HATA kart bulunamadı: %s" % name_start)
	fails += 1

const PLAN := {2040: [["O01", "Güneş"], ["U01", "Yeşil park"]], 2041: [["O02", "Su depolama"]], 2042: [["U02", "İklim serinleme"]], 2044: [["C01", "Kıyı"]], 2046: [["O03", "Geri dönüşüm"]]}
var queue: Array = []
var planned := {}

func _process(_d: float) -> bool:
	# Ekip A12: inşaattan sonra kamera yeni binayı gösterirken tıklamalar ıskalar; gösterim bitene kadar bekle.
	var rig = current_scene.find_child("CameraRig", true, false) if current_scene else null
	if rig and rig.has_method("is_showcasing") and rig.is_showcasing():
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	if f == 30:
		_click_control(current_scene.get_node("%NewGameButton"))
		wait = 40
		return false
	if f < 80:
		return false
	if bus == null:
		bus = root.get_node("EventBus"); gs = root.get_node("GameState")
		bus.build_rejected.connect(_log_rej)
		_check(current_scene.name == "Game" and gs.stats.year == 2040, "menüden oyuna geçildi, 2040")
	var phase: StringName = gs.phase
	if phase == &"build" and not planned.has(gs.stats.year):
		planned[gs.stats.year] = true
		queue = PLAN.get(gs.stats.year, []).duplicate()
	if phase == &"build":
		if not queue.is_empty():
			var item: Array = queue.pop_front()
			if item[0] == "__pick":
				_pick(item[1]); wait = 8
				queue.push_front(["__build", ""])
			elif item[0] == "__build":
				var bb: Button = _ui("BuildPanel").find_child("BuildButton", true, false)
				_click_control(bb); wait = 20
			else:
				_click_plot(item[0]); wait = 12
				queue.push_front(["__pick", item[1]])
			return false
		if step == 0 and gs.stats.year == 2043:
			step = 1
			_click_control(_ui("LabButton")); wait = 10
			return false
		if step == 1:
			var lab = current_scene.get_node("UI/ClimateLab")
			for i in 6:
				lab.find_child("Tabs", true, false).current_tab = i
			_check(lab.visible, "İklim Laboratuvarı açıldı, 6 sekme gezildi")
			lab.close(); step = 2; wait = 5
			return false
		_click_control(_ui("EndTurnButton")); wait = 25
		return false
	if phase == &"crisis":
		var panel = current_scene.get_node("UI/EventPanel")
		var buttons: Array = panel.find_child("Responses", true, false).get_children().filter(func(b): return not b.disabled)
		if fps_samples.size() < 60:
			fps_samples.append(Engine.get_frames_per_second())
			return false
		_click_control(buttons[0]); wait = 5
		var confirm = panel.find_child("ConfirmButton", true, false)
		_click_control(confirm); wait = 30
		fps_samples.append(-1)
		return false
	if phase == &"report":
		var report = current_scene.get_node("UI/YearReport")
		_click_control(report.find_child("ContinueButton", true, false)); wait = 20
		return false
	if phase == &"game_over":
		var final_ui = current_scene.get_node("UI/FinalReport")
		_check(final_ui.visible, "2052 sonunda final raporu açıldı")
		_check(gs.history.size() == 13 and gs.crisis_log.size() == 3 and gs.build_log.size() == 6, "13 yıl, 3 kriz, 6 yatırım kaydedildi (%d yatırım)" % gs.build_log.size())
		var crisis_fps := fps_samples.filter(func(x): return x > 0)
		var avg := 0.0
		for x in crisis_fps: avg += x
		print("  FPS (kriz anı, vsync kapalı, bu Mac): ort %d, en düşük %d" % [roundi(avg / max(crisis_fps.size(), 1)), crisis_fps.min() if crisis_fps.size() > 0 else 0])
		print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
		quit(1 if fails else 0)
		return true
	return false
