@tool
extends Node3D
## Sahip: A. Akdeniz dekoru (mimari §2.3 Decor): yollar, belediye meydanı ve kordon meydanı, mevcut evler,
## zeytinlik, servi ve palmiyeler, marina (iskele, fener, dalgakıran, tekneler), plaj şemsiyeleri,
## arkada dağ silüeti ve caddede dolaşan birkaç araç.
## Sahneye kaydedilmez: her açılışta aynı seed ile kodla kurulur (editörde de görünür).
## Aynı mesh + materyal çiftleri tek bir MultiMeshInstance3D'de toplanır (az draw call).
## Kardeş Plots node'undaki arsalar ve yollar ev/ağaç yerleşiminde otomatik olarak boş bırakılır.

const M_PLASTER := preload("res://assets/materials/plaster_white.tres")
const M_TERRACOTTA := preload("res://assets/materials/terracotta.tres")
const M_STONE := preload("res://assets/materials/stone.tres")
const M_CONCRETE := preload("res://assets/materials/concrete.tres")
const M_ASPHALT := preload("res://assets/materials/asphalt.tres")
const M_MARKING := preload("res://assets/materials/road_marking.tres")
const M_GRASS := preload("res://assets/materials/grass.tres")
const M_OLIVE := preload("res://assets/materials/foliage_olive.tres")
const M_CYPRESS := preload("res://assets/materials/foliage_cypress.tres")
const M_PALM := preload("res://assets/materials/foliage_palm.tres")
const M_HILL := preload("res://assets/materials/hill_green.tres")
const M_MOUNTAIN := preload("res://assets/materials/mountain.tres")
const M_WOOD := preload("res://assets/materials/wood.tres")
const M_WINDOW := preload("res://assets/materials/window_dark.tres")
const M_SOLAR := preload("res://assets/materials/solar_panel.tres")
const M_TANK := preload("res://assets/materials/tank_white.tres")
const M_WATER := preload("res://assets/materials/water_basin.tres")
const M_TURQUOISE := preload("res://assets/materials/accent_turquoise.tres")
const M_LIGHT := preload("res://assets/materials/signal_light.tres")
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
const CAR_COLORS: Array[Material] = [
	preload("res://assets/materials/plaster_white.tres"),
	preload("res://assets/materials/accent_blue.tres"),
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
## Belediye meydanı (ana caddenin kuzeyinde, batı mahallesinde) ve kordon meydanı (iskelenin başında).
const TOWN_SQUARE := Rect2(-34, -14.3, 11, 8)
const COAST_SQUARE := Rect2(-6.5, 9.6, 8, 4)
const HOUSE_AREAS: Array[Rect2] = [
	Rect2(-56, -14, 33, 20), Rect2(23, -14, 33, 20), Rect2(-56, -31, 27, 12), Rect2(29, -31, 27, 12),
	Rect2(-56, 9.6, 38, 4), Rect2(18, 9.6, 38, 4),
]
const PIER := Rect2(2.8, 13.0, 2.4, 17.5)
## Kumsal eğimi: z = 14'te 0 m, her metrede bu kadar alçalır (CityWorld/Terrain/Beach ile aynı).
const BEACH_START_Z := 14.0
const BEACH_SLOPE := 1.3 / 9.0
## Cadde şeritleri: [z, yön, x başlangıç, x bitiş]
const LANES: Array = [[-4.85, -1.0, -56.0, 56.0], [-3.15, 1.0, -56.0, 56.0], [-16.6, -1.0, -38.0, 38.0], [-15.4, 1.0, -38.0, 38.0]]

@export var seed := 2040
@export var car_count := 10

var _rng := RandomNumberGenerator.new()
var _blocked: Array[Rect2] = []
var _batches := {}
var _cars: Array = []
var _box := BoxMesh.new()
var _prism := PrismMesh.new()
var _sphere := SphereMesh.new()
var _cylinder := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _pyramid := CylinderMesh.new()


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_batches.clear()
	_cars.clear()
	_box.size = Vector3.ONE
	_prism.size = Vector3.ONE
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 10
	_sphere.rings = 5
	for cylinder in [_cylinder, _cone, _pyramid]:
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		cylinder.rings = 0
	_cylinder.top_radius = 0.5
	_cylinder.radial_segments = 8
	_cone.top_radius = 0.0
	_cone.radial_segments = 7
	_pyramid.top_radius = 0.0
	_pyramid.radial_segments = 4
	_rng.seed = seed
	_collect_blocked()
	_build_ground_cover()
	_build_town_square()
	_build_coast_square()
	_build_houses()
	_build_trees()
	_build_coast()
	_build_mountains()
	_flush_batches()
	_build_traffic()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for car in _cars:
		var node: Node3D = car.node
		node.position.x += car.dir * car.speed * delta
		if car.dir > 0.0 and node.position.x > car.x_max:
			node.position.x = car.x_min
		elif car.dir < 0.0 and node.position.x < car.x_min:
			node.position.x = car.x_max


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
	_blocked.append(TOWN_SQUARE.grow(0.5))
	_blocked.append(COAST_SQUARE)


func _is_free(area: Rect2) -> bool:
	for rect in _blocked:
		if rect.intersects(area):
			return false
	return true


# --- MultiMesh toplama ---

## Parçayı (mesh, materyal, gölge) grubuna ekler; sahneye _flush_batches() koyar.
func _add(mesh: Mesh, material: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO, shadows := true) -> void:
	_push(mesh, material, Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), shadows)


