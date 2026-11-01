class_name BuildPlot
extends Node3D
## Sahip: A. Arsa verisi, vurgu ve bina yuvası (mimari §2.5).
## plot_id ve plot_kind sözleşme §7'deki listeden gelir; CityWorld.tscn içinde ayarlanır.
## Görsel katman (VisualOverlay): Highlight (arsa kenarında ince çerçeve), HighlightFill (hafif dolgu),
## DebugOverlay (geliştirici etiketi, normal oyunda gizli). Seçim ve fare üstü bilgisi CityWorld'den gelir
## (mevcut ışın testi); arsa yalnızca görünümünü değiştirir, uygunluk hesaplamaz, GameState'e yazmaz.

const KIND_MATERIALS := {
	&"urban": preload("res://assets/materials/plot_urban.tres"),
	&"open": preload("res://assets/materials/plot_open.tres"),
	&"coastal": preload("res://assets/materials/plot_coastal.tres"),
}
const PLACEHOLDER_SCENE := preload("res://scenes/buildings/Building.tscn")
const PLACEHOLDER_MATERIAL := preload("res://assets/materials/plaster_white.tres")
## Vurgu durumlarının paylaşılan materyalleri (Inspector'dan düzenlenebilir .tres dosyaları).
const MAT_BUILDABLE := preload("res://assets/materials/plot_state_buildable.tres")
const MAT_HOVER := preload("res://assets/materials/plot_state_hover.tres")
const MAT_SELECTED := preload("res://assets/materials/plot_state_selected.tres")
const MAT_INVALID := preload("res://assets/materials/plot_state_invalid.tres")
const MAT_FILL_HOVER := preload("res://assets/materials/plot_fill_hover.tres")
const MAT_FILL_SELECTED := preload("res://assets/materials/plot_fill_selected.tres")
## Geliştirici etiketinde gösterilen tür adı.
const KIND_NAMES := {&"urban": "KENT", &"open": "AÇIK ALAN", &"coastal": "KIYI"}
## Tıklama kutusunun yüksekliği; binanın üstüne tıklamak da arsayı seçsin.
const PICK_HEIGHT := 5.0
## Çerçeve: arsa kenarının hemen içinde, zeminin (0.12) biraz üstünde; z-fighting olmaz.
const FRAME_WIDTH := 0.22
const FRAME_HEIGHT := 0.02
const FRAME_Y := 0.135
const FRAME_INSET := 0.04
## Fare üstü ve seçimde yavaş, hafif nefes alma (saniye cinsinden periyot, saydamlık aralığı).
const PULSE_PERIOD := 2.4
const PULSE_DEPTH := 0.25

## Arsa boyutu → çerçeve mesh'i; aynı boyuttaki arsalar tek mesh'i paylaşır.
static var _frame_meshes := {}

@export var plot_id: StringName
@export var plot_kind: StringName = &"urban"
## Kare arsanın kenar uzunluğu (metre).
@export var size := 6.0

@onready var _pad: MeshInstance3D = $Pad
@onready var _highlight: MeshInstance3D = $VisualOverlay/Highlight
@onready var _fill: MeshInstance3D = $VisualOverlay/HighlightFill
@onready var _debug: Node3D = $VisualOverlay/DebugOverlay
@onready var _label: Label3D = $VisualOverlay/DebugOverlay/Label
@onready var _shape: CollisionShape3D = $PickArea/CollisionShape3D
@onready var _anchor: Marker3D = $BuildingAnchor

## Arsadaki binanın kimliği (sözleşme §8); boşsa &"". Yalnızca görsel amaçlı, GameState'in kopyası değildir.
var building_id: StringName = &""

var _pad_material: StandardMaterial3D
var _pad_base_color: Color
var _selected := false
var _hovered := false
## İnşaat modunda (bir arsa seçiliyken) boş arsalara ince "kurulabilir" çerçevesi.
var _buildable_hint := false
## Final sunumu karşılaştırmasında yatırımlı arsaların çerçevesi.
var _showcase := false


