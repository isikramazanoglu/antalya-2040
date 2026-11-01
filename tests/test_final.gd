extends SceneTree
## Sahip: B. Prompt 10A testleri: yıllık geçmiş, final değerlendirmesi, 2040 ↔ 2052 karşılaştırması, final ekranı, JSON, final sunum sinyalleri.
## Çalıştır: <godot> --headless --path . --script res://tests/test_final.gd

var bus: Node
var gs: Node
var cat: Node
var fails := 0
var frame := 0
var summary: Dictionary = {}


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


func _build(plot: StringName, kind: StringName, id: StringName) -> void:
	bus.plot_selected.emit(plot, kind, true)
	bus.build_requested.emit(plot, id)


func _run() -> void:
	bus = root.get_node("EventBus")
	gs = root.get_node("GameState")
	cat = root.get_node("Catalog")
	var b: BalanceConfig = cat.data.balance
	bus.game_over.connect(func(s): summary.merge(s))
	bus.crisis_started.connect(func(id, _r, _s):
		var opts := EventManager.available_responses(cat.get_event(id), gs.built_definitions())
		bus.crisis_response_chosen.emit(id, opts[0].id if opts[0].cost <= gs.stats.credits else &"do_nothing"))

	print("Yatırımlar ve bütçe")
	_build(&"O01", &"open", &"solar_plant")
	_build(&"O01", &"open", &"solar_plant")  # aynı istek tekrar
	_check(gs.build_log.size() == 1 and gs.stats.credits == 1000 - cat.get_building(&"solar_plant").cost, "aynı yatırım bir kez kaydedildi ve bir kez ödendi")
	gs.stats.credits = 10
	_build(&"U01", &"urban", &"green_park")
	_check(gs.build_log.size() == 1 and gs.get_building_on(&"U01") == &"", "bütçe yetersizken yatırım yapılmadı, kayıt eklenmedi")
	gs.stats.credits = 600

	print("Yıllık döngü 2040–2052")
	var year := 2040
	while gs.phase != &"game_over" and year < 2060:
		if year == 2041:
			_build(&"U01", &"urban", &"green_park")
		if year == 2044:
			_build(&"O02", &"open", &"water_storage")
		bus.end_turn_requested.emit()
		bus.report_closed.emit()
		year += 1
	_check(gs.phase == &"game_over" and gs.stats.year == 2052, "2052 sonunda oyun final değerlendirmesine geçti (yıl %d)" % gs.stats.year)
	_check(gs.history.size() == 13 and gs.year_reports.size() == 13, "13 yılın geçmişi ve raporu saklandı")
	var seq := true
	for i in 13:
		seq = seq and gs.history[i].year == 2040 + i and gs.year_reports[i].year == 2040 + i
	_check(seq, "kayıtlar 2040'tan 2052'ye sırayla, birer kez")
	var st: Dictionary = summary.start_stats
	_check(st.year == 2040 and st.credits == 1000 and st.population == 500 and st.water_security == 60.0 and st.emissions_total == 100.0,
			"2040 başlangıç değerleri doğru kaydedildi (1000 kredi, 500 kişi, su 60, emisyon 100)")
	_check(st.energy_demand == 50.0 and st.water_demand == 50.0, "başlangıç kaydında enerji ve su talebi dolu (50 / 50)")
	_check(gs.year_reports[0].investment_cost == cat.get_building(&"solar_plant").cost and gs.year_reports[1].investment_cost == cat.get_building(&"green_park").cost,
			"yıllık yatırım maliyetleri raporlarda doğru")
	var history_copy: Dictionary = gs.history[0].duplicate(true)
	_check(gs.history[0].credits != gs.stats.credits and history_copy == gs.history[0], "geçmiş kaydı sonraki yıllardan etkilenmedi")

	print("Final değerlendirmesi")
	var ev: Dictionary = summary.get("evaluation", {})
	_check(ev.dimensions.size() == 7 and ev.dimensions.all(func(d): return d.score >= 0 and d.score <= 100) and ev.overall >= 0 and ev.overall <= 100,
			"7 alt puan ve genel puan 0–100 içinde (genel %d, %s)" % [ev.overall, ev.grade])
	var w := 0
	for v in FinalEvaluator.WEIGHTS.values():
		w += v
	_check(w == 100 and summary.score == ev.overall and summary.grade == ev.grade, "ağırlıklar toplamı 100; özet puanı değerlendirmeyle aynı")
	_check(ev.best.score >= ev.worst.score and ev.grade_text != "", "en iyi ve en zayıf alan ile sonuca özel metin var")
	var renewable: Dictionary = ev.comparisons.filter(func(r): return r.key == "renewable_share")[0]
	_check(renewable.start == 0.0 and renewable.pct == null and renewable.final > 0.0 and renewable.improved, "başlangıcı 0 olan göstergede yüzde hesaplanmadı, hata yok")
	var em: Dictionary = ev.comparisons.filter(func(r): return r.key == "emissions_total")[0]
	_check(em.better == &"down", "emisyonda düşüş olumlu sayılıyor")
	var budget: Dictionary = ev.comparisons.filter(func(r): return r.key == "credits")[0]
	_check(budget.better == &"neutral" and not budget.improved, "bütçe değişimi tek başına başarı sayılmıyor")
	_check(ev.totals.investment_cost == gs.build_log.reduce(func(a, e): return a + e.cost, 0) and ev.totals.buildings == gs.build_log.size(),
			"toplam yatırım maliyeti ve yapı sayısı kayıtlarla aynı (%d kredi, %d yapı)" % [ev.totals.investment_cost, ev.totals.buildings])
	_check(gs.crisis_log.size() == 3 and gs.crisis_log.all(func(c): return c.has("response_id") and c.has("year")), "3 kriz ve müdahaleleri kaydedildi")
	_check(summary.city_2040.plots.is_empty() and summary.city_2052.plots.size() == gs.plots.size() and summary.city_2052.builds.size() == gs.build_log.size(),
			"görsel sözleşme verisi: city_2040 ve city_2052 doğru")

	print("Eksik veri")
	var empty := FinalEvaluator.evaluate({}, {}, [], [], [], [], b)
	_check(empty.dimensions.size() == 7 and empty.dimensions.all(func(d): return d.score >= 0 and d.score <= 100), "boş geçmişte çökme yok, puanlar sınırda (genel %d)" % empty.overall)
	var odd := FinalEvaluator.evaluate({"population": 0, "emissions_total": 0}, {"credits": -9999, "water_demand": 0, "population": 0}, [{"credits": -5}], [], [], [], b)
	_check(odd.overall >= 0 and odd.overall <= 100, "eksi bütçe ve sıfır nüfusta sıfıra bölme yok")

	print("Final ekranı")
	var final_ui := current_scene.get_node("UI/FinalReport")
	var report_ui := current_scene.get_node("UI/YearReport")
	_check(final_ui.visible and not report_ui.visible, "final raporu açık, yıllık rapor kapalı")
	bus.end_turn_requested.emit()
	bus.report_closed.emit()
	_check(gs.phase == &"game_over" and gs.stats.year == 2052 and final_ui.visible, "final ekranından yıl geçişine ya da rapora dönülmüyor")
	var text := ""
	for r in final_ui.find_children("*", "RichTextLabel", true, false):
		text += r.get_parsed_text()
	_check(text.contains("Para") and text.contains("Elektrik") and text.contains("Su") and text.contains("Doğa ve karbon") and text.contains("Krizler") and text.contains("Yatırımlar"),
			"final raporunda bütün bölümler var")
	_check(final_ui.find_children("*", "LineChart", true, false).size() >= 4 and text.contains("dünyanın havasındaki CO₂"), "grafikler var; yerel emisyon küresel CO₂'den ayrılmış")
	_check(not final_ui.find_child("PresentButton", true, false).visible, "Ekip A dinlemiyorsa \"dönüşümü izle\" düğmesi gizli")
	final_ui.find_child("ExportButton", true, false).pressed.emit()
	var status: String = final_ui.find_child("ExportStatus", true, false).text
	var path := status.trim_prefix("Kaydedildi: ")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_check(parsed is Dictionary and parsed.has("evaluation") and parsed.history.size() == 13, "JSON dışa aktarıldı ve okunabiliyor")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	print("Final sunum sinyalleri (v1.9)")
	var got := {}
	var listener := func(s): got.merge(s)
	bus.final_presentation_requested.connect(listener)
	final_ui._on_game_over(summary)
	var present: Button = final_ui.find_child("PresentButton", true, false)
	_check(present.visible, "dinleyen varsa düğme görünüyor")
	present.pressed.emit()
	_check(not final_ui.visible and got.get("score") == summary.score, "düğme sunumu summary ile başlattı, rapor gizlendi")
	bus.final_presentation_finished.emit()
	_check(final_ui.visible, "sunum bitince rapor geri geldi")
	present.pressed.emit()
	var esc := InputEventAction.new()
	esc.action = &"cancel"
	esc.pressed = true
	final_ui._unhandled_input(esc)
	_check(final_ui.visible, "sunum bitiş sinyali gelmese de Esc ile rapora dönülüyor")
	bus.final_presentation_requested.disconnect(listener)
	print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
