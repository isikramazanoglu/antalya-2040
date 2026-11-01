@tool
extends Node3D
## Sahip: A. Akdeniz dekoru (mimari §2.3 Decor): yollar, belediye meydanı ve kordon meydanı, mevcut evler,
## zeytinlik (rezervuar çevresi boş), servi ve palmiyeler, marina (iskele, fener, dalgakıran, tekneler), plaj şemsiyeleri,
## arkada dağ silüeti ve caddede dolaşan birkaç araç.
## Sahneye kaydedilmez: her açılışta aynı seed ile kodla kurulur (editörde de görünür).
## Aynı mesh + materyal çiftleri tek bir MultiMeshInstance3D'de toplanır (az draw call).
## Kardeş Plots node'undaki arsalar ve yollar ev/ağaç yerleşiminde otomatik olarak boş bırakılır.
## Görsel revizyon 5: yol hiyerarşisi (ana cadde, kuzey yolu, mahalle yolları, kordon), kaldırım ve bordür,
## yaya geçidi, dur çizgisi, dönüş okları, paralel otopark, aydınlatma ve sokak ağaçları; 1–3 katlı Akdeniz evleri
## (iki görünen cephede pencere, balkon, panjur, teraslı dam), ana caddede dükkânlar. Yalnızca görsel.

const M_PLASTER := preload("res://assets/materials/buildings/bld_cream.tres")
const M_TERRACOTTA := preload("res://assets/materials/buildings/bld_terracotta.tres")
const M_STONE := preload("res://assets/materials/stone.tres")
const M_CONCRETE := preload("res://assets/materials/concrete.tres")
const M_ASPHALT := preload("res://assets/materials/asphalt.tres")
const M_MARKING := preload("res://assets/materials/road_marking.tres")
const M_FIELD := preload("res://assets/materials/field_grass.tres")
const M_OLIVE := preload("res://assets/materials/foliage_olive.tres")
const M_CYPRESS := preload("res://assets/materials/foliage_cypress.tres")
const M_PALM := preload("res://assets/materials/foliage_palm.tres")
const M_HILL := preload("res://assets/materials/hill_green.tres")
const M_MOUNTAIN := preload("res://assets/materials/mountain.tres")
const M_WOOD := preload("res://assets/materials/wood.tres")
const M_WINDOW := preload("res://assets/materials/buildings/bld_window.tres")
const M_SOLAR := preload("res://assets/materials/buildings/bld_solar.tres")
const M_TANK := preload("res://assets/materials/buildings/bld_tank.tres")
const M_WATER := preload("res://assets/materials/water_basin.tres")
const M_TURQUOISE := preload("res://assets/materials/buildings/bld_turquoise.tres")
const M_ROAD_MAIN := preload("res://assets/materials/city/road_main.tres")
const M_ROAD_LOCAL := preload("res://assets/materials/city/road_local.tres")
const M_SIDEWALK := preload("res://assets/materials/city/sidewalk.tres")
const M_CURB := preload("res://assets/materials/city/curb.tres")
const M_LINE := preload("res://assets/materials/city/road_marking.tres")
const M_RAIL := preload("res://assets/materials/buildings/bld_metal_dark.tres")
const M_GLASS := preload("res://assets/materials/buildings/bld_glass.tres")
const M_HEDGE := preload("res://assets/materials/buildings/bld_shrub.tres")
const M_TYRE := preload("res://assets/materials/buildings/bld_asphalt.tres")
const M_TAIL := preload("res://assets/materials/buildings/bld_terracotta.tres")
const AWNINGS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_turquoise.tres"),
	preload("res://assets/materials/buildings/bld_terracotta.tres"),
	preload("res://assets/materials/buildings/bld_green_accent.tres"),
	preload("res://assets/materials/buildings/bld_bin_yellow.tres"),
]
## Sokak ölçüleri (oyun birimi; şehir ölçeği yaklaşık 1 birim ≈ 2,3 m).
const SIDEWALK := 0.75
const SIDEWALK_TOP := 0.09
const CURB := 0.1
const PARKING := 1.0
const FLOOR_H := 1.4
## Görsel revizyon 7: Akdeniz bina kütüphanesi (scripts/world/dev/gen_building_library.gd üretir).
## Yalnızca dekor; yatırım binaları (BuildingDefinition) ayrı sahnelerdir ve burada kullanılmaz.
const LIBRARY := {
	&"house_a": "residential/residential_house_a", &"house_b": "residential/residential_house_b",
	&"house_c": "residential/mediterranean_house_c", &"apartment_a": "apartments/apartment_midrise_a",
	&"apartment_b": "apartments/apartment_modern_b", &"apartment_c": "apartments/apartment_urban_c",
	&"villa_a": "villas/villa_modern_a", &"villa_b": "villas/villa_mediterranean_b",
	&"shop_a": "commercial/commercial_shop_a", &"shop_b": "commercial/commercial_shop_b",
	&"public_a": "public/public_building_a", &"public_b": "public/public_building_b",
}
## Cephe rengi çeşitlemesi: kütüphane modelinin arch_facade yüzeyi bu tonlarla değiştirilmiş kopyalar.
const FACADE_TINTS: Array[Material] = [
	preload("res://assets/materials/architecture/arch_facade.tres"),
	preload("res://assets/materials/architecture/arch_facade_ochre.tres"),
	preload("res://assets/materials/architecture/arch_facade_rose.tres"),
	preload("res://assets/materials/architecture/arch_facade_white.tres"),
]
## Arsaların önünü (kamera yönü +x+z) kapatmasın diye yüksek modeller yalnızca bu x aralığının dışında.
## İnce bina ayrıntılarının (korkuluk, klima, bitki) görünür kaldığı kamera uzaklığı (zoom 22–105).
const FINE_DETAIL_RANGE := 80.0
const TALL_WEST_X := -28.0
const TALL_EAST_X := 36.0
## Kamu yapıları: belirli mahallelerde, hedef noktaya en yakın boş yere.
const LANDMARKS: Array = [[&"public_a", Vector2(-29, 0.5)], [&"public_b", Vector2(25, 0.5)]]
const M_POT := preload("res://assets/materials/buildings/bld_terracotta.tres")
const M_PLANTER := preload("res://assets/materials/buildings/bld_stone_dark.tres")
const M_PAVING_LIGHT := preload("res://assets/materials/city/paving_light.tres")
const FLOWERS: Array[Material] = [
	preload("res://assets/materials/city/flower_pink.tres"),
	preload("res://assets/materials/city/flower_purple.tres"),
	preload("res://assets/materials/buildings/bld_fruit.tres"),
	preload("res://assets/materials/city/flower_white.tres"),
	preload("res://assets/materials/city/flower_yellow.tres"),
]
const M_POT_STONE := preload("res://assets/materials/buildings/bld_stone.tres")
const M_POT_CREAM := preload("res://assets/materials/buildings/bld_cream.tres")
const M_BIN := preload("res://assets/materials/buildings/bld_green_accent.tres")
const SKINS: Array[Material] = [
	preload("res://assets/materials/city/skin_light.tres"),
	preload("res://assets/materials/city/skin_mid.tres"),
	preload("res://assets/materials/city/skin_dark.tres"),
]
const SHIRTS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_turquoise.tres"),
	preload("res://assets/materials/buildings/bld_terracotta.tres"),
	preload("res://assets/materials/buildings/bld_cream.tres"),
	preload("res://assets/materials/buildings/bld_bin_blue.tres"),
	preload("res://assets/materials/buildings/bld_green_accent.tres"),
	preload("res://assets/materials/buildings/bld_bin_yellow.tres"),
	preload("res://assets/materials/city/flower_pink.tres"),
]
const TROUSERS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_metal_dark.tres"),
	preload("res://assets/materials/buildings/bld_window.tres"),
	preload("res://assets/materials/buildings/bld_wood.tres"),
	preload("res://assets/materials/buildings/bld_stone.tres"),
]
const M_HAIR := preload("res://assets/materials/buildings/bld_soil_dark.tres")
const M_LIGHT := preload("res://assets/materials/signal_light.tres")
const ACCENTS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_turquoise.tres"),
	preload("res://assets/materials/buildings/bld_bin_blue.tres"),
	preload("res://assets/materials/buildings/bld_wood.tres"),
]
const UMBRELLAS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_turquoise.tres"),
	preload("res://assets/materials/buildings/bld_terracotta.tres"),
	preload("res://assets/materials/buildings/bld_bin_yellow.tres"),
]
const CAR_COLORS: Array[Material] = [
	preload("res://assets/materials/buildings/bld_cream.tres"),
	preload("res://assets/materials/buildings/bld_bin_blue.tres"),
	preload("res://assets/materials/buildings/bld_turquoise.tres"),
	preload("res://assets/materials/buildings/bld_terracotta.tres"),
	preload("res://assets/materials/buildings/bld_metal.tres"),
	preload("res://assets/materials/buildings/bld_bin_yellow.tres"),
]

