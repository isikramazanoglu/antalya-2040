extends SceneTree
## Sahip: A. Prompt 9B doğrulama testi: 12 yatırım modeli × 10 senaryo.
## Çalıştırma: <godot> --path . --resolution 1280x720 --script res://scripts/world/dev/test_buildings.gd
## Pencereli çalışır (kamera ve draw call ölçümü için). SONUÇ: TAMAM beklenir.

const PALETTE_DIR := "res://assets/materials/buildings/"
const PAD_EMBED := 0.12
const MAX_MERGED_PARTS := 24
## Koruyucu tepki beklenen binalar (gen_buildings.py ile aynı).
const CRISIS_RESPONSES := {
	&"cooling_center": &"heat", &"green_park": &"heat", &"urban_farming": &"drought",
	&"water_storage": &"drought", &"coastal_restoration": &"coastal_flood",
}

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await create_timer(t).timeout


## Model altındaki görünür mesh'lerin binaya (arsa çapasına) göre sınır kutusu.
func model_aabb(building: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in building.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var local: Transform3D = building.global_transform.affine_inverse() * mi.global_transform
		var b := local * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Birleştirmeden önceki geometri imzası: mesh türleri ve boyutları (renkten bağımsız).
func geometry_signature(scene: PackedScene) -> String:
	var state := scene.get_state()
	var parts: Array[String] = []
	var inst := scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	for mesh in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		parts.append("%s|%s|%s" % [mi.mesh.get_class(), mi.mesh.get_aabb().size.snapped(Vector3.ONE * 0.01),
			mi.position.snapped(Vector3.ONE * 0.01)])
	inst.free()
	parts.sort()
	return "%d:%s" % [state.get_node_count(), ";".join(parts)]


func building_materials(building: Node3D) -> Array:
	var result := []
	for mesh in building.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			result.append(mat)
	return result


func _run() -> void:
	var catalog = root.get_node("Catalog")
	change_scene_to_file("res://scenes/dev/CitySandbox.tscn")
	await wait(1.5)
	var city = current_scene.get_node("CityWorld")
	var sb = current_scene.get_node("Sandbox")
	var fx = city.get_node("DisasterFX")
	var camera: Camera3D = city.get_node("CameraRig/Pitch/Camera3D")
	var rig = city.get_node("CameraRig")
	var defs: Array = catalog.data.buildings
	check(defs.size() == 12, "katalogda 12 yatırım var (%d)" % defs.size())

	# Arsa türü → arsalar (sözleşme §7).
	var plots_by_kind := {}
	for plot in city.get_plots():
		if not plots_by_kind.has(plot.plot_kind):
			plots_by_kind[plot.plot_kind] = []
		plots_by_kind[plot.plot_kind].append(plot)

	var signatures := {}
	print("\n[1-3, 7, 10] sahne, kimlik, arsa türü, materyal, sanat yönetimi")
	for def in defs:
		var id: StringName = def.id
		var path := "res://scenes/buildings/b_%s.tscn" % id
		var scene: PackedScene = def.scene
		# 1) yükleniyor mu
		check(scene != null and ResourceLoader.exists(path), "%s: sahne yükleniyor" % id)
		if scene == null:
			continue
		# 2) doğru building_id ve katalog bağlantısı
		check(scene.resource_path == path, "%s: BuildingDefinition.scene → %s" % [id, path.get_file()])
		var probe: Node3D = scene.instantiate()
		check(probe is Building and probe.building_id == id, "%s: sahnedeki building_id eşleşiyor" % id)
		# 3) izinli her arsa türünde, arsa modelden küçük değil
		for kind in def.allowed_plot_kinds:
			var plots: Array = plots_by_kind.get(kind, [])
			var fits := plots.size() > 0
			for plot in plots:
				fits = fits and plot.size >= probe.footprint - 0.01
			check(fits, "%s: '%s' arsalarına sığıyor (model %.0f m)" % [id, kind, probe.footprint])
		# 7) materyaller ortak paletten ve yüklü
		root.add_child(probe)  # _ready: birleştirme
		var mats := building_materials(probe)
		var from_palette := mats.size() > 0
		for mat in mats:
			from_palette = from_palette and mat != null and String(mat.resource_path).begins_with(PALETTE_DIR)
		check(from_palette, "%s: %d yüzeyin materyali yüklü ve ortak paletten" % [id, mats.size()])
		# 8) birleştirme: az parça
		var parts := probe.find_children("*", "MeshInstance3D", true, false).size()
		check(parts <= MAX_MERGED_PARTS, "%s: birleştirme sonrası %d mesh (≤ %d)" % [id, parts, MAX_MERGED_PARTS])
		probe.queue_free()
		# 10) aynı geometri yeniden boyanmamış
		var sig := geometry_signature(scene)
		check(not signatures.has(sig), "%s: geometrisi diğer modellerden farklı" % id)
		signatures[sig] = id

	print("\n[4-6] şehre yerleştirme, zemin, çakışma, kamera")
	sb.build_all()
	await wait(1.5)
	var placed := {}  # building_id -> [plot, building]
	for plot in city.get_plots():
		var b = plot.get_building()
		if b:
			placed[plot.building_id] = [plot, b]
	check(placed.size() == 12, "12 bina şehirde (%d)" % placed.size())
	var boxes := {}
	for id in placed:
		var plot: BuildPlot = placed[id][0]
		var b: Building = placed[id][1]
		# 6) arsa merkezinde
		var anchor: Vector3 = plot.get_node("BuildingAnchor").global_position
		check(b.global_position.is_equal_approx(anchor), "%s: %s arsasının merkezinde" % [id, plot.plot_id])
		# 4) zemin: havada değil, gömülmüyor
		var box := model_aabb(b)
		check(box.position.y >= -PAD_EMBED - 0.01 and box.position.y <= 0.06,
			"%s: zemine oturuyor (alt %.2f m)" % [id, box.position.y])
		# 5) arsa içinde kalıyor → komşu arsalarla çakışmaz
		var half := plot.size * 0.5
		var inside := box.position.x >= -half and box.end.x <= half and box.position.z >= -half and box.end.z <= half
		check(inside, "%s: %s arsasının içinde (x %.1f..%.1f, z %.1f..%.1f, ±%.1f)" % [
			id, plot.plot_id, box.position.x, box.end.x, box.position.z, box.end.z, half])
		boxes[id] = AABB(box.position + b.global_position, box.size)
	var overlap := false
	var ids := boxes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if boxes[ids[i]].intersects(boxes[ids[j]]):
				overlap = true
				print("    çakışma: %s / %s" % [ids[i], ids[j]])
	check(not overlap, "binaların sınır kutuları birbiriyle çakışmıyor")
	# 6) kamera: açılış kadrajında görünür, yakınlaşınca ekranın ortasında
	await wait(0.5)
	for id in placed:
		var b: Building = placed[id][1]
		var center: Vector3 = boxes[id].get_center()
		var top := Vector3(center.x, boxes[id].end.y, center.z)
		check(camera.is_position_in_frustum(center) and camera.is_position_in_frustum(top),
			"%s: açılış kadrajında görünüyor" % id)
	var plot_c: BuildPlot = placed[&"coastal_restoration"][0]
	rig._target_zoom = 24.0
	rig.focus_on(plot_c.global_position)
	await wait(1.5)
	var screen := camera.unproject_position(boxes[&"coastal_restoration"].get_center())
	var vp := root.get_visible_rect().size
	check(Rect2(vp * 0.2, vp * 0.6).has_point(screen), "yakın planda kıyı modeli ekranın ortasında")

	print("\n[8] performans")
	rig._target_zoom = 74.0
	rig.focus_on(Vector3(-4, 0, -6))
	await wait(1.5)
	# Vsync kapalı ölçülür: 60 Hz ekranda vsync açıkken sonuç tam 60'ta takılıp 59,x ile sınırı kaçırıyordu.
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(0.3)
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		frames += 1
	var fps := frames / ((Time.get_ticks_msec() - t0) / 1000.0)
	DisplayServer.window_set_vsync_mode(vsync)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("    12 bina: %.0f FPS, %d draw call" % [fps, draws])
	check(fps >= 60.0, "12 binalı şehir ≥ 60 FPS (%.0f)" % fps)
	var lights := 0
	for id in placed:
		lights += (placed[id][1] as Node).find_children("*", "Light3D", true, false).size()
	check(lights == 0, "binalarda gerçek zamanlı ışık yok")

	print("\n[9] kriz görsel tepkileri")
	for id in CRISIS_RESPONSES:
		var b: Building = placed[id][1]
		var risk: StringName = CRISIS_RESPONSES[id]
		check(b.has_crisis_response(risk), "%s: %s tepkisi var" % [id, risk])
	var crises: Dictionary = sb.CRISES
	var by_risk := {&"heat": crises[KEY_1], &"drought": crises[KEY_2], &"coastal_flood": crises[KEY_3]}
	for risk in by_risk:
		var hidden := true
		for id in CRISIS_RESPONSES:
			if CRISIS_RESPONSES[id] == risk:
				hidden = hidden and not _crisis_node(placed[id][1], risk).visible
		check(hidden, "%s: kriz yokken tepkiler gizli" % risk)
		sb.set_stage(by_risk[risk], &"active")
		await wait(3.0)
		var shown := true
		for id in CRISIS_RESPONSES:
			if CRISIS_RESPONSES[id] == risk:
				shown = shown and _crisis_node(placed[id][1], risk).visible
		check(shown, "%s: kriz anında koruyucu binaların tepkisi görünüyor" % risk)
		sb.set_stage(by_risk[risk], &"ended")
		await wait(3.5)
		var off := true
		for id in CRISIS_RESPONSES:
			if CRISIS_RESPONSES[id] == risk:
				off = off and not _crisis_node(placed[id][1], risk).visible
		check(off, "%s: kriz bitince tepkiler kalkıyor" % risk)
	var beacon: Node3D = (placed[&"coastal_restoration"][1] as Node).find_child("Beacon", true, false)
	check(beacon != null and beacon.is_visible_in_tree(), "erken uyarı ışığı (Beacon) yerinde ve görünür")

	# Kuraklık: bina bitkileri hafif solar, koruma oranı bunu azaltır, bitince geri döner.
	var lawn: StandardMaterial3D = load(PALETTE_DIR + "bld_lawn.tres")
	var fields: StandardMaterial3D = load("res://assets/materials/field_grass.tres")
	var lawn0 := lawn.albedo_color
	var fields0 := fields.albedo_color
	sb.mitigation = 0.0
	sb.set_stage(crises[KEY_2], &"active")
	await wait(3.5)
	var lawn_shift: float = _dist(lawn.albedo_color, lawn0)
	var field_shift: float = _dist(fields.albedo_color, fields0)
	check(lawn_shift > 0.01 and lawn_shift < field_shift * 0.5,
		"kuraklık: park çimi tarladan çok daha az solar (%.3f < %.3f)" % [lawn_shift, field_shift])
	sb.mitigation = 0.8
	sb.set_stage(crises[KEY_2], &"active")
	await wait(3.5)
	var field_shift_m: float = _dist(fields.albedo_color, fields0)
	check(field_shift_m < field_shift * 0.75, "koruma oranı 0.8: kuraklık görseli hafifliyor (%.3f < %.3f)" % [
		field_shift_m, field_shift])
	check(is_equal_approx(fx.get_effect(&"drought_dust").mitigation, 0.8), "DisasterFX mitigation'ı aşama bilgisinden aldı")
	sb.mitigation = 0.0
	sb.set_stage(crises[KEY_2], &"ended")
	await wait(3.5)
	check(lawn.albedo_color.is_equal_approx(lawn0), "kuraklık bitince park çimi asıl rengine döndü")

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)


func _crisis_node(building: Building, risk: StringName) -> Node3D:
	return building.get_node("Model/Live/Crisis_%s" % risk)


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
