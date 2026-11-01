extends SceneTree
## Sahip: A. Görsel revizyon 9 · dekoratif trafik testi. Çalıştırma:
## <godot> --path . --script res://scripts/world/dev/test_traffic.gd
## Gerçek Game.tscn: araç kütüphanesi, hareketli araçların yolda kalması ve üst üste binmemesi, yön ve tekerlek
## dönüşü, otobüsün durakta beklemesi, yaya–araç çakışmaması (hızlandırılmış ~80 sn), park yerleri (kaldırımda
## değil), çarpışma şekli olmaması, kamera ve arsa seçimi, GameState'in değişmemesi.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


## Aracın tabanı (dönük dikdörtgenin XZ köşeleri yerine örnek noktalar).
func footprint_points(v: Dictionary) -> PackedVector2Array:
	var follow: PathFollow3D = v.follow
	var fwd := -follow.global_transform.basis.z
	var right := follow.global_transform.basis.x
	var pos := follow.global_position
	var half: float = v.length * 0.5
	var out := PackedVector2Array()
	for a in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for b in [-1.0, 0.0, 1.0]:
			var p: Vector3 = pos + fwd * half * a + right * 0.36 * b
			out.append(Vector2(p.x, p.z))
	return out


func _run() -> void:
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await create_timer(2.0).timeout
	var world: Node3D = current_scene.get_node("CityWorld")
	var traffic = world.get_node("Traffic")
	var ped = world.get_node("Pedestrians")
	var decor = world.get_node("Decor")
	var rig = world.get_node("CameraRig")
	var stats_before: Dictionary = gs.get_stats().duplicate(true)

	print("Araç kütüphanesi")
	var lib_ok := true
	for model in VehicleLibrary.MODELS:
		var scene: Node3D = (load(VehicleLibrary.MODELS[model]) as PackedScene).instantiate()
		var body: MeshInstance3D = scene.get_node("Body")
		var aabb := body.mesh.get_aabb()
		var wheels := scene.get_children().filter(func(c): return c.name.begins_with("Wheel_"))
		var wheel_bottom := INF
		for w: MeshInstance3D in wheels:
			wheel_bottom = minf(wheel_bottom, w.position.y - w.mesh.get_aabb().size.y * 0.5)
		if wheels.size() < 2 or absf(wheel_bottom) > 0.01 or aabb.position.y < -0.01:
			lib_ok = false
			print("       %s: tekerlek %d, taban %.3f, gövde alt %.3f" % [model, wheels.size(), wheel_bottom, aabb.position.y])
		scene.free()
	check(VehicleLibrary.MODELS.size() >= 8 and lib_ok, "%d model; tekerlekler zemine oturuyor, gövde zemine girmiyor" % VehicleLibrary.MODELS.size())
	var sedan_len := VehicleLibrary.length_of(&"sedan") * 2.3
	var bus_len := VehicleLibrary.length_of(&"city_bus") * 2.3
	check(sedan_len > 4.2 and sedan_len < 4.9 and bus_len > 10.0 and bus_len < 12.0, "ölçek: sedan %.1f m, otobüs %.1f m" % [sedan_len, bus_len])

	print("Hareketli araçlar")
	var counts: Dictionary = traffic.get_counts()
	check(counts.moving >= 10, "%d hareketli araç, %d rota" % [counts.moving, counts.routes])
	check(counts.models.size() >= 7 and counts.models.has(&"city_bus") and counts.models.has(&"minibus"), "trafikte %d farklı model, otobüs ve minibüs var" % counts.models.size())
	check(traffic.find_children("*", "CollisionShape3D", true, false).is_empty() and traffic.find_children("*", "CollisionObject3D", true, false).is_empty(), "araçlarda çarpışma şekli / fizik gövdesi yok")
	var roads: Array[Rect2] = []
	for r in decor.ROADS_EW:
		roads.append((r as Rect2).grow(0.05))
	var bus_v: Dictionary = {}
	for v in traffic._vehicles:
		if v.model == &"city_bus":
			bus_v = v
	# Otobüsü durağın 3 birim gerisine al, sonra hızlandırılmış simülasyon.
	var stop_offset: float = bus_v.stop_offset
	(bus_v.follow as PathFollow3D).progress = stop_offset - 3.0
	bus_v.dwelt = false
	var off_road := 0
	var overlaps := 0
	var ped_hits := 0
	var heading_bad := 0
	var bus_stopped_at_stop := false
	var last_pos := {}
	var wheel_spin_seen := false
	rig.set_view({"position": Vector3(-6, 0, -4), "zoom": 22.0, "yaw": 0.0}, true)
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		var walkers: PackedVector3Array = ped.walker_positions()
		for route in traffic._routes:
			var list: Array = route.vehicles
			for i in list.size():
				var v: Dictionary = list[i]
				var pts := footprint_points(v)
				var center := pts[7]
				var inside := false
				for r in roads:
					if r.has_point(center):
						inside = true
				# U dönüşleri de yol dikdörtgeninin içinde (cadde x ±54,85 < 56; kuzey yolu ±37,1 < 38).
				if not inside:
					off_road += 1
				# Aynı rotadaki öndeki araçla çakışma: ardışık iki aracın tabanları.
				if list.size() > 1:
					var lead: Dictionary = list[(i + 1) % list.size()]
					var lp: PathFollow3D = lead.follow
					var gap: float = fposmod(lp.progress - (v.follow as PathFollow3D).progress, route.length) - (lead.length + v.length) * 0.5
					if gap < -0.02:
						overlaps += 1
				# Yaya–araç: yürüyen biri aracın tabanının içinde mi (0,12 birim pay).
				for p in walkers:
					var q := Vector2(p.x, p.z)
					if q.distance_to(center) > v.length:
						continue
					var follow: PathFollow3D = v.follow
					var local: Vector3 = follow.global_transform.affine_inverse() * Vector3(p.x, follow.global_position.y, p.z)
					if absf(local.x) < 0.36 and absf(local.z) < v.length * 0.5 - 0.05:
						ped_hits += 1
				# Yön: hareket yönü burun yönüyle aynı.
				var key: int = (v.follow as Object).get_instance_id()
				var now: Vector3 = (v.follow as PathFollow3D).global_position
				if last_pos.has(key):
					var d: Vector3 = now - last_pos[key]
					d.y = 0
					if d.length() > 0.02 and (-(v.follow as PathFollow3D).global_transform.basis.z).dot(d.normalized()) < 0.8:
						heading_bad += 1
				last_pos[key] = now
				for w: Array in v.wheels:
					if (w[0] as Node3D).has_meta("spin") and absf((w[0] as Node3D).get_meta("spin")) > 0.5:
						wheel_spin_seen = true
		if bus_v.dwell > 0.0:
			var bp: Vector3 = (bus_v.follow as PathFollow3D).global_position
			bus_stopped_at_stop = absf(bp.x - decor.BUS_STOP.x) < 0.6 and absf(bp.z + 4.85) < 0.2
	Engine.time_scale = 1.0
	check(off_road == 0, "araçlar yolda kaldı (yol dışı örnek: %d)" % off_road)
	check(overlaps == 0, "aynı rotadaki araçlar üst üste binmedi (%d)" % overlaps)
	check(heading_bad == 0, "araçların burnu hareket yönünde (%d ters)" % heading_bad)
	check(wheel_spin_seen, "yakındaki araçların tekerlekleri dönüyor")
	check(bus_stopped_at_stop, "otobüs meydan durağında durdu")
	check(ped_hits == 0, "yayalar araçların içinden geçmedi (%d örnek)" % ped_hits)
	var kordon := Rect2(-56, 5.8, 112, 2.4)
	var on_promenade := 0
	for v in traffic._vehicles:
		var p: Vector3 = (v.follow as PathFollow3D).global_position
		if kordon.has_point(Vector2(p.x, p.z)):
			on_promenade += 1
	check(on_promenade == 0, "kordona araç girmiyor")

	print("Park etmiş araçlar ve bisikletler")
	var spots: Array = decor.parking_spots
	var strip := Rect2(-37, -18.5, 74, 1.0)
	var bad_spot := 0
	for s in spots:
		var p := Vector2(s.position.x, s.position.z)
		var ok := strip.has_point(p)
		for r in decor.ROADS_NS:
			if (r as Rect2).has_point(p):
				ok = true
		if not ok:
			bad_spot += 1
	check(spots.size() >= 15 and bad_spot == 0, "%d park yeri; hepsi otopark cebinde ya da yolda (kaldırımda değil: %d)" % [spots.size(), bad_spot])
	var parked_overlap := 0
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			if (spots[i].position as Vector3).distance_to(spots[j].position) < 2.1:
				parked_overlap += 1
	check(parked_overlap == 0, "park etmiş araçlar birbirine girmiyor (%d)" % parked_overlap)
	check(traffic.has_node("Parked") and traffic.get_node("Parked").mesh.get_surface_count() > 0, "park etmiş araçlar tek mesh (%d yüzey)" % traffic.get_node("Parked").mesh.get_surface_count())

	print("Kamera, arsa seçimi ve GameState")
	var plot := world.get_node("Plots/U06")
	rig.set_view({"position": plot.global_position, "zoom": 40.0, "yaw": 0.0}, true)
	await create_timer(0.5).timeout
	var sel := []
	bus.plot_selected.connect(func(id, _k, _e): sel.append(id))
	var screen: Vector2 = root.get_camera_3d().unproject_position(plot.global_position + Vector3(0, 0.1, 0))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = screen
		ev.global_position = screen
		root.push_input(ev, true)
		await physics_frame
		await process_frame
	check(sel.has(&"U06"), "arsa tıklaması araçlara rağmen çalışıyor (%s)" % [sel])
	bus.plot_deselect_requested.emit()
	var view0: Dictionary = rig.get_view()
	for code in [KEY_RIGHT]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
		key.pressed = true
		Input.parse_input_event(key)
		await create_timer(0.4).timeout
		var up := key.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
	await process_frame
	check(rig.get_view().position != view0.position, "ok tuşu kamerayı kaydırıyor")
	check(gs.get_stats() == stats_before, "GameState göstergeleri araçlardan etkilenmedi")

	print("SONUÇ: %s (%d hata)" % ["TAMAM" if _fails == 0 else "HATA", _fails])
	quit(1 if _fails > 0 else 0)