## Alanlar Rect2(x0, z0, genişlik, derinlik) biçiminde, dünya koordinatında.
const ROADS_EW: Array[Rect2] = [Rect2(-38, -17.5, 76, 3), Rect2(-56, -5.75, 112, 3.5)]
const ROADS_NS: Array[Rect2] = [
	Rect2(-21.75, -17.5, 2.5, 25.3), Rect2(-11.5, -17.5, 3, 25.3), Rect2(-1.5, -17.5, 3, 25.3),
	Rect2(8.5, -17.5, 3, 25.3), Rect2(19.25, -17.5, 2.5, 25.3),
]
const PROMENADE := Rect2(-56, 5.8, 112, 2.4)
## Sahil yürüyüş yolu: kumsalın başında, denize bakan bank, saksı, korkuluk ve dinlenme alanları.
const SEAFRONT := Rect2(-56, 13.7, 112, 0.95)
## Kumsala inen korkuluk açıklıkları (merdiven yerleri), x merkezleri.
const BEACH_OPENINGS: Array[float] = [-44.0, -30.0, -2.5, 22.0, 38.0]
const SEAFRONT_REST: Array[float] = [-37.0, -22.0, 28.0, 46.0]
const FIELDS := Rect2(-100, -58, 200, 27)
const ORCHARD := Rect2(-98, -55, 196, 21)
## Şehrin batısında ve doğusunda kırsal tarım alanları (kamera kenara gidince şehir kırsala döner).
const SIDE_FIELDS: Array[Rect2] = [Rect2(-100, -31, 43.5, 43), Rect2(56.5, -31, 43.5, 43)]
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
var _library := {}
## Mahalle başına birleşik bina mesh'i: alan anahtarı → {materyal: SurfaceTool}.
var _building_tools := {}
var _blocked: Array[Rect2] = []
var _batches := {}
var _cars: Array = []
var _box := BoxMesh.new()
var _prism := PrismMesh.new()
var _sphere := SphereMesh.new()
var _cylinder := CylinderMesh.new()
var _cone := CylinderMesh.new()
var _pyramid := CylinderMesh.new()
var _car_meshes := {}
## Statik insan figürleri tek mesh'te birleşir: materyal başına bir yüzey (birkaç draw call).
var _people_tools := {}
var _capsule := CapsuleMesh.new()


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_batches.clear()
	_cars.clear()
	_car_meshes.clear()
	_people_tools.clear()
	_capsule.radius = 0.5
	_capsule.height = 2.0
	_capsule.radial_segments = 8
	_capsule.rings = 2
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
	_build_seafront()
	_build_mountains()
	_flush_batches()
	_flush_buildings()
	_flush_people()
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
		_blocked.append(road.grow(SIDEWALK + 0.35))
	var north: Rect2 = ROADS_EW[0]
	_blocked.append(Rect2(north.position.x, north.position.y - PARKING - SIDEWALK - 0.3, north.size.x, PARKING + SIDEWALK + 0.3))
	_blocked.append(PROMENADE.grow(0.3))
	_blocked.append(SEAFRONT.grow(0.15))
	_blocked.append(PIER)
	_blocked.append(TOWN_SQUARE.grow(0.5))
	_blocked.append(COAST_SQUARE)
	var reservoir := get_parent().get_node_or_null("Reservoir")
	if reservoir and reservoir.get("footprint") != null:
		_blocked.append((reservoir.get("footprint") as Rect2).grow(1.5))


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
	var key := "%d:%d:%s" % [mesh.get_instance_id(), material.get_instance_id() if material else 0, shadows]
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
	_flat(FIELDS, 0.015, 0.03, M_FIELD)
	for area in SIDE_FIELDS:
		_flat(area, 0.015, 0.03, M_FIELD)
	_flat(PROMENADE, 0.045, 0.06, M_STONE)
	# Kordon döşemesi: kenarlarda koyu taş bant, ortada açık taş şerit.
	for z in [PROMENADE.position.y + 0.15, PROMENADE.end.y - 0.15]:
		_flat(Rect2(PROMENADE.position.x, z - 0.15, PROMENADE.size.x, 0.3), 0.05, 0.02, M_PLANTER)
	_flat(Rect2(PROMENADE.position.x, PROMENADE.get_center().y - 0.35, PROMENADE.size.x, 0.7), 0.049, 0.02, M_PAVING_LIGHT)
	_build_streets()


# --- Sokaklar: yol hiyerarşisi, kaldırım ve bordür, işaretler, otopark, aydınlatma, sokak ağaçları ---

## Ana cadde koyu asfalt (kenar çizgileri, kesik orta çizgi), kuzey yolu (orta çizgi, kuzeyinde paralel otopark),
## mahalle yolları açık asfalt (çizgisiz), kordon taş yaya yolu. Kaldırımlar kavşak ağızlarında kesilir ve
## köşelerde birleşir. Yalnızca görsel: trafik kuralı ya da oyun mantığı yok.
func _build_streets() -> void:
	var north: Rect2 = ROADS_EW[0]
	var avenue: Rect2 = ROADS_EW[1]
	_flat(avenue, 0.045, 0.06, M_ROAD_MAIN)
	_flat(north, 0.04, 0.05, M_ROAD_LOCAL)
	for road in ROADS_NS:
		_flat(road, 0.035, 0.05, M_ROAD_LOCAL)
	var gaps: Array[Vector2] = []
	for road in ROADS_NS:
		gaps.append(Vector2(road.position.x, road.end.x))
	for span in _spans(avenue.position.x, avenue.end.x, gaps):
		_sidewalk_x(span, avenue.position.y - SIDEWALK, avenue.position.y, true)
		_sidewalk_x(span, avenue.end.y, avenue.end.y + SIDEWALK, false)
	for span in _spans(north.position.x, north.end.x, gaps):
		_sidewalk_x(span, north.end.y, north.end.y + SIDEWALK, false)
	# Kuzey yolunun kuzeyi: paralel otopark şeridi ve kaldırım.
	var park := Rect2(north.position.x + 1.0, north.position.y - PARKING, north.size.x - 2.0, PARKING)
	_flat(park, 0.042, 0.05, M_ROAD_LOCAL)
	_sidewalk_x(Vector2(north.position.x, north.end.x), park.position.y - SIDEWALK, park.position.y, true)
	var bay := 2.4
	var bx := park.position.x
	while bx <= park.end.x + 0.01:
		_line(Vector3(bx, 0.049, park.get_center().y), Vector3(0.06, 0.01, PARKING - 0.1))
		if bx + bay <= park.end.x and _rng.randf() < 0.55:
			var yaw := 0.0 if _rng.randf() < 0.5 else PI
			_push(_car_mesh(CAR_COLORS[_rng.randi() % CAR_COLORS.size()]), null,
					Transform3D(Basis(Vector3.UP, yaw), Vector3(bx + bay * 0.5, 0.045, park.get_center().y)))
		bx += bay
	var hx := park.position.x + 1.5
	while hx < park.end.x - 1.0:
		if _rng.randf() < 0.6:
			_add(_sphere, M_HEDGE, Vector3(hx, 0.15, park.position.y - SIDEWALK - 0.25), Vector3(0.6, 0.32, 0.4))
		hx += 2.0
	# Mahalle yollarının kaldırımları: kuzey yolundan ana caddeye, ana caddeden kordona.
	for road in ROADS_NS:
		for span in [Vector2(north.end.y + SIDEWALK, avenue.position.y - SIDEWALK), Vector2(avenue.end.y + SIDEWALK, PROMENADE.position.y)]:
			_sidewalk_z(span, road.position.x - SIDEWALK, road.position.x, true)
			_sidewalk_z(span, road.end.x, road.end.x + SIDEWALK, false)
	_build_markings(north, avenue)
	_build_street_furniture(avenue)


