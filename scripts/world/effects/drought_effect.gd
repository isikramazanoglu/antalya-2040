extends CrisisEffect
## Sahip: A. Kuraklık: tarlalar, zeytinlik ve boş açık alan arsaları sararır, hafif toz sisi.
## Şehir merkezi ve kurulu binalar (parklar, kent tarımı) yeşil kalır: bina materyallerine dokunulmaz.
## Su depolama gibi kuraklığa karşı koruyan binaların çevresinde mavi hare.
## Rezervuarın su seviyesi bu efektte değil, Reservoir'da GameState'in su güvenliğinden gelir.

const DUST_FOG := Color(0.86, 0.76, 0.54)
const DRY_SUN := Color(1.0, 0.9, 0.72)
const DRY_COLOR := Color(0.8, 0.67, 0.38)
const DRY_PAD := Color(0.78, 0.68, 0.44)

## Kırsal alanın paylaşılan materyalleri; sahne kapanınca asıl renklerine döner.
## StandardMaterial3D'de albedo_color, ShaderMaterial'da (foliage) `albedo` değişir.
@export var dry_materials: Array[Material] = []
## Şehrin her yerini kaplayan zemin materyali; çölleşmiş görünmesin diye daha az sararır.
@export var ground_material: StandardMaterial3D
@export var ground_weight := 0.35

var _bases := {}


func setup(fx: DisasterFX) -> void:
	super.setup(fx)
	for material in dry_materials:
		_bases[material] = _get_albedo(material)
	if ground_material:
		_bases[ground_material] = ground_material.albedo_color


func contribute(a: Dictionary) -> void:
	var s := strength()
	a.sun_color = (a.sun_color as Color).lerp(DRY_SUN, s * 0.25)
	a.fog_color = (a.fog_color as Color).lerp(DUST_FOG, s * 0.6)
	a.fog_density += 0.0018 * s
	a.saturation *= 1.0 - 0.08 * s
	a.weight = maxf(a.weight, s)


func apply_local() -> void:
	var s := strength()
	for material in _bases:
		var weight := ground_weight if material == ground_material else 1.0
		_set_albedo(material, (_bases[material] as Color).lerp(DRY_COLOR, s * weight))
	for plot in affected_plots():
		plot.set_weather_tint(DRY_PAD, s * 0.85 if plot.is_empty() else 0.0)


func restore() -> void:
	for material in _bases:
		_set_albedo(material, _bases[material])


func _get_albedo(material: Material) -> Color:
	if material is ShaderMaterial:
		return material.get_shader_parameter("albedo")
	return (material as StandardMaterial3D).albedo_color


func _set_albedo(material: Material, color: Color) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("albedo", color)
	else:
		(material as StandardMaterial3D).albedo_color = color
