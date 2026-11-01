extends SceneTree
## Sahip: A. Prompt A12 · inşaat gösterimi kamerası testi. Gerçek Game.tscn, gerçek EventBus inşaat akışı
## (plot_selected + build_requested → GameController onayı → build_approved). Çalıştırma:
## <godot> --path . --script res://scripts/world/dev/test_showcase.gd

var _fails := 0
var bus
var gs
var city
var rig: CameraRig
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await create_timer(t).timeout


func build(plot_id: StringName, kind: StringName, building_id: StringName) -> void:
	bus.plot_selected.emit(plot_id, kind, true)
	bus.build_requested.emit(plot_id, building_id)


func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func push_mouse(e: InputEventMouse) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	Input.warp_mouse(e.position * scale)
	root.push_input(e, true)


func left(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	push_mouse(e)


func drag_left(from: Vector2, to: Vector2) -> void:
	left(true, from)
	for i in 8:
		var e := InputEventMouseMotion.new()
		e.position = from.lerp(to, float(i + 1) / 8)
		e.relative = (to - from) / 8
		e.global_position = e.position
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		push_mouse(e)
		await process_frame
	left(false, to)


## Gösterimi izler: en yakın an, bekleme sırasında binanın ekrandaki yeri; bitince dönülen görünüm.
func watch(box: AABB, seconds: float) -> Dictionary:
	var size := root.get_visible_rect().size
	var min_zoom := INF
	var centered := false
	var max_step := 0.0
	var last := rig.position
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame
		min_zoom = minf(min_zoom, cam.position.z)
		max_step = maxf(max_step, rig.position.distance_to(last))
		last = rig.position
		var s := cam.unproject_position(box.get_center())
		if Rect2(size * 0.3, size * 0.4).has_point(s):
			centered = true
	return {"min_zoom": min_zoom, "centered": centered, "max_step": max_step}


func _run() -> void:
	bus = root.get_node("EventBus")
	gs = root.get_node("GameState")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(2.0)
	city = current_scene.get_node("CityWorld")
	rig = city.get_camera_rig()
	cam = root.get_camera_3d()
	gs.stats.credits = 99999
	var stats_keys: Array = gs.get_stats().keys()

	print("\n[1] küçük yapı (konut, U03): yaklaş, göster, önceki görünüme dön")
	rig.set_view({"position": Vector3(-8, 0, -2), "zoom": 70.0, "yaw": 0.0}, true)
	await wait(0.4)
	var home := rig.get_view()
	var yaw0 := rig.rotation.y
	build(&"U03", &"urban", &"efficient_housing")
	await process_frame
	check(rig.is_showcasing(), "başarılı inşaattan sonra gösterim başladı")
	var box_small: AABB = city.building_bounds(city.find_plot(&"U03"))
	var w := await watch(box_small, 4.5)
	check(w.centered, "bina bekleme sırasında ekranın ortasında")
	var small_zoom: float = rig.showcase_zoom_for(box_small)
	check(absf(w.min_zoom - small_zoom) < 1.5 and small_zoom >= rig.zoom_min, "küçük yapıda yakınlık %.0f (en yakın %.0f, sınır %.0f)" % [small_zoom, w.min_zoom, rig.zoom_min])
	check(w.max_step < 1.5, "kamera sıçramadan, yumuşak hareket etti (kare başına en çok %.2f)" % w.max_step)
	await wait(0.6)
	check(not rig.is_showcasing() and flat(rig.position).distance_to(flat(home.position)) < 0.15 and absf(cam.position.z - home.zoom) < 0.5,
		"gösterim bitince önceki konum ve yakınlığa döndü (%.2f, %.1f)" % [flat(rig.position).distance_to(flat(home.position)), cam.position.z])
	check(is_equal_approx(rig.rotation.y, yaw0), "kamera açısı değişmedi")

	print("\n[2] büyük yapı (güneş tesisi, 8 m'lik açık alan O03) ve farklı boyutta yatırım (park, U01)")
	build(&"O03", &"open", &"solar_plant")
	await process_frame
	var box_big: AABB = city.building_bounds(city.find_plot(&"O03"))
	var big_zoom: float = rig.showcase_zoom_for(box_big)
	var wb := await watch(box_big, 4.5)
	check(wb.centered and big_zoom > small_zoom, "büyük yapı daha geniş kadrajda (%.0f > %.0f) ve ortada" % [big_zoom, small_zoom])
	await wait(0.5)
	build(&"U01", &"urban", &"green_park")
	await process_frame
	var box_park: AABB = city.building_bounds(city.find_plot(&"U01"))
	check(box_park.size.x > 1.0 and box_park.size.x <= 6.5, "park kutusu modelden hesaplandı, büyüme animasyonundan etkilenmedi (%.1f m)" % box_park.size.x)
	await wait(4.5)

	print("\n[3] başarısız inşaat: gösterim yok")
	gs.stats.credits = 0
	var before_fail := rig.get_view()
	build(&"U04", &"urban", &"cooling_center")
	await wait(0.5)
	check(not rig.is_showcasing() and city.find_plot(&"U04").is_empty(), "kredi yokken inşaat olmadı, kamera gösterime geçmedi")
	check(flat(rig.position).distance_to(flat(before_fail.position)) < 0.05, "kamera yerinde kaldı")
	gs.stats.credits = 99999
	bus.plot_deselect_requested.emit()

	print("\n[4] gösterim sırasında elle müdahale: gösterim olduğu yerde biter, sıçrama yok")
	var cases := [["WASD (D)", "key"], ["ok tuşu (→)", "arrow"], ["sol sürükleme", "drag"], ["tekerlek", "wheel"]]
	var plots := [[&"U05", &"urban", &"cooling_center"], [&"U06", &"urban", &"transit_hub"], [&"U07", &"urban", &"food_rescue"], [&"U08", &"urban", &"public_efficiency"]]
	for i in cases.size():
		rig.set_view({"position": Vector3(-8, 0, -2), "zoom": 70.0, "yaw": 0.0}, true)
		await wait(0.3)
		build(plots[i][0], plots[i][1], plots[i][2])
		await wait(0.5)
		var started := rig.is_showcasing()
		match cases[i][1]:
			"key":
				key(KEY_D, true)
				await wait(0.3)
				key(KEY_D, false)
			"arrow":
				key(KEY_RIGHT, true)
				await wait(0.3)
				key(KEY_RIGHT, false)
			"drag":
				var size := root.get_visible_rect().size
				await drag_left(size * 0.5, size * 0.5 + Vector2(-120, 60))
			"wheel":
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_WHEEL_DOWN
				e.pressed = true
				e.position = root.get_visible_rect().size * 0.5
				push_mouse(e)
		var cancelled := not rig.is_showcasing()
		var zoom_after := cam.position.z
		# Sıçrama yok: iptalden sonra kare başına adım küçük; gösterim süresi dolduğunda da eski görünüme dönülmez.
		var max_step := 0.0
		var last := rig.position
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 3500:
			await process_frame
			max_step = maxf(max_step, rig.position.distance_to(last))
			last = rig.position
		var from_home := flat(rig.position).distance_to(Vector2(-8, -2))
		check(started and cancelled and not rig.is_showcasing() and from_home > 1.0 and max_step < 1.5,
			"%s gösterimi iptal etti; kamera eski görünüme dönmedi (uzaklık %.1f), sıçrama yok (adım %.2f)" % [cases[i][0], from_home, max_step])
		if cases[i][1] == "wheel":
			check(cam.position.z > zoom_after - 0.5, "tekerlek sonrası yakınlık oyuncuda kaldı (%.0f)" % cam.position.z)
		bus.plot_deselect_requested.emit()

	print("\n[5] harita kenarındaki arsa (C02, kıyı) ve art arda inşaatlar")
	rig.set_view({"position": Vector3(0, 0, -6), "zoom": 80.0, "yaw": 0.0}, true)
	await wait(0.3)
	var home2 := rig.get_view()
	build(&"C02", &"coastal", &"coastal_restoration")
	await wait(0.4)
	build(&"O01", &"open", &"water_storage")
	await wait(0.2)
	build(&"O02", &"open", &"urban_farming")
	await process_frame
	check(rig.is_showcasing(), "art arda inşaatta gösterim tek ve sürüyor (en son yapı)")
	var max_x := -INF
	var max_z := -INF
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
		max_x = maxf(max_x, rig.position.x)
		max_z = maxf(max_z, rig.position.z)
	var b: Rect2 = rig.bounds
	check(max_x <= b.end.x + 0.01 and max_z <= b.end.y + 0.01, "kamera sınırların içinde kaldı (en çok x %.1f, z %.1f)" % [max_x, max_z])
	check(not rig.is_showcasing() and flat(rig.position).distance_to(flat(home2.position)) < 0.15 and absf(cam.position.z - home2.zoom) < 0.5,
		"art arda gösterimlerden sonra ilk görünüme dönüldü")
	# Kenardaki arsa tek başına: hedef sınırla kırpılır.
	rig.showcase(city.building_bounds(city.find_plot(&"C02")))
	await wait(1.4)
	check(rig.position.z <= b.end.y + 0.01, "kıyı arsasında kadraj sınır içinde (z %.1f ≤ %.0f)" % [rig.position.z, b.end.y])
	await wait(3.0)

	print("\n[6] geçersiz bina ve final sunumu")
	var plot_u03 = city.find_plot(&"U03")
	var bnode: Node3D = plot_u03.get_building()
	bnode.get_parent().remove_child(bnode)
	bnode.free()
	city.showcase_building(&"U03")  # bina yok: arsa karesine düşer, hata yok
	await wait(0.2)
	check(rig.is_showcasing(), "bina silinmiş arsada gösterim hata vermeden arsayı gösterdi")
	city.showcase_building(&"X99")  # olmayan arsa: sessizce yok sayılır
	await wait(4.5)
	rig.cinematic = true
	rig.showcase(box_small)
	check(not rig.is_showcasing(), "final sunumunda (sinematik) gösterim yapılmaz")
	rig.cinematic = false

	print("\n[7] gösterimden sonra arsa seçimi")
	rig.set_view({"position": Vector3(4, 0, -1), "zoom": 45.0, "yaw": 0.0}, true)
	await wait(0.4)
	var picked := []
	var on_pick := func(id, _k, _e): picked.append(id)
	bus.plot_selected.connect(on_pick)
	bus.plot_deselect_requested.emit()
	await wait(0.2)
	var p := cam.unproject_position(city.find_plot(&"U07").global_position)
	left(true, p)
	left(false, p)
	await wait(0.3)
	bus.plot_selected.disconnect(on_pick)
	check(picked == [&"U07"], "tıklama arsayı seçiyor (%s)" % str(picked))
	check(gs.get_stats().keys() == stats_keys, "GameState göstergelerinin yapısı değişmedi")

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)