## [a, b] aralığından boşlukları çıkarır (kavşak ağızları).
func _spans(a: float, b: float, gaps: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var start := a
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p, q): return p.x < q.x)
	for gap in sorted:
		if gap.y <= start or gap.x >= b:
			continue
		if gap.x > start:
			result.append(Vector2(start, gap.x))
		start = maxf(start, gap.y)
	if start < b:
		result.append(Vector2(start, b))
	return result


## Doğu-batı kaldırımı (z0..z1); bordür yol tarafında (curb_at_end: z1 kenarı).
func _sidewalk_x(span: Vector2, z0: float, z1: float, curb_at_end: bool) -> void:
	if span.y - span.x < 0.05:
		return
	_flat(Rect2(span.x, z0, span.y - span.x, z1 - z0), SIDEWALK_TOP, 0.09, M_SIDEWALK)
	_flat(Rect2(span.x, z1 - CURB if curb_at_end else z0, span.y - span.x, CURB), SIDEWALK_TOP + 0.015, 0.1, M_CURB)


## Kuzey-güney kaldırımı (x0..x1); bordür yol tarafında (curb_at_end: x1 kenarı).
func _sidewalk_z(span: Vector2, x0: float, x1: float, curb_at_end: bool) -> void:
	if span.y - span.x < 0.05:
		return
	_flat(Rect2(x0, span.x, x1 - x0, span.y - span.x), SIDEWALK_TOP, 0.09, M_SIDEWALK)
	_flat(Rect2(x1 - CURB if curb_at_end else x0, span.x, CURB, span.y - span.x), SIDEWALK_TOP + 0.015, 0.1, M_CURB)


func _line(pos: Vector3, size: Vector3) -> void:
	_add(_box, M_LINE, pos, size, Vector3.ZERO, false)


func _dashes_x(span: Vector2, z: float, y: float) -> void:
	var x := span.x + 0.8
	while x < span.y - 0.8:
		_line(Vector3(x + 0.6, y, z), Vector3(1.2, 0.01, 0.1))
		x += 3.0


## Yaya geçidi: kuzey-güney yolunda, şeritler yol boyunca (z) uzanır, enine (x) dizilir.
func _zebra_z(road: Rect2, band: Vector2, y: float) -> void:
	var x := road.position.x + 0.22
	while x < road.end.x - 0.15:
		_line(Vector3(x, y, (band.x + band.y) * 0.5), Vector3(0.17, 0.01, band.y - band.x - 0.12))
		x += 0.36


## Yaya geçidi: doğu-batı yolunda, şeritler yol boyunca (x) uzanır, enine (z) dizilir.
func _zebra_x(road: Rect2, band: Vector2, y: float) -> void:
	var z := road.position.y + 0.22
	while z < road.end.y - 0.15:
		_line(Vector3((band.x + band.y) * 0.5, y, z), Vector3(band.y - band.x - 0.12, 0.01, 0.17))
		z += 0.36


## Düz ileri oku (gövde + iki kanat); dir +1 doğu, -1 batı.
func _arrow(pos: Vector3, dir: float) -> void:
	_line(pos, Vector3(0.9, 0.01, 0.09))
	var tip := pos + Vector3(dir * 0.45, 0, 0)
	for side in [-1.0, 1.0]:
		_add(_box, M_LINE, tip + Vector3(-dir * 0.14, 0, side * 0.1), Vector3(0.34, 0.01, 0.08),
				Vector3(0, dir * side * deg_to_rad(40), 0), false)


func _build_markings(north: Rect2, avenue: Rect2) -> void:
	var y_main := 0.052
	var y_north := 0.047
	var y_local := 0.042
	var gaps: Array[Vector2] = []
	for road in ROADS_NS:
		gaps.append(Vector2(road.position.x - SIDEWALK - 0.3, road.end.x + SIDEWALK + 0.3))
	for span in _spans(avenue.position.x, avenue.end.x, gaps):
		for z in [avenue.position.y + 0.17, avenue.end.y - 0.17]:
			_line(Vector3((span.x + span.y) * 0.5, y_main, z), Vector3(span.y - span.x, 0.01, 0.06))
		_dashes_x(span, avenue.get_center().y, y_main)
	for span in _spans(north.position.x, north.end.x, gaps):
		_dashes_x(span, north.get_center().y, y_north)
	var mid := avenue.get_center().y
	for i in ROADS_NS.size():
		var road: Rect2 = ROADS_NS[i]
		var cx := road.get_center().x
		var half := road.size.x * 0.5
		for band in [Vector2(north.end.y, north.end.y + SIDEWALK), Vector2(avenue.position.y - SIDEWALK, avenue.position.y),
				Vector2(avenue.end.y, avenue.end.y + SIDEWALK)]:
			_zebra_z(road, band, y_local)
		# Dur çizgileri: güneye giden şerit (x < orta) caddenin kuzeyinde, kuzeye giden (x > orta) güneyinde.
		_line(Vector3(cx - half * 0.5, y_local, avenue.position.y - SIDEWALK - 0.22), Vector3(half - 0.12, 0.01, 0.1))
		_line(Vector3(cx + half * 0.5, y_local, avenue.end.y + SIDEWALK + 0.22), Vector3(half - 0.12, 0.01, 0.1))
		for band in [Vector2(road.position.x - SIDEWALK, road.position.x), Vector2(road.end.x, road.end.x + SIDEWALK)]:
			_zebra_x(avenue, band, y_main)
		# Ana caddede dur çizgisi + ok: doğuya giden şerit güney yarıda, batıya giden kuzey yarıda.
		var east_stop := road.position.x - SIDEWALK - 0.22
		var west_stop := road.end.x + SIDEWALK + 0.22
		_line(Vector3(east_stop, y_main, (mid + avenue.end.y) * 0.5), Vector3(0.1, 0.01, avenue.end.y - mid - 0.25))
		_line(Vector3(west_stop, y_main, (mid + avenue.position.y) * 0.5), Vector3(0.1, 0.01, mid - avenue.position.y - 0.25))
		if i > 0 and i < ROADS_NS.size() - 1:
			_arrow(Vector3(east_stop - 1.4, y_main, (mid + avenue.end.y) * 0.5), 1.0)
			_arrow(Vector3(west_stop + 1.4, y_main, (mid + avenue.position.y) * 0.5), -1.0)


