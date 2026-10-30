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
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.phase_changed.connect(func(phase): %EndTurnButton.disabled = phase != &"build")
	_on_stats_changed(GameState.get_stats())


func _on_stats_changed(stats: Dictionary) -> void:
	%Year.text = str(stats.year)
	for key in _labels:
		_labels[key].text = "%s  %s" % [UiText.STAT_NAMES[key], UiText.format_value(stats[key])]
