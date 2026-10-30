@tool
extends Node3D
## Sahip: A. Akdeniz dekoru (mimari §2.3 Decor): yollar, mevcut evler, zeytinlik, servi ve palmiyeler,
## iskele, tekneler, plaj şemsiyeleri ve arkada dağ silüeti.
## Sahneye kaydedilmez: her açılışta aynı seed ile kodla kurulur (editörde de görünür).
## Kardeş Plots node'undaki arsalar ve yollar ev/ağaç yerleşiminde otomatik olarak boş bırakılır.

const M_PLASTER := preload("res://assets/materials/plaster_white.tres")
const M_TERRACOTTA := preload("res://assets/materials/terracotta.tres")
const M_STONE := preload("res://assets/materials/stone.tres")
const M_ASPHALT := preload("res://assets/materials/asphalt.tres")
const M_MARKING := preload("res://assets/materials/road_marking.tres")
const M_GRASS := preload("res://assets/materials/grass.tres")
const M_OLIVE := preload("res://assets/materials/canopy_olive.tres")
const M_CYPRESS := preload("res://assets/materials/cypress.tres")
const M_PALM := preload("res://assets/materials/palm_leaf.tres")
const M_HILL := preload("res://assets/materials/hill_green.tres")
const M_MOUNTAIN := preload("res://assets/materials/mountain.tres")
const M_WOOD := preload("res://assets/materials/wood.tres")
const M_WINDOW := preload("res://assets/materials/window_dark.tres")
const M_SOLAR := preload("res://assets/materials/solar_panel.tres")
const M_TANK := preload("res://assets/materials/tank_white.tres")
const ACCENTS: Array[Material] = [
	preload("res://assets/materials/accent_turquoise.tres"),
	preload("res://assets/materials/accent_blue.tres"),
	preload("res://assets/materials/wood.tres"),
]
const UMBRELLAS: Array[Material] = [
	preload("res://assets/materials/accent_turquoise.tres"),
	preload("res://assets/materials/terracotta.tres"),
	preload("res://assets/materials/accent_yellow.tres"),
]

## Alanlar Rect2(x0, z0, genişlik, derinlik) biçiminde, dünya koordinatında.
const ROADS_EW: Array[Rect2] = [Rect2(-38, -17.5, 76, 3), Rect2(-56, -5.75, 112, 3.5)]
const ROADS_NS: Array[Rect2] = [
	Rect2(-21.75, -17.5, 2.5, 25.3), Rect2(-11.5, -17.5, 3, 25.3), Rect2(-1.5, -17.5, 3, 25.3),
	Rect2(8.5, -17.5, 3, 25.3), Rect2(19.25, -17.5, 2.5, 25.3),
]
const PROMENADE := Rect2(-56, 5.8, 112, 2.4)
const FIELDS := Rect2(-60, -58, 120, 27)
const ORCHARD := Rect2(-58, -55, 116, 21)
const HOUSE_AREAS: Array[Rect2] = [
	Rect2(-56, -14, 33, 20), Rect2(23, -14, 33, 20), Rect2(-56, -31, 27, 12), Rect2(29, -31, 27, 12),
	Rect2(-56, 9.6, 38, 4), Rect2(18, 9.6, 38, 4), Rect2(-6.5, 9.6, 8, 4),
]
const PIER := Rect2(2.8, 13.0, 2.4, 17.5)
## Kumsal eğimi: z = 14'te 0 m, her metrede bu kadar alçalır (CityWorld/Terrain/Beach ile aynı).
const BEACH_START_Z := 14.0
const BEACH_SLOPE := 1.3 / 9.0

@export var seed := 2040