## Ana cadde kaldırımlarında sırayla aydınlatma direği ve sokak ağacı; kordon boyunca direkler.
func _build_street_furniture(avenue: Rect2) -> void:
	var i := 0
	var x := avenue.position.x + 2.5
	while x < avenue.end.x - 2.0:
		if not _near_ns_road(x, 1.0):
			for side in [-1.0, 1.0]:
				var z := avenue.position.y - SIDEWALK * 0.5 if side < 0.0 else avenue.end.y + SIDEWALK * 0.5
				if i % 2 == 0:
					_lamp(Vector3(x, SIDEWALK_TOP, z), side)
				else:
					_add(_box, M_CURB, Vector3(x, SIDEWALK_TOP + 0.005, z), Vector3(0.5, 0.02, 0.5), Vector3.ZERO, false)
					_olive(x, z, 0.5)
		x += 3.5
		i += 1
	# Kavşak köşelerinde çiçeklik (yaya geçidinin kenarı, kaldırımın dış yarısı).
	for road in ROADS_NS:
		for cx in [road.position.x - SIDEWALK - 0.55, road.end.x + SIDEWALK + 0.55]:
			for cz in [avenue.position.y - SIDEWALK * 0.5, avenue.end.y + SIDEWALK * 0.5]:
				_planter_box(Vector3(cx, SIDEWALK_TOP, cz), Vector3(0.7, 0.28, 0.45))
	x = PROMENADE.position.x + 6.0
	while x < PROMENADE.end.x - 4.0:
		var spot := Vector2(x, PROMENADE.position.y + 0.3)
		if not _near_ns_road(x, 0.8) and not COAST_SQUARE.grow(0.6).has_point(spot):
			_lamp(Vector3(x, 0.045, spot.y), -1.0)
		x += 8.0


func _near_ns_road(x: float, margin: float) -> bool:
	for road in ROADS_NS:
		if x > road.position.x - SIDEWALK - margin and x < road.end.x + SIDEWALK + margin:
			return true
	return false


## Aydınlatma direği; kol yola doğru uzanır (side -1: yol +z yönünde).
func _lamp(base: Vector3, side: float) -> void:
	_add(_cylinder, M_RAIL, base + Vector3(0, 1.2, 0), Vector3(0.1, 2.4, 0.1))
	_add(_box, M_RAIL, base + Vector3(0, 2.36, -side * 0.22), Vector3(0.05, 0.05, 0.5))
	_add(_box, M_TANK, base + Vector3(0, 2.3, -side * 0.44), Vector3(0.16, 0.07, 0.26))


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
	# Döşeme: kenarda koyu taş bant, çeşmenin çevresinde açık taş halka; köşelerde çiçeklik ve ağaç grubu.
	var sq := TOWN_SQUARE
	for edge in [Rect2(sq.position.x, sq.position.y, sq.size.x, 0.35), Rect2(sq.position.x, sq.end.y - 0.35, sq.size.x, 0.35),
			Rect2(sq.position.x, sq.position.y, 0.35, sq.size.y), Rect2(sq.end.x - 0.35, sq.position.y, 0.35, sq.size.y)]:
		_flat(edge, 0.058, 0.02, M_PLANTER)
	_add(_cylinder, M_PAVING_LIGHT, fountain + Vector3(0, 0.055, 0), Vector3(3.6, 0.02, 3.6), Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		var corner := Vector3(cx + side * (sq.size.x * 0.5 - 1.0), 0.06, sq.end.y - 0.9)
		_planter_box(corner, Vector3(1.2, 0.35, 0.7))
		_olive(cx + side * 2.6, sq.end.y - 0.7, 0.7)
		_bench(Vector3(cx + side * 1.2, 0.06, fountain.z + 1.5), PI)
		_person(Vector3(cx + side * 1.3, 0.06, fountain.z + 1.48), PI, &"sit")
		_pot(Vector3(cx + side * 1.8, 0.06, portico_z + 0.9), 0.9)
		_lamp(Vector3(cx + side * (sq.size.x * 0.5 - 0.6), 0.06, sq.position.y + 3.6), -1.0)
	_person(Vector3(cx - 0.8, 0.06, fountain.z - 1.4), 0.3, &"stand")
	_person(Vector3(cx - 0.55, 0.06, fountain.z - 1.55), -2.6, &"stand")
	_person(Vector3(cx + 2.8, 0.06, fountain.z - 0.6), PI * 0.5, &"walk")


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
	# Büfenin önünde kafe masaları ve şemsiyeleri, köşelerde saksılar.
	for k in 3:
		var t := Vector3(c.x - 0.6 + k * 1.15, 0.06, c.y - 0.9)
		_add(_cylinder, M_WOOD, t + Vector3(0, 0.22, 0), Vector3(0.5, 0.05, 0.5))
		_add(_cylinder, M_RAIL, t + Vector3(0, 0.11, 0), Vector3(0.06, 0.22, 0.06))
		_add(_cylinder, M_WOOD, t + Vector3(0, 0.6, 0), Vector3(0.04, 1.1, 0.04))
		_add(_cone, AWNINGS[k % AWNINGS.size()], t + Vector3(0, 1.2, 0), Vector3(1.0, 0.25, 1.0))
	for corner in [Vector3(COAST_SQUARE.position.x + 0.4, 0.06, COAST_SQUARE.position.y + 0.4), Vector3(COAST_SQUARE.end.x - 0.4, 0.06, COAST_SQUARE.position.y + 0.4)]:
		_pot_group(corner, 0.9)
	_person(Vector3(c.x - 0.6, 0.06, c.y - 0.62), PI, &"sit")
	_person(Vector3(c.x + 0.55, 0.06, c.y - 1.2), 0.0, &"sit")
	_person(Vector3(c.x + 1.9, 0.06, c.y - 0.1), PI * 0.8, &"stand")
	_person(Vector3(c.x + 2.15, 0.06, c.y - 0.3), -PI * 0.6, &"stand")
	_lamp(Vector3(c.x - 2.6, 0.06, c.y - 1.6), -1.0)


# --- Mevcut evler: beyaz sıva, terracotta çatı, damda güneş kolektörü ---

func _build_houses() -> void:
	var avenue: Rect2 = ROADS_EW[1]
	for landmark in LANDMARKS:
		_place_landmark(landmark[0], landmark[1])
	# Her sırada soldan sağa paketleme: model kendi tabanı kadar yer kaplar, aralarda 0,3–1,1 birim sokak/bahçe.
	for i in HOUSE_AREAS.size():
		var area := HOUSE_AREAS[i]
		var z := area.position.y + 2.2
		while z < area.end.y - 1.0:
			var x := area.position.x + 0.3
			while x < area.end.x - 2.0:
				if _rng.randf() < 0.08:
					x += 2.5  # boş bahçe / ara sokak
					continue
				var hz := z + _rng.randf_range(-0.4, 0.4)
				# Ana caddeye bakan sıra (caddenin kuzeyi, ön cephe caddeye dönük): dükkânlar.
				var shop := hz < avenue.position.y and hz + 2.0 > avenue.position.y - SIDEWALK - 3.4
				var placed := Rect2()
				for key in [_pick_model(i, x, hz, shop), &"house_c", &"house_a"]:
					placed = _try_place(key, x, hz, area)
					if placed.has_area():
						break
				x = placed.end.x + _rng.randf_range(0.3, 1.1) if placed.has_area() else x + 1.0
			z += 4.6


## Mahalleye göre model seçimi: kıyıda villa ve alçak evler, kuzeyde apartmanlar, cadde cephesinde dükkânlar,
## kenarlarda villalar. Yüksek modeller arsaların ve ana caddenin kamera tarafına (+x, +z) konmaz.
func _pick_model(area_index: int, x: float, z: float, shop: bool) -> StringName:
	var tall := (x < TALL_WEST_X or x > TALL_EAST_X) and z < ROADS_EW[1].position.y
	var pool: Array
	if shop:
		pool = [&"shop_a", &"shop_a", &"shop_b", &"apartment_c"] if tall else [&"shop_a", &"shop_a", &"shop_b"]
	elif area_index >= 4:
		pool = [&"villa_a", &"villa_b", &"house_b", &"house_a"]
	elif area_index >= 2:
		pool = [&"apartment_a", &"apartment_b", &"apartment_c", &"apartment_a", &"house_a"] if tall else [&"house_a", &"house_c", &"house_b"]
	elif absf(x) > 48.0:
		pool = [&"villa_a", &"villa_b", &"house_b", &"house_c"]
	elif tall:
		pool = [&"house_a", &"house_c", &"house_b", &"apartment_a", &"apartment_b", &"house_c", &"apartment_c"]
	else:
		pool = [&"house_a", &"house_b", &"house_c", &"villa_a", &"villa_b", &"house_b"]
	return pool[_rng.randi() % pool.size()]


## Model alana sığar ve boşsa yerleştirir (left: tabanın sol kenarı, z: pivot; ön cephe +z) ve tabanı döndürür;
## sığmazsa boş Rect2. Yerleşen taban komşu evlerle arayı korumak için bloklanır.
func _try_place(key: StringName, left: float, z: float, area: Rect2) -> Rect2:
	var variants: Array = _library_mesh(key)
	var aabb: AABB = variants[0].get_aabb()
	var x := left - aabb.position.x
	# Alan kenarına taşan modeli (ör. kıyı şeridinde bahçe duvarlı villa) alanın içine kaydır.
	x = clampf(x, area.position.x - aabb.position.x, area.end.x - aabb.end.x)
	z = clampf(z, area.position.y - aabb.position.z, area.end.y - aabb.end.z)
	var footprint := Rect2(x + aabb.position.x, z + aabb.position.z, aabb.size.x, aabb.size.z)
	if not (area.encloses(footprint) and _is_free(footprint)):
		return Rect2()
	var mesh: ArrayMesh = variants[_rng.randi() % variants.size()]
	var key_area := "%d_%d" % [area.position.x, area.position.y]
	if not _building_tools.has(key_area):
		_building_tools[key_area] = {}
	var tools: Dictionary = _building_tools[key_area]
	var xform := Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z))
	for s in mesh.get_surface_count():
		var material := mesh.surface_get_material(s)
		if not tools.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = st
		(tools[material] as SurfaceTool).append_from(mesh, s, xform)
	_blocked.append(footprint.grow(0.2))
	# Bazı evlerin yanında zeytin ağacı (dekor, yer varsa).
	if key.begins_with("house") and _rng.randf() < 0.25 and _is_free(Rect2(footprint.end.x + 0.2, z - 0.5, 1.0, 1.0)):
		_olive(footprint.end.x + 0.7, z, 0.65)
	return footprint


