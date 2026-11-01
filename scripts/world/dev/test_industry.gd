extends SceneTree
## Sahip: A. Prompt A14 · sanayi görselleri testi. Gerçek Game.tscn; işletmeler B'nin gerçek akışıyla
## (BusinessSimulator.create → GameController._publish → EventBus v1.10) ve doğrudan sinyalle kurulur.
## Çalıştırma: <godot> --path . --script res://scripts/world/dev/test_industry.gd

var _fails := 0
var bus
var gs
var gc
var cat
var ind
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


func btype(id: StringName) -> Resource:
	for t in cat.data.business_types:
		if t.id == id:
			return t
	return null


## B'nin gerçek akışı: işletme kaydı + görsel bildirim (oyunda bunu GameController.business_month yapar).
func spawn_real(type_id: StringName, site: StringName) -> Dictionary:
	gs.business_seq += 1
	var b: Dictionary = BusinessSimulator.create(btype(type_id), site, gs.business_seq, gs.stats.year, gs.month)
	gs.set_business(b)
	gc.refresh_resources()
	gc._publish(b, bus.business_spawned)
	return b


func info(id: StringName, vis: StringName, site: StringName, smoke: float, status := &"active", viol := 0, up := {}, restored := false) -> Dictionary:
	var d := {"business_id": id, "business_type": &"test", "business_name": "Test", "visual_id": vis, "site_id": site,
		"operational_status": status, "violation_level": viol, "emission_level": 1, "smoke_intensity": smoke,
		"upgrades": {"filter": up.get("filter", false), "clean_energy": up.get("clean_energy", false), "treatment": up.get("treatment", false)}}
	if restored:
		d["restored"] = true
	return d


