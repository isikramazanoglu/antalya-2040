extends SceneTree
## Sahip: B. Prompt 7A'nın 12 kriz testi. Krizler sabit yıllı (2043 sıcak, 2046 kuraklık, 2049 taşkın), sonuç tekrarlanabilir.
## Çalıştır: <godot> --headless --path . --script res://tests/test_crises.gd

var bus: Node
var gs: Node
var cat: Node
var fails := 0
var frame := 0
var stages: Array = []
var resolved: Array = []
var reports: Array = []


func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://scenes/dev/UISandbox.tscn")


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		_run()
		quit(1 if fails else 0)
		return true
	return false


func _defs(ids: Array) -> Array[BuildingDefinition]:
	var out: Array[BuildingDefinition] = []
	for id in ids:
		out.append(cat.get_building(id))
	return out


func _ids(responses: Array) -> Array:
	return responses.map(func(r): return r.id)


func _next_year() -> void:
	bus.end_turn_requested.emit()
	bus.report_closed.emit()


func _run() -> void:
	bus = root.get_node("EventBus")
	gs = root.get_node("GameState")
	cat = root.get_node("Catalog")
	var b: BalanceConfig = cat.data.balance
	bus.crisis_stage_changed.connect(func(id, stage, info): stages.append([id, stage, info, gs.stats.year]))
	bus.crisis_resolved.connect(func(r): resolved.append(r))
	bus.year_ended.connect(func(r): reports.append(r))
	var heat: EventDefinition = cat.get_event(&"heatwave")
	var drought: EventDefinition = cat.get_event(&"drought")
	var flood: EventDefinition = cat.get_event(&"coastal_flood")
	var none: Array[BuildingDefinition] = []
	var stats: Dictionary = gs.get_stats()

	print("Yatırım avantajları (saf hesap)")
	var a_none := EventManager.assess(drought, 0.6, stats, none, b)
	var a_storage := EventManager.assess(drought, 0.6, stats, _defs([&"water_storage"]), b)
	var tanker := EventManager.find_response(drought, &"emergency_tanker")
	_check(EventManager.preview(drought, tanker, a_storage).water_security > EventManager.preview(drought, tanker, a_none).water_security,
			"4) su deposu kuraklık kaybını azaltıyor (%d → %d)" % [EventManager.preview(drought, tanker, a_none).water_security, EventManager.preview(drought, tanker, a_storage).water_security])
	_check(not _ids(EventManager.available_responses(drought, none)).has(&"use_storage") and _ids(EventManager.available_responses(drought, _defs([&"water_storage"]))).has(&"use_storage"),
			"4) \"Su depolamayı devreye al\" yalnızca su deposu varsa görünüyor")
	var m_heat_none: float = EventManager.assess(heat, 0.6, stats, none, b).mitigation
	var m_heat := EventManager.assess(heat, 0.6, stats, _defs([&"green_park", &"cooling_center"]), b)
	_check(m_heat.mitigation > m_heat_none and m_heat.advantages.size() == 2, "6) park + serinleme merkezi sıcak hasarını %%%d azaltıyor" % roundi(m_heat.mitigation * 100))
	var heat_opts := _ids(EventManager.available_responses(heat, _defs([&"green_park", &"cooling_center"])))
	_check(heat_opts.has(&"use_cooling_centers") and heat_opts.has(&"use_parks") and not _ids(EventManager.available_responses(heat, none)).has(&"use_parks"),
			"6) park ve serinleme müdahaleleri yalnızca o binalar varsa açılıyor")
	var m_flood := EventManager.assess(flood, 0.6, stats, _defs([&"coastal_restoration"]), b)
	_check(m_flood.mitigation >= 0.45 and _ids(EventManager.available_responses(flood, _defs([&"coastal_restoration"]))).has(&"early_warning"),
			"7) kıyı restorasyonu taşkın hasarını %%%d azaltıyor, erken uyarı müdahalesini açıyor" % roundi(m_flood.mitigation * 100))
	var a_low := EventManager.assess(drought, 0.6, {"population": 500, "water_security": 30.0}, none, b)
	var a_high := EventManager.assess(drought, 0.6, {"population": 500, "water_security": 80.0}, none, b)
	_check(a_low.vulnerability > a_high.vulnerability, "8a) su güvenliği düşük şehir kuraklığa daha hassas (×%.2f > ×%.2f)" % [a_low.vulnerability, a_high.vulnerability])

	print("Yaşam döngüsü (gerçek tur akışı)")
	bus.plot_selected.emit(&"U01", &"urban", true)
	bus.build_requested.emit(&"U01", &"green_park")
	_next_year()  # 2040
	_next_year()  # 2041
	bus.end_turn_requested.emit()  # 2042 sonu
	var warn := stages.filter(func(s): return s[0] == &"heatwave" and s[1] == &"warning")
	_check(warn.size() == 1 and warn[0][3] == 2042 and warn[0][2].due_year == 2043, "1) sıcak hava uyarısı 2042 sonunda, 2043 için")
	_check(warn[0][2].visual_effect_id == &"heat_haze" and warn[0][2].affected_area == &"city" and warn[0][2].has("progress"), "1) uyarı görsel bilgiyi taşıyor (efekt, bölge, ilerleme)")
	bus.report_closed.emit()
	var prep := stages.filter(func(s): return s[0] == &"heatwave" and s[1] == &"preparation")
	_check(prep.size() == 1 and prep[0][3] == 2043, "2) 2043 başında hazırlık aşaması bildirildi")
	_check(is_equal_approx(prep[0][2].mitigation, 0.25) and prep[0][2].advantages == [&"green_park"], "v1.6) aşama bilgisi koruma oranını (%25) ve parkı taşıyor")
	var energy_before: float = gs.stats.energy_security
	bus.end_turn_requested.emit()  # 2043 sonu: kriz
	_check(gs.phase == &"crisis" and stages[-1][1] == &"active", "kriz başladı, aşama active")
	var credits_before: int = gs.stats.credits
	bus.crisis_response_chosen.emit(&"heatwave", &"use_parks")
	bus.crisis_response_chosen.emit(&"heatwave", &"use_parks")  # ikinci kez
	_check(resolved.size() == 1, "9/10) aynı kriz için ikinci yanıt işlenmedi")
	var r: Dictionary = resolved[0]
	_check(r.damage.has("energy_security") and r.damage.energy_security < 0.0, "5) aşırı sıcak enerji sistemini zorladı (enerji %+d)" % r.damage.energy_security)
	_check(gs.stats.energy_security < energy_before, "5) enerji güvenliği %d → %d" % [energy_before, gs.stats.energy_security])
	var rep: Dictionary = reports[-1]
	_check(gs.stats.credits == credits_before + int(r.damage.credits) + rep.income - rep.upkeep + rep.missions.reward, "9) kriz maliyeti kasadan bir kez düştü")
	_check(rep.crisis_results.size() == 1 and rep.crisis_results[0].has("assessment") and rep.crisis_results[0].severity > 0.0, "12) sonuç ve hasar dökümü yıl sonu raporunda")
	var report_body: String = current_scene.get_node("UI/YearReport").find_child("Body", true, false).text
	_check(report_body.contains("Bu yıl yaşanan kriz") and report_body.contains("şiddet"), "12) YearReport kriz bölümünü gösteriyor")
	bus.report_closed.emit()
	_check(gs.phase == &"build" and gs.stats.year == 2044 and stages.any(func(s): return s[0] == &"heatwave" and s[1] == &"ended"), "11) kriz bitti (ended), 2044'te normal tura dönüldü")
	bus.crisis_response_chosen.emit(&"heatwave", &"do_nothing")
	_check(resolved.size() == 1 and gs.phase == &"build", "10) tamamlanmış krize sonradan gelen yanıt işlenmedi")

	print("Kuraklık ve bütçe")
	_next_year()  # 2044
	_next_year()  # 2045 (uyarı)
	var water_before: float = gs.stats.water_security
	gs.stats.credits = 50
	bus.end_turn_requested.emit()  # 2046 sonu: kuraklık
	_check(gs.phase == &"crisis", "kuraklık 2046 sonunda başladı")
	bus.crisis_response_chosen.emit(&"drought", &"emergency_tanker")  # 120 kredi, kasada 50
	_check(gs.phase == &"crisis" and gs.stats.credits == 50 and resolved.size() == 1, "8) bütçe yetmeyen müdahale reddedildi, durum değişmedi")
	bus.crisis_response_chosen.emit(&"drought", &"use_storage")  # su deposu yok
	_check(gs.phase == &"crisis" and resolved.size() == 1, "8b) altyapısı olmayan müdahale reddedildi")
	bus.crisis_response_chosen.emit(&"drought", &"water_restriction")
	_check(resolved.size() == 2 and resolved[1].damage.water_security < 0.0 and gs.stats.water_security < water_before,
			"3) kuraklık su güvenliğini düşürdü (%d → %d)" % [water_before, gs.stats.water_security])
	print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
