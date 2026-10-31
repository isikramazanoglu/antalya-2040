extends Node3D
## Sahip: A. Şehrin rezervuarı (gölet). Su seviyesi GameState'teki su güvenliğini (0..100) izler:
## su depolama yatırımı onu artırdığında göl dolar, kuraklık hasarı düşürdüğünde çekilir.
## Kendi değer üretmez; yalnızca stats_changed'i dinler ve GameState.get_stats() okur (sözleşme §4).

## Rezervuarın dünyadaki alanı (x0, z0, genişlik, derinlik); dekor burayı boş bırakır.
@export var footprint := Rect2(-6, -45, 12, 10)
## Su güvenliği 0 iken ve 100 iken su yüzeyinin yerel yüksekliği (metre).
@export var empty_level := 0.08
@export var full_level := 1.0
## Seviyenin yeni değere yaklaşma hızı (metre/saniye).
@export var level_speed := 0.25

@onready var _water: MeshInstance3D = $Water

var _target := 0.0


func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	_on_stats_changed(GameState.get_stats())
	_water.position.y = _target


## 0..1 arası doluluk (görsel), su güvenliğinden.
func get_fill() -> float:
	return inverse_lerp(empty_level, full_level, _water.position.y)


func get_target_fill() -> float:
	return inverse_lerp(empty_level, full_level, _target)


func _on_stats_changed(stats: Dictionary) -> void:
	var fill := clampf(float(stats.get("water_security", 0.0)) / 100.0, 0.0, 1.0)
	_target = lerpf(empty_level, full_level, fill)
	set_process(true)


func _process(delta: float) -> void:
	_water.position.y = move_toward(_water.position.y, _target, level_speed * delta)
	if is_equal_approx(_water.position.y, _target):
		set_process(false)
