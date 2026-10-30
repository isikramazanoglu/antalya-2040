extends Control
## Sahip: B. Üst gösterge çubuğu ve "Yılı bitir".

const SHOWN_STATS: Array[String] = ["credits", "population", "water_security", "energy_security",
		"quality_of_life", "ecosystem_health", "emissions_total"]

var _labels: Dictionary = {}


func _ready() -> void:
	for key in SHOWN_STATS:
		var label := Label.new()
		%Stats.add_child(label)
		_labels[key] = label
	%EndTurnButton.pressed.connect(EventBus.end_turn_requested.emit)
	%ClimateLabButton.pressed.connect(func(): get_tree().call_group("climate_lab", "toggle"))
	EventBus.crisis_warned.connect(func(_w): _refresh_warnings())
	EventBus.crisis_resolved.connect(func(_r): _refresh_warnings())
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(func(phase): %EndTurnButton.disabled = phase != &"build")
	_on_stats_changed(GameState.get_stats())
	_refresh_warnings()


func _on_stats_changed(stats: Dictionary) -> void:
	%Year.text = str(stats.year)
	for key in _labels:
		_labels[key].text = "%s  %s" % [UiText.STAT_NAMES[key], UiText.format_value(stats[key])]


## Bekleyen krizler GameState'ten okunur; yeni uyarı ve çözülen krizde yenilenir.
func _refresh_warnings() -> void:
	for child in %Warnings.get_children():
		child.queue_free()
	for w in GameState.pending_crises:
		var def := Catalog.get_event(w.event_id)
		var label := Label.new()
		label.text = "Uyarı · %d sonunda %s bekleniyor" % [w.due_year, def.display_name if def else str(w.event_id)]
		label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		%Warnings.add_child(label)
