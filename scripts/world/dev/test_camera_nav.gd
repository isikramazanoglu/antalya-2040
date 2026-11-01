extends SceneTree
## Sahip: A. Görsel revizyon 5 · kamera navigasyonu testi: WASD + ok tuşları (ekran yönü), sabit açı,
## orta tuşla zemini tutup sürükleme, arayüzle çakışma, zoom ve pan hızı, sınırlar, yazı alanı, seçim.
## A11: sol tuşla sürükleme (eşik, seçimle çakışmama, arayüz, yakın/uzak zoom, sınırlar).
## Gerçek Game.tscn, gerçek tuş/fare olayları. Çalıştırma:
## <godot> --path . --resolution 1280x720 --script res://scripts/world/dev/test_camera_nav.gd

var _fails := 0
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


func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


## Tuşu basılı tutar, kamera durulana kadar bekler; bakılan noktanın ekranda nereye kaydığını döndürür.
func hold(code: Key, seconds: float) -> Vector2:
	var probe := rig.position
	var before := cam.unproject_position(probe)
	key(code, true)
	await wait(seconds)
	key(code, false)
	await wait(0.8)
	return cam.unproject_position(probe) - before


## Gerçek imleç de yapay olayın konumunda (test sırasında fare kımıldarsa karışmasın).
func push_mouse(e: InputEventMouse) -> void:
	var scale := Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	Input.warp_mouse(e.position * scale)
	root.push_input(e, true)


