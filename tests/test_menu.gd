## Sahip: B. Ana menü: üç düğme, OYUN HAKKINDA penceresi, arka plan şehrin girdiye kapalı olması, YENİ OYUN → Game ve GameState sıfırlama.
## Pencere gerektirir: <godot> --path . --script res://tests/test_menu.gd
extends SceneTree
var f := 0
var fails := 0
var selected := false
func _initialize() -> void:
	change_scene_to_file("res://scenes/main/MainMenu.tscn")
func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c: fails += 1
func _click(pos: Vector2) -> void:
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = p; e.position = pos; e.global_position = pos
		root.push_input(e, true)
func _process(_d: float) -> bool:
	f += 1
	var gs = root.get_node("GameState")
	match f:
		5:
			root.get_node("EventBus").plot_selected.connect(func(_a, _b, _c): selected = true)
			var b: Button = current_scene.get_node("%NewGameButton")
			_check(b.text == "YENİ OYUN" and current_scene.get_node("%AboutButton").text == "OYUN HAKKINDA" and current_scene.get_node("%QuitButton").text == "ÇIKIŞ", "üç düğme Türkçe karakterlerle")
			_check(current_scene.get_node("CityBackdrop").process_mode == Node.PROCESS_MODE_DISABLED, "arka plan şehir girdiye kapalı")
		60:
			var city = current_scene.get_node("CityBackdrop")
			_click(root.get_camera_3d().unproject_position(city.get_node("Plots/U06").global_position))
		64:
			_check(not selected, "menüde şehre tıklayınca arsa seçilmiyor")
			_click(current_scene.get_node("%AboutButton").get_global_rect().get_center())
		70:
			_check(current_scene.get_node("%About").visible, "OYUN HAKKINDA penceresi açıldı (gerçek tıklama)")
			_click(current_scene.get_node("%AboutCloseButton").get_global_rect().get_center())
		75:
			_check(not current_scene.get_node("%About").visible, "Kapat ile kapandı")
			gs.stats.credits = 5
			_click(current_scene.get_node("%NewGameButton").get_global_rect().get_center())
		95:
			_check(current_scene.name == "Game", "YENİ OYUN → Game sahnesi")
			var s = gs.get_stats()
			_check(s.year == 2040 and s.credits == 1000 and s.population == 500 and s.water_security == 60.0 and s.quality_of_life == 50.0 and s.ecosystem_health == 60.0 and s.emissions_total == 100.0, "GameState başlangıç değerleri sıfırlandı")
			_check(root.get_camera_3d() != null, "kamera var")
			print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
			quit(1 if fails else 0)
			return true
	return false
