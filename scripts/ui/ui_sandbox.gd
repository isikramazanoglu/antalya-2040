extends Node
## Sahip: B. Şehir olmadan arayüz testi: Ekip A'nın sinyallerini taklit eder.
## 1 = kent arsası U01, 2 = açık alan O01, 3 = açık alan O02, 4 = kıyı C01, 0 = seçimi kaldır.

const FAKE_PLOTS := {
	KEY_1: [&"U01", &"urban"],
	KEY_2: [&"O01", &"open"],
	KEY_3: [&"O02", &"open"],
	KEY_4: [&"C01", &"coastal"],
}


func _ready() -> void:
	EventBus.build_approved.connect(func(p, b): print("[sandbox] build_approved ", p, " ", b))
	EventBus.build_rejected.connect(func(p, b, r): print("[sandbox] build_rejected ", p, " ", b, " ", r))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_0:
		EventBus.plot_deselected.emit()
	elif FAKE_PLOTS.has(key.keycode):
		var plot: Array = FAKE_PLOTS[key.keycode]
		EventBus.plot_selected.emit(plot[0], plot[1], GameState.get_building_on(plot[0]) == &"")
