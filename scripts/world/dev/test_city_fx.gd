extends SceneTree
## Sahip: A. Prompt 7B doğrulama testi: kriz görsellerinin 15 test maddesi. Çalıştırma: <godot> --path . --script res://scripts/world/dev/test_city_fx.gd

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func wait(t: float) -> void:
	await create_timer(t).timeout


func snapshot_env(city: Node) -> Dictionary:
	var env: Environment = city.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = city.get_node("Sun")
	return {"sun_color": sun.light_color, "sun_energy": sun.light_energy, "fog": env.fog_density,
		"fog_color": env.fog_light_color, "sat": env.adjustment_saturation, "sky": env.background_energy_multiplier,
		"sea_y": city.get_node("Sea").position.y}


func env_equal(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		var x = a[k]
		var y = b[k]
		if x is Color:
			if not (x as Color).is_equal_approx(y):
				return false
		elif not is_equal_approx(x, y):
			return false
	return true


func _run() -> void:
	var EB = root.get_node("EventBus")
	var GS = root.get_node("GameState")
	change_scene_to_file("res://scenes/dev/CitySandbox.tscn")
	await wait(1.5)
	var city = current_scene.get_node("CityWorld")
	var sb = current_scene.get_node("Sandbox")
	var fx = city.get_node("DisasterFX")
	var heat = fx.get_effect(&"heat_haze")
	var drought = fx.get_effect(&"drought_dust")
	var flood = fx.get_effect(&"storm_surge")
	sb.build_all()
	await wait(1.0)
	var base_env := snapshot_env(city)
	var gs_before: Dictionary = GS.get_stats()
	var gs_plots_before: Dictionary = GS.plots.duplicate()
	var fields: StandardMaterial3D = load("res://assets/materials/field_grass.tres")
	var ground: StandardMaterial3D = load("res://assets/materials/ground.tres")
	var grass: StandardMaterial3D = load("res://assets/materials/grass.tres")
	var fields0 := fields.albedo_color
	var ground0 := ground.albedo_color
	var grass0 := grass.albedo_color
	var crises: Dictionary = sb.CRISES

	print("Aşamalar (uyarı → hazırlık → kriz)")
	sb.set_stage(crises[KEY_2], &"warning")
	await wait(3.0)
	var warn_level: float = drought.level
	sb.set_stage(crises[KEY_2], &"preparation")
	await wait(3.0)
	var prep_level: float = drought.level
	sb.set_stage(crises[KEY_2], &"active")
	await wait(3.0)
	check(warn_level > 0.05 and warn_level < prep_level and prep_level < drought.level,
			"seviye aşamayla artar (uyarı %.2f < hazırlık %.2f < kriz %.2f)" % [warn_level, prep_level, drought.level])

	print("1-3) Kuraklık")
	check(fields.albedo_color != fields0, "1) tarlalar sarardı")
	var ground_shift := (Vector3(ground.albedo_color.r, ground.albedo_color.g, ground.albedo_color.b) - Vector3(ground0.r, ground0.g, ground0.b)).length()
	var field_shift := (Vector3(fields.albedo_color.r, fields.albedo_color.g, fields.albedo_color.b) - Vector3(fields0.r, fields0.g, fields0.b)).length()
	check(ground_shift > 0.0 and ground_shift < field_shift, "1) şehir zemini tarlalardan az etkilenir (çölleşme yok)")
	check(grass.albedo_color.is_equal_approx(grass0), "1) park çimleri (bina materyali) yeşil kaldı")
	var o05 = city.find_plot(&"O05")
	var o01 = city.find_plot(&"O01")
	check(o05._pad_material.albedo_color != o05._pad_base_color, "1) boş açık alan arsası O05 sarardı")
	check(o01._pad_material.albedo_color.is_equal_approx(o01._pad_base_color), "1) güneş tesisli O01 arsası sararmadı")
	check(drought._markers.has(&"O02") and drought._markers[&"O02"].visible, "1) su deposu (O02) çevresinde koruma haresi")
	var res = city.get_node("Reservoir")
	EB.stats_changed.emit({"water_security": 30.0})
	await wait(0.1)
	check(is_equal_approx(res.get_target_fill(), 0.3), "2) rezervuar hedefi su güvenliği 30 → %%30 (%.2f)" % res.get_target_fill())
	await wait(4.0)
	var low: float = res.get_fill()
	EB.stats_changed.emit({"water_security": 90.0})
	await wait(5.0)
	check(low < 0.4 and res.get_fill() > 0.8, "2) seviye veriye göre değişir (%.2f → %.2f)" % [low, res.get_fill()])
	sb.set_stage(crises[KEY_2], &"resolved")
	await wait(3.5)
	check(drought.level > 0.2 and drought.level < 0.5, "çözüldü aşamasında toparlanma (%.2f)" % drought.level)
	sb.set_stage(crises[KEY_2], &"ended")
	await wait(3.5)
	check(fields.albedo_color.is_equal_approx(fields0) and ground.albedo_color.is_equal_approx(ground0)
			and o05._pad_material.albedo_color.is_equal_approx(o05._pad_base_color), "3) kuraklık bitti: materyaller ve arsa normal")

	print("4-6) Aşırı sıcak")
	sb.set_stage(crises[KEY_1], &"active")
	await wait(3.0)
	var sun: DirectionalLight3D = city.get_node("Sun")
	check(not sun.light_color.is_equal_approx(base_env.sun_color) and fx.get_node("HeatEffect/HeatHaze").visible, "4) güneş ısındı, ısı pusu açık")
	check(sun.light_color.g > 0.8 and sun.light_color.b > 0.65, "4) şehir turuncuya boyanmadı (güneş %s)" % sun.light_color)
	check(heat._markers.has(&"U01") and heat._markers[&"U01"].visible, "5) yeşil park (U01) çevresinde serin hare")
	check(heat._markers.has(&"U02") and heat._markers[&"U02"].visible, "6) serinleme merkezi (U02) çevresinde serin hare")
	check(city.find_plot(&"U02").get_building().visible, "6) serinleme merkezi binası görünür")
	check(grass.albedo_color.is_equal_approx(grass0), "5) parklar sıcakta kurumadı")

	print("11) Aynı aşama iki kez")
	var markers_before: int = heat.get_child_count()
	var fx_children: int = fx.get_child_count()
	sb.set_stage(crises[KEY_1], &"active")
	sb.set_stage(crises[KEY_1], &"active")
	await wait(0.5)
	check(heat.get_child_count() == markers_before and fx.get_child_count() == fx_children, "11) efekt ve hare kopyası oluşmadı")

	print("12) Efekt açıkken kamera")
	var rig = city.get_node("CameraRig")
	var zoom0: float = rig._target_zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	check(rig._target_zoom < zoom0, "12) yakınlaştırma çalışıyor")
	var pos0: Vector3 = rig._target_pos
	Input.action_press("cam_left")
	await wait(0.4)
	Input.action_release("cam_left")
	check(rig._target_pos.x < pos0.x, "12) kaydırma çalışıyor")
	sb.set_stage(crises[KEY_1], &"ended")
	await wait(3.5)

	print("7-9) Kıyı taşkını")
	var u07 = city.find_plot(&"U07")
	var u07_color: Color = u07._pad_material.albedo_color
	sb.set_stage(crises[KEY_3], &"warning")
	await wait(0.5)
	sb.set_stage(crises[KEY_3], &"active")
	await wait(3.0)
	var sea: Node3D = city.get_node("Sea")
	check(sea.position.y > base_env.sea_y + 0.2 and flood.get_node("FloodWater").visible, "7) deniz ve kordon suyu yükseldi")
	var flood_mesh: MeshInstance3D = flood.get_node("FloodWater")
	var aabb: AABB = flood_mesh.global_transform * flood_mesh.get_aabb()
	check(aabb.position.z >= 5.5 and aabb.end.z <= 16.0, "8) taşkın suyu yalnızca kıyı şeridinde (z %.1f..%.1f)" % [aabb.position.z, aabb.end.z])
	check(u07._pad_material.albedo_color.is_equal_approx(u07_color) and ground.albedo_color.is_equal_approx(ground0), "8) şehir içi arsa ve zemin bozulmadı")
	var mat: ShaderMaterial = flood_mesh.get_surface_override_material(0)
	var rect: Vector4 = mat.get_shader_parameter("protect_a")
	var c02: Vector3 = city.find_plot(&"C02").global_position
	check(rect.x < c02.x and rect.z > c02.x and rect.y < c02.z and rect.w > c02.z, "9) kıyı restorasyonlu C02 korunan alan (su girmiyor)")
	check(flood._markers.has(&"C02") and flood._markers[&"C02"].visible, "9) C02 çevresinde koruma haresi")
	var beacon: Node3D = city.find_plot(&"C02").get_building().find_child("Beacon", true, false)
	var seen := {}
	for i in 12:
		seen[beacon.visible] = true
		await wait(0.1)
	check(seen.size() == 2, "9) erken uyarı ışığı yanıp sönüyor")
	sb.set_stage(crises[KEY_3], &"resolved")
	await wait(0.2)
	sb.set_stage(crises[KEY_3], &"ended")
	await wait(3.5)
	check(beacon.visible, "erken uyarı ışığı bitince açık kaldı")

	print("10) Normale dönüş")
	check(env_equal(snapshot_env(city), base_env), "10) ışık, gök, sis, renk ve deniz başlangıç değerlerinde")
	check(fx.current_risk() == &"" and not fx.get_node("HeatEffect/HeatHaze").visible and not flood.get_node("Rain").emitting, "10) bütün efektler kapalı")

	print("13) GameState'e dokunulmadı")
	var gs_after: Dictionary = GS.get_stats()
	gs_before.erase("water_security")
	gs_after.erase("water_security")
	check(gs_after == gs_before and GS.plots == gs_plots_before, "13) GameState değerleri ve arsalar aynı")

	print("15) Ekip B'nin kriz sistemiyle uçtan uca (Game.tscn)")
	var stages: Array = []
	EB.crisis_stage_changed.connect(func(id, stage, _info): stages.append([id, stage]))
	GS.reset()
	change_scene_to_file("res://scenes/main/Game.tscn")
	await wait(1.5)
	city = current_scene.get_node("CityWorld")
	heat = city.get_node("DisasterFX").get_effect(&"heat_haze")
	var peak := 0.0
	var crisis_seen := false
	for guard in 8:
		if GS.stats.year > 2043:
			break
		EB.end_turn_requested.emit()
		await wait(0.3)
		if GS.phase == &"crisis":
			crisis_seen = true
			await wait(3.0)
			peak = heat.level
			var def = root.get_node("Catalog").get_event(&"heatwave")
			EB.crisis_response_chosen.emit(&"heatwave", def.responses[def.responses.size() - 1].id)
			await wait(0.3)
		if GS.phase == &"report":
			EB.report_closed.emit()
			await wait(0.3)
	var heat_stages: Array = stages.filter(func(s): return s[0] == &"heatwave").map(func(s): return s[1])
	check(crisis_seen and peak > 0.9, "15) 2043 sıcak hava krizinde efekt tam seviyede (%.2f)" % peak)
	check(heat_stages == [&"warning", &"preparation", &"active", &"resolved", &"ended"], "15) B'den gelen aşamalar sırayla işlendi: %s" % str(heat_stages))
	await wait(3.5)
	check(heat.level < 0.01, "15) kriz bitince efekt kapandı")

	print("SONUÇ: " + ("TAMAM" if _fails == 0 else "%d HATA" % _fails))
	quit(_fails)
