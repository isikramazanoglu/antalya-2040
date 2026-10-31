extends SceneTree
## Sahip: A. Prompt 10B testi: final şehir sunumu, FINAL_VISUAL_CONTRACT.md kabul ölçütleri 1–6 + Esc + geçici binalar.
## Çalıştırma: <godot> --path . --resolution 1280x720 --script res://scripts/world/dev/test_final_presentation.gd
## (1920x1080 ile de). Gerçek Game.tscn'i 2052'ye kadar oynatır; ~2,5 dakika sürer. SONUÇ: TAMAM beklenir.

const PLAN := {
	2040: [[&"O01", &"open", &"solar_plant"], [&"U01", &"urban", &"green_park"]],
	2042: [[&"O02", &"open", &"water_storage"]],
	2044: [[&"C01", &"coastal", &"coastal_restoration"]],
	2046: [[&"U02", &"urban", &"cooling_center"]],
}

var _fails := 0
var _finished := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await create_timer(t).timeout


## Sunum belirli sahneye gelene (adım metninde "●  <ad>") ya da bitene kadar bekler.
func wait_step(presentation, step: String, limit := 90.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < limit * 1000.0:
		if not presentation.is_playing():
			return false
		if presentation._steps.text.contains("●  " + step):
			return true
		await wait(0.2)
	return false


func wait_finished(count: int, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while _finished < count and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await wait(0.2)
	return (Time.get_ticks_msec() - t0) / 1000.0


func snapshot(gs) -> String:
	return var_to_str([gs.plots, gs.stats, gs.build_log, gs.crisis_log, gs.history.size(), gs.phase])


func visible_building(city, plot: BuildPlot) -> Node3D:
	var real := plot.get_building()
	if real and real.visible:
		return real
	var stand_in: Node3D = city._stand_ins.get(plot.plot_id)
	return stand_in if stand_in and stand_in.visible else null


func _run() -> void:
	var bus = root.get_node("EventBus")
	var gs = root.get_node("GameState")
	var cat = root.get_node("Catalog")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(2.0)
	bus.final_presentation_finished.connect(func(): _finished += 1)
	bus.crisis_started.connect(func(id, _r, _s):
		var opts := EventManager.available_responses(cat.get_event(id), gs.built_definitions())
		bus.crisis_response_chosen.emit(id, opts[0].id if opts[0].cost <= gs.stats.credits else &"do_nothing"))
	var summary := {}
	bus.game_over.connect(func(s): summary.merge(s))
	var year := 2040
	while gs.phase != &"game_over" and year < 2060:
		for b in PLAN.get(year, []):
			gs.stats.credits = maxi(gs.stats.credits, 2000)
			bus.plot_selected.emit(b[0], b[1], true)
			bus.build_requested.emit(b[0], b[2])
		bus.end_turn_requested.emit()
		await process_frame
		bus.report_closed.emit()
		await process_frame
		year += 1
	await wait(1.0)
	var game := current_scene
	var city = game.get_node("CityWorld")
	var rig: CameraRig = city.get_camera_rig()
	var presentation = city.get_node("FinalPresentation")  # tipsiz: --script derlemesi autoload yüklenmeden olur
	var final_ui = game.get_node("UI/FinalReport")
	var button: Button = final_ui.find_child("PresentButton", true, false)
	print("\n[1] düğme ve başlangıç")
	check(gs.phase == &"game_over" and summary.has("city_2052"), "oyun 2052'de bitti, summary geldi")
	check(button.visible, "Ekip A dinlediği için \"Şehrin dönüşümünü izle\" düğmesi görünüyor")
	var max_ui_layer := 0
	for layer in game.find_children("*", "CanvasLayer", true, false):
		if not city.is_ancestor_of(layer):
			max_ui_layer = maxi(max_ui_layer, layer.layer)
	check(presentation._layer.layer > max_ui_layer, "sunum katmanı arayüzün üstünde (%d > %d)" % [presentation._layer.layer, max_ui_layer])

	var before := snapshot(gs)
	var view_before: Dictionary = rig.get_view()
	var real_buildings := {}
	for plot in city.get_plots():
		if plot.get_building():
			real_buildings[plot.plot_id] = plot.get_building()
	button.pressed.emit()
	var t0 := Time.get_ticks_msec()

	print("\n[2] 2040 görünümü")
	await wait(2.5)
	var all_hidden := true
	for plot in city.get_plots():
		all_hidden = all_hidden and visible_building(city, plot) == null
	check(all_hidden, "2040: arsalarda bina görünmüyor (city_2040.plots boş)")
	check(not final_ui.visible and presentation._layer.visible, "rapor gizli, sunum katmanı açık")
	check(rig.cinematic and root.disable_3d, "kamera sinematik modda, ana görünümün 3D çizimi kapalı")
	check(presentation._image_2040 != null, "2040 görüntüsü karşılaştırma için alındı")
	Input.parse_input_event(_key(KEY_W, true))
	var view_mid: Dictionary = rig.get_view()
	await wait(0.5)
	Input.parse_input_event(_key(KEY_W, false))
	check(rig.get_view().position.distance_to(view_mid.position) < 3.0, "sunum sırasında WASD kamerayı oynatmıyor")

	print("\n[3] dönüşüm ve 2052")
	check(await wait_step(presentation, "2052"), "dönüşüm sahnesinden 2052 sahnesine geçildi")
	var final_plots: Dictionary = summary.city_2052.plots
	var layout_ok := true
	for plot in city.get_plots():
		var want := StringName(final_plots.get(plot.plot_id, &""))
		var shown := visible_building(city, plot)
		if want == &"":
			layout_ok = layout_ok and shown == null
		else:
			var shown_id: StringName = shown.building_id if shown is Building else &""
			layout_ok = layout_ok and shown_id == want
			if shown_id != want:
				print("    %s: beklenen %s, görünen %s" % [plot.plot_id, want, shown_id])
	check(layout_ok, "2052: %d yatırımın her biri doğru modelle, boş arsalar boş" % final_plots.size())
	check(await wait_step(presentation, "Karşılaştırma"), "karşılaştırma sahnesi geldi")
	await wait(1.0)
	check(presentation._before.visible and presentation._divider.visible, "2040 ↔ 2052 perdesi açık")

	print("\n[4] bitiş")
	var secs := await wait_finished(1, 90.0)
	var total := (Time.get_ticks_msec() - t0) / 1000.0
	check(_finished == 1, "final_presentation_finished bir kez yayıldı")
	check(total < 100.0, "sunum B'nin 120 sn yedeğinden önce bitti (%.1f sn)" % total)
	await wait(1.0)
	check(final_ui.visible, "final raporu geri geldi")
	check(not rig.cinematic and not root.disable_3d and not presentation._layer.visible, "kamera oyuncuya, 3D çizim ana görünüme döndü, katman kapandı")
	check(rig.get_view().position.is_equal_approx(view_before.position) and is_equal_approx(rig.get_view().zoom, view_before.zoom),
		"kamera sunum öncesi görünüme döndü")
	var restored := true
	for plot_id in real_buildings:
		restored = restored and real_buildings[plot_id].visible and city.find_plot(plot_id).get_building() == real_buildings[plot_id]
	check(restored and city._stand_ins.is_empty(), "gerçek binalar yerinde ve görünür, geçici kopya kalmadı")
	check(snapshot(gs) == before, "GameState değişmedi (plots, stats, build_log, crisis_log, history, faz)")

	print("\n[5] Esc ile atlama")
	button.pressed.emit()
	await wait(3.0)
	var esc := InputEventAction.new()
	esc.action = &"cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait_finished(2, 3.0)
	await wait(1.0)
	check(_finished == 2 and final_ui.visible, "Esc sunumu bitirdi, bitiş sinyali yayıldı, rapor geri geldi")
	check(not rig.cinematic and not root.disable_3d and city._stand_ins.is_empty() and snapshot(gs) == before,
		"atlamadan sonra kamera, görünüm ve GameState asıl hâlinde")

	print("\n[6] geçici binalar ve eksik veri")
	var odd: Dictionary = summary.duplicate(true)
	odd.city_2052.plots[&"U08"] = &"food_rescue"
	odd.city_2052.plots[&"O05"] = &"unknown_building"
	odd.city_2052.builds.append({"plot_id": &"U08", "building_id": &"food_rescue", "year": 2051, "cost": 100})
	presentation.play(odd)
	check(await wait_step(presentation, "2052"), "değiştirilmiş yerleşimle sunum 2052'ye geldi")
	var u08: BuildPlot = city.find_plot(&"U08")
	var stand_in := visible_building(city, u08)
	check(stand_in is Building and stand_in.building_id == &"food_rescue" and u08.is_empty(),
		"şehirde olmayan yatırım geçici kopyayla gösterildi, arsaya kalıcı bina eklenmedi")
	check(visible_building(city, city.find_plot(&"O05")) == null, "bilinmeyen yatırım kimliği boş arsa olarak geçildi (uyarı)")
	presentation.skip()
	await wait_finished(3, 3.0)
	await wait(0.6)
	check(city._stand_ins.is_empty() and u08.is_empty() and gs.get_building_on(&"U08") == &"", "geçici kopya silindi, U08 boş kaldı")
	presentation.play({})
	await wait_finished(4, 2.0)
	check(_finished == 4 and not presentation.is_playing(), "summary eksikse sunum atlanıp hemen bitiş yayıldı")
	presentation.play({"city_2040": {"plots": {}}, "city_2052": {"year": 2052, "plots": {}, "builds": []}})
	await wait(5.5)
	check(presentation.is_playing() and presentation._caption.text.contains("yatırım yapılmadı"), "hiç yatırım yoksa sunum çökmeden \"yatırım yapılmadı\" diyor")
	presentation.skip()
	await wait_finished(5, 3.0)
	await wait(0.6)
	check(_finished == 5 and snapshot(gs) == before, "yatırımsız sunum da temiz bitti, GameState değişmedi")

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)


func _key(code: Key, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e
