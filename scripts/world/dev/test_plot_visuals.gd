extends SceneTree
## Sahip: A. Görsel revizyon Prompt 2 testi: arsa etiketleri, inşaat modu, fare üstü, seçim vurguları.
## Gerçek Game.tscn'de gerçek fare olaylarıyla (mevcut ışın testi). Çalıştırma:
## <godot> --path . --resolution 1280x720 --script res://scripts/world/dev/test_plot_visuals.gd

var _fails := 0
var city
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await create_timer(t).timeout


func plot(id: StringName) -> BuildPlot:
	return city.find_plot(id)


func mouse_to(id) -> void:
	var e := InputEventMouseMotion.new()
	e.position = cam.unproject_position(plot(id).global_position) if id != null else _empty_point()
	e.global_position = e.position
	root.push_input(e, true)  # görünüm koordinatı (1920x1080 taban ölçeklenir)
	await wait(0.15)


## Hiçbir arsanın tıklama kutusuna denk gelmeyen ekran noktası (mevcut ışın testiyle bulunur).
func _empty_point() -> Vector2:
	var size := root.get_visible_rect().size
	for y in range(40, int(size.y), 60):
		for x in range(40, int(size.x), 60):
			if city._plot_at(Vector2(x, y)) == null:
				return Vector2(x, y)
	return Vector2(4, 4)


func click(id: StringName) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = cam.unproject_position(plot(id).global_position)
		e.global_position = e.position
		root.push_input(e, true)
	await wait(0.2)


func states() -> Dictionary:
	var result := {}
	for p in city.get_plots():
		result[p.plot_id] = p.highlight_state()
	return result