func _ready() -> void:
	_pad.scale = Vector3(size, 1.0, size)
	var box := BoxShape3D.new()
	box.size = Vector3(size, PICK_HEIGHT, size)
	_shape.shape = box
	_shape.position.y = PICK_HEIGHT * 0.5
	_pad_material = KIND_MATERIALS.get(plot_kind, KIND_MATERIALS[&"urban"]).duplicate()
	_pad.material_override = _pad_material
	_pad_base_color = _pad_material.albedo_color
	_highlight.mesh = _frame_mesh(size)
	_fill.scale = Vector3(size - FRAME_INSET * 2.0, 1.0, size - FRAME_INSET * 2.0)
	_label.text = "%s · %s" % [plot_id, KIND_NAMES.get(plot_kind, String(plot_kind))]
	_label.position = Vector3(-size * 0.5 + 0.25, _label.position.y, size * 0.5 - 0.25)
	_refresh()


## Yalnızca fare üstü ya da seçiliyken çalışır; boşta hiçbir arsa her kare iş yapmaz.
func _process(_delta: float) -> void:
	var phase := fmod(Time.get_ticks_msec() / 1000.0, PULSE_PERIOD) / PULSE_PERIOD
	_highlight.transparency = PULSE_DEPTH * (0.5 - 0.5 * cos(phase * TAU))


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


## İnşaat modu ipucu (CityWorld verir): boş arsada ince "kurulabilir" çerçevesi.
func set_buildable_hint(value: bool) -> void:
	if _buildable_hint != value:
		_buildable_hint = value
		_refresh()


## Final sunumu karşılaştırması: yatırımlı arsa hafif çerçeveyle belirtilir.
func set_showcase(value: bool) -> void:
	if _showcase != value:
		_showcase = value
		_refresh()


## Geliştirici katmanı (arsa kimliği ve türü). Normal oyunda kapalı; CityWorld.show_debug_overlay yönetir.
func set_debug_visible(value: bool) -> void:
	_debug.visible = value


## Eski ad (final sunumu kullanıyor): geliştirici katmanının görünürlüğü.
func set_label_visible(value: bool) -> void:
	set_debug_visible(value)


func is_debug_visible() -> bool:
	return _debug.visible


## Görünen vurgu durumu (test ve araçlar için): &"", &"buildable", &"hover", &"selected", &"invalid", &"showcase".
func highlight_state() -> StringName:
	if not _highlight.visible:
		return &""
	match _highlight.material_override:
		MAT_SELECTED:
			return &"selected"
		MAT_HOVER:
			return &"hover"
		MAT_INVALID:
			return &"invalid"
	return &"showcase" if _showcase and not _buildable_hint else &"buildable"


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


## Öncelik: seçili > fare üstü (boşsa turkuaz, doluysa turuncu) > kurulabilir ipucu > sunum > yok.
func _refresh() -> void:
	var outline: Material = null
	var fill: Material = null
	if _selected:
		outline = MAT_SELECTED
		fill = MAT_FILL_SELECTED
	elif _hovered:
		outline = MAT_HOVER if is_empty() else MAT_INVALID
		fill = MAT_FILL_HOVER if is_empty() else null
	elif _buildable_hint and is_empty():
		outline = MAT_BUILDABLE
	elif _showcase:
		outline = MAT_BUILDABLE
	_highlight.visible = outline != null
	_highlight.material_override = outline
	_highlight.transparency = 0.0
	_fill.visible = fill != null
	_fill.material_override = fill
	set_process(_selected or _hovered)


## Arsa kenarında dört ince kenardan oluşan çerçeve (tek mesh, tek draw call).
static func _frame_mesh(plot_size: float) -> Mesh:
	if _frame_meshes.has(plot_size):
		return _frame_meshes[plot_size]
	var half := plot_size * 0.5 - FRAME_INSET - FRAME_WIDTH * 0.5
	var length := plot_size - FRAME_INSET * 2.0
	var st := SurfaceTool.new()
	for side in 4:
		var edge := BoxMesh.new()
		# Yan kenarlar köşelerde üst üste binmesin (saydamlıkta köşe parlamasın).
		var edge_length := length if side % 2 == 0 else length - FRAME_WIDTH * 2.0
		edge.size = Vector3(edge_length, FRAME_HEIGHT, FRAME_WIDTH)
		var xform := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3.ZERO)
		xform = xform * Transform3D(Basis.IDENTITY, Vector3(0, FRAME_Y, half))
		st.append_from(edge, 0, xform)
	var mesh := st.commit()
	_frame_meshes[plot_size] = mesh
	return mesh


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