## Baca ağzının üstünde iki kare arası ortalama piksel farkı (duman hareket ediyor mu).
func smoke_motion(marker: Node3D) -> float:
	var top := marker.global_position + Vector3(0.6, 1.4, 0)
	# Görüntü pencere çözünürlüğünde, unproject tuval (1920x1080) ölçeğinde: oranla taşınır.
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var k := Vector2(img.get_size()) / root.get_visible_rect().size
	var s := cam.unproject_position(top) * k
	var half := int(70 * k.x)
	var r := Rect2i(Vector2i(clampi(int(s.x) - half, 0, img.get_width() - half * 2), clampi(int(s.y) - half, 0, img.get_height() - half * 2)), Vector2i(half * 2, half * 2))
	var a := img.get_region(r)
	await wait(0.35)
	await RenderingServer.frame_post_draw
	var b := root.get_texture().get_image().get_region(r)
	var diff := 0.0
	for y in range(0, r.size.y, 4):
		for x in range(0, r.size.x, 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			diff += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return diff


func _run() -> void:
	bus = root.get_node("EventBus")
	gs = root.get_node("GameState")
	cat = root.get_node("Catalog")
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(2.0)
	var world = current_scene.get_node("CityWorld")
	ind = world.get_node("Industry")
	gc = current_scene.find_child("GameController", true, false)
	rig = world.get_camera_rig()
	cam = root.get_camera_3d()

	print("\n[1] sanayi yerleri")
	var plots: Array = world.get_plots()
	var clash := 0
	for site in ind.SITES:
		var c: Vector3 = ind.site_position(site)
		var r := Rect2(c.x - 3, c.z - 3, 6, 6)
		for plot in plots:
			var h: float = plot.size * 0.5
			if r.intersects(Rect2(plot.global_position.x - h, plot.global_position.z - h, h * 2, h * 2)):
				clash += 1
		for road in world.get_node("Decor").ROADS_EW + world.get_node("Decor").ROADS_NS:
			if r.intersects(road):
				clash += 1
		if r.intersects(world.get_node("Reservoir").footprint):  # dünya koordinatında
			clash += 1
	check(ind.SITES.size() == 8 and clash == 0, "8 sanayi yeri (I01–I08) arsalar, yollar ve rezervuarla çakışmıyor (%d)" % clash)
	var b: Rect2 = rig.bounds
	var reachable := true
	for site in ind.SITES:
		var c: Vector3 = ind.site_position(site)
		reachable = reachable and c.z >= b.position.y - 1.0
	check(reachable, "kamera sanayi şeridine yaklaşabiliyor (sınır z %.0f)" % b.position.y)

	print("\n[2] gerçek akış: B'nin işletmeleri (visual_info) modele dönüşüyor")
	var heavy := spawn_real(&"heavy_factory", &"I04")
	var small := spawn_real(&"small_factory", &"I03")
	var store := spawn_real(&"logistics_warehouse", &"I05")
	await wait(1.0)
	var node_h: Node3D = ind.get_business_node(heavy.business_id)
	check(node_h != null and node_h.position.distance_to(ind.site_position(&"I04") + Vector3(0, ind.PAD_TOP, 0)) < 0.01,
		"ağır sanayi I04'te, beton sahanın üstünde (%s)" % (node_h.position if node_h else "yok"))
	check(ind.get_business_node(small.business_id) != null and ind.get_business_node(store.business_id) != null, "küçük fabrika ve depo kuruldu")
	var models := {}
	for id in [heavy.business_id, small.business_id, store.business_id]:
		models[ind.get_business_node(id).scene_file_path] = true
	check(models.size() == 3, "üç tür üç farklı model (%d)" % models.size())
	check(node_h.scale.is_equal_approx(Vector3.ONE), "büyüme animasyonu bitti, ölçek 1")
	var aabb: AABB = (node_h.get_node("Body") as MeshInstance3D).mesh.get_aabb()
	check(absf(aabb.position.y) < 0.02 and aabb.size.x <= 6.0 and aabb.size.z <= 6.0, "model zemine oturuyor ve 6 × 6 yerin içinde (alt %.2f, %.1f × %.1f)" % [aabb.position.y, aabb.size.x, aabb.size.z])
	bus.business_spawned.emit(BusinessSimulator.visual_info(heavy, btype(&"heavy_factory"), cat.data.balance))
	await process_frame
	check(ind.business_count() == 3 and ind.get_node_or_null(String(heavy.business_id)) != null, "aynı business_id için ikinci model kurulmadı")

	print("\n[3] duman: hareket, yoğunluk, filtre, askı")
	rig.set_view({"position": Vector3(-12, 0, -33.5), "zoom": 22.0, "yaw": 0.0}, true)
	await wait(0.6)
	var smoke_h: Array = ind.get_business_smoke(heavy.business_id)
	check(smoke_h.size() == 2 and (smoke_h[0] as GPUParticles3D).emitting, "ağır sanayinin iki bacası tütüyor")
	var marker: Node3D = (smoke_h[0] as Node3D).get_parent()
	bus.business_updated.emit(info(heavy.business_id, &"Industrial_HeavyFactory", &"I04", 1.0))
	await wait(1.5)
	var moving := await smoke_motion(marker)
	check(moving > 1.5, "baca dumanı ekranda hareket ediyor (piksel farkı %.1f)" % moving)
	var pm := (smoke_h[0] as GPUParticles3D).process_material as ParticleProcessMaterial
	var dark := pm.color.r
	var full := (smoke_h[0] as GPUParticles3D).amount_ratio
	bus.business_updated.emit(info(heavy.business_id, &"Industrial_HeavyFactory", &"I04", 0.2))
	await process_frame
	check(pm.color.r > dark + 0.2 and (smoke_h[0] as GPUParticles3D).amount_ratio < full, "düşük yoğunluk: daha açık ve seyrek duman (%.2f → %.2f)" % [dark, pm.color.r])
	bus.business_updated.emit(info(heavy.business_id, &"Industrial_HeavyFactory", &"I04", 0.8, &"active", 0, {"filter": true}))
	await process_frame
	check(pm.color.r > 0.9 and pm.color.a < 0.5, "filtre: beyaz ve saydam duman")
	# B'nin gerçek kararı: denetle → faaliyeti durdur (askı) → yeniden aç.
	gs.stats.credits = 99999
	var r1: StringName = gc.inspect_business(heavy.business_id)
	var r2: StringName = gc.order_business(heavy.business_id, &"suspend")
	await process_frame
	var win := node_h.get_node("Windows") as MeshInstance3D
	check(r1 == &"" and r2 == &"" and not (smoke_h[0] as GPUParticles3D).emitting and win.material_override != null,
		"askı (B'nin kararı): duman yok, ışıklar sönük (%s, %s)" % [r1, r2])
	await wait(5.2)
	var still := await smoke_motion(marker)
	check(still < moving * 0.5, "askıda baca üstü duruldu (piksel farkı %.1f)" % still)
	var r3: StringName = gc.resume_business(heavy.business_id)
	await process_frame
	check(r3 == &"" and win.material_override == null, "yeniden açılınca (B'nin kararı) ışıklar yandı")

	print("\n[4] yükseltmeler, ihlal uyarısı, kaldırma, yükleme")
	bus.business_updated.emit(info(small.business_id, &"Industrial_SmallFactory", &"I03", 0.5, &"active", 3, {"clean_energy": true, "treatment": true}))
	await process_frame
	var node_s: Node3D = ind.get_business_node(small.business_id)
	check(node_s.get_node("Upgrade_clean_energy").visible and node_s.get_node("Upgrade_treatment").visible, "temiz enerji (çatı paneli) ve arıtma tankı görünür")
	var warn := node_s.get_node_or_null("Warning") as Label3D
	check(warn != null and warn.visible, "ihlal seviyesi 3: uyarı işareti var")
	bus.business_updated.emit(info(small.business_id, &"Industrial_SmallFactory", &"I03", 0.5, &"active", 1))
	await process_frame
	check(not warn.visible and not node_s.get_node("Upgrade_clean_energy").visible, "ihlal düşünce uyarı ve kaldırılan yükseltme gizlendi")
	bus.business_removed.emit(store.business_id, &"I05")
	await wait(0.2)
	check(ind.get_business_node(store.business_id) == null and ind.get_node_or_null(String(store.business_id)) == null, "kapanan işletmenin modeli kaldırıldı")
	bus.business_spawned.emit(info(&"B990", &"Industrial_TextilePlant", &"I08", 0.3, &"active", 0, {}, true))
	await process_frame
	check(ind.get_business_node(&"B990").scale.is_equal_approx(Vector3.ONE), "kayıttan yüklenen işletme animasyonsuz, hemen yerinde")
	bus.business_spawned.emit(info(&"B991", &"Industrial_Unknown", &"I07", 0.3))
	await process_frame
	check(ind.get_business_node(&"B991") != null, "bilinmeyen visual_id küçük fabrikaya düştü")
	bus.business_spawned.emit(info(&"B992", &"Industrial_SmallFactory", &"Z99", 0.3))
	await process_frame
	check(ind.get_business_node(&"B992") == null, "bilinmeyen sanayi yeri sessizce yok sayıldı")

	print("\n[5] kamera, arsa seçimi, GameState")
	rig.set_view({"position": Vector3(4, 0, -1), "zoom": 45.0, "yaw": 0.0}, true)
	await wait(0.4)
	var picked := []
	var on_pick := func(id, _k, _e): picked.append(id)
	bus.plot_selected.connect(on_pick)
	var p := cam.unproject_position(world.find_plot(&"U07").global_position)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		root.push_input(e, true)
	await wait(0.2)
	bus.plot_selected.disconnect(on_pick)
	check(picked == [&"U07"], "arsa seçimi çalışıyor (%s)" % str(picked))
	check(ind.find_children("*", "CollisionShape3D", true, false).is_empty(), "sanayi görsellerinde çarpışma şekli yok")
	var before_stats: Dictionary = gs.get_stats()
	bus.business_updated.emit(info(small.business_id, &"Industrial_SmallFactory", &"I03", 1.0, &"active", 4))
	await process_frame
	check(gs.get_stats() == before_stats, "görsel güncellemeler GameState'i değiştirmiyor")

	print("\nSONUÇ: %s" % ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(0 if _fails == 0 else 1)