func _run() -> void:
	var bus = root.get_node("EventBus")
	var gs = root.get_node("GameState")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(2.0)
	city = current_scene.get_node("CityWorld")
	cam = root.get_camera_3d()
	current_scene.get_node("UI").visible = false  # yalnızca 3D katmanı; tıklamalar arayüze takılmasın
	for b in [[&"U02", &"urban", &"cooling_center"], [&"O01", &"open", &"solar_plant"]]:
		gs.stats.credits = 3000
		bus.plot_selected.emit(b[0], b[1], true)
		bus.build_requested.emit(b[0], b[2])
	bus.plot_deselect_requested.emit()
	city.get_camera_rig().set_view({"position": Vector3(-3, 0, -4), "zoom": 40.0, "yaw": 0.0}, true)
	await wait(1.0)
	var plots_before := var_to_str(gs.plots)

	print("\n[1] normal görünüm")
	await mouse_to(null)
	var labels_hidden := true
	for p in city.get_plots():
		labels_hidden = labels_hidden and not p.is_debug_visible()
		labels_hidden = labels_hidden and p.find_child("Label", true, false) != null  # silinmedi, gizli
	check(labels_hidden, "15 arsanın kimlik etiketi gizli (node'lar ve kimlikler duruyor)")
	check(states().values().all(func(s): return s == &""), "normal görünümde hiçbir arsada vurgu yok")
	check(plot(&"U03").plot_id == &"U03" and plot(&"C01").plot_kind == &"coastal", "arsa kimlikleri ve türleri korunuyor")
	city.show_debug_overlay = true
	check(plot(&"U03").is_debug_visible() and plot(&"U03").find_child("Label", true, false).text == "U03 · KENT", "geliştirici katmanı açılınca etiketler geri geliyor")
	city.show_debug_overlay = false
	check(not plot(&"U03").is_debug_visible(), "geliştirici katmanı kapanınca etiketler yine gizli")

	print("\n[3] fare üstü")
	await mouse_to(&"U03")
	var s := states()
	check(s[&"U03"] == &"hover" and s.values().count(&"") == 14, "fare U03'te: yalnızca U03 turkuaz (hover)")
	await mouse_to(&"U02")
	s = states()
	check(s[&"U02"] == &"invalid" and s[&"U03"] == &"", "dolu U02'de turuncu (uygun değil), U03'ün vurgusu kalktı")
	await mouse_to(null)
	check(states().values().all(func(x): return x == &""), "fare çıkınca vurgu yok")

	print("\n[2] inşaat modu ve [4] seçim")
	await click(&"U07")
	await mouse_to(null)
	s = states()
	check(city.is_build_mode() and s[&"U07"] == &"selected", "U07 tıklandı: inşaat modu açık, U07 seçili (mavi)")
	var buildable_ok := true
	for p in city.get_plots():
		if p.plot_id == &"U07":
			continue
		var want := &"buildable" if p.is_empty() else &""
		buildable_ok = buildable_ok and s[p.plot_id] == want
	check(buildable_ok, "inşaat modunda boş arsalar ince yeşil çerçeveli, dolu arsalar parlamıyor (%d çerçeve) %s" % [s.values().count(&"buildable"), "" if buildable_ok else str(s)])
	await mouse_to(&"U03")
	s = states()
	check(s[&"U07"] == &"selected" and s[&"U03"] == &"hover", "başka arsanın üstüne gelince seçim korunuyor, U03 hover")
	await mouse_to(null)
	check(states()[&"U03"] == &"buildable", "fare ayrılınca U03 inşaat modu çerçevesine döndü")
	check(plot(&"U07").get("_selected") and not plot(&"U03").get("_selected"), "seçim mantığı (BuildPlot._selected) değişmedi")

	print("\n[5] inşaat modundan çıkış")
	bus.plot_deselect_requested.emit()
	await wait(0.2)
	s = states()
	check(not city.is_build_mode() and s.values().all(func(x): return x == &""), "panel kapanınca (v1.3) bütün vurgular kalktı %s" % ("" if s.values().all(func(x): return x == &"") else str(s)))
	await click(&"U07")
	bus.phase_changed.emit(&"report")
	await wait(0.2)
	check(states().values().all(func(x): return x == &"") and not city.is_build_mode(), "build dışı fazda vurgu ve inşaat modu yok")
	await mouse_to(&"U03")
	check(states()[&"U03"] == &"", "build dışı fazda fare üstü vurgu yok")
	bus.phase_changed.emit(&"build")
	await wait(0.2)

	print("\n[4b] inşa sonrası")
	await click(&"U04")
	gs.stats.credits = 3000
	bus.build_requested.emit(&"U04", &"green_park")
	await wait(0.5)
	check(plot(&"U04").is_occupied(), "bina yerleştirme çalışıyor (U04'e park)")
	bus.plot_deselect_requested.emit()
	await wait(0.2)

	print("\n[7] kamera ve zoom")
	await click(&"U07")
	var rig: CameraRig = city.get_camera_rig()
	rig.set_view({"position": Vector3(10, 0, -10), "zoom": 80.0, "yaw": 0.4}, true)
	await wait(0.4)
	var hl: MeshInstance3D = plot(&"U07").get_node("VisualOverlay/Highlight")
	check(hl.is_visible_in_tree() and hl.global_position.is_equal_approx(plot(&"U07").global_position),
		"kamera kayıp dönünce ve uzaklaşınca seçim çerçevesi arsada kalıyor")
	check(hl.get_aabb().size.x >= plot(&"U07").size - 0.1 and hl.get_aabb().size.x <= plot(&"U07").size + 0.01,
		"çerçeve arsa ölçüsünde (%.2f m, arsa %.0f m)" % [hl.get_aabb().size.x, plot(&"U07").size])
	bus.plot_deselect_requested.emit()

	print("\n[6] performans ve kaynaklar")
	var meshes := {}
	var materials := {}
	for p in city.get_plots():
		var h: MeshInstance3D = p.get_node("VisualOverlay/Highlight")
		meshes[h.mesh] = true
		p.set_buildable_hint(true)
		if p.is_empty():
			materials[h.material_override] = true
	check(meshes.size() == 2, "çerçeve mesh'i arsa boyutu başına bir tane, paylaşılıyor (%d mesh)" % meshes.size())
	check(materials.size() == 1, "aynı durumdaki (boş) arsalar tek materyali paylaşıyor")
	var processing := 0
	for p in city.get_plots():
		processing += 1 if p.is_processing() else 0
	check(processing == 0, "inşaat modu çerçeveleri her kare iş yapmıyor (animasyon yalnızca hover/seçimde)")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await wait(2.0)
	var fps := (Engine.get_frames_drawn() - f0) / ((Time.get_ticks_msec() - t0) / 1000.0)
	print("    15 arsa vurgulu: %.0f FPS" % fps)
	check(fps > 60.0, "bütün arsalar vurguluyken FPS yeterli (%.0f)" % fps)
	for p in city.get_plots():
		p.set_buildable_hint(false)
	check(var_to_str(gs.plots) != plots_before and gs.plots.has(&"U04"), "GameState yalnızca gerçek inşaatla değişti (U04)")

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)
