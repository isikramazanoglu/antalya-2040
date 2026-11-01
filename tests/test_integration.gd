extends SceneTree
## Sahip: B. Prompt 6 entegrasyon testleri (17 senaryo): gerçek Game sahnesi, Ekip A'nın şehri, gerçek tıklamalar.
## Pencere gerektirir: <godot> --path . --resolution 1280x720 --script res://tests/test_integration.gd (ayrıca 1920x1080)
## Ekip A'nın node'larına yalnızca okumak için bakılır.

var f := 0
var fails := 0
var bus: Node
var gs: Node
var cat: Node
var log: Array = []
var reloads := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c:
		fails += 1


func _ui(n: String) -> Node:
	return current_scene.get_node("UI/" + n)


func _panel(child: String) -> Node:
	return _ui("BuildPanel").find_child(child, true, false)


func _plot(id: String) -> Node3D:
	return current_scene.get_node("CityWorld/Plots/" + id)


func _click_plot(id: String) -> void:
	var pos := root.get_camera_3d().unproject_position(_plot(id).global_position)
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)


func _pick_card(name_start: String) -> bool:
	for card in _panel("Cards").get_children():
		for l in card.find_children("*", "Label", true, false):
			if l.text.begins_with(name_start):
				card.pressed.emit()
				return true
	return false


func _last_reason() -> Variant:
	var r := log.filter(func(l): return l[0] == "build_rejected")
	return r[-1][3] if r.size() > 0 else null


func _hud_value(title: String) -> String:
	for row in _ui("HUD").find_child("ResourceList", true, false).find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() >= 3 and row.get_child(1) is Label and row.get_child(1).text == title:
			return row.get_child(2).text
	return "?"


