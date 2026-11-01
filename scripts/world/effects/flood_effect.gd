extends CrisisEffect
## Sahip: A. Kıyı taşkını: deniz ve kordon şeridinde su yükselir, dalgalar sertleşir, fırtına ışığı, yağmur.
## Kıyı restorasyonu gibi taşkına karşı koruyan binaların arsasına taşkın suyu girmez (su shader'ında
## korunan alan) ve çevresinde yeşil hare görünür. Erken uyarı kulesinin ışığı (bina sahnesindeki
## "Beacon") efekt sürdükçe yanıp söner.

const STORM_FOG := Color(0.45, 0.5, 0.55)
const BEACON_NODE := "Beacon"
## Korunan arsanın çevresine bırakılan kuru pay (metre).
const PROTECT_MARGIN := 0.8

## Şiddet 1 iken denizin yükselmesi (metre).
@export var max_sea_rise := 0.45
## Şiddet 1 iken kordon şeridindeki taşkın suyunun zeminden yüksekliği (metre).
@export var max_flood_height := 0.35

@onready var _flood: MeshInstance3D = $FloodWater
@onready var _rain: GPUParticles3D = $Rain

var _sea_material: ShaderMaterial
var _flood_material: ShaderMaterial
var _sea_y := 0.0
var _wave_height := 0.0
var _flood_y := 0.0


func setup(fx: DisasterFX) -> void:
	super.setup(fx)
	# Paylaşılan materyalleri değil kopyalarını değiştir.
	_sea_material = (fx.sea.material_override as ShaderMaterial).duplicate()
	fx.sea.material_override = _sea_material
	_flood_material = (_flood.get_surface_override_material(0) as ShaderMaterial).duplicate()
	_flood.set_surface_override_material(0, _flood_material)
	_sea_y = fx.sea.position.y
	_wave_height = _sea_material.get_shader_parameter("wave_height")
	_flood_y = _flood.position.y


func contribute(a: Dictionary) -> void:
	var s := level
	a.sun_energy *= 1.0 - 0.5 * s
	a.sky_energy *= 1.0 - 0.4 * s
	a.ambient_energy *= 1.0 - 0.25 * s
	a.fog_color = (a.fog_color as Color).lerp(STORM_FOG, s * 0.7)
	a.fog_density += 0.004 * s
	a.saturation *= 1.0 - 0.25 * s
	a.weight = maxf(a.weight, s)


func apply_local() -> void:
	var rise := level * lerpf(0.5, 1.0, severity) * damping()
	_fx.sea.position.y = _sea_y + max_sea_rise * rise
	_sea_material.set_shader_parameter("wave_height", _wave_height * (1.0 + 3.0 * level))
	_flood.visible = rise > 0.01
	_flood.position.y = _flood_y + max_flood_height * rise
	_rain.emitting = level > 0.05
	_rain.amount_ratio = level
	var rects := [Vector4.ZERO, Vector4.ZERO]
	var plots := protective_plots()
	for i in mini(plots.size(), rects.size()):
		var p: Vector3 = plots[i].global_position
		var half: float = plots[i].size * 0.5 + PROTECT_MARGIN
		rects[i] = Vector4(p.x - half, p.z - half, p.x + half, p.z + half)
	_flood_material.set_shader_parameter("protect_a", rects[0])
	_flood_material.set_shader_parameter("protect_b", rects[1])
	if not is_active():
		_set_beacons(true)


func restore() -> void:
	_set_beacons(true)


func _process(delta: float) -> void:
	super._process(delta)
	_set_beacons(fmod(_time, 1.0) < 0.5)


func _set_beacons(on: bool) -> void:
	for plot in protective_plots():
		var building := plot.get_building()
		if building == null:
			continue
		var beacon := building.find_child(BEACON_NODE, true, false) as Node3D
		if beacon:
			beacon.visible = on
