class_name Building
extends Node3D
## Sahip: A. Bina tabanı (mimari §2.6). Her b_<id>.tscn bu sahneden miras alır ve yalnızca Model altını doldurur.
## Bina sahnelerinde çarpışma yoktur; tıklama arsadan gelir.
## Sahneler scripts/world/dev/gen_buildings.py ile üretilir (ortak yerleşim standardı orada denetlenir).
## Model altındaki sabit parçalar açılışta materyale göre birleştirilir; Model/Live altındakiler
## (kriz tepkileri, işaret ışığı) ayrı kalır. Bina hiçbir hesap yapmaz, GameState'e yazmaz.

const DUST_MATERIAL := preload("res://assets/materials/sand.tres")
const LIVE_NODE := "Live"
## Kriz tepkisi düğümü: Model/Live/Crisis_<risk_type> (sözleşme §3.3 risk_type).
const CRISIS_NODE := "Crisis_%s"
## Bu seviyenin altında kriz tepkisi gizli kalır (uyarı aşaması yalnızca atmosferde görünür).
const CRISIS_SHOW_LEVEL := 0.25

@export var grow_time := 0.7
## Sözleşme §8 kimliği; sahneyi üreten araç yazar.
@export var building_id: StringName
## Modelin tasarlandığı en küçük arsanın kenarı (metre); model bu karenin içinde kalır.
@export var footprint := 6.0
## Yükseklik sınıfı: ground, infra, public, housing, mast (gen_buildings.py HEIGHTS).
@export var height_class: StringName

@onready var _model: Node3D = $Model


func _ready() -> void:
	_merge_static_meshes()


## Model ölçeği 0 → 1 (Tween) ve tabanda kısa bir toz bulutu.
func play_build_animation() -> void:
	_model.scale = Vector3(0.01, 0.01, 0.01)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE, grow_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_dust()


## Kriz görselinin binadaki karşılığı (ör. serinleme merkezinde su sisi). Seviyeyi DisasterFX verir.
func set_crisis_level(risk_type: StringName, level: float) -> void:
	var node := _model.get_node_or_null("%s/%s" % [LIVE_NODE, CRISIS_NODE % risk_type]) as Node3D
	if node:
		node.visible = level >= CRISIS_SHOW_LEVEL


func has_crisis_response(risk_type: StringName) -> bool:
	return _model.has_node("%s/%s" % [LIVE_NODE, CRISIS_NODE % risk_type])


## Sabit parçaları materyal (ve gölge ayarı) başına tek ArrayMesh'te toplar: ~40 node yerine ~10 draw call.
func _merge_static_meshes() -> void:
	var tools := {}  # anahtar -> SurfaceTool
	var materials := {}
	var shadows := {}
	var merged: Array[MeshInstance3D] = []
	for child in _model.get_children():
		var part := child as MeshInstance3D
		if part == null or part.mesh == null or part.get_child_count() > 0:
			continue
		var material := part.get_surface_override_material(0)
		var key := "%d_%d" % [material.get_instance_id() if material else 0, part.cast_shadow]
		if not tools.has(key):
			var st := SurfaceTool.new()
			tools[key] = st
			materials[key] = material
			shadows[key] = part.cast_shadow
		(tools[key] as SurfaceTool).append_from(part.mesh, 0, part.transform)
		merged.append(part)
	for part in merged:
		_model.remove_child(part)
		part.queue_free()
	for key in tools:
		var mesh := (tools[key] as SurfaceTool).commit()
		mesh.surface_set_material(0, materials[key])
		var instance := MeshInstance3D.new()
		instance.name = "Merged"
		instance.mesh = mesh
		instance.cast_shadow = shadows[key]
		_model.add_child(instance)


func _spawn_dust() -> void:
	var dust := CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.25
	puff.height = 0.5
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = DUST_MATERIAL
	dust.mesh = puff
	dust.amount = 18
	dust.lifetime = 0.9
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 3.5
	dust.gravity = Vector3(0.0, -4.0, 0.0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.5
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
