class_name DisasterFX
extends Node3D
## Sahip: A. Kriz görselleri (mimari §5):
## sıcak = güneş ve sis sıcak tona döner + ısı pusu, kuraklık = zemin ve bitki örtüsü sararır + toz sisi,
## kıyı taşkını = deniz ve kıyı şeridinde su yükselir + fırtına ışığı + yağmur.
## CityWorld: crisis_started → play(), crisis_resolved → stop(). Şiddet (0..1) etkinin büyüklüğünü ölçekler.

const HEAT_SUN := Color(1.0, 0.7, 0.42)
const HEAT_FOG := Color(1.0, 0.72, 0.48)
const DUST_FOG := Color(0.86, 0.74, 0.5)
const STORM_FOG := Color(0.45, 0.5, 0.55)

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var sea: MeshInstance3D
## Kuraklıkta sararan ortak materyaller; sahne kapanınca asıl renklerine döner.
@export var dry_materials: Array[StandardMaterial3D] = []
@export var dry_color := Color(0.8, 0.66, 0.36)
## Şiddet 1 iken denizin yükselmesi (metre).
@export var max_sea_rise := 0.45
## Şiddet 1 iken kıyı şeridindeki taşkın suyunun zeminden yüksekliği (metre).
@export var max_flood_height := 0.35
@export var fade_in_time := 2.5
@export var fade_out_time := 3.0
## Kriz çözüldükten sonra efektin bir süre daha görünmesi.
@export var fade_out_delay := 1.5

@onready var _rain: GPUParticles3D = $Rain
@onready var _flood: MeshInstance3D = $FloodWater
@onready var _haze_layer: CanvasLayer = $HeatHaze
@onready var _haze: ColorRect = $HeatHaze/Haze

var _env: Environment
var _sea_material: ShaderMaterial
var _base := {}
var _dry_base := {}
var _flood_base_y := 0.0
var _risk_type: StringName = &""
var _severity := 0.0
var _level := 0.0
var _tween: Tween


func _ready() -> void:
	# Sahnenin alt kaynakları örnekler arasında paylaşılır; değiştirdiklerimizin kopyasıyla çalışırız.
	_env = world_environment.environment.duplicate()
	world_environment.environment = _env
	_sea_material = (sea.material_override as ShaderMaterial).duplicate()
	sea.material_override = _sea_material
	_base = {
		"sun_color": sun.light_color,
		"sun_energy": sun.light_energy,
		"sky_energy": _env.background_energy_multiplier,
		"ambient_energy": _env.ambient_light_energy,
		"fog_enabled": _env.fog_enabled,
		"fog_color": _env.fog_light_color,
		"fog_density": _env.fog_density,
		"adjustment_enabled": _env.adjustment_enabled,
		"saturation": _env.adjustment_saturation,
		"contrast": _env.adjustment_contrast,
		"sea_y": sea.position.y,
		"wave_height": _sea_material.get_shader_parameter("wave_height"),
	}
	for material in dry_materials:
		_dry_base[material] = material.albedo_color
	_flood_base_y = _flood.position.y
	_apply(0.0)


func _exit_tree() -> void:
	for material in _dry_base:
		material.albedo_color = _dry_base[material]


func play(risk_type: StringName, severity: float) -> void:
	if risk_type != _risk_type:
		_apply(0.0)
	_risk_type = risk_type
	_severity = clampf(severity, 0.0, 1.0)
	_animate_to(1.0, fade_in_time, 0.0)


func stop() -> void:
	if _risk_type != &"":
		_animate_to(0.0, fade_out_time, fade_out_delay)


func current_risk() -> StringName:
	return _risk_type


func _animate_to(target: float, time: float, delay: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_method(_apply, _level, target, time).set_trans(Tween.TRANS_SINE)
	if target == 0.0:
		_tween.tween_callback(func(): _risk_type = &"")


## level: 0 = efekt yok, 1 = tam efekt. Her şey taban değerlerden hesaplanır, birikme olmaz.
func _apply(level: float) -> void:
	_level = level
	var strength := level * lerpf(0.55, 1.0, _severity)
	var heat := strength if _risk_type == &"heat" else 0.0
	var dry := strength if _risk_type == &"drought" else 0.0
	var storm := level if _risk_type == &"coastal_flood" else 0.0
	var rise := storm * lerpf(0.5, 1.0, _severity)

	sun.light_color = (_base.sun_color as Color).lerp(HEAT_SUN, heat * 0.65 + dry * 0.35)
	sun.light_energy = _base.sun_energy * (1.0 + 0.3 * heat + 0.1 * dry - 0.6 * storm)
	_env.background_energy_multiplier = _base.sky_energy * (1.0 - 0.45 * storm)
	_env.ambient_light_energy = _base.ambient_energy * (1.0 - 0.3 * storm)

	var fog_amount := maxf(heat, maxf(dry, storm))
	_env.fog_enabled = _base.fog_enabled or fog_amount > 0.01
	_env.fog_light_color = (_base.fog_color as Color).lerp(HEAT_FOG, heat).lerp(DUST_FOG, dry).lerp(STORM_FOG, storm)
	_env.fog_density = _base.fog_density + 0.003 * heat + 0.0035 * dry + 0.004 * storm
	_env.adjustment_enabled = _base.adjustment_enabled or fog_amount > 0.01
	_env.adjustment_saturation = _base.saturation * (1.0 + 0.15 * heat - 0.25 * dry - 0.3 * storm)
	_env.adjustment_contrast = _base.contrast * (1.0 + 0.05 * heat)

	for material in _dry_base:
		material.albedo_color = (_dry_base[material] as Color).lerp(dry_color, dry)

	_haze_layer.visible = heat > 0.01
	(_haze.material as ShaderMaterial).set_shader_parameter("strength", heat)

	sea.position.y = _base.sea_y + max_sea_rise * rise
	_sea_material.set_shader_parameter("wave_height", _base.wave_height * (1.0 + 3.0 * storm))
	_flood.visible = rise > 0.01
	_flood.position.y = _flood_base_y + max_flood_height * rise
	_rain.emitting = storm > 0.05
	_rain.amount_ratio = storm