func _place_landmark(key: StringName, target: Vector2) -> void:
	for r in 6:
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := target.x + dx * 1.0
				var z := target.y + dz * 1.0
				for area in HOUSE_AREAS:
					if area.has_point(Vector2(x, z)) and _try_place(key, x, z, area).has_area():
						return


## Kütüphane modelini yükler; cephesi arch_facade olanlar için renk çeşitlemeli kopyalar üretir (önbellekli).
func _library_mesh(key: StringName) -> Array:
	if _library.has(key):
		return _library[key]
	var base: ArrayMesh = load("res://assets/buildings/%s.tres" % LIBRARY[key])
	var variants: Array = [base]
	var facade := -1
	for s in base.get_surface_count():
		if base.surface_get_material(s) == FACADE_TINTS[0]:
			facade = s
	if facade >= 0:
		for tint in FACADE_TINTS.slice(1):
			var copy: ArrayMesh = base.duplicate()
			copy.surface_set_material(facade, tint)
			variants.append(copy)
	_library[key] = variants
	return variants


# --- Bitki örtüsü ---

func _build_trees() -> void:
	# Kuzeydeki zeytinlik.
	var z := ORCHARD.position.y + 2.0
	while z < ORCHARD.end.y:
		var x := ORCHARD.position.x + 2.0
		while x < ORCHARD.end.x:
			if _rng.randf() < 0.55 and _is_free(Rect2(x - 1.0, z - 1.0, 2.0, 2.0)):
				_olive(x + _rng.randf_range(-1.0, 1.0), z + _rng.randf_range(-1.0, 1.0), _rng.randf_range(0.8, 1.2))
			x += 4.2
		z += 4.2
	# Batı ve doğu kırsalı: seyrek zeytin sıraları ve tarla sınırlarında serviler.
	for area in SIDE_FIELDS:
		z = area.position.y + 2.5
		while z < area.end.y - 1.5:
			var x := area.position.x + 2.5
			while x < area.end.x - 1.5:
				if _rng.randf() < 0.4 and _is_free(Rect2(x - 1.0, z - 1.0, 2.0, 2.0)):
					_olive(x + _rng.randf_range(-0.8, 0.8), z + _rng.randf_range(-0.8, 0.8), _rng.randf_range(0.8, 1.15))
				x += 5.0
			if _rng.randf() < 0.5:
				_cypress(area.position.x + 1.0 if area.position.x < 0.0 else area.end.x - 1.0, z, _rng.randf_range(0.85, 1.1))
			z += 5.0
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


# --- Sahil yürüyüş yolu ve peyzaj parçaları ---