func _push(mesh: Mesh, material: Material, xform: Transform3D, shadows := true) -> void:
	var key := "%d:%d:%s" % [mesh.get_instance_id(), material.get_instance_id(), shadows]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "material": material, "shadows": shadows, "xforms": []}
	_batches[key].xforms.append(xform)


func _flush_batches() -> void:
	for batch in _batches.values():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.xforms.size()
		for i in batch.xforms.size():
			multimesh.set_instance_transform(i, batch.xforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = batch.material
		if not batch.shadows:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()


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


# --- Meydanlar ---

## Belediye binası (saat kuleli, revaklı), taş meydan, çeşme, ağaçlar ve banklar.
func _build_town_square() -> void:
	_flat(TOWN_SQUARE, 0.05, 0.06, M_STONE)
	var cx := TOWN_SQUARE.get_center().x
	var hall_z := TOWN_SQUARE.position.y + 1.9
	_add(_box, M_PLASTER, Vector3(cx, 1.5, hall_z), Vector3(7.0, 3.0, 3.0))
	_add(_prism, M_TERRACOTTA, Vector3(cx, 3.5, hall_z), Vector3(3.4, 1.0, 7.4), Vector3(0, PI * 0.5, 0))
	_add(_box, M_WINDOW, Vector3(cx, 1.9, hall_z + 1.51), Vector3(6.0, 0.6, 0.04), Vector3.ZERO, false)
	# Saat kulesi.
	_add(_box, M_PLASTER, Vector3(cx, 3.4, hall_z), Vector3(1.6, 6.8, 1.6))
	_add(_pyramid, M_TERRACOTTA, Vector3(cx, 7.4, hall_z), Vector3(2.4, 1.4, 2.4), Vector3(0, PI * 0.25, 0))
	_add(_cylinder, M_PLASTER, Vector3(cx, 5.6, hall_z + 0.82), Vector3(1.0, 0.06, 1.0), Vector3(PI * 0.5, 0, 0))
	_add(_box, M_WINDOW, Vector3(cx, 5.75, hall_z + 0.87), Vector3(0.06, 0.38, 0.02), Vector3.ZERO, false)
	_add(_box, M_WINDOW, Vector3(cx + 0.12, 5.6, hall_z + 0.87), Vector3(0.28, 0.06, 0.02), Vector3.ZERO, false)
	# Revak ve basamaklar.
	var portico_z := hall_z + 1.9
	for i in 6:
		_add(_cylinder, M_PLASTER, Vector3(cx - 3.0 + i * 1.2, 1.3, portico_z), Vector3(0.3, 2.6, 0.3))
	_add(_box, M_PLASTER, Vector3(cx, 2.75, portico_z - 0.3), Vector3(7.2, 0.3, 1.4))
	_add(_box, M_STONE, Vector3(cx, 0.15, portico_z + 0.75), Vector3(4.0, 0.2, 0.7))
	# Meydan çeşmesi, ağaçlar, banklar.
	var fountain := Vector3(cx, 0.0, TOWN_SQUARE.end.y - 1.9)
	_add(_cylinder, M_STONE, fountain + Vector3(0, 0.25, 0), Vector3(2.2, 0.4, 2.2))
	_add(_cylinder, M_WATER, fountain + Vector3(0, 0.46, 0), Vector3(1.9, 0.04, 1.9), Vector3.ZERO, false)
	_add(_cylinder, M_STONE, fountain + Vector3(0, 0.75, 0), Vector3(0.3, 0.8, 0.3))
	for side in [-1.0, 1.0]:
		_olive(cx + side * 4.4, TOWN_SQUARE.end.y - 1.3, 0.9)
		_cypress(cx + side * 4.6, hall_z + 0.2, 0.9)
		_add(_box, M_WOOD, Vector3(cx + side * 2.3, 0.25, fountain.z), Vector3(0.4, 0.3, 1.2))


## Kordon meydanı: taş zemin, küçük çeşme, büfe, banklar.
func _build_coast_square() -> void:
	_flat(COAST_SQUARE, 0.05, 0.06, M_STONE)
	var c := COAST_SQUARE.get_center()
	_add(_cylinder, M_STONE, Vector3(c.x - 1.5, 0.2, c.y), Vector3(1.6, 0.3, 1.6))
	_add(_cylinder, M_WATER, Vector3(c.x - 1.5, 0.36, c.y), Vector3(1.35, 0.04, 1.35), Vector3.ZERO, false)
	_add(_box, M_PLASTER, Vector3(c.x + 2.2, 0.7, c.y + 0.6), Vector3(1.6, 1.4, 1.2))
	_add(_box, M_TURQUOISE, Vector3(c.x + 2.2, 1.45, c.y + 1.35), Vector3(1.9, 0.06, 0.8), Vector3(deg_to_rad(12), 0, 0))
	_add(_box, M_WINDOW, Vector3(c.x + 2.2, 0.85, c.y + 1.21), Vector3(1.0, 0.45, 0.02), Vector3.ZERO, false)
	for x in [-3.4, 0.4]:
		_add(_box, M_WOOD, Vector3(c.x + x, 0.25, c.y + 1.3), Vector3(1.2, 0.3, 0.4))
	_olive(c.x - 3.3, c.y - 1.2, 0.7)


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


# --- Kıyı: marina (iskele, fener, dalgakıran, tekneler), şemsiyeler ---

func _build_coast() -> void:
	var deck := PIER.get_center()
	_add(_box, M_WOOD, Vector3(deck.x, 0.08, deck.y), Vector3(PIER.size.x, 0.18, PIER.size.y))
	var post_z := PIER.position.y + 1.5
	while post_z < PIER.end.y:
		for side in [-1.0, 1.0]:
			_add(_cylinder, M_WOOD, Vector3(deck.x + side * (PIER.size.x * 0.5 - 0.15), -0.9, post_z), Vector3(0.24, 2.0, 0.24))
		post_z += 3.4
	_lighthouse(Vector3(deck.x, 0.0, PIER.end.y + 1.2))
	# Dalgakıran: fenerden doğuya uzanan kaya sırası.
	var rock_x := deck.x + 1.8
	while rock_x < deck.x + 16.0:
		var r := _rng.randf_range(0.9, 1.4)
		_add(_sphere, M_STONE, Vector3(rock_x, -0.35, PIER.end.y + 1.6 + _rng.randf_range(-0.4, 0.4)),
				Vector3(r * 1.6, r, r * 1.4), Vector3(0, _rng.randf() * TAU, 0))
		rock_x += 1.3
	# İskeleye bağlı tekneler ve açıktakiler.
	_boat(Vector3(1.6, -0.35, 17.5), 0.0, false)
	_boat(Vector3(6.4, -0.35, 19.5), PI, true)
	_boat(Vector3(1.6, -0.35, 23.0), 0.05, true)
	_boat(Vector3(6.4, -0.35, 26.5), PI - 0.05, false)
	_boat(Vector3(-15.0, -0.35, 24.5), 1.2, true)
	_boat(Vector3(18.0, -0.35, 28.0), 0.6, false)
	# Plaj şemsiyeleri (kıyı arsalarından, meydandan ve iskeleden uzakta).
	var x := -50.0
	while x < 50.0:
		var ux := x + _rng.randf_range(-0.8, 0.8)
		var uz := _rng.randf_range(15.0, 16.0)
		if _is_free(Rect2(ux - 1.0, uz - 1.0, 2.0, 2.0)) and absf(ux - deck.x) > 2.5:
			var base_y := -(uz - BEACH_START_Z) * BEACH_SLOPE
			_add(_cylinder, M_WOOD, Vector3(ux, base_y + 1.0, uz), Vector3(0.07, 2.0, 0.07))
			_add(_cone, UMBRELLAS[_rng.randi() % UMBRELLAS.size()], Vector3(ux, base_y + 2.1, uz), Vector3(2.2, 0.5, 2.2))
		x += _rng.randf_range(3.5, 6.0)


func _lighthouse(base: Vector3) -> void:
	_add(_cylinder, M_STONE, base + Vector3(0, -0.2, 0), Vector3(2.6, 0.8, 2.6))
	var tower := CylinderMesh.new()
	tower.top_radius = 0.32
	tower.bottom_radius = 0.5
	tower.height = 1.0
	tower.radial_segments = 10
	tower.rings = 0
	_add(tower, M_PLASTER, base + Vector3(0, 2.6, 0), Vector3(1.4, 5.2, 1.4))
	_add(_cylinder, M_TERRACOTTA, base + Vector3(0, 3.2, 0), Vector3(0.95, 0.5, 0.95))
	_add(_cylinder, M_TURQUOISE, base + Vector3(0, 5.35, 0), Vector3(1.1, 0.3, 1.1))
	_add(_sphere, M_LIGHT, base + Vector3(0, 5.8, 0), Vector3(0.55, 0.6, 0.55))
	_add(_cone, M_TURQUOISE, base + Vector3(0, 6.3, 0), Vector3(1.1, 0.5, 1.1))


func _boat(pos: Vector3, yaw: float, sail: bool) -> void:
	var holder := Transform3D(Basis(Vector3.UP, yaw), pos)
	var parts: Array = [
		[_box, M_PLASTER, Vector3(0, 0, 0), Vector3(1.3, 0.5, 3.0)],
		[_box, ACCENTS[1], Vector3(0, 0.15, 0), Vector3(1.32, 0.12, 3.02)],
		[_box, M_PLASTER, Vector3(0, 0.5, -0.5), Vector3(0.9, 0.6, 1.0)],
		[_box, M_WINDOW, Vector3(0, 0.6, 0.01), Vector3(0.8, 0.22, 0.02)],
	]
	if sail:
		parts.append([_cylinder, M_WOOD, Vector3(0, 2.0, 0.3), Vector3(0.08, 3.4, 0.08)])
		# Prizmanın üçgeni XY düzleminde; Y çevresinde 90° döndürünce yelken teknenin boyuna dizilir.
		parts.append([_prism, M_PLASTER, Vector3(0, 2.1, 0.95), Vector3(1.2, 2.6, 0.04), PI * 0.5])
	for part in parts:
		var part_yaw: float = part[4] if part.size() > 4 else 0.0
		_push(part[0], part[1], holder * Transform3D(Basis(Vector3.UP, part_yaw) * Basis.from_scale(part[3]), part[2]))


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


# --- Cadde trafiği: şeritlerde dolaşan birkaç low-poly araç ---

func _build_traffic() -> void:
	var traffic := Node3D.new()
	traffic.name = "Traffic"
	add_child(traffic)
	for i in car_count:
		var lane: Array = LANES[i % LANES.size()]
		var car := Node3D.new()
		car.position = Vector3(_rng.randf_range(lane[2], lane[3]), 0.05, lane[0])
		car.rotation.y = 0.0 if lane[1] > 0.0 else PI
		traffic.add_child(car)
		var color: Material = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
		for part in [[color, Vector3(0, 0.3, 0), Vector3(1.8, 0.45, 0.9)],
				[M_WINDOW, Vector3(-0.1, 0.68, 0), Vector3(1.0, 0.35, 0.82)]]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = _box
			mesh.material_override = part[0]
			mesh.position = part[1]
			mesh.scale = part[2]
			car.add_child(mesh)
		_cars.append({"node": car, "dir": lane[1], "speed": _rng.randf_range(3.5, 6.0), "x_min": lane[2], "x_max": lane[3]})
