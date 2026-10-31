class_name DisasterFX
extends Node3D
## Sahip: A. Kriz görsellerinin yöneticisi (mimari §2.3, §5). Prompt 7B'deki CityEffectManager görevi.
## Her kriz görseli ayrı bir CrisisEffect alt node'udur (sıcak, kuraklık, taşkın); bu node olay kimliğini
## doğru efekte yönlendirir, aşamaya göre seviyeyi ayarlar, atmosferi (güneş, gök, sis, renk) tüm
## efektlerin katkısından taban değerlere göre yeniden hesaplar ve sahne kapanınca her şeyi geri yükler.
## Ekonomi veya kriz hesabı yapmaz, GameState'e yazmaz.
##
## CityWorld bağlantısı:
## - crisis_stage_changed (sözleşme v1.5) → set_stage(): warning / preparation / active / resolved / ended
## - crisis_started / crisis_resolved → play() / stop() (aşama sinyali gelmeyen durumlar, ör. CitySandbox)

## Aşamaya göre görsel seviye: uyarıda hafif belirti, hazırlıkta biraz daha, krizde tam, sonra toparlanma.
const STAGE_LEVELS := {&"warning": 0.15, &"preparation": 0.3, &"active": 1.0, &"resolved": 0.35, &"ended": 0.0}
const RISK_TO_VISUAL := {&"heat": &"heat_haze", &"drought": &"drought_dust", &"coastal_flood": &"storm_surge"}

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var sea: MeshInstance3D
@export var fade_in_time := 2.5
@export var fade_out_time := 3.0
## crisis_resolved'dan (aşama sinyali yokken) sonra efektin bir süre daha görünmesi.
@export var fade_out_delay := 1.5

var _env: Environment
var _base := {}
var _effects := {}  # visual_effect_id -> CrisisEffect


func _ready() -> void:
	# Sahnenin alt kaynakları örnekler arasında paylaşılır; değiştirdiklerimizin kopyasıyla çalışırız.
	_env = world_environment.environment.duplicate()
	world_environment.environment = _env
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
	}
	for child in get_children():
		if child is CrisisEffect:
			_effects[child.visual_effect_id] = child
			child.setup(self)
	refresh()


func _exit_tree() -> void:
	for effect in _effects.values():
		effect.restore()


## Sözleşme §5.6. Bilinmeyen görsel kimliğinde false döner ve uyarı yazar.
func set_stage(stage: StringName, info: Dictionary) -> bool:
	var effect: CrisisEffect = _effects.get(info.get("visual_effect_id", &""))
	if effect == null or not STAGE_LEVELS.has(stage):
		push_warning("DisasterFX: bilinmeyen kriz görseli/aşaması: %s / %s" % [info.get("visual_effect_id"), stage])
		return false
	effect.severity = clampf(info.get("severity", effect.severity), 0.0, 1.0)
	if info.has("affected_plot_kinds"):
		effect.affected_plot_kinds = info.affected_plot_kinds.duplicate()
	var target: float = STAGE_LEVELS[stage]
	effect.rebuild_markers()
	effect.animate_to(target, fade_in_time if target > effect.level else fade_out_time)
	return true


## Aşama sinyali olmadan krizi doğrudan başlatır (sözleşme §3.3 crisis_started).
func play(risk_type: StringName, severity: float) -> void:
	var effect := get_effect_for_risk(risk_type)
	if effect == null:
		push_warning("DisasterFX: '%s' için görsel yok" % risk_type)
		return
	effect.severity = clampf(severity, 0.0, 1.0)
	effect.rebuild_markers()
	effect.animate_to(1.0, fade_in_time)


## Açık bütün efektleri kısa bir gecikmeyle söndürür.
func stop() -> void:
	for effect in _effects.values():
		if effect.is_active():
			effect.animate_to(0.0, fade_out_time, fade_out_delay)


func get_effect(visual_effect_id: StringName) -> CrisisEffect:
	return _effects.get(visual_effect_id)


func get_effect_for_risk(risk_type: StringName) -> CrisisEffect:
	return _effects.get(RISK_TO_VISUAL.get(risk_type, &""))


## En güçlü açık efektin risk_type'ı; hiçbiri açık değilse &"".
func current_risk() -> StringName:
	var best: CrisisEffect = null
	for effect in _effects.values():
		if effect.is_active() and (best == null or effect.level > best.level):
			best = effect
	return best.risk_type if best else &""


## Yeni bina kurulunca koruyucu bina hareleri güncellenir.
func refresh_protection() -> void:
	for effect in _effects.values():
		effect.rebuild_markers()
	refresh()


func get_city_plots() -> Array[BuildPlot]:
	var city := get_parent()
	if city and city.has_method("get_plots"):
		return city.get_plots()
	return []


## Atmosferi taban değerlerden ve tüm efektlerin katkısından yeniden kurar; birikme olmaz.
func refresh() -> void:
	var a := {
		"sun_color": _base.sun_color,
		"sun_energy": _base.sun_energy,
		"sky_energy": _base.sky_energy,
		"ambient_energy": _base.ambient_energy,
		"fog_color": _base.fog_color,
		"fog_density": _base.fog_density,
		"saturation": _base.saturation,
		"contrast": _base.contrast,
		"weight": 0.0,
	}
	for effect in _effects.values():
		if effect.is_active():
			effect.contribute(a)
	sun.light_color = a.sun_color
	sun.light_energy = a.sun_energy
	_env.background_energy_multiplier = a.sky_energy
	_env.ambient_light_energy = a.ambient_energy
	_env.fog_enabled = _base.fog_enabled or a.weight > 0.01
	_env.fog_light_color = a.fog_color
	_env.fog_density = a.fog_density
	_env.adjustment_enabled = _base.adjustment_enabled or a.weight > 0.01
	_env.adjustment_saturation = a.saturation
	_env.adjustment_contrast = a.contrast
	for effect in _effects.values():
		effect.apply_local()