var _rng := RandomNumberGenerator.new()
var _blocked: Array[Rect2] = []
var _box := BoxMesh.new()
var _prism := PrismMesh.new()
var _sphere := SphereMesh.new()
var _cylinder := CylinderMesh.new()
var _cone := CylinderMesh.new()


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_box.size = Vector3.ONE
	_prism.size = Vector3.ONE
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 10
	_sphere.rings = 5
	_cylinder.top_radius = 0.5
	_cylinder.bottom_radius = 0.5
	_cylinder.height = 1.0
	_cylinder.radial_segments = 8
	_cylinder.rings = 0
	_cone.top_radius = 0.0
	_cone.bottom_radius = 0.5
	_cone.height = 1.0
	_cone.radial_segments = 7
	_cone.rings = 0
	_rng.seed = seed
	_collect_blocked()
	_build_ground_cover()
	_build_houses()
	_build_trees()
	_build_coast()
	_build_mountains()


func _collect_blocked() -> void:
	_blocked.clear()
	var plots := get_parent().get_node_or_null("Plots")
	if plots:
		for plot in plots.get_children():
			var plot_size: float = plot.get("size") if plot.get("size") != null else 6.0
			var p: Vector3 = plot.position
			_blocked.append(Rect2(p.x - plot_size * 0.5, p.z - plot_size * 0.5, plot_size, plot_size).grow(1.0))
	for road in ROADS_EW + ROADS_NS:
		_blocked.append(road.grow(0.4))
	_blocked.append(PROMENADE.grow(0.3))
	_blocked.append(PIER)


func _is_free(area: Rect2) -> bool:
	for rect in _blocked:
		if rect.intersects(area):
			return false
	return true


