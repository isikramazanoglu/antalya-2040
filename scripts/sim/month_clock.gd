class_name MonthClock
extends Node
## Sahip: B. Takvimi gerçek zamanda ilerletir: her ay balance.seconds_per_month / hız saniye.
## Yalnızca build fazında ve hiçbir panel açık değilken akar (oyuncu okurken zaman durur).
## Ayın sonucu TurnManager.advance_month'ta; bu düğüm hesap yapmaz. HUD "month_clock" grubundan bulur.

const SPEEDS := [0, 1, 2, 3]  # 0 = durdu

var speed := 1
## Testler takvimi elle sürer (--script ile çalışırken kapalı); oyun ve test_months açık.
var enabled := not OS.get_cmdline_args().has("--script")
var progress := 0.0  # içinde bulunulan ayın 0..1 kısmı (HUD çubuğu için)


func _ready() -> void:
	add_to_group("month_clock")


func set_speed(value: int) -> void:
	speed = clampi(value, 0, SPEEDS.size() - 1)


func toggle_pause() -> void:
	set_speed(1 if speed == 0 else 0)


func is_running() -> bool:
	return enabled and speed > 0 and GameState.phase == &"build" and not _panel_open() and not _quiz_open()


func _quiz_open() -> bool:
	var q := get_tree().get_first_node_in_group("climate_quiz")
	return q != null and q.visible


func _panel_open() -> bool:
	for panel in get_tree().get_nodes_in_group("ui_panel"):
		if panel is CanvasItem and panel.is_visible_in_tree():
			return true
	return false


func _process(delta: float) -> void:
	if not is_running():
		return
	progress += delta * speed / maxf(Catalog.data.balance.seconds_per_month, 0.05)
	if progress >= 1.0:
		progress = 0.0
		var tm := (get_parent() as GameController).turn_manager
		var q := get_tree().get_first_node_in_group("climate_quiz")
		if q:
			q.ask(tm.advance_month)  # doğru cevaptan sonra ay bir kez ilerler
		else:
			tm.advance_month()
