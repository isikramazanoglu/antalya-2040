extends SceneTree
## Sahip: B. Prompt 5'in 20 arayüz kabul kriteri. Pencere gerektirir; iki çözünürlükte çalıştırılır:
## <godot> --path . --resolution 1280x720 --script res://tests/test_ui.gd   (ve 1920x1080)

var f := 0
var fails := 0
var bus: Node
var gs: Node
var log: Array = []


func _initialize() -> void:
	change_scene_to_file("res://scenes/main/Game.tscn")


func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c:
		fails += 1


func _ui(path: String) -> Node:
	return current_scene.get_node("UI/" + path)


func _find(root_name: String, child: String) -> Node:
	return _ui(root_name).find_child(child, true, false)


func _click(pos: Vector2) -> void:
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)


func _click_plot(id: String) -> void:
	_click(root.get_camera_3d().unproject_position(current_scene.get_node("CityWorld/Plots/" + id).global_position))


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = &"cancel"
	e.pressed = true
	root.push_input(e, true)


func _card_labels() -> String:
	var t := ""
	for l in _find("BuildPanel", "Cards").find_children("*", "Label", true, false):
		t += l.text + "\n"
	return t


func _visible_panels() -> Array:
	return get_nodes_in_group("ui_panel").filter(func(p): return p.visible)


