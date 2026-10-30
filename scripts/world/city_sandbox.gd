extends Node
## Sahip: A. CitySandbox (mimari §6): şehri Ekip B'nin kodu olmadan dener; B'nin sinyallerini taklit eder.
## B = sıradaki binayı kur · N = kalanların hepsini kur · 1 = sıcak hava · 2 = kuraklık · 3 = kıyı taşkını
## R = krizi bitir · P = fazı build / report arasında değiştir. Seçim sinyalleri konsola yazılır.

## Her bina sözleşme §8'de izinli bir arsaya; ilk dördü demo senaryosundaki yerler.
const BUILD_ORDER: Array = [
	[&"O01", &"solar_plant"], [&"U01", &"green_park"], [&"O02", &"water_storage"], [&"U02", &"cooling_center"],
	[&"U03", &"efficient_housing"], [&"U04", &"public_efficiency"], [&"C01", &"water_reuse"],
	[&"O03", &"urban_farming"], [&"U05", &"food_rescue"], [&"O04", &"recycling_compost"],
	[&"U06", &"transit_hub"], [&"C02", &"coastal_restoration"],
]
const CRISES := {
	KEY_1: [&"heatwave", &"heat"],
	KEY_2: [&"drought", &"drought"],
	KEY_3: [&"coastal_flood", &"coastal_flood"],
}
const CRISIS_SEVERITY := 0.8

var _next := 0
var _phase: StringName = &"build"
var _crisis_id: StringName = &""


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
			resolve_crisis()
		KEY_P:
			set_phase(&"report" if _phase == &"build" else &"build")
		_:
			if CRISES.has(key.keycode):
				start_crisis(CRISES[key.keycode][0], CRISES[key.keycode][1], CRISIS_SEVERITY)


func build_next() -> void:
	if _next >= BUILD_ORDER.size():
		return
	var entry: Array = BUILD_ORDER[_next]
	_next += 1
	EventBus.build_approved.emit(entry[0], entry[1])


func build_all() -> void:
	while _next < BUILD_ORDER.size():
		build_next()


func start_crisis(event_id: StringName, risk_type: StringName, severity: float) -> void:
	_crisis_id = event_id
	set_phase(&"crisis")
	EventBus.crisis_started.emit(event_id, risk_type, severity)


func resolve_crisis() -> void:
	if _crisis_id == &"":
		return
	EventBus.crisis_resolved.emit({
		"event_id": _crisis_id,
		"response_id": &"sandbox",
		"risk_type": &"",
		"mitigation": 0.0,
		"damage": {},
		"summary_text": "CitySandbox",
	})
	_crisis_id = &""
	set_phase(&"build")


func set_phase(phase: StringName) -> void:
	_phase = phase
	print("[city] phase_changed ", phase)
	EventBus.phase_changed.emit(phase)
