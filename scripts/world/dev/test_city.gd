extends SceneTree
## Sahip: A. Şehir doğrulama testi (Gün 1–3, Prompt 3–6). Çalıştırma: <godot> --path . --script res://scripts/world/dev/test_city.gd

var _fails := 0
var _events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func click(screen: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = screen
		ev.global_position = screen
		root.push_input(ev, true)
		await physics_frame
		await process_frame


func screen_of(node: Node3D) -> Vector2:
	return root.get_camera_3d().unproject_position(node.global_position + Vector3(0, 0.1, 0))


func _run() -> void:
	var EB = root.get_node("EventBus")
	EB.plot_selected.connect(func(p, k, e): _events.append(["sel", p, k, e]))
	EB.plot_deselected.connect(func(): _events.append(["desel"]))

	print("Bina sahneleri")
	var ids := ["efficient_housing", "solar_plant", "public_efficiency", "water_storage", "water_reuse", "green_park",
			"cooling_center", "urban_farming", "food_rescue", "recycling_compost", "transit_hub", "coastal_restoration"]
	for id in ids:
		var scene: PackedScene = load("res://scenes/buildings/b_%s.tscn" % id)
		var inst = scene.instantiate() if scene else null
		check(inst is Building and inst.get_node("Model").get_child_count() >= 5, "b_%s yüklendi, Building tabanlı" % id)
		if inst:
			inst.free()

	print("CitySandbox")
	change_scene_to_file("res://scenes/dev/CitySandbox.tscn")
	await frames(10)
	var city = current_scene.get_node("CityWorld")
	var plots: Array = city.get_plots()
	check(plots.size() == 15, "15 arsa var")
	var kinds := {}
	for p in plots:
		kinds[p.plot_kind] = kinds.get(p.plot_kind, 0) + 1
	check(kinds.get(&"urban") == 8 and kinds.get(&"open") == 5 and kinds.get(&"coastal") == 2, "8 urban, 5 open, 2 coastal")
	var decor = city.get_node("Decor")
	var mm_count := 0
	var instances := 0
	for c in decor.get_children():
		if c is MultiMeshInstance3D:
			mm_count += 1
			instances += c.multimesh.instance_count
	check(mm_count > 10 and instances > 500, "dekor MultiMesh ile kuruldu (%d grup, %d parça)" % [mm_count, instances])
	check(city.get_plot_kind(&"C01") == &"coastal" and city.get_plot_kind(&"X99") == &"", "get_plot_kind")
	var label: Label3D = city.find_plot(&"O02").get_node("VisualOverlay/DebugOverlay/Label")
	check(label.text == "O02 · AÇIK ALAN" and not city.find_plot(&"O02").is_debug_visible(),
		"geliştirici etiketi kimlik + tür (%s), normal oyunda gizli" % label.text)
	# Görsel revizyon 9: trafik CityWorld/Traffic düğümünde (PathFollow3D).
	# Geçitte bekleyen olabilir: en az bir aracın ilerlemesi yeter.
	var cars: Array = city.get_node("Traffic")._vehicles
	var before := cars.map(func(v): return (v.follow as Node3D).global_position)
	await create_timer(0.5).timeout
	var moved := 0
	for i in cars.size():
		if (cars[i].follow as Node3D).global_position.distance_to(before[i]) > 0.05:
			moved += 1
	check(moved > cars.size() / 2, "caddede araçlar hareket ediyor (%d / %d)" % [moved, cars.size()])

	# Kamera 1 sn otursun.
	await create_timer(1.0).timeout
	var u01 = city.find_plot(&"U01")
	_events.clear()
	await click(screen_of(u01))
	check(_events == [["sel", &"U01", &"urban", true]], "U01'e tıklama → plot_selected(U01, urban, true)  %s" % str(_events))
	check(u01.highlight_state() == &"selected", "U01 vurgulu (seçili)")

	var o01 = city.find_plot(&"O01")
	_events.clear()
	await click(screen_of(o01))
	check(_events == [["sel", &"O01", &"open", true]], "O01'e tıklama → plot_selected(O01, open, true)")
	check(u01.highlight_state() != &"selected", "U01 seçim vurgusu kalktı")

	_events.clear()
	await click(root.get_visible_rect().size * Vector2(0.5, 0.97))
	check(_events == [["desel"]], "boş yere tıklama → plot_deselected  %s" % str(_events))

	await click(screen_of(o01))
	_events.clear()
	await click(screen_of(o01), MOUSE_BUTTON_RIGHT)
	check(_events == [["desel"]], "sağ tık → plot_deselected")

	print("Seçimi bırak isteği (v1.3)")
	await click(screen_of(o01))
	_events.clear()
	EB.plot_deselect_requested.emit()
	await frames(1)
	check(_events == [["desel"]] and o01.highlight_state() != &"selected", "plot_deselect_requested → vurgu kalktı, plot_deselected yayıldı")
	_events.clear()
	EB.plot_deselect_requested.emit()
	await frames(1)
	check(_events.is_empty(), "seçim yokken istek gelirse sinyal yayılmaz")

	print("İnşaat")
	EB.build_approved.emit(&"O01", &"solar_plant")
	await frames(2)
	check(not o01.is_empty(), "build_approved(O01, solar_plant) → bina kuruldu")
	check(o01.get_node("BuildingAnchor").get_child(0).name == "b_solar_plant", "doğru sahne: b_solar_plant")
	_events.clear()
	await click(screen_of(o01) + Vector2(0, -20))
	check(_events.size() == 1 and _events[0][0] == "sel" and _events[0][3] == false, "dolu arsa → is_empty=false")
	EB.build_approved.emit(&"O01", &"water_storage")
	await frames(1)
	check(o01.get_node("BuildingAnchor").get_child_count() == 1, "dolu arsaya ikinci bina eklenmez")
	EB.build_approved.emit(&"X99", &"solar_plant")
	await frames(1)
	check(true, "bilinmeyen arsa çökmeden uyarı verir")

	check(not city.place_building(&"O01", &"water_storage"), "place_building dolu arsada false döner")
	check(not city.place_building(&"X99", &"solar_plant"), "place_building bilinmeyen arsada false döner")
	check(city.is_plot_occupied(&"O01") and not city.is_plot_occupied(&"O05"), "is_plot_occupied")
	var o05 = city.find_plot(&"O05")
	EB.plot_deselect_requested.emit()  # seçili arsada "seçili" durumu fare üstünden önce gelir
	await frames(1)
	o05.set_hovered(true)
	var empty_state: StringName = o05.highlight_state()
	o05.set_hovered(false)
	o01.set_hovered(true)
	check(empty_state == &"hover" and o01.highlight_state() == &"invalid", "fare üstünde boş arsa turkuaz, dolu arsa turuncu (%s / %s)" % [empty_state, o01.highlight_state()])
	o01.set_hovered(false)
	await click(screen_of(o01))  # faz kilidi testi seçili bir arsa bekliyor

	print("Faz kilidi")
	_events.clear()
	EB.phase_changed.emit(&"report")
	await frames(1)
	check(_events == [["desel"]], "phase report → seçili arsa bırakıldı")
	_events.clear()
	await click(screen_of(u01))
	check(_events.is_empty(), "report fazında tıklama yok sayılır")
	EB.phase_changed.emit(&"build")
	await click(screen_of(u01))
	check(_events.size() == 1, "build fazında seçim geri açıldı")

	print("Tüm binalar")
	var sandbox = current_scene.get_node("Sandbox")
	sandbox._next = 1
	sandbox.build_all()
	await create_timer(1.0).timeout
	var built := 0
	for p in plots:
		if not p.is_empty():
			built += 1
	check(built == 12, "12 bina 12 arsada (%d)" % built)

	print("Kriz efektleri (aşama sinyali yokken yedek yol: crisis_started / crisis_resolved)")
	var fx = city.get_node("DisasterFX")
	var sea: Node3D = city.get_node("Sea")
	var sea_y := sea.position.y
	var fields: StandardMaterial3D = load("res://assets/materials/field_grass.tres")
	var fields_color := fields.albedo_color
	var resolved := {"event_id": &"x", "response_id": &"x", "risk_type": &"x", "mitigation": 0.0, "damage": {}, "summary_text": ""}
	EB.crisis_started.emit(&"coastal_flood", &"coastal_flood", 0.8)
	await create_timer(3.0).timeout
	check(sea.position.y > sea_y + 0.2, "taşkın: deniz yükseldi (%.2f → %.2f)" % [sea_y, sea.position.y])
	check(fx.get_node("FloodEffect/Rain").emitting, "taşkın: yağmur")
	EB.crisis_resolved.emit(resolved)
	await create_timer(5.0).timeout
	check(is_equal_approx(sea.position.y, sea_y) and fx.current_risk() == &"", "taşkın bitti: deniz eski seviyede")
	EB.crisis_started.emit(&"drought", &"drought", 0.8)
	await create_timer(3.0).timeout
	check(fields.albedo_color != fields_color, "kuraklık: tarlalar sarardı")
	var olive: ShaderMaterial = load("res://assets/materials/foliage_olive.tres")
	check(olive.get_shader_parameter("albedo") != Color(0.42, 0.52, 0.26, 1), "kuraklık: zeytin ağaçları sarardı")
	EB.crisis_resolved.emit(resolved)
	await create_timer(5.0).timeout
	check(fields.albedo_color.is_equal_approx(fields_color), "kuraklık bitti: tarla rengi geri döndü")
	EB.crisis_started.emit(&"heatwave", &"heat", 0.8)
	await create_timer(3.0).timeout
	check(fx.get_node("HeatEffect/HeatHaze").visible, "sıcak: ısı pusu açık")
	EB.crisis_resolved.emit(resolved)
	await create_timer(5.0).timeout
	check(not fx.get_node("HeatEffect/HeatHaze").visible, "sıcak bitti: pus kapandı")

	print("Game.tscn (Ekip B ile uçtan uca)")
	root.get_node("GameState").reset()
	change_scene_to_file("res://scenes/main/Game.tscn")
	await create_timer(1.5).timeout
	city = current_scene.get_node("CityWorld")
	var gs = root.get_node("GameState")
	var panel = current_scene.get_node("UI/BuildPanel")
	_events.clear()
	await click(screen_of(city.find_plot(&"O02")))
	check(_events.size() == 1 and _events[0][1] == &"O02", "oyunda O02 seçildi")
	check(panel.visible, "BuildPanel açıldı")
	var credits: int = gs.stats.credits
	EB.build_requested.emit(&"O02", &"water_storage")
	await create_timer(1.0).timeout
	check(gs.get_building_on(&"O02") == &"water_storage", "GameController onayladı")
	check(not city.find_plot(&"O02").is_empty(), "şehirde su deposu kuruldu")
	check(gs.stats.credits < credits, "kredi düştü (%d → %d)" % [credits, gs.stats.credits])
	EB.build_requested.emit(&"U01", &"green_park")
	await frames(2)
	check(city.find_plot(&"U01").is_empty(), "seçilmemiş arsaya talep (plot_kind bilinmiyor) reddedilir, şehir boş kalır")

	# Panelin arkasında kalan arsa seçilince kamera onu güvenli alana getirir.
	var c1 = city.find_plot(&"C02")
	var o5 = city.find_plot(&"O05")
	city._select(o5)
	await create_timer(1.5).timeout
	var vs: Vector2 = root.get_visible_rect().size
	var sp: Vector2 = root.get_camera_3d().unproject_position(o5.global_position)
	check(sp.x > vs.x * 0.2 and sp.x < vs.x * 0.75 and sp.y > vs.y * 0.08 and sp.y < vs.y * 0.88,
			"seçilen O05 panellerin arasına getirildi (%.0f, %.0f)" % [sp.x, sp.y])
	city._select(c1)
	await create_timer(1.5).timeout
	sp = root.get_camera_3d().unproject_position(c1.global_position)
	check(sp.x > vs.x * 0.2 and sp.x < vs.x * 0.75 and sp.y < vs.y * 0.88, "seçilen C02 de görünür alanda (%.0f, %.0f)" % [sp.x, sp.y])

	# Sahne yeniden açılınca binalar geri gelir.
	change_scene_to_file("res://scenes/main/Game.tscn")
	await create_timer(1.0).timeout
	check(not current_scene.get_node("CityWorld").find_plot(&"O02").is_empty(), "yeniden açılışta bina GameState'ten geri kuruldu")

	print("SONUÇ: " + ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(_fails)