func _process(_d: float) -> bool:
	f += 1
	match f:
		10:
			bus = root.get_node("EventBus")
			gs = root.get_node("GameState")
			for s in ["build_requested", "build_approved", "build_rejected", "plot_selected"]:
				bus.connect(s, func(a = null, b = null, c = null): log.append([s, a, b, c]))
		40:
			print("Pencere %s, viewport %s" % [DisplayServer.window_get_size(), root.get_visible_rect().size])
			_check(_ui("HUD").visible and _find("HUD", "TopBar").visible, "1) HUD açılıyor")
			_check(_find("HUD", "YearValue").text == "Ocak 2040" and _find("HUD", "PopulationValue").text == "500" and _find("HUD", "CreditsValue").text == "1.000",
					"2) tarih Ocak 2040, nüfus 500, bütçe 1.000 gösteriliyor")
			_click_plot("O01")
		50:
			_check(_ui("BuildPanel").visible, "6) boş arsa seçince BuildPanel açıldı (gerçek tıklama)")
			var n: int = _find("BuildPanel", "Cards").get_child_count()
			_check(n == root.get_node("Catalog").buildings_for_plot_kind(&"open").size(), "7) açık alana uygun %d yatırım listelendi" % n)
			var labels := _card_labels()
			_check(labels.contains("Güneş enerjisi tesisi") and labels.contains("400 kredi · bakımı her yıl 10 · açık alan") and labels.contains("Temiz elektrik üretir +20"),
					"8) kart adı, maliyet, gider, arsa türü ve etki gösteriyor")
			_check(not _find("BuildPanel", "Cards").find_children("*", "TextureRect", true, false).is_empty(), "8) kartta bina görseli var")
			_find("BuildPanel", "Cards").get_child(0).pressed.emit()
		55:
			_check(_find("BuildPanel", "DetailSummary").text.contains("Ne işe yarar?") and _find("BuildPanel", "DetailSummary").text.contains("İklime faydası"),
					"8) seçilen kartın eğitim ayrıntısı görünüyor")
			_find("BuildPanel", "BuildButton").pressed.emit()
			_find("BuildPanel", "BuildButton").pressed.emit()  # çift tıklama denemesi
		90:
			_check(log.any(func(l): return l[0] == "build_requested") and log.any(func(l): return l[0] == "build_approved"), "10) istek GameController'a ulaştı ve onaylandı")
			_check(gs.stats.credits == 600, "11) bütçe bir kez düştü: 1000 - 400 = %d" % gs.stats.credits)
			_check(_find("HUD", "CreditsValue").text == "600", "3) HUD bütçesi güncellendi (%s)" % _find("HUD", "CreditsValue").text)
			var energy_detail := ""
			for l in _find("HUD", "ResourceList").find_children("*", "Label", true, false):
				if l.text.begins_with("İhtiyaç"):
					energy_detail = l.text
			_check(energy_detail.contains("İhtiyaç 50 · temiz enerji 20 · 30 kömür ve doğalgazdan"), "5) enerji üretimi, tüketimi ve dengesi gösteriliyor (%s)" % energy_detail)
			_check(not _find("BuildPanel", "BuildButton").visible and _find("BuildPanel", "Hint").text.contains("Bu arsada"), "12) dolu arsada inşa düğmesi yok")
			bus.build_requested.emit(&"O01", &"water_storage")
			var rejected := log.filter(func(l): return l[0] == "build_rejected")
			_check(not rejected.is_empty() and rejected[-1][3] == &"plot_occupied" and gs.stats.credits == 600, "12) dolu arsaya ikinci istek reddedildi, bütçe değişmedi")
			_click_plot("O02")
		100:
			var water_before := int(gs.stats.water_security)
			for card in _find("BuildPanel", "Cards").get_children():
				for l in card.find_children("*", "Label", true, false):
					if l.text.begins_with("Su depolama"):
						card.pressed.emit()
			_find("BuildPanel", "BuildButton").pressed.emit()
			set_meta("water_before", water_before)
		130:
			var water_value := ""
			for l in _find("HUD", "ResourceList").find_children("*", "Label", true, false):
				if l.get_parent().get_child(1) is Label and l.get_parent().get_child(1).text == "Su" and l.get_index() == 2:
					water_value = l.text
			_check(water_value == str(int(gs.stats.water_security)) and gs.stats.water_security > get_meta("water_before"), "4) su güvenliği HUD'da %s oldu" % water_value)
			gs.stats.credits = 100
			bus.stats_changed.emit(gs.get_stats())
			_click_plot("U01")
		140:
			_find("BuildPanel", "Cards").get_child(0).pressed.emit()
		142:
			pass
		145:
			_check(_find("BuildPanel", "BuildButton").disabled and _find("BuildPanel", "ErrorLabel").text.contains("yeterli bütçen yok"), "9) yetersiz bütçede inşa düğmesi kapalı, neden yazıyor")
			var asked := [false]
			bus.plot_deselect_requested.connect(func(): asked[0] = true, CONNECT_ONE_SHOT)
			_find("BuildPanel", "CloseButton").pressed.emit()
			_check(asked[0] and not _ui("BuildPanel").visible, "v1.3) × ile kapatınca plot_deselect_requested yayıldı")
			_click_plot("U01")
			gs.stats.credits = 600
			bus.stats_changed.emit(gs.get_stats())
			var before := log.filter(func(l): return l[0] == "plot_selected").size()
			_click(_ui("BuildPanel").get_global_rect().get_center())
			set_meta("sel_before", before)
		150:
			_check(log.filter(func(l): return l[0] == "plot_selected").size() == get_meta("sel_before"), "17) panel üstüne tıklama arkadaki şehre geçmiyor")
			_find("HUD", "LabButton").pressed.emit()
		160:
			_check(_ui("ClimateLab").visible and not _ui("BuildPanel").visible and _visible_panels().size() == 1, "16) İklim Laboratuvarı açıldı, BuildPanel kapandı (tek panel)")
			var chart = _find("ClimateLab", "EmissionChart")
			var expected: float = gs.stats.emissions_by_sector.energy
			_check(chart.series.size() == 5 and is_equal_approx(chart.series[0].values[-1], expected), "14) emisyon grafiği gerçek veriyle, sanayi dahil 5 kalem (enerji %.1f)" % expected)
			_ui("ClimateLab").open_tab("Su ve elektrik")
			_check(_find("ClimateLab", "ResourceText").text.contains("temiz elektrik payı %40"), "13) Laboratuvar (C) güncel enerji verisini gösteriyor")
			_esc()
		165:
			_check(not _ui("ClimateLab").visible, "16) Esc ile Laboratuvar kapandı")
			_find("HUD", "CityInfoButton").pressed.emit()
		170:
			_check(_ui("CityInfo").visible and _find("CityInfo", "Body").text.contains("Güneş enerjisi tesisi"), "16) Şehir bilgileri açıldı, yatırımları listeliyor")
			_find("HUD", "SettingsButton").pressed.emit()
		175:
			_check(_ui("SettingsPanel").visible and not _ui("CityInfo").visible, "16) Ayarlar açıldı, Şehir bilgileri kapandı")
			_esc()
			bus.end_turn_requested.emit()
		200:
			_check(_ui("YearReport").visible and _find("YearReport", "Body").text.contains("Yıl sonu bütçesi") and _find("YearReport", "Body").text.contains("Temiz elektrik"),
					"15) yıl sonu raporu gerçek verilerle açıldı")
			_check(_overflow().is_empty(), "18/19) görünür arayüz öğesi ekran dışına taşmıyor %s" % str(_overflow()))
			_find("YearReport", "ContinueButton").pressed.emit()
		210:
			_find("HUD", "ReportButton").pressed.emit()
		215:
			_check(_ui("YearReport").visible and _find("YearReport", "ContinueButton").text == "Kapat", "16) \"Son rapor\" son raporu yeniden açtı")
			_esc()
		220:
			_check(not _ui("YearReport").visible and gs.phase == &"build", "16) Esc ile kapandı, oyun build fazında")
			var font: Font = _find("HUD", "Logo").get_theme_font("font")
			var missing := ""
			for ch in "ğüşıöçİĞÜŞÖÇâ":
				if not font.has_char(ch.unicode_at(0)):
					missing += ch
			_check(missing == "", "20) yazı tipinde bütün Türkçe karakterler var %s" % missing)
			print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
			quit(1 if fails else 0)
			return true
	return false


## Ekranda görünen Control'lerden viewport dışına taşanlar (yalnızca UI katmanı).
func _overflow() -> Array:
	var screen := root.get_visible_rect().grow(1.0)
	var out := []
	for c in _ui("").find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.size != Vector2.ZERO and not screen.encloses(c.get_global_rect()) and not c.get_parent() is ScrollContainer and not _in_scroll(c):
			out.append(c.name)
	return out


func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer or p is RichTextLabel:
			return true
		p = p.get_parent()
	return false
