extends SceneTree
## Sahip: A. Görsel revizyon 8 · yaya sistemi testi. Çalıştırma:
## <godot> --path . --script res://scripts/world/dev/test_pedestrians.gd
## Gerçek Game.tscn: karakter sayıları, yürüyüş animasyonu ve yönü, ayakların zemine oturması, rotaların bina /
## arsa içinden geçmemesi, oturanların bank yüksekliği, çarpışma şekli olmaması, animasyon LOD'u, kamera ve arsa
## seçiminin çalışması, GameState'in yayalardan etkilenmemesi.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var gs = root.get_node("GameState")
	var bus = root.get_node("EventBus")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await create_timer(2.0).timeout
	var world: Node3D = current_scene.get_node("CityWorld")
	var ped = world.get_node("Pedestrians")
	var decor = world.get_node("Decor")
	var rig = world.get_node("CameraRig")
	var stats_before: Dictionary = gs.get_stats().duplicate(true)

	print("Karakterler ve sayılar")
	var counts: Dictionary = ped.get_counts()
	check(counts.walkers >= 30, "yürüyen yaya sayısı %d (≥ 30)" % counts.walkers)
	check(counts.live_idle > 0 and counts.live_idle <= ped.MAX_LIVE_IDLE, "canlı bekleyen %d (≤ %d)" % [counts.live_idle, ped.MAX_LIVE_IDLE])
	check(decor.people_spots.size() >= 20, "Decor %d oturan/bekleyen yeri kaydetti" % decor.people_spots.size())
	var models := {}
	for w in ped._walkers:
		models[w.body.scene_file_path] = true
	check(models.size() >= 6, "yürüyenlerde %d farklı karakter modeli (≥ 6)" % models.size())
	var skeletons: Array = ped.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == counts.walkers + counts.live_idle, "her canlı karakterde Skeleton3D var (%d)" % skeletons.size())

	print("Yürüyüş")
	var w0: Dictionary = ped._walkers[0]
	var player: AnimationPlayer = w0.player
	check(player.current_animation == "Walk", "yürüyen Walk animasyonu oynatıyor")
	check(player.get_animation("Walk").loop_mode == Animation.LOOP_LINEAR, "Walk döngüde")
	var phases := {}
	for w in ped._walkers.slice(0, 10):
		phases[snappedf((w.player as AnimationPlayer).current_animation_position, 0.05)] = true
	check(phases.size() >= 5, "adım fazları farklı (%d farklı faz / 10 kişi)" % phases.size())
	# Kameraya yakın bir yürüyeni izle: konum değişiyor, yüzü hareket yönüne bakıyor, ayak zeminde.
	rig.set_view({"position": Vector3(-6, 0, 7), "zoom": 22.0, "yaw": 0.0}, true)
	await create_timer(0.6).timeout
	var near: Dictionary = {}
	for w in ped._walkers:
		if w.tier == 0:
			near = w
			break
	check(not near.is_empty(), "yakın zoom'da animasyonu her kare oynayan yürüyen var")
	if not near.is_empty():
		var body: Node3D = near.body
		var p0 := body.global_position
		var t0: float = (near.player as AnimationPlayer).current_animation_position
		await create_timer(0.5).timeout
		var p1 := body.global_position
		var moved := p1 - p0
		check(moved.length() > 0.15, "yürüyen ilerledi (%.2f birim / 0,5 sn)" % moved.length())
		check((near.player as AnimationPlayer).current_animation_position != t0, "yürüme animasyonu ilerliyor")
		var facing := body.global_transform.basis.z.normalized()  # model +z'ye bakar
		var dir := Vector3(moved.x, 0, moved.z).normalized()
		check(facing.dot(dir) > 0.9, "yüz hareket yönünde (nokta çarpım %.2f)" % facing.dot(dir))
	var ground_ok := true
	for w in ped._walkers:
		var y: float = (w.body as Node3D).global_position.y
		if not (absf(y - 0.05) < 0.02 or absf(y - 0.09) < 0.02 or absf(y - 0.06) < 0.02):
			ground_ok = false
	check(ground_ok, "bütün yürüyenlerin tabanı yürüdüğü yüzeyde (kordon 0,05 / meydan 0,06 / kaldırım 0,09)")

	print("Rotalar binalardan ve arsalardan geçmiyor")
	var plots := world.get_node("Plots").get_children()
	var crossing := 0
	for path: Path3D in ped.find_children("Route_*", "Path3D", false, false):
		var pts := path.curve.get_baked_points()
		for i in range(0, pts.size(), 4):
			var p := Vector2(pts[i].x, pts[i].z)
			for plot in plots:
				var half: float = plot.size * 0.5
				if Rect2(plot.global_position.x - half, plot.global_position.z - half, half * 2, half * 2).has_point(p):
					crossing += 1
					if crossing <= 3:
						print("       arsa içinde: %s %s (%s)" % [path.name, p, plot.name])
	check(crossing == 0, "rota noktalarından hiçbiri arsa içinde değil (%d)" % crossing)
	var inside_building := 0
	for path: Path3D in ped.find_children("Route_*", "Path3D", false, false):
		var pts := path.curve.get_baked_points()
		for i in range(0, pts.size(), 2):
			for fp: Rect2 in decor.building_footprints:
				if fp.has_point(Vector2(pts[i].x, pts[i].z)):
					inside_building += 1
	check(decor.building_footprints.size() > 50 and inside_building == 0, "rota %d bina tabanının hiçbirine girmiyor (%d nokta)" % [decor.building_footprints.size(), inside_building])

	print("Oturanlar ve bekleyenler")
	var sits: Array = decor.people_spots.filter(func(s): return s.pose == &"sit")
	check(sits.size() >= 6, "%d kişi bank / kafe sandalyesinde oturuyor" % sits.size())
	var baked: Node = ped.get_node("Baked")
	var baked_tris := 0
	for mi: MeshInstance3D in baked.get_children():
		baked_tris += mi.mesh.surface_get_array_len(0) / 3
		var aabb := mi.get_aabb()
		if aabb.position.y < -0.02:
			check(false, "pişmiş kişi zeminin altına girmiyor (%s)" % aabb.position.y)
	check(baked.get_child_count() > 0 and baked_tris > 0, "oturan/bekleyenler pişmiş mesh (%d yüzey, %d üçgen)" % [baked.get_child_count(), baked_tris])

	print("Çarpışma ve arsa seçimi")
	check(ped.find_children("*", "CollisionShape3D", true, false).is_empty(), "yayalarda çarpışma şekli yok")
	check(ped.find_children("*", "CollisionObject3D", true, false).is_empty(), "yayalarda fizik gövdesi yok")
	var plot := world.get_node("Plots/U05")
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
	check(sel.has(&"U05"), "arsa tıklaması yayalara rağmen çalışıyor (%s)" % [sel])
	bus.plot_deselect_requested.emit()

	print("Animasyon LOD")
	rig.set_view({"position": Vector3(0, 0, -6), "zoom": 105.0, "yaw": 0.0}, true)
	await create_timer(0.6).timeout

	var tiers := [0, 0, 0]
	for a in ped._walkers + ped._idlers:
		tiers[a.tier] += 1
	check(tiers[0] == 0, "en uzak zoom'da tam hızda animasyon yok (yakın %d, orta %d, durmuş %d)" % tiers)
	var shadowless := true
	for a in ped._walkers:
		if a.tier != 0 and (a.meshes[0] as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadowless = false
	check(shadowless, "yakın olmayan karakterler gölge düşürmüyor")
	rig.set_view({"position": Vector3(-6, 0, -4), "zoom": 22.0, "yaw": 0.0}, true)
	await create_timer(0.6).timeout
	tiers = [0, 0, 0]
	for a in ped._walkers + ped._idlers:
		tiers[a.tier] += 1
	check(tiers[2] > 0, "yakın zoom'da ekran dışındakiler duruyor (%d)" % tiers[2])

	print("Kamera ve GameState")
	var view0: Dictionary = rig.get_view()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.4).timeout
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)
	check(rig.get_view().position != view0.position, "D tuşu kamerayı kaydırıyor")
	check(gs.get_stats() == stats_before, "GameState göstergeleri yayalardan etkilenmedi")
	check(not root.has_node("Pedestrians"), "yaya sistemi autoload değil (CityWorld içinde)")

	print("SONUÇ: %s (%d hata)" % ["TAMAM" if _fails == 0 else "HATA", _fails])
	quit(1 if _fails > 0 else 0)