## Kumsalın başında taş yürüyüş yolu: denize bakan banklar, aralarında saksılar, deniz tarafında korkuluk
## (merdiven açıklıklarıyla), aydınlatma ve pergolalı dinlenme alanları. Kıyı arsaları ve iskele boş kalır.
func _build_seafront() -> void:
	var gaps: Array[Vector2] = [Vector2(PIER.position.x - 0.2, PIER.end.x + 0.2)]
	var plots := get_parent().get_node_or_null("Plots")
	if plots:
		for plot in plots.get_children():
			var plot_size: float = plot.get("size") if plot.get("size") != null else 6.0
			if plot.position.z + plot_size * 0.5 > SEAFRONT.position.y:
				gaps.append(Vector2(plot.position.x - plot_size * 0.5 - 0.4, plot.position.x + plot_size * 0.5 + 0.4))
	var top := 0.06
	for span in _spans(SEAFRONT.position.x, SEAFRONT.end.x, gaps):
		# Kumsal eğimi üstünde duran döşeme (altı kumun içine iner).
		var c := Vector2((span.x + span.y) * 0.5, SEAFRONT.get_center().y)
		_add(_box, M_STONE, Vector3(c.x, top - 0.17, c.y), Vector3(span.y - span.x, 0.34, SEAFRONT.size.y), Vector3.ZERO, false)
		_flat(Rect2(span.x, SEAFRONT.end.y - 0.18, span.y - span.x, 0.18), top + 0.01, 0.02, M_PLANTER)
		# Korkuluk: direkler ve tutamak; merdiven açıklıklarında kesilir.
		var rail_gaps: Array[Vector2] = []
		for ox in BEACH_OPENINGS:
			rail_gaps.append(Vector2(ox - 0.9, ox + 0.9))
		for rail in _spans(span.x + 0.2, span.y - 0.2, rail_gaps):
			var rz := SEAFRONT.end.y - 0.09
			_add(_box, M_RAIL, Vector3((rail.x + rail.y) * 0.5, top + 0.42, rz), Vector3(rail.y - rail.x, 0.05, 0.05))
			_add(_box, M_RAIL, Vector3((rail.x + rail.y) * 0.5, top + 0.22, rz), Vector3(rail.y - rail.x, 0.03, 0.03), Vector3.ZERO, false)
			var px := rail.x
			while px <= rail.y + 0.01:
				_add(_box, M_RAIL, Vector3(px, top + 0.22, rz), Vector3(0.05, 0.44, 0.05))
				px += 1.2
		for ox in BEACH_OPENINGS:
			if ox > span.x + 1.0 and ox < span.y - 1.0:
				for k in 3:
					var base_y := -(SEAFRONT.end.y + 0.25 + k * 0.3 - BEACH_START_Z) * BEACH_SLOPE
					_add(_box, M_STONE, Vector3(ox, top - 0.05 - k * 0.08 + minf(base_y, 0.0) * 0.3, SEAFRONT.end.y + 0.2 + k * 0.3), Vector3(1.6, 0.12, 0.32))
		# Denize bakan banklar, aralarında saksılar; düzenli aralıklarla aydınlatma.
		var bx := span.x + 1.6
		var k := 0
		while bx < span.y - 1.2:
			if not _near(bx, BEACH_OPENINGS, 1.4) and not _near(bx, SEAFRONT_REST, 2.0):
				if k % 3 == 2:
					_lamp(Vector3(bx, top, SEAFRONT.position.y + 0.18), -1.0)
				elif k % 3 == 1:
					_pot(Vector3(bx, top, SEAFRONT.get_center().y - 0.1), 0.95)
				else:
					_bench(Vector3(bx, top, SEAFRONT.get_center().y + 0.05), 0.0)
					if _rng.randf() < 0.45:
						_person(Vector3(bx + _rng.randf_range(-0.3, 0.3), top, SEAFRONT.get_center().y + 0.07), 0.0, &"sit")
					elif k % 6 == 3:
						_trash_bin(Vector3(bx + 0.8, top, SEAFRONT.get_center().y))
			bx += 2.2
			k += 1
	# Dinlenme alanları: pergola, iki bank, saksı ve ağaç.
	for rx in SEAFRONT_REST:
		var inside := false
		for span in _spans(SEAFRONT.position.x, SEAFRONT.end.x, gaps):
			inside = inside or (rx > span.x + 2.0 and rx < span.y - 2.0)
		if not inside:
			continue
		var cz := SEAFRONT.get_center().y
		for sx in [-1.2, 1.2]:
			for sz in [-0.3, 0.3]:
				_add(_box, M_WOOD, Vector3(rx + sx, top + 0.7, cz + sz), Vector3(0.07, 1.4, 0.07))
		for s in 6:
			_add(_box, M_WOOD, Vector3(rx - 1.2 + s * 0.48, top + 1.42, cz), Vector3(0.07, 0.05, 0.8))
		_add(_box, M_WOOD, Vector3(rx, top + 1.38, cz - 0.32), Vector3(2.5, 0.06, 0.06))
		_add(_box, M_WOOD, Vector3(rx, top + 1.38, cz + 0.32), Vector3(2.5, 0.06, 0.06))
		_bench(Vector3(rx - 0.6, top, cz + 0.05), 0.0)
		_bench(Vector3(rx + 0.6, top, cz + 0.05), 0.0)
		_person(Vector3(rx - 0.75, top, cz + 0.07), 0.0, &"sit")
		_person(Vector3(rx + 0.5, top, cz + 0.07), 0.1, &"sit")
		_trash_bin(Vector3(rx + 1.95, top, cz - 0.25))
		_pot(Vector3(rx - 1.6, top, cz), 1.0)
		_pot(Vector3(rx + 1.6, top, cz), 1.0)
	# Kordonda yürüyenler ve sahil yolunda denize bakanlar (az ve dağınık).
	var wx := PROMENADE.position.x + 3.0
	while wx < PROMENADE.end.x - 3.0:
		if not _near_ns_road(wx, 0.6) and _rng.randf() < 0.55:
			var lane := PROMENADE.get_center().y + _rng.randf_range(-0.5, 0.4)
			_person(Vector3(wx + _rng.randf_range(-1.0, 1.0), 0.05, lane), PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5, &"walk")
			if _rng.randf() < 0.35:
				_person(Vector3(wx + 0.3, 0.05, lane + 0.25), PI * 0.5, &"walk")
		wx += _rng.randf_range(4.0, 7.0)
	for span in _spans(SEAFRONT.position.x, SEAFRONT.end.x, gaps):
		var vx := span.x + 3.0
		while vx < span.y - 3.0:
			if _rng.randf() < 0.3 and not _near(vx, SEAFRONT_REST, 2.2):
				_person(Vector3(vx, 0.06, SEAFRONT.end.y - 0.32), _rng.randf_range(-0.3, 0.3), &"stand")
			vx += 5.0
	# Seyir noktası, yönlendirme tabelaları, bisiklet parkı.
	_viewpoint(Vector3(-15.0 if not _near(-15.0, BEACH_OPENINGS, 1.0) else -17.0, 0.06, SEAFRONT.end.y + 0.35))
	_signpost(Vector3(COAST_SQUARE.end.x + 0.5, 0.05, PROMENADE.end.y - 0.2))
	_signpost(Vector3(TOWN_SQUARE.end.x + 0.6, 0.06, TOWN_SQUARE.end.y - 0.4))
	_bike_rack(Vector3(COAST_SQUARE.position.x + 0.6, 0.06, COAST_SQUARE.end.y - 0.45), 3)
	# Kordonda (palmiye sırası) banklar ve saksılar.
	var x := PROMENADE.position.x + 4.5
	while x < PROMENADE.end.x - 3.0:
		if not _near_ns_road(x, 0.6) and not COAST_SQUARE.grow(0.8).has_point(Vector2(x, PROMENADE.end.y)):
			_bench(Vector3(x, 0.05, PROMENADE.end.y - 0.45), 0.0)
			if _rng.randf() < 0.35:
				_person(Vector3(x + 0.25, 0.05, PROMENADE.end.y - 0.43), 0.0, &"sit")
			if _rng.randf() < 0.5:
				_pot_group(Vector3(x + 1.2, 0.05, PROMENADE.end.y - 0.45), 0.8)
			else:
				_trash_bin(Vector3(x + 0.9, 0.05, PROMENADE.end.y - 0.4))
		x += 6.0


func _near(x: float, list: Array, margin: float) -> bool:
	for v in list:
		if absf(x - v) < margin:
			return true
	return false