func middle(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_MIDDLE
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_MIDDLE if pressed else 0
	e.position = pos
	e.global_position = pos
	push_mouse(e)


func left(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	push_mouse(e)


func motion(from: Vector2, to: Vector2, held := true, mask := MOUSE_BUTTON_MASK_MIDDLE) -> void:
	var steps := 8
	for i in steps:
		var e := InputEventMouseMotion.new()
		e.position = from.lerp(to, float(i + 1) / steps)
		e.relative = (to - from) / steps
		e.global_position = e.position
		e.button_mask = mask if held else 0
		push_mouse(e)
		await process_frame


## Ekran noktasının altındaki zemin (y = 0) noktası.
func ground(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	return o + d * (-o.y / d.y)


func _run() -> void:
	var bus = root.get_node("EventBus")
	var gs = root.get_node("GameState")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(2.0)
	city = current_scene.get_node("CityWorld")
	rig = city.get_camera_rig()
	cam = root.get_camera_3d()
	gs.stats.credits = 3000
	bus.plot_selected.emit(&"U06", &"urban", true)
	bus.build_requested.emit(&"U06", &"transit_hub")
	bus.plot_deselect_requested.emit()
	await wait(1.0)
	var building: Node3D = city.find_plot(&"U06").get_building()
	var building_pos := building.global_position
	var start_view := rig.get_view()
	var yaw0 := rig.rotation.y
	var pitch0: float = rig.get_node("Pitch").rotation.x
	rig.set_view({"position": Vector3(-3, 0, -4), "zoom": 50.0, "yaw": 0.0}, true)
	await wait(0.3)

	print("\n[1-5] klavye: WASD ve ok tuşları ekran yönünde")
	var moves := {}
	for pair in [[KEY_W, "W"], [KEY_S, "S"], [KEY_A, "A"], [KEY_D, "D"], [KEY_UP, "↑"], [KEY_DOWN, "↓"], [KEY_LEFT, "←"], [KEY_RIGHT, "→"]]:
		moves[pair[1]] = await hold(pair[0], 0.4)
	# W (haritada yukarı) → görüntü aşağı kayar; D (sağa) → görüntü sola kayar.
	var dir_ok := func(v: Vector2, want: Vector2) -> bool: return v.length() > 40.0 and v.normalized().dot(want) > 0.95
	check(dir_ok.call(moves["W"], Vector2.DOWN) and dir_ok.call(moves["↑"], Vector2.DOWN), "W ve ↑: harita ekranda yukarı yönde gezildi (%s, %s)" % [moves["W"].round(), moves["↑"].round()])
	check(dir_ok.call(moves["S"], Vector2.UP) and dir_ok.call(moves["↓"], Vector2.UP), "S ve ↓: aşağı (%s, %s)" % [moves["S"].round(), moves["↓"].round()])
	check(dir_ok.call(moves["A"], Vector2.RIGHT) and dir_ok.call(moves["←"], Vector2.RIGHT), "A ve ←: sola (%s, %s)" % [moves["A"].round(), moves["←"].round()])
	check(dir_ok.call(moves["D"], Vector2.LEFT) and dir_ok.call(moves["→"], Vector2.LEFT), "D ve →: sağa (%s, %s)" % [moves["D"].round(), moves["→"].round()])
	check(is_equal_approx(rig.rotation.y, yaw0) and is_equal_approx(rig.get_node("Pitch").rotation.x, pitch0), "kaydırmada kamera açısı değişmedi")
	await hold(KEY_Q, 0.6)
	await hold(KEY_E, 0.6)
	check(is_equal_approx(rig.rotation.y, yaw0), "Q/E kamerayı döndürmüyor (sabit açı)")

	print("\n[6-7] orta tuşla sürükleme")
	rig.set_view({"position": Vector3(-3, 0, -4), "zoom": 50.0, "yaw": 0.0}, true)
	await wait(0.4)
	var size := root.get_visible_rect().size
	var a := size * Vector2(0.55, 0.45)
	var b := size * Vector2(0.7, 0.6)
	var grabbed := ground(a)
	middle(true, a)
	await motion(a, b)
	middle(false, b)
	await wait(0.2)
	var under_b := ground(b)
	check(Vector2(under_b.x, under_b.z).distance_to(Vector2(grabbed.x, grabbed.z)) < 0.3,
		"sürüklenen zemin noktası imleçle birlikte gitti (sapma %.2f m)" % Vector2(under_b.x, under_b.z).distance_to(Vector2(grabbed.x, grabbed.z)))
	var after_release := rig.position
	await motion(b, a, false)
	await wait(0.3)
	check(rig.position.distance_to(after_release) < 0.01 and not rig._dragging, "tuş bırakılınca hareket durdu")
	middle(true, a)
	await motion(a, b)
	await motion(b, a, false)  # tuş başka yerde (ör. arayüzde) bırakıldı: bırakma olayı gelmedi
	check(not rig._dragging, "tuş arayüzün üstünde bırakılsa da sürükleme takılı kalmıyor")
	check(is_equal_approx(rig.rotation.y, yaw0) and is_equal_approx(rig.get_view().zoom, 50.0), "sürüklemede açı ve yakınlık sabit")

	print("\n[13-14] arayüzle çakışma")
	var bar: Control = current_scene.get_node("UI/HUD").find_child("BottomBar", true, false)
	var on_ui := bar.get_global_rect().get_center()
	var before_ui := rig.position
	middle(true, on_ui)
	await motion(on_ui, on_ui + Vector2(0, -200))
	middle(false, on_ui + Vector2(0, -200))
	await wait(0.4)
	check(rig.position.distance_to(before_ui) < 0.01, "alt çubuğun üstünde başlayan sürükleme haritayı oynatmadı")
	var edit := LineEdit.new()
	current_scene.get_node("UI").add_child(edit)
	edit.grab_focus()
	await process_frame
	var typed := await hold(KEY_W, 0.4)
	check(typed.length() < 1.0, "yazı alanı odaktayken W haritayı kaydırmıyor")
	edit.queue_free()
	await process_frame

	print("\n[8-10] zoom ve pan hızı")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = size * 0.5
	var zoom_before: float = rig.get_view().zoom
	push_mouse(wheel)
	await wait(0.3)
	check(rig.get_view().zoom < zoom_before, "tekerlek yakınlaştırıyor (%.0f → %.0f)" % [zoom_before, rig.get_view().zoom])
	var speeds := []
	for z in [30.0, 90.0]:
		rig.set_view({"position": Vector3(-3, 0, -4), "zoom": z, "yaw": 0.0}, true)
		await wait(0.3)
		var p0 := rig.position
		await hold(KEY_D, 0.5)
		speeds.append(rig.position.distance_to(p0))
	check(speeds[1] > speeds[0] * 2.0, "uzakta pan daha hızlı, yakında daha yavaş (yakın %.1f m, uzak %.1f m)" % [speeds[0], speeds[1]])

	print("\n[11-12] sınırlar")
	rig.set_view({"position": Vector3(0, 0, -6), "zoom": 60.0, "yaw": 0.0}, true)
	await hold(KEY_D, 4.0)
	await hold(KEY_S, 4.0)
	var b_rect: Rect2 = rig.bounds
	var p := Vector2(rig.position.x, rig.position.z)
	check(p.x <= b_rect.end.x + 0.01 and p.y <= b_rect.end.y + 0.01 and (p.x > b_rect.end.x - 1.0 or p.y > b_rect.end.y - 1.0),
		"sınıra kadar gidiyor ve dışarı çıkmıyor (%.1f, %.1f; sınır %.0f, %.0f)" % [p.x, p.y, b_rect.end.x, b_rect.end.y])

	print("\n[A11] sol tuşla sürükleme")
	var picked_l := []
	var on_pick := func(id, _k, _e): picked_l.append(id)
	bus.plot_selected.connect(on_pick)
	rig.set_view({"position": Vector3(0, 0, -4), "zoom": 50.0, "yaw": 0.0}, true)
	await wait(0.4)
	# Arsanın üstünde basıp sürükle: harita imleçle gider, arsa seçilmez.
	var start_l := cam.unproject_position(city.find_plot(&"U07").global_position)
	var end_l := start_l + Vector2(-260, -140)
	var grabbed_l := ground(start_l)
	left(true, start_l)
	await motion(start_l, end_l, true, MOUSE_BUTTON_MASK_LEFT)
	var hovered_while: bool = city._hovered != null
	var dragging_now := rig.is_left_dragging()
	left(false, end_l)
	await wait(0.3)
	var under_l := ground(end_l)
	var dev_l := Vector2(under_l.x, under_l.z).distance_to(Vector2(grabbed_l.x, grabbed_l.z))
	check(dragging_now and dev_l < 0.3, "sol tuşla sürükleme: tutulan zemin imleçle gitti (sapma %.2f)" % dev_l)
	check(picked_l.is_empty(), "sürükleme bitince arsa seçilmedi (%s)" % str(picked_l))
	check(not hovered_while, "sürüklenirken arsa fare üstü vurgusu yok")
	check(is_equal_approx(rig.rotation.y, yaw0) and is_equal_approx(rig.get_node("Pitch").rotation.x, pitch0) and is_equal_approx(rig.get_view().zoom, 50.0),
		"sol sürüklemede açı ve yakınlık sabit")
	var rest := rig.position
	await motion(end_l, start_l, false, MOUSE_BUTTON_MASK_LEFT)
	await wait(0.3)
	check(rig.position.distance_to(rest) < 0.01, "tuş bırakılınca kamera yeni yerinde kaldı")
	# Eşiğin altındaki titreşim tıklamadır: arsa seçilir, kamera kıpırdamaz.
	var plot_pos := cam.unproject_position(city.find_plot(&"U07").global_position)
	var cam_before := rig.position
	left(true, plot_pos)
	await motion(plot_pos, plot_pos + Vector2(4, 3), true, MOUSE_BUTTON_MASK_LEFT)
	left(false, plot_pos + Vector2(4, 3))
	await wait(0.3)
	check(picked_l == [&"U07"], "küçük titreşimli kısa tıklama arsayı seçti (%s)" % str(picked_l))
	check(rig.position.distance_to(cam_before) < 0.05, "eşik altında kamera kıpırdamadı")
	bus.plot_deselect_requested.emit()
	await wait(0.2)
	picked_l.clear()
	# Arayüzde başlayan sol sürükleme haritayı oynatmaz, arsa seçmez.
	var before_ui_l := rig.position
	left(true, on_ui)
	await motion(on_ui, on_ui + Vector2(0, -260), true, MOUSE_BUTTON_MASK_LEFT)
	left(false, on_ui + Vector2(0, -260))
	await wait(0.4)
	check(rig.position.distance_to(before_ui_l) < 0.01 and picked_l.is_empty(), "alt çubukta başlayan sol sürükleme haritayı oynatmadı, seçim yok")
	# Haritada başlayıp arayüzde bırakılırsa (bırakma olayı gelmez) sürükleme takılı kalmaz.
	left(true, size * 0.5)
	await motion(size * 0.5, size * 0.6, true, MOUSE_BUTTON_MASK_LEFT)
	await motion(size * 0.6, size * 0.5, false, MOUSE_BUTTON_MASK_LEFT)
	check(not rig.is_left_dragging(), "tuş arayüzde bırakılsa da sol sürükleme takılmıyor")
	# Yakın ve uzak zoomda hassasiyet: tutulan zemin her ikisinde de imleçte (yakında az, uzakta çok kayar).
	var travelled := []
	var devs := []
	for z in [22.0, 95.0]:
		rig.set_view({"position": Vector3(0, 0, -4), "zoom": z, "yaw": 0.0}, true)
		await wait(0.4)
		var p0 := rig.position
		var s0 := size * Vector2(0.5, 0.5)
		var s1 := size * Vector2(0.62, 0.58)
		var g0 := ground(s0)
		left(true, s0)
		await motion(s0, s1, true, MOUSE_BUTTON_MASK_LEFT)
		left(false, s1)
		await wait(0.3)
		var g1 := ground(s1)
		devs.append(Vector2(g1.x, g1.z).distance_to(Vector2(g0.x, g0.z)))
		travelled.append(rig.position.distance_to(p0))
	check(devs[0] < 0.3 and devs[1] < 0.3 and travelled[1] > travelled[0] * 2.5,
		"hassasiyet zoom'a göre: yakın %.1f m, uzak %.1f m kaydı; zemin imleçte (sapma %.2f / %.2f)" % [travelled[0], travelled[1], devs[0], devs[1]])
	# Sınırlar: çok uzun sürükleme sınırda durur.
	rig.set_view({"position": Vector3(0, 0, -6), "zoom": 60.0, "yaw": 0.0}, true)
	await wait(0.3)
	for k in 6:
		left(true, size * Vector2(0.8, 0.8))
		await motion(size * Vector2(0.8, 0.8), size * Vector2(0.15, 0.15), true, MOUSE_BUTTON_MASK_LEFT)
		left(false, size * Vector2(0.15, 0.15))
	await wait(1.0)
	var pl := Vector2(rig.position.x, rig.position.z)
	var bl: Rect2 = rig.bounds
	check(bl.grow(0.01).has_point(pl) and (pl.x > bl.end.x - 1.0 or pl.y > bl.end.y - 1.0),
		"sol sürüklemeyle sınıra varılıyor, dışına çıkılmıyor (%.1f, %.1f)" % [pl.x, pl.y])
	# Normal tıklama sürüklemelerden sonra da çalışıyor.
	rig.set_view({"position": Vector3(4, 0, -1), "zoom": 45.0, "yaw": 0.0}, true)
	await wait(0.4)
	picked_l.clear()
	var u08 := cam.unproject_position(city.find_plot(&"U08").global_position)
	left(true, u08)
	left(false, u08)
	await wait(0.3)
	check(picked_l == [&"U08"], "sürüklemelerden sonra tıklama yine seçiyor (%s)" % str(picked_l))
	bus.plot_selected.disconnect(on_pick)
	bus.plot_deselect_requested.emit()
	await wait(0.2)

	print("\n[oyun] seçim ve binalar kamera hareketinden etkilenmiyor")
	rig.set_view({"position": Vector3(4, 0, -1), "zoom": 45.0, "yaw": 0.0}, true)
	await wait(0.4)
	var picked := []
	var listener := func(id, _k, _e): picked.append(id)
	bus.plot_selected.connect(listener)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = cam.unproject_position(city.find_plot(&"U07").global_position)
		e.global_position = e.position
		push_mouse(e)
	await wait(0.3)
	bus.plot_selected.disconnect(listener)
	check(picked == [&"U07"], "kaydırıp yakınlaşınca tıklanan arsa doğru seçildi (%s)" % str(picked))
	check(building.global_position.is_equal_approx(building_pos) and gs.get_building_on(&"U06") == &"transit_hub",
		"bina yerinde, GameState aynı")
	bus.plot_deselect_requested.emit()
	rig.cinematic = true
	var cine0 := rig.position
	await hold(KEY_D, 0.4)
	check(rig.position.distance_to(cine0) < 0.01, "final sunumunda (sinematik) klavye kamerayı oynatmıyor")
	rig.cinematic = false
	rig.set_view(start_view, true)

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)
