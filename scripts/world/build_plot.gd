class_name BuildPlot
extends Node3D
## Sahip: A. Arsa verisi, vurgu ve bina yuvası (mimari §2.5).
## plot_id ve plot_kind sözleşme §7'deki listeden gelir; CityWorld.tscn içinde ayarlanır.

const KIND_MATERIALS := {
	&"urban": preload("res://assets/materials/plot_urban.tres"),
	&"open": preload("res://assets/materials/plot_open.tres"),
	&"coastal": preload("res://assets/materials/plot_coastal.tres"),
}
const PLACEHOLDER_SCENE := preload("res://scenes/buildings/Building.tscn")
const PLACEHOLDER_MATERIAL := preload("res://assets/materials/plaster_white.tres")
## Tıklama kutusunun yüksekliği; binanın üstüne tıklamak da arsayı seçsin.
const PICK_HEIGHT := 5.0
const HOVER_COLOR := Color(0.3, 0.95, 0.9)

@export var plot_id: StringName
@export var plot_kind: StringName = &"urban"
## Kare arsanın kenar uzunluğu (metre).
@export var size := 6.0

@onready var _pad: MeshInstance3D = $Pad
@onready var _highlight: MeshInstance3D = $Highlight
@onready var _label: Label3D = $Label
@onready var _shape: CollisionShape3D = $PickArea/CollisionShape3D
@onready var _anchor: Marker3D = $BuildingAnchor

var _pad_material: StandardMaterial3D
var _selected := false
var _hovered := false
var _pulse := 0.0


func _ready() -> void:
	_pad.scale = Vector3(size, 1.0, size)
	_highlight.scale = Vector3(size + 0.7, 1.0, size + 0.7)
	var box := BoxShape3D.new()
	box.size = Vector3(size, PICK_HEIGHT, size)
	_shape.shape = box
	_shape.position.y = PICK_HEIGHT * 0.5
	_pad_material = KIND_MATERIALS.get(plot_kind, KIND_MATERIALS[&"urban"]).duplicate()
	_pad.material_override = _pad_material
	_label.text = String(plot_id)
	_label.position = Vector3(-size * 0.5 + 0.25, _label.position.y, size * 0.5 - 0.25)
	_refresh()


func _process(delta: float) -> void:
	_pulse += delta
	_highlight.transparency = 0.15 + 0.25 * (0.5 + 0.5 * sin(_pulse * 4.0))


func is_empty() -> bool:
	return _anchor.get_child_count() == 0


func set_selected(value: bool) -> void:
	_selected = value
	_refresh()


func set_hovered(value: bool) -> void:
	if _hovered != value:
		_hovered = value
		_refresh()


## Sahne yoksa yer tutucu kutu koyar (sözleşme §4). Arsada bina varsa yeni bina eklenmez.
func place_building(scene: PackedScene, animate := true) -> Node3D:
	if not is_empty():
		push_warning("BuildPlot %s: arsa dolu, ikinci bina eklenmedi" % plot_id)
		return null
	var building: Node3D = scene.instantiate() if scene else _make_placeholder()
	_anchor.add_child(building)
	if animate and building.has_method("play_build_animation"):
		building.play_build_animation()
	_label.modulate.a = 0.35
	return building


func _refresh() -> void:
	_highlight.visible = _selected
	set_process(_selected)
	_pad_material.emission_enabled = _selected or _hovered
	_pad_material.emission = HOVER_COLOR
	_pad_material.emission_energy_multiplier = 0.45 if _selected else 0.2


func _make_placeholder() -> Node3D:
	var building: Node3D = PLACEHOLDER_SCENE.instantiate()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size * 0.5, 1.6, size * 0.5)
	mesh.mesh = box
	mesh.position.y = 0.8
	mesh.material_override = PLACEHOLDER_MATERIAL
	building.get_node("Model").add_child(mesh)
	return building