## Bank: ahşap oturak ve sırtlık, taş ayaklar. yaw 0: sırtlık kuzeyde, oturan güneye (+z, denize) bakar.
func _bench(base: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_push(_box, M_WOOD, Transform3D(b * Basis.from_scale(Vector3(1.1, 0.07, 0.36)), base + Vector3(0, 0.3, 0)))
	_push(_box, M_WOOD, Transform3D(b * Basis.from_scale(Vector3(1.1, 0.26, 0.06)), base + b * Vector3(0, 0.46, -0.17)))
	for sx in [-0.45, 0.45]:
		_push(_box, M_PLANTER, Transform3D(b * Basis.from_scale(Vector3(0.08, 0.3, 0.32)), base + b * Vector3(sx, 0.15, 0)))


## Saksı: terracotta, taş, krem beton, modern dikdörtgen ya da geniş kase; içinde çalı + çiçek ya da küçük süs ağacı.
func _pot(base: Vector3, s: float) -> void:
	var kind := _rng.randi() % 5
	var top := 0.32 * s
	match kind:
		0:
			_add(_cylinder, M_POT, base + Vector3(0, 0.16 * s, 0), Vector3(0.36, 0.32, 0.36) * s)
		1:
			_add(_box, M_POT_STONE, base + Vector3(0, 0.15 * s, 0), Vector3(0.36, 0.3, 0.36) * s)
			top = 0.3 * s
		2:
			_add(_cylinder, M_POT_CREAM, base + Vector3(0, 0.2 * s, 0), Vector3(0.4, 0.4, 0.4) * s)
			top = 0.4 * s
		3:
			_add(_box, M_RAIL, base + Vector3(0, 0.22 * s, 0), Vector3(0.26, 0.44, 0.26) * s)
			top = 0.44 * s
		_:
			_add(_sphere, M_POT_STONE, base + Vector3(0, 0.1 * s, 0), Vector3(0.52, 0.26, 0.52) * s)
			top = 0.18 * s
	if _rng.randf() < 0.25:
		# Küçük süs ağacı (zeytin).
		_add(_cylinder, M_WOOD, base + Vector3(0, top + 0.2 * s, 0), Vector3(0.05, 0.4, 0.05) * s)
		_add(_sphere, M_OLIVE, base + Vector3(0, top + 0.48 * s, 0), Vector3(0.42, 0.36, 0.42) * s)
		return
	_add(_sphere, M_HEDGE, base + Vector3(0, top + 0.1 * s, 0), Vector3(0.42, 0.32, 0.42) * s)
	_add(_sphere, FLOWERS[_rng.randi() % FLOWERS.size()], base + Vector3(0.05, top + 0.23 * s, 0.03), Vector3(0.24, 0.16, 0.24) * s)


## 2-3 saksılık küçük grup (tek tek dağılmasın diye).
func _pot_group(base: Vector3, s: float) -> void:
	var n := 2 + _rng.randi() % 2
	for k in n:
		_pot(base + Vector3((k - (n - 1) * 0.5) * 0.36 * s, 0, _rng.randf_range(-0.08, 0.08)), s * _rng.randf_range(0.8, 1.1))


## Çöp kutusu (yeşil gövde, koyu kapak).
func _trash_bin(base: Vector3) -> void:
	_add(_cylinder, M_BIN, base + Vector3(0, 0.17, 0), Vector3(0.2, 0.34, 0.2))
	_add(_cylinder, M_RAIL, base + Vector3(0, 0.355, 0), Vector3(0.22, 0.03, 0.22))


## Yönlendirme tabelası: direk ve iki ok levhası.
func _signpost(base: Vector3) -> void:
	_add(_cylinder, M_RAIL, base + Vector3(0, 0.55, 0), Vector3(0.05, 1.1, 0.05))
	_add(_box, M_TURQUOISE, base + Vector3(0.12, 0.98, 0), Vector3(0.3, 0.09, 0.02), Vector3(0, 0.3, 0))
	_add(_box, M_POT_CREAM, base + Vector3(-0.1, 0.86, 0), Vector3(0.28, 0.08, 0.02), Vector3(0, -0.4, 0))


## Bisiklet parkı: U demirleri ve birkaç bisiklet (tekerlekler, gövde, gidon).
func _bike_rack(base: Vector3, count: int) -> void:
	for k in count + 1:
		var x := base.x + k * 0.36
		_add(_box, M_RAIL, Vector3(x, base.y + 0.17, base.z), Vector3(0.03, 0.34, 0.03))
		_add(_box, M_RAIL, Vector3(x, base.y + 0.34, base.z), Vector3(0.03, 0.03, 0.28))
	for k in count:
		var x := base.x + 0.18 + k * 0.36
		var frame: Material = SHIRTS[_rng.randi() % SHIRTS.size()]
		for wz in [-0.22, 0.22]:
			_add(_cylinder, M_TYRE, Vector3(x, base.y + 0.13, base.z + wz), Vector3(0.26, 0.03, 0.26), Vector3(0, 0, PI * 0.5))
		_add(_box, frame, Vector3(x, base.y + 0.2, base.z), Vector3(0.03, 0.03, 0.42))
		_add(_box, frame, Vector3(x, base.y + 0.28, base.z - 0.05), Vector3(0.03, 0.18, 0.03))
		_add(_box, M_RAIL, Vector3(x, base.y + 0.36, base.z + 0.2), Vector3(0.18, 0.02, 0.02))


## Seyir noktası: taş platform, korkuluk ve dürbün.
func _viewpoint(base: Vector3) -> void:
	_add(_box, M_STONE, base + Vector3(0, -0.02, 0), Vector3(1.6, 0.12, 0.9))
	_add(_box, M_RAIL, base + Vector3(0, 0.38, 0.42), Vector3(1.6, 0.04, 0.04))
	_add(_cylinder, M_RAIL, base + Vector3(0.4, 0.3, 0.15), Vector3(0.05, 0.6, 0.05))
	_add(_box, M_RAIL, base + Vector3(0.4, 0.64, 0.17), Vector3(0.1, 0.07, 0.18), Vector3(deg_to_rad(-12), 0, 0))


# --- İnsanlar: statik, düşük poligonlu figürler (simülasyon yok) ---

## Ayakta, yürüyen ya da oturan figür; boy yaklaşık 0,78 birim (≈ 1,75 m). +z ileri.
func _person(base: Vector3, yaw: float, pose: StringName) -> void:
	var shirt: Material = SHIRTS[_rng.randi() % SHIRTS.size()]
	var trousers: Material = TROUSERS[_rng.randi() % TROUSERS.size()]
	var skin: Material = SKINS[_rng.randi() % SKINS.size()]
	var holder := Transform3D(Basis(Vector3.UP, yaw), base)
	for part in _person_parts(pose, shirt, trousers, skin):
		if not _people_tools.has(part[1]):
			_people_tools[part[1]] = SurfaceTool.new()
		(_people_tools[part[1]] as SurfaceTool).append_from(part[0], 0,
				holder * Transform3D(Basis.from_euler(part[4]) * Basis.from_scale(part[3]), part[2]))


## Kütüphane binaları: her mahalle tek MeshInstance3D, materyal başına bir yüzey (az draw call; mahalle
## bazında görünüm dışı ayıklama sürer).
func _flush_buildings() -> void:
	for key_area in _building_tools:
		var tools: Dictionary = _building_tools[key_area]
		# Üç katman: ana kütleler (cephe, taş, çatı) gölge düşürür; cephe ayrıntıları (cam, çerçeve, panjur, korniş)
		# gölgesiz; ince ayrıntılar (korkuluk babaları, klima, saksı bitkisi) gölgesiz ve uzakta gizlenir (LOD:
		# en uzak zoom'da birkaç pikselden küçükler). Gölge geçişindeki üçgen yükü yarıdan aza iner.
		for layer in ["mass", "detail", "fine"]:
			var mesh := ArrayMesh.new()
			for material in tools:
				if _building_layer(material) != layer:
					continue
				(tools[material] as SurfaceTool).commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, material)
			if mesh.get_surface_count() == 0:
				continue
			var instance := MeshInstance3D.new()
			instance.name = "Buildings_%s_%s" % [key_area, layer]
			instance.mesh = mesh
			if layer != "mass":
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if layer == "fine":
				instance.visibility_range_end = FINE_DETAIL_RANGE
				instance.visibility_range_end_margin = 8.0
				instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(instance)
	_building_tools.clear()