func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			bus = root.get_node("EventBus")
			gs = root.get_node("GameState")
			cat = root.get_node("Catalog")
			for s in ["build_requested", "build_approved", "build_rejected"]:
				bus.connect(s, func(a = null, b = null, c = null): log.append([s, a, b, c]))
			current_scene.get_node("%NewGameButton").pressed.emit()
		30:
			# TEST 15'in ilk yarısı: oyundan menüye dön, tekrar gir; eski sahne referansları sorun çıkarmamalı.
			change_scene_to_file("res://scenes/main/MainMenu.tscn")
		40:
			current_scene.get_node("%NewGameButton").pressed.emit()
		70:
			_check(current_scene.name == "Game" and gs.stats.credits == 1000, "15) menü → oyun → menü → oyun: sahne temiz yeniden kuruldu")
			_click_plot("O01")
		80:
			_check(_ui("BuildPanel").visible and _plot("O01").get("_selected"), "1) boş arsa (O01) seçildi, yatırım menüsü açıldı")
			_check(_pick_card("Güneş"), "3) açık alanda Güneş enerjisi tesisi listeleniyor")
		85:
			var detail: String = _panel("DetailSummary").text
			_check(detail.contains("Enerji emisyonu") and detail.contains("Temel fayda"), "7a) seçilen yatırımın etkileri ve eğitim bilgisi gösteriliyor")
			_panel("BuildButton").pressed.emit()
			_panel("BuildButton").pressed.emit()
		110:
			var solar: BuildingDefinition = cat.get_building(&"solar_plant")
			_check(log.filter(func(l): return l[0] == "build_approved").size() == 1 and gs.stats.credits == 1000 - solar.cost,
					"4/5) güneş bir kez onaylandı, bütçe %d azaldı (%d)" % [solar.cost, gs.stats.credits])
			_check(gs.stats.renewable_energy == 20.0 and gs.stats.renewable_share > 0.0 and gs.stats.emissions_by_sector.energy < 40.0,
					"4) enerji üretimi, yenilenebilir payı ve enerji emisyonu hemen güncellendi (%.1f)" % gs.stats.emissions_by_sector.energy)
			var building: Node3D = _plot("O01").get_building()
			_check(building != null and building.is_visible_in_tree(), "9) güneş tesisi gerçek şehir sahnesinde görünüyor")
			var anchor: Node3D = _plot("O01").get_node("BuildingAnchor")
			_check(building.global_position.distance_to(anchor.global_position) < 0.01 and building.global_position.y >= _plot("O01").global_position.y - 0.01,
					"10) bina arsanın bağlantı noktasında, zeminin altında değil")
			_check(_hud_value("Yerel emisyon") == str(roundi(gs.stats.emissions_total)) and _ui("HUD").find_child("CreditsValue", true, false).text == str(gs.stats.credits),
					"11) HUD bütçe ve yerel emisyonu GameState'ten gösteriyor (emisyon %s)" % _hud_value("Yerel emisyon"))
			_click_plot("O01")
		120:
			_check(not _panel("BuildButton").visible, "2) dolu arsa seçilince inşa düğmesi yok")
			bus.build_requested.emit(&"O01", &"water_storage")
			_check(_last_reason() == &"plot_occupied" and gs.stats.credits == 600, "2) dolu arsaya istek reddedildi, bütçe değişmedi")
			bus.build_requested.emit(&"U01", &"solar_plant")
			_check(_last_reason() == &"unknown_plot", "13a) bu oturumda bildirilmemiş arsaya istek reddedildi")
			_click_plot("U01")
		130:
			_check(_plot("U01").get("_selected") and not _plot("O01").get("_selected"), "14) seçim U01'e geçti, O01'in vurgusu kalktı")
			bus.build_requested.emit(&"U01", &"water_storage")
			_check(_last_reason() == &"wrong_plot_kind" and gs.get_building_on(&"U01") == &"", "13) su deposu kent arsasına yerleştirilemedi")
			var park: BuildingDefinition = cat.get_building(&"green_park")
			var keep: PackedScene = park.scene
			park.scene = null
			var before: Dictionary = gs.get_stats()
			bus.build_requested.emit(&"U01", &"green_park")
			_check(_last_reason() == &"scene_unavailable" and gs.get_stats() == before and gs.get_building_on(&"U01") == &"" and _plot("U01").is_empty(),
					"12) sahne yüklenemezse reddedildi; bütçe, arsa ve şehir değişmedi")
			park.scene = keep
			var eco: float = gs.stats.ecosystem_health
			var qol: float = gs.stats.quality_of_life
			_pick_card("Yeşil park")
			set_meta("eco", eco)
			set_meta("qol", qol)
		135:
			_panel("BuildButton").pressed.emit()
		160:
			_check(gs.stats.ecosystem_health > get_meta("eco") and gs.stats.quality_of_life > get_meta("qol")
					and _hud_value("Ekosistem sağlığı") == str(roundi(gs.stats.ecosystem_health)) and _hud_value("Yaşam kalitesi") == str(roundi(gs.stats.quality_of_life)),
					"8) park: ekosistem %d, yaşam %d; HUD aynı değerleri gösteriyor" % [gs.stats.ecosystem_health, gs.stats.quality_of_life])
			_check(_plot("U01").get_building() != null, "9) park şehirde görünüyor")
			_panel("CloseButton").pressed.emit()
			_check(not _ui("BuildPanel").visible and not _plot("U01").get("_selected"), "14/v1.3) × ile kapatınca şehirdeki arsa vurgusu da kalktı (A bağlantısı)")
			_click_plot("O02")
		170:
			_pick_card("Su depolama")
		175:
			set_meta("water", gs.stats.water_security)
			set_meta("supply", gs.stats.water_supply)
			_panel("BuildButton").pressed.emit()
		200:
			_check(gs.stats.water_security > get_meta("water") and gs.stats.water_supply > get_meta("supply") and _hud_value("Su güvenliği") == str(roundi(gs.stats.water_security)),
					"7) su deposu: su güvenliği %d, su arzı %d; HUD güncel" % [gs.stats.water_security, gs.stats.water_supply])
			_check(gs.stats.credits == 1000 - 400 - 150 - 250, "4/5) toplam harcama tam olarak 800 (%d kaldı)" % gs.stats.credits)
			_click_plot("O03")
		210:
			_pick_card("Atık su")
		215:
			var before_credits: int = gs.stats.credits
			_check(_panel("BuildButton").disabled and _panel("ErrorLabel").text.contains("yeterli bütçen yok"), "6) 350 kredilik yatırıma 200 kredi yetmiyor, düğme kapalı ve neden yazıyor")
			bus.build_requested.emit(&"O03", &"water_reuse")
			_check(_last_reason() == &"not_enough_credits" and gs.stats.credits == before_credits and _plot("O03").is_empty(), "6) doğrudan istek de reddedildi, hiçbir şey değişmedi")
			print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
			quit(1 if fails else 0)
			return true
	return false