func _add(mesh: Mesh, material: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	instance.scale = size
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _flat(rect: Rect2, top: float, thickness: float, material: Material) -> void:
	var center := rect.get_center()
	_add(_box, material, Vector3(center.x, top - thickness * 0.5, center.y),
			Vector3(rect.size.x, thickness, rect.size.y), Vector3.ZERO, false)


# --- Zemin: yollar, kordon, tarlalar ---

func _build_ground_cover() -> void:
	_flat(FIELDS, 0.015, 0.03, M_GRASS)
	for road in ROADS_NS:
		_flat(road, 0.035, 0.05, M_ASPHALT)
	for road in ROADS_EW:
		_flat(road, 0.045, 0.06, M_ASPHALT)
	_flat(PROMENADE, 0.045, 0.06, M_STONE)
	# Ana caddenin orta şeridi.
	var avenue_z := ROADS_EW[1].get_center().y
	var x := ROADS_EW[1].position.x + 1.5
	while x < ROADS_EW[1].end.x - 1.0:
		_add(_box, M_MARKING, Vector3(x, 0.05, avenue_z), Vector3(1.2, 0.01, 0.12), Vector3.ZERO, false)
		x += 3.0


# --- Mevcut evler: beyaz sıva, terracotta çatı, damda güneş kolektörü ---

func _build_houses() -> void:
	for area in HOUSE_AREAS:
		var z := area.position.y + 2.2
		while z < area.end.y - 1.0:
			var x := area.position.x + 2.2
			while x < area.end.x - 1.0:
				if _rng.randf() < 0.85:
					var w := _rng.randf_range(2.4, 3.6)
					var d := _rng.randf_range(2.4, 3.4)
					var hx := x + _rng.randf_range(-0.5, 0.5)
					var hz := z + _rng.randf_range(-0.4, 0.4)
					var footprint := Rect2(hx - w * 0.5, hz - d * 0.5, w, d)
					if area.encloses(footprint) and _is_free(footprint):
						_house(hx, hz, w, d)
						_blocked.append(footprint.grow(0.3))
				x += 4.6
			z += 4.6


func _house(x: float, z: float, w: float, d: float) -> void:
	var h := 2.0 if _rng.randf() < 0.55 else 3.4
	h += _rng.randf_range(-0.2, 0.3)
	_add(_box, M_PLASTER, Vector3(x, h * 0.5, z), Vector3(w, h, d))
	if _rng.randf() < 0.65:
		if _rng.randf() < 0.5:
			_add(_prism, M_TERRACOTTA, Vector3(x, h + 0.45, z), Vector3(w + 0.3, 0.9, d + 0.3))
		else:
			_add(_prism, M_TERRACOTTA, Vector3(x, h + 0.45, z), Vector3(d + 0.3, 0.9, w + 0.3), Vector3(0, PI * 0.5, 0))
	else:
		# Düz dam: merdiven odası ve güneş enerjili su ısıtıcısı (Akdeniz kentlerinde yaygın).
		_add(_box, M_PLASTER, Vector3(x - w * 0.2, h + 0.35, z - d * 0.15), Vector3(w * 0.35, 0.7, d * 0.4))
		_add(_box, M_SOLAR, Vector3(x + w * 0.2, h + 0.3, z + d * 0.15), Vector3(0.9, 0.05, 0.6), Vector3(deg_to_rad(30), 0, 0))
		_add(_cylinder, M_TANK, Vector3(x + w * 0.2, h + 0.55, z - d * 0.1), Vector3(0.32, 0.9, 0.32), Vector3(0, 0, PI * 0.5))
	# Kameraya bakan cephe: pencere bandı ve renkli kapı.
	_add(_box, M_WINDOW, Vector3(x, h * 0.62, z + d * 0.5 + 0.01), Vector3(w * 0.5, minf(0.6, h * 0.22), 0.04), Vector3.ZERO, false)
	if _rng.randf() < 0.7:
		var accent: Material = ACCENTS[_rng.randi() % ACCENTS.size()]
		_add(_box, accent, Vector3(x + w * 0.28, 0.5, z + d * 0.5 + 0.02), Vector3(0.5, 1.0, 0.04), Vector3.ZERO, false)


# --- Bitki örtüsü ---

func _build_trees() -> void:
	# Kuzeydeki zeytinlik.
	var z := ORCHARD.position.y + 2.0
	while z < ORCHARD.end.y:
		var x := ORCHARD.position.x + 2.0
		while x < ORCHARD.end.x:
			if _rng.randf() < 0.55:
				_olive(x + _rng.randf_range(-1.0, 1.0), z + _rng.randf_range(-1.0, 1.0), _rng.randf_range(0.8, 1.2))
			x += 4.2
		z += 4.2
	# Açık alan arsaları arasında servi çiftleri.
	for gap_x in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
		for gap_z in [-26.0, -22.0]:
			if _is_free(Rect2(gap_x - 0.5, gap_z - 0.5, 1.0, 1.0)):
				_cypress(gap_x + _rng.randf_range(-0.3, 0.3), gap_z, _rng.randf_range(0.85, 1.15))
	# Kordon boyunca palmiyeler.
	var px := PROMENADE.position.x + 3.0
	while px < PROMENADE.end.x:
		if _is_free(Rect2(px - 0.6, 8.6, 1.2, 1.2)):
			_palm(px, 9.0, _rng.randf_range(3.2, 4.4))
		px += 6.0


func _olive(x: float, z: float, s: float) -> void:
	_add(_cylinder, M_WOOD, Vector3(x, 0.5 * s, z), Vector3(0.25, 1.0, 0.25) * s)
	_add(_sphere, M_OLIVE, Vector3(x, 1.4 * s, z), Vector3(1.9, 1.2, 1.9) * s, Vector3(0, _rng.randf() * TAU, 0))


func _cypress(x: float, z: float, s: float) -> void:
	_add(_cylinder, M_WOOD, Vector3(x, 0.3 * s, z), Vector3(0.2, 0.6, 0.2) * s)
	_add(_sphere, M_CYPRESS, Vector3(x, 2.4 * s, z), Vector3(1.0, 4.2, 1.0) * s)


func _palm(x: float, z: float, h: float) -> void:
	var lean := Vector3(_rng.randf_range(-0.08, 0.08), 0, _rng.randf_range(-0.08, 0.08))
	_add(_cylinder, M_WOOD, Vector3(x, h * 0.5, z), Vector3(0.22, h, 0.22), lean)
	var top := Vector3(x - lean.z * h * 0.5, h, z + lean.x * h * 0.5)
	for i in 7:
		var angle := TAU * i / 7.0 + _rng.randf_range(-0.2, 0.2)
		var dir := Vector3(sin(angle), 0, cos(angle))
		_add(_box, M_PALM, top + dir * 0.75 - Vector3(0, 0.2, 0), Vector3(0.38, 0.06, 1.7), Vector3(deg_to_rad(28), angle, 0))


# --- Kıyı: iskele, tekneler, şemsiyeler ---

func _build_coast() -> void:
	var deck := PIER.get_center()
	_add(_box, M_WOOD, Vector3(deck.x, 0.08, deck.y), Vector3(PIER.size.x, 0.18, PIER.size.y))
	var post_z := PIER.position.y + 1.5
	while post_z < PIER.end.y:
		for side in [-1.0, 1.0]:
			_add(_cylinder, M_WOOD, Vector3(deck.x + side * (PIER.size.x * 0.5 - 0.15), -0.9, post_z), Vector3(0.24, 2.0, 0.24))
		post_z += 3.4
	_boat(Vector3(7.5, -0.35, 22.0), 0.15)
	_boat(Vector3(0.5, -0.35, 26.0), -0.3)
	_boat(Vector3(-15.0, -0.35, 24.5), 1.2)
	_boat(Vector3(18.0, -0.35, 28.0), 0.6)
	# Plaj şemsiyeleri (kıyı arsalarından ve iskeleden uzakta).
	var x := -50.0
	while x < 50.0:
		var ux := x + _rng.randf_range(-0.8, 0.8)
		var uz := _rng.randf_range(15.0, 16.0)
		if _is_free(Rect2(ux - 1.0, uz - 1.0, 2.0, 2.0)) and absf(ux) > 2.0:
			var base_y := -(uz - BEACH_START_Z) * BEACH_SLOPE
			_add(_cylinder, M_WOOD, Vector3(ux, base_y + 1.0, uz), Vector3(0.07, 2.0, 0.07))
			_add(_cone, UMBRELLAS[_rng.randi() % UMBRELLAS.size()], Vector3(ux, base_y + 2.1, uz), Vector3(2.2, 0.5, 2.2))
		x += _rng.randf_range(3.5, 6.0)


func _boat(pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	for part in [
		[M_PLASTER, Vector3(0, 0, 0), Vector3(1.3, 0.5, 3.0)],
		[ACCENTS[1], Vector3(0, 0.15, 0), Vector3(1.32, 0.12, 3.02)],
		[M_PLASTER, Vector3(0, 0.5, -0.3), Vector3(0.9, 0.6, 1.0)],
		[M_WINDOW, Vector3(0, 0.6, 0.21), Vector3(0.8, 0.22, 0.02)],
	]:
		var mesh := _add(_box, part[0], part[1], part[2])
		mesh.reparent(holder, false)


# --- Arka plan: dağ silüeti ---

func _build_mountains() -> void:
	var x := -95.0
	while x < 95.0:
		var r := _rng.randf_range(14.0, 24.0)
		var h := _rng.randf_range(14.0, 28.0)
		var z := _rng.randf_range(-82.0, -70.0)
		_add(_cone, M_MOUNTAIN, Vector3(x, h * 0.5, z), Vector3(r * 2.0, h, r * 2.0), Vector3(0, _rng.randf() * TAU, 0), false)
		x += _rng.randf_range(12.0, 18.0)
	x = -80.0
	while x < 80.0:
		var r := _rng.randf_range(8.0, 13.0)
		var h := _rng.randf_range(5.0, 9.0)
		_add(_cone, M_HILL, Vector3(x, h * 0.5, _rng.randf_range(-66.0, -60.0)), Vector3(r * 2.0, h, r * 2.0), Vector3(0, _rng.randf() * TAU, 0), false)
		x += _rng.randf_range(10.0, 16.0)
