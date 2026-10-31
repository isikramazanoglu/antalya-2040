extends Node
## Sahip: A. CitySandbox (mimari §6): şehri Ekip B'nin kodu olmadan dener; B'nin sinyallerini taklit eder.
## B = sıradaki binayı kur · N = kalanların hepsini kur · P = fazı build / report arasında değiştir
## 1 / 2 / 3 = sıcak hava / kuraklık / kıyı taşkını: her basış krizi bir sonraki aşamaya geçirir
##   (uyarı → hazırlık → kriz → çözüldü → bitti), B'nin TurnManager'ı ile aynı sırada sinyal yayar.
## R = açık bütün krizleri bitir. Seçim sinyalleri konsola yazılır.

## Her bina sözleşme §8'de izinli bir arsaya; ilk dördü demo senaryosundaki yerler.
const BUILD_ORDER: Array = [
	[&"O01", &"solar_plant"], [&"U01", &"green_park"], [&"O02", &"water_storage"], [&"U02", &"cooling_center"],
	[&"U03", &"efficient_housing"], [&"U04", &"public_efficiency"], [&"C01", &"water_reuse"],
	[&"O03", &"urban_farming"], [&"U05", &"food_rescue"], [&"O04", &"recycling_compost"],
	[&"U06", &"transit_hub"], [&"C02", &"coastal_restoration"],
]
## Sözleşme §5.6 info alanları; değerler data/events/*.tres ile aynı.
const CRISES := {
	KEY_1: {"event_id": &"heatwave", "risk_type": &"heat", "visual_effect_id": &"heat_haze",
			"affected_area": &"city", "affected_plot_kinds": [&"urban"]},
	KEY_2: {"event_id": &"drought", "risk_type": &"drought", "visual_effect_id": &"drought_dust",
			"affected_area": &"farmland", "affected_plot_kinds": [&"open"]},
	KEY_3: {"event_id": &"coastal_flood", "risk_type": &"coastal_flood", "visual_effect_id": &"storm_surge",
			"affected_area": &"coast", "affected_plot_kinds": [&"coastal"]},
}
const STAGES: Array[StringName] = [&"warning", &"preparation", &"active", &"resolved", &"ended"]
const PROGRESS := {&"warning": 0.0, &"preparation": 0.25, &"active": 0.5, &"resolved": 0.75, &"ended": 1.0}
const CRISIS_SEVERITY := 0.8

var _next := 0
var _phase: StringName = &"build"
var _stage_index := {}  # event_id -> son yayılan aşamanın sırası


func _ready() -> void:
	EventBus.plot_selected.connect(func(p, k, e): print("[city] plot_selected ", p, " ", k, " bos=", e))
	EventBus.plot_deselected.connect(func(): print("[city] plot_deselected"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_B:
			build_next()
		KEY_N:
			build_all()
		KEY_R:
			end_all_crises()
		KEY_P:
			set_phase(&"report" if _phase == &"build" else &"build")
		_:
			if CRISES.has(key.keycode):
				advance_crisis(CRISES[key.keycode])


func build_next() -> void:
	if _next >= BUILD_ORDER.size():
		return
	var entry: Array = BUILD_ORDER[_next]
	_next += 1
	EventBus.build_approved.emit(entry[0], entry[1])


func build_all() -> void:
	while _next < BUILD_ORDER.size():
		build_next()


## Krizi bir sonraki aşamaya geçirir; son aşamadan sonra baştan başlar.
func advance_crisis(crisis: Dictionary) -> void:
	var index: int = (_stage_index.get(crisis.event_id, -1) + 1) % STAGES.size()
	set_stage(crisis, STAGES[index])


func set_stage(crisis: Dictionary, stage: StringName) -> void:
	_stage_index[crisis.event_id] = STAGES.find(stage)
	var info := {
		"severity": CRISIS_SEVERITY,
		"due_year": 2043,
		"visual_effect_id": crisis.visual_effect_id,
		"affected_area": crisis.affected_area,
		"affected_plot_kinds": crisis.affected_plot_kinds.duplicate(),
		"progress": PROGRESS[stage],
	}
	print("[city] crisis_stage_changed ", crisis.event_id, " ", stage)
	# B'nin sırası: active → crisis_started, crisis_resolved → resolved.
	if stage == &"active":
		set_phase(&"crisis")
		EventBus.crisis_stage_changed.emit(crisis.event_id, stage, info)
		EventBus.crisis_started.emit(crisis.event_id, crisis.risk_type, CRISIS_SEVERITY)
	elif stage == &"resolved":
		EventBus.crisis_resolved.emit({
			"event_id": crisis.event_id, "response_id": &"sandbox", "risk_type": crisis.risk_type,
			"mitigation": 0.0, "damage": {}, "summary_text": "CitySandbox",
		})
		EventBus.crisis_stage_changed.emit(crisis.event_id, stage, info)
		set_phase(&"build")
	else:
		EventBus.crisis_stage_changed.emit(crisis.event_id, stage, info)


func end_all_crises() -> void:
	for crisis in CRISES.values():
		if _stage_index.has(crisis.event_id):
			set_stage(crisis, &"ended")
			_stage_index.erase(crisis.event_id)
	if _phase != &"build":
		set_phase(&"build")


func set_phase(phase: StringName) -> void:
	_phase = phase
	print("[city] phase_changed ", phase)
	EventBus.phase_changed.emit(phase)
