class_name CrisisEffect
extends Node3D
## Sahip: A. Tek bir kriz görselinin tabanı (DisasterFX yönetir).
## DisasterFX seviyeyi (0 = yok, 1 = tam) ve şiddeti verir; efekt atmosfere katkısını ekler ve kendi
## yerel görsellerini uygular. Hiçbir hesap yapmaz, GameState'e yazmaz; kriz kararını Ekip B verir.
## Koruyucu binalar, Catalog'daki BuildingDefinition.risk_reduction alanında bu risk_type'ı taşıyanlardır;
## koruma oranı burada hesaplanmaz: Ekip B'nin aşama bilgisindeki `mitigation` (sözleşme v1.6) görseli
## hafifletir, koruyucu binaların yerinde bir hare görünür ve binalar kendi kriz tepkilerini gösterir
## (Building.set_crisis_level).

## Sözleşme §5.6 visual_effect_id: heat_haze, drought_dust, storm_surge.
@export var visual_effect_id: StringName
## Sözleşme §3.3 risk_type: heat, drought, coastal_flood.
@export var risk_type: StringName
## Aşama bilgisi gelmezse (CitySandbox) kullanılan etkilenen arsa türleri.
@export var default_plot_kinds: Array[StringName] = []
@export var marker_color := Color(0.3, 0.9, 0.9)
## Kriz aktif olunca kameranın görünür tutmaya çalıştığı nokta.
@export var focus_point := Vector3.ZERO

const MARKER_HEIGHT := 0.25
## Tam koruma (mitigation 1) görselin bu kadarını alır; kriz yine de görünür kalır.
const MITIGATION_DAMPING := 0.5

var level := 0.0
var severity := 0.5
## Ekip B'nin koruma oranı 0..0.8 (sözleşme §5.6, v1.6); aşama bilgisi yoksa 0.
var mitigation := 0.0
var affected_plot_kinds: Array = []

var _fx: DisasterFX
var _tween: Tween
var _markers := {}  # plot_id -> MeshInstance3D
var _marker_material: StandardMaterial3D
var _time := 0.0


func setup(fx: DisasterFX) -> void:
	_fx = fx
	affected_plot_kinds = default_plot_kinds.duplicate()
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker_material.albedo_color = Color(marker_color, 0.0)
	set_process(false)


## Etkin şiddet: seviye × şiddet (zayıf kriz de görünür kalsın diye en az %55) × koruma payı.
func strength() -> float:
	return level * lerpf(0.55, 1.0, severity) * damping()


## Koruma oranının görsele etkisi: 1 (korumasız) → 0.6 (en yüksek koruma, 0.8).
func damping() -> float:
	return 1.0 - MITIGATION_DAMPING * clampf(mitigation, 0.0, 1.0)


func animate_to(target: float, time: float, delay := 0.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_method(_set_level, level, target, time).set_trans(Tween.TRANS_SINE)


func is_active() -> bool:
	return level > 0.001


## Atmosfer katkısı: DisasterFX'in taban değerlerle başlattığı sözlüğü değiştirir.
func contribute(_atmosphere: Dictionary) -> void:
	pass


## Yerel görseller (materyal, su, parçacık...). Her seviye değişiminde çağrılır.
func apply_local() -> void:
	pass


## Sahne kapanırken paylaşılan materyalleri asıl hâline döndürür.
func restore() -> void:
	pass


## Koruyucu binaların yerindeki hareleri yeniden kurar (yeni bina kurulunca da çağrılır).
func rebuild_markers() -> void:
	var wanted := {}
	for plot in protective_plots():
		wanted[plot.plot_id] = plot
	for plot_id in _markers.keys():
		if not wanted.has(plot_id):
			_markers[plot_id].queue_free()
			_markers.erase(plot_id)
	for plot_id in wanted:
		if not _markers.has(plot_id):
			_markers[plot_id] = _make_marker(wanted[plot_id])
	_update_markers()
	apply_buildings()


## Kurulu binaların kendi kriz tepkileri (Model/Live/Crisis_<risk_type>) seviyeyi izler.
func apply_buildings() -> void:
	for plot in _fx.get_city_plots():
		var building := plot.get_building() as Building
		if building:
			building.set_crisis_level(risk_type, level)


func protective_plots() -> Array[BuildPlot]:
	var result: Array[BuildPlot] = []
	for plot in _fx.get_city_plots():
		if plot.building_id == &"":
			continue
		var def := Catalog.get_building(plot.building_id)
		if def and (def.risk_reduction.has(risk_type) or def.risk_reduction.has(String(risk_type))):
			result.append(plot)
	return result


func affected_plots() -> Array[BuildPlot]:
	var result: Array[BuildPlot] = []
	for plot in _fx.get_city_plots():
		if plot.plot_kind in affected_plot_kinds:
			result.append(plot)
	return result


func _set_level(value: float) -> void:
	level = value
	set_process(is_active())
	_fx.refresh()
	apply_buildings()


func _process(delta: float) -> void:
	_time += delta
	_update_markers()


func _update_markers() -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	_marker_material.albedo_color = Color(marker_color, clampf(level * 1.6, 0.0, 0.55) * pulse)
	for marker in _markers.values():
		marker.visible = is_active()


func _make_marker(plot: BuildPlot) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = plot.size * 0.5
	ring.outer_radius = plot.size * 0.5 + 0.35
	ring.rings = 24
	ring.ring_segments = 6
	var marker := MeshInstance3D.new()
	marker.mesh = ring
	marker.material_override = _marker_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.global_position = plot.global_position + Vector3(0, MARKER_HEIGHT, 0)
	marker.visible = is_active()
	return marker
