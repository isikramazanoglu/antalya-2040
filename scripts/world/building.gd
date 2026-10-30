class_name Building
extends Node3D
## Sahip: A. Bina tabanı (mimari §2.6). Her b_<id>.tscn bu sahneden miras alır ve yalnızca Model altını doldurur.
## Bina sahnelerinde çarpışma yoktur; tıklama arsadan gelir.

const DUST_MATERIAL := preload("res://assets/materials/sand.tres")

@export var grow_time := 0.7

@onready var _model: Node3D = $Model


## Model ölçeği 0 → 1 (Tween) ve tabanda kısa bir toz bulutu.
func play_build_animation() -> void:
	_model.scale = Vector3(0.01, 0.01, 0.01)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE, grow_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_dust()


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