static func _building_layer(material: Material) -> String:
	var name := material.resource_path.get_file().get_basename().trim_prefix("arch_")
	if name.begins_with("facade") or name in ["stone", "roof", "wood"]:
		return "mass"
	if name in ["rail", "metal", "plant"]:
		return "fine"
	return "detail"


func _flush_people() -> void:
	if _people_tools.is_empty():
		return
	var mesh := ArrayMesh.new()
	for material in _people_tools:
		(_people_tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var instance := MeshInstance3D.new()
	instance.name = "People"
	instance.mesh = mesh
	add_child(instance)
	_people_tools.clear()


## Figürün parçaları: [mesh, materyal, konum, ölçek, dönüş].
func _person_parts(pose: StringName, shirt: Material, trousers: Material, skin: Material) -> Array:
	var parts: Array = []  # [mesh, material, pos, scale, rot]
	var hip := 0.36
	if pose == &"sit":
		hip = 0.33
		for lx in [-0.045, 0.045]:
			parts.append([_capsule, trousers, Vector3(lx, hip, 0.1), Vector3(0.07, 0.11, 0.07), Vector3(PI * 0.5, 0, 0)])
			parts.append([_capsule, trousers, Vector3(lx, hip * 0.5, 0.2), Vector3(0.06, 0.09, 0.06), Vector3.ZERO])
	else:
		var swing := 0.25 if pose == &"walk" else 0.0
		for k in 2:
			var lx := -0.045 if k == 0 else 0.045
			var a := swing if k == 0 else -swing
			parts.append([_capsule, trousers, Vector3(lx, hip * 0.5, 0), Vector3(0.07, hip * 0.5, 0.07), Vector3(a, 0, 0)])
	var chest := hip + 0.15
	parts.append([_capsule, shirt, Vector3(0, chest, 0), Vector3(0.15, 0.12, 0.1), Vector3.ZERO])
	var arm_swing := 0.3 if pose == &"walk" else 0.08
	for k in 2:
		var ax := -0.1 if k == 0 else 0.1
		var a := arm_swing if k == 0 else -arm_swing
		if pose == &"sit":
			a = -0.6
		parts.append([_capsule, shirt, Vector3(ax, chest - 0.02, 0.02 if pose == &"sit" else 0.0), Vector3(0.045, 0.11, 0.045), Vector3(a, 0, 0)])
	parts.append([_sphere, skin, Vector3(0, chest + 0.2, 0), Vector3(0.12, 0.13, 0.12), Vector3.ZERO])
	parts.append([_sphere, M_HAIR, Vector3(0, chest + 0.24, -0.01), Vector3(0.125, 0.08, 0.125), Vector3.ZERO])
	return parts


## Taş çiçeklik: yeşillik ve iki renk çiçek.
func _planter_box(center: Vector3, size: Vector3) -> void:
	_add(_box, M_PLANTER, center + Vector3(0, size.y * 0.5, 0), size)
	_add(_box, M_HEDGE, center + Vector3(0, size.y + 0.05, 0), Vector3(size.x - 0.1, 0.14, size.z - 0.1))
	for k in 2:
		_add(_sphere, FLOWERS[_rng.randi() % FLOWERS.size()], center + Vector3((k - 0.5) * size.x * 0.45, size.y + 0.14, 0),
				Vector3(size.z * 0.45, 0.16, size.z * 0.45))


# --- Arka plan: dağ silüeti ---

func _build_mountains() -> void:
	var x := -95.0
	while x < 95.0:
		var r := _rng.randf_range(14.0, 24.0)
		var h := _rng.randf_range(14.0, 28.0)
		var z := _rng.randf_range(-82.0, -70.0)
		_add(_cone, M_MOUNTAIN, Vector3(x, h * 0.5, z), Vector3(r * 2.0, h, r * 2.0), Vector3(0, _rng.randf() * TAU, 0), false)
		x += _rng.randf_range(12.0, 18.0)
	# Toros etekleri batıya ve doğuya kıvrılır: kara parçasının yan kenarı (x = ±110) ve arkası görünmez.
	for side in [-1.0, 1.0]:
		var sz := -62.0
		while sz < -2.0:
			var r := _rng.randf_range(10.0, 15.0)
			var h := _rng.randf_range(7.0, 15.0) * clampf(1.0 + (sz + 30.0) * -0.01, 0.6, 1.3)
			var sx: float = side * _rng.randf_range(104.0, 112.0)
			_add(_cone, M_HILL if sz > -35.0 else M_MOUNTAIN, Vector3(sx, h * 0.5, sz), Vector3(r * 2.0, h, r * 2.0),
					Vector3(0, _rng.randf() * TAU, 0), false)
			sz += _rng.randf_range(9.0, 13.0)
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
		var car := MeshInstance3D.new()
		car.mesh = _car_mesh(CAR_COLORS[_rng.randi() % CAR_COLORS.size()])
		car.position = Vector3(_rng.randf_range(lane[2], lane[3]), 0.05, lane[0])
		car.rotation.y = 0.0 if lane[1] > 0.0 else PI
		traffic.add_child(car)
		_cars.append({"node": car, "dir": lane[1], "speed": _rng.randf_range(3.5, 6.0), "x_min": lane[2], "x_max": lane[3]})


## Low-poly otomobil (gövde, kabin camı ve tavanı, tekerlekler, ön ve arka lambalar), +x ileri.
## Tek ArrayMesh; renk başına bir kez kurulur, hareketli ve park etmiş araçlar paylaşır.
func _car_mesh(color: Material) -> ArrayMesh:
	if _car_meshes.has(color):
		return _car_meshes[color]
	var parts := [
		[_box, color, Vector3(0, 0.33, 0), Vector3(1.9, 0.38, 0.84), Vector3.ZERO],
		[_box, M_WINDOW, Vector3(-0.1, 0.62, 0), Vector3(1.02, 0.24, 0.78), Vector3.ZERO],
		[_box, color, Vector3(-0.1, 0.77, 0), Vector3(1.06, 0.07, 0.8), Vector3.ZERO],
		[_box, M_TANK, Vector3(0.94, 0.4, 0.27), Vector3(0.04, 0.07, 0.16), Vector3.ZERO],
		[_box, M_TANK, Vector3(0.94, 0.4, -0.27), Vector3(0.04, 0.07, 0.16), Vector3.ZERO],
		[_box, M_TAIL, Vector3(-0.94, 0.4, 0.27), Vector3(0.04, 0.07, 0.16), Vector3.ZERO],
		[_box, M_TAIL, Vector3(-0.94, 0.4, -0.27), Vector3(0.04, 0.07, 0.16), Vector3.ZERO],
	]
	for wx in [-0.6, 0.6]:
		for wz in [-0.4, 0.4]:
			parts.append([_cylinder, M_TYRE, Vector3(wx, 0.16, wz), Vector3(0.32, 0.12, 0.32), Vector3(PI * 0.5, 0, 0)])
	var tools := {}
	for part in parts:
		var material: Material = part[1]
		if not tools.has(material):
			tools[material] = SurfaceTool.new()
		var xform := Transform3D(Basis.from_euler(part[4]) * Basis.from_scale(part[3]), part[2])
		(tools[material] as SurfaceTool).append_from(part[0], 0, xform)
	var mesh := ArrayMesh.new()
	for material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	_car_meshes[color] = mesh
	return mesh
