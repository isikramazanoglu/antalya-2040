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
## Arsa etiketinde gösterilen tür adı.
const KIND_NAMES := {&"urban": "KENT", &"open": "AÇIK ALAN", &"coastal": "KIYI"}
## Tıklama kutusunun yüksekliği; binanın üstüne tıklamak da arsayı seçsin.
const PICK_HEIGHT := 5.0
## Boş arsa turkuaz, dolu arsa kehribar tonunda parlar.
const HOVER_EMPTY := Color(0.3, 0.95, 0.9)
const HOVER_OCCUPIED := Color(1.0, 0.7, 0.3)

@export var plot_id: StringName
@export var plot_kind: StringName = &"urban"
## Kare arsanın kenar uzunluğu (metre).
@export var size := 6.0

@onready var _pad: MeshInstance3D = $Pad
@onready var _highlight: MeshInstance3D = $Highlight
@onready var _label: Label3D = $Label
@onready var _shape: CollisionShape3D = $PickArea/CollisionShape3D
@onready var _anchor: Marker3D = $BuildingAnchor

## Arsadaki binanın kimliği (sözleşme §8); boşsa &"". Yalnızca görsel amaçlı, GameState'in kopyası değildir.
var building_id: StringName = &""

var _pad_material: StandardMaterial3D
var _pad_base_color: Color
var _highlight_material: StandardMaterial3D
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
	_pad_base_color = _pad_material.albedo_color
	_highlight_material = _highlight.get_surface_override_material(0).duplicate()
	_highlight.set_surface_override_material(0, _highlight_material)
	_label.text = "%s · %s" % [plot_id, KIND_NAMES.get(plot_kind, String(plot_kind))]
	_label.position = Vector3(-size * 0.5 + 0.25, _label.position.y, size * 0.5 - 0.25)
	_refresh()


func _process(delta: float) -> void:
	_pulse += delta
	_highlight.transparency = 0.15 + 0.25 * (0.5 + 0.5 * sin(_pulse * 4.0))


func is_empty() -> bool:
	return _anchor.get_child_count() == 0


func is_occupied() -> bool:
	return not is_empty()


## Arsadaki bina node'u; boşsa null.
func get_building() -> Node3D:
	return _anchor.get_child(0) as Node3D if is_occupied() else null


func set_selected(value: bool) -> void:
	_selected = value
	_refresh()


func set_hovered(value: bool) -> void:
	if _hovered != value:
		_hovered = value
		_refresh()


## Final sunumunda arsa etiketi gizlenir (sinematik görüntü); sunum bitince geri gelir.
func set_label_visible(value: bool) -> void:
	_label.visible = value


## Kriz görselleri için zemin rengini geçici olarak bir tona çeker (0 = asıl renk).
func set_weather_tint(color: Color, amount: float) -> void:
	_pad_material.albedo_color = _pad_base_color.lerp(color, clampf(amount, 0.0, 1.0))


## Sahne yoksa yer tutucu kutu koyar (sözleşme §4). Arsada bina varsa yeni bina eklenmez.
func place_building(scene: PackedScene, animate := true, id: StringName = &"") -> Node3D:
	if not is_empty():
		push_warning("BuildPlot %s: arsa dolu, ikinci bina eklenmedi" % plot_id)
		return null
	var building: Node3D = scene.instantiate() if scene else _make_placeholder()
	building_id = id
	_anchor.add_child(building)
	if animate and building.has_method("play_build_animation"):
		building.play_build_animation()
	_label.modulate.a = 0.35
	_refresh()
	return building


func _refresh() -> void:
	var color := HOVER_OCCUPIED if is_occupied() else HOVER_EMPTY
	_highlight.visible = _selected
	set_process(_selected)
	_pad_material.emission_enabled = _selected or _hovered
	_pad_material.emission = color
	_pad_material.emission_energy_multiplier = 0.45 if _selected else 0.2
	_highlight_material.albedo_color = Color(color, 0.8)


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
