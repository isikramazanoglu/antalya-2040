extends Node3D
## Sahip: A. Görsel revizyon 9 · Dekoratif şehir trafiği (yalnızca görsel; GameState, ekonomi, emisyon, ulaşım
## kapasitesi ile bağlantısı yok; çarpışma şekli ya da fizik gövdesi yok).
## - Hareketli araçlar: ana cadde ve kuzey yolunda kapalı Path3D rotaları (iki şerit, uçlarda yuvarlak U dönüşü,
##   sağdan akış). PathFollow3D; tekerlekler hızla orantılı döner.
## - Basit takip: öndeki araca yaklaşınca yavaşlar, durur (üst üste binmez); yaya geçidinde yaya varken bekler;
##   otobüs belediye meydanı durağında birkaç saniye durur. Gerçek trafik simülasyonu / ışık mantığı yok.
## - Park etmiş araçlar: Decor'un kaydettiği yerlere, tek birleşik mesh (materyal başına yüzey).
## Yaya sistemi (pedestrians.gd) yaya geçidindeki araçları buradan sorar: vehicle_in_zone().

const ROAD_Y := 0.045
## Seyir hızı (birim/sn; 1 birim ≈ 2,3 m → ~18–22 km/s, sakin şehir içi). Otobüs biraz yavaş.
const CRUISE := Vector2(2.0, 2.5)
const BUS_CRUISE := 1.7
const ACCEL := 1.4
const BRAKE := 4.0
## Öndeki araçla tampon arası: bunun altında durur, iki katında yavaşlamaya başlar.
const MIN_GAP := 0.55
const SLOW_GAP := 2.2
## Yaya geçidi: aracın burnu bölgeye bu kadar kala yaya varsa durur.
const CROSSING_LOOKAHEAD := 1.0
const BUS_DWELL := 5.0
## Tekerlek dönüşü yalnızca kameraya yakın ve görünür araçlarda (uzakta birkaç piksel).
const WHEEL_RANGE := 70.0

@export var decor_path: NodePath = ^"../Decor"
@export var pedestrians_path: NodePath = ^"../Pedestrians"

var _rng := RandomNumberGenerator.new()
## Rota: {path: Path3D, length, vehicles: Array}
var _routes: Array[Dictionary] = []
## Araç: {follow, model, length, speed, cruise, wheels: [[node, yaw, radius]], route, dwell, dwelt, stop_offset}
var _vehicles: Array[Dictionary] = []
## Yaya geçitleri (XZ dikdörtgen): araçlar yayayı, yayalar aracı burada bekler.
var crossings: Array[Rect2] = []
var _occupied_by_vehicle: Array[bool] = []
var _pedestrians: Node
var _wheel_timer := 0.0
var _camera_eye := Vector3.ZERO
var _camera: Camera3D


func _ready() -> void:
	_rng.seed = 2041
	_pedestrians = get_node_or_null(pedestrians_path)
	_build_crossings()
	_build_routes()
	var decor := get_node_or_null(decor_path)
	_build_parked(decor.get("parking_spots") if decor else [])


func _process(delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	_camera_eye = _camera.global_position if _camera else Vector3.ZERO
	_update_crossing_occupancy()
	var walkers := _walker_positions()
	for route in _routes:
		var list: Array = route.vehicles
		var length: float = route.length
		for i in list.size():
			var v: Dictionary = list[i]
			var leader: Dictionary = list[(i + 1) % list.size()]
			var follow: PathFollow3D = v.follow
			var target: float = v.cruise
			# Öndeki araç (aynı rota, sıra korunur; aralık rota uzunluğunda döngüsel).
			if list.size() > 1:
				var gap: float = fposmod((leader.follow as PathFollow3D).progress - follow.progress, length) - (leader.length + v.length) * 0.5
				if gap < MIN_GAP:
					target = 0.0
				elif gap < SLOW_GAP:
					target = minf(target, v.cruise * (gap - MIN_GAP) / (SLOW_GAP - MIN_GAP))
			# Yaya geçidi.
			if _crossing_blocked(v, walkers):
				target = 0.0
			# Otobüs durağı.
			if v.has("stop_offset"):
				target = _bus_stop_target(v, target, delta, length)
			var rate := ACCEL if target > v.speed else BRAKE
			v.speed = move_toward(v.speed, target, rate * delta)
			follow.progress += v.speed * delta
			if v.has("exhaust"):  # teslim hotfix: egzoz hızla artar, durunca rölantide az
				(v.exhaust as GPUParticles3D).amount_ratio = clampf(v.speed / maxf(v.cruise, 0.01), 0.15, 1.0)
			_spin_wheels(v, v.speed * delta)


## Yaya sistemi için: geçitte (bölgenin içinde) araç var mı?
func vehicle_in_zone(index: int) -> bool:
	return index >= 0 and index < _occupied_by_vehicle.size() and _occupied_by_vehicle[index]


func get_counts() -> Dictionary:
	var parked := 0
	if has_node("Parked"):
		parked = get_node("Parked").get_meta("count", 0)
	var models := {}
	for v in _vehicles:
		models[v.model] = true
	return {"moving": _vehicles.size(), "parked": parked, "models": models.keys(), "routes": _routes.size()}


# --- Rotalar ---

## Kapalı şerit döngüsü: z_out şeridinde +x yönünde x0 → x1, x1'de yarım daire, z_back şeridinde geri.
## Sağdan akış: +x'e giden araç güneydeki (büyük z) şeritte.
func _loop_curve(x0: float, x1: float, z_east: float, z_west: float) -> Curve3D:
	var curve := Curve3D.new()
	var r := absf(z_east - z_west) * 0.5
	var zc := (z_east + z_west) * 0.5
	curve.add_point(Vector3(x0, ROAD_Y, z_east))
	curve.add_point(Vector3(x1, ROAD_Y, z_east))
	for k in range(1, 12):
		var a := PI * 0.5 - PI * k / 12.0  # güneyden kuzeye, doğu ucunda
		curve.add_point(Vector3(x1 + cos(a) * r, ROAD_Y, zc + sin(a) * r))
	curve.add_point(Vector3(x1, ROAD_Y, z_west))
	curve.add_point(Vector3(x0, ROAD_Y, z_west))
	for k in range(1, 12):
		var a := -PI * 0.5 - PI * k / 12.0  # kuzeyden güneye, batı ucunda
		curve.add_point(Vector3(x0 + cos(a) * r, ROAD_Y, zc + sin(a) * r))
	curve.add_point(Vector3(x0, ROAD_Y, z_east))
	return curve


func _build_routes() -> void:
	# Ana cadde (Rect2(-56, -5.75, 112, 3.5)): doğuya giden şerit z -3,15, batıya giden z -4,85; uçlar haritanın kenarında.
	var avenue := _add_route("AnaCadde", _loop_curve(-54.0, 54.0, -3.15, -4.85))
	# Kuzey yolu (Rect2(-38, -17.5, 76, 3)): doğuya z -15,4, batıya z -16,6.
	var north := _add_route("KuzeyYolu", _loop_curve(-36.5, 36.5, -15.4, -16.6))
	var avenue_fleet: Array[StringName] = [&"city_bus", &"sedan", &"city_car", &"compact_suv", &"minibus", &"electric_car",
		&"sedan", &"delivery_van", &"city_car", &"compact_suv", &"electric_car", &"sedan"]
	var north_fleet: Array[StringName] = [&"delivery_van", &"city_car", &"sedan", &"electric_car", &"compact_suv"]
	_populate(avenue, avenue_fleet)
	_populate(north, north_fleet)
	# Otobüs durağı: batıya giden şeritte, durak sundurmasının hizasında (Decor.BUS_STOP).
	var stop := Vector3(-31.3, ROAD_Y, -4.85)
	for v in _vehicles:
		if v.model == &"city_bus":
			v.stop_offset = (avenue.path as Path3D).curve.get_closest_offset(stop)
			v.dwell = 0.0
			v.dwelt = false


func _add_route(route_name: String, curve: Curve3D) -> Dictionary:
	var path := Path3D.new()
	path.name = "Route_" + route_name
	path.curve = curve
	add_child(path)
	var route := {"path": path, "length": curve.get_baked_length(), "vehicles": []}
	_routes.append(route)
	return route


## Araçlar rotaya eşit aralıkla (küçük sapmayla) dizilir; listede rota sırasına göre tutulur (öndeki = sonraki).
func _populate(route: Dictionary, fleet: Array[StringName]) -> void:
	var length: float = route.length
	for i in fleet.size():
		var model := fleet[i]
		var progress := length * (i + _rng.randf_range(0.0, 0.3)) / fleet.size()
		var v := _spawn(route, model, progress, i * 7919 + 13)
		route.vehicles.append(v)


func _spawn(route: Dictionary, model: StringName, progress: float, look: int) -> Dictionary:
	var follow := PathFollow3D.new()
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	follow.loop = true
	(route.path as Path3D).add_child(follow)
	follow.progress = progress
	var body: Node3D = (load(VehicleLibrary.MODELS[model]) as PackedScene).instantiate()
	follow.add_child(body)
	var mesh_body: MeshInstance3D = body.get_node("Body")
	for s in mesh_body.mesh.get_surface_count():
		var m := mesh_body.mesh.surface_get_material(s)
		if m and m.resource_name == "veh_paint":
			mesh_body.set_surface_override_material(s, VehicleLibrary.paint_for(model, look))
	var wheels := []
	for child in body.get_children():
		if child.name.begins_with("Wheel_"):
			var w := child as MeshInstance3D
			wheels.append([w, w.rotation.y, w.mesh.get_aabb().size.y * 0.5])
	var exhaust := _make_exhaust(body)
	var cruise := BUS_CRUISE if model == &"city_bus" else _rng.randf_range(CRUISE.x, CRUISE.y)
	var v := {"follow": follow, "body": body, "model": model, "length": VehicleLibrary.length_of(model), "speed": cruise,
		"cruise": cruise, "wheels": wheels, "spin": 0.0, "exhaust": exhaust}
	_vehicles.append(v)
	return v


## Teslim hotfix (B, Emre devre dışıyken): arka uçta (stop lambası tarafı, +z) alçakta küçük egzoz dumanı.
## Parçacıklar dünya koordinatında kalır: araç ilerledikçe arkasında kısa, hızla dağılan bir iz bırakır.
static var _exhaust_mat: ParticleProcessMaterial
static var _exhaust_mesh: QuadMesh


func _make_exhaust(body: Node3D) -> GPUParticles3D:
	if _exhaust_mat == null:
		_exhaust_mat = ParticleProcessMaterial.new()
		_exhaust_mat.direction = Vector3(0, 1, 0)
		_exhaust_mat.spread = 25.0
		_exhaust_mat.initial_velocity_min = 0.15
		_exhaust_mat.initial_velocity_max = 0.3
		_exhaust_mat.gravity = Vector3(0, 0.25, 0)
		_exhaust_mat.scale_min = 0.6
		_exhaust_mat.scale_max = 1.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.6))
		var ct := CurveTexture.new()
		ct.curve = curve
		_exhaust_mat.scale_curve = ct
		var g := Gradient.new()
		g.set_color(0, Color(0.55, 0.55, 0.55, 0.45))
		g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		_exhaust_mat.color_ramp = gt
		_exhaust_mesh = QuadMesh.new()
		_exhaust_mesh.size = Vector2(0.14, 0.14)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_exhaust_mesh.material = m
	var aabb := (body.get_node("Body") as MeshInstance3D).mesh.get_aabb()
	var p := GPUParticles3D.new()
	p.name = "Exhaust"
	p.amount = 10
	p.lifetime = 0.9
	p.local_coords = false
	p.process_material = _exhaust_mat
	p.draw_pass_1 = _exhaust_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(aabb.position.x + aabb.size.x * 0.25, 0.12, aabb.end.z + 0.02)
	body.add_child(p)
	return p


func _bus_stop_target(v: Dictionary, target: float, delta: float, length: float) -> float:
	var d := fposmod(v.stop_offset - (v.follow as PathFollow3D).progress, length)
	if v.dwell > 0.0:
		v.dwell -= delta
		return 0.0
	if d > length * 0.5:
		v.dwelt = false  # durağı geçti; bir sonraki turda yine durur
		return target
	if not v.dwelt:
		if d < 0.05:
			v.dwell = BUS_DWELL
			v.dwelt = true
			return 0.0
		# Durağa yumuşak yanaşma: kalan mesafeye göre hız (fren mesafesi v²/2a).
		return minf(target, sqrt(2.0 * BRAKE * 0.5 * d) + 0.15)
	return target


## Tekerlekler: x ekseni (aks) etrafında; sol tekerlekler (y dönüşü PI) ters yönde.
func _spin_wheels(v: Dictionary, distance: float) -> void:
	if distance == 0.0:
		return
	var pos: Vector3 = (v.body as Node3D).global_position
	if _camera == null or _camera_eye.distance_to(pos) > WHEEL_RANGE or not _camera.is_position_in_frustum(pos):
		return
	for w: Array in v.wheels:
		var node: MeshInstance3D = w[0]
		var radius: float = w[2]
		var angle: float = node.get_meta("spin", 0.0) - distance / radius
		node.set_meta("spin", angle)
		node.basis = Basis(Vector3.UP, w[1]) * Basis(Vector3.RIGHT, angle if w[1] == 0.0 else -angle)


# --- Yaya geçitleri ---

## Yaya rotalarının araç şeritlerini kestiği yerler (pedestrians.gd rotaları): mahalle sokaklarının kaldırım
## şeritleri ana caddeden geçer; ana cadde ve kuzey yolu yaya döngülerinin uçları.
func _build_crossings() -> void:
	for x: float in [-22.15, -18.85, -1.85, 1.85, 18.85, 22.15, -54.0, 54.0]:
		crossings.append(Rect2(x - 0.3, -5.75, 0.6, 3.5))
	for x: float in [-37.0, 37.0]:
		crossings.append(Rect2(x - 0.3, -17.5, 0.6, 3.0))
	_occupied_by_vehicle.resize(crossings.size())


func _update_crossing_occupancy() -> void:
	for i in crossings.size():
		_occupied_by_vehicle[i] = false
	for v in _vehicles:
		var follow: PathFollow3D = v.follow
		var pos := follow.global_position
		var fwd := -follow.global_transform.basis.z
		var half: float = v.length * 0.5
		for i in crossings.size():
			var zone := crossings[i].grow(0.15)
			for k in 5:
				var p := pos + fwd * lerpf(-half, half, k / 4.0)
				if zone.has_point(Vector2(p.x, p.z)):
					_occupied_by_vehicle[i] = true
					break


func _walker_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _pedestrians and _pedestrians.has_method("walker_positions"):
		out = _pedestrians.walker_positions()
	return out


## Aracın burnu geçide CROSSING_LOOKAHEAD kadar yaklaşmışsa (henüz girmemişse) ve geçitte ya da kenarında yaya varsa dur.
func _crossing_blocked(v: Dictionary, walkers: PackedVector3Array) -> bool:
	var follow: PathFollow3D = v.follow
	var fwd := -follow.global_transform.basis.z
	var nose: Vector3 = follow.global_position + fwd * (v.length * 0.5)
	var ahead: Vector3 = nose + fwd * CROSSING_LOOKAHEAD
	for zone in crossings:
		if zone.has_point(Vector2(nose.x, nose.z)):
			continue  # zaten girdi: geçip gider
		if not _segment_hits(zone, Vector2(nose.x, nose.z), Vector2(ahead.x, ahead.z)):
			continue
		var wait_zone := zone.grow(0.4)
		for p in walkers:
			if wait_zone.has_point(Vector2(p.x, p.z)):
				return true
	return false


func _segment_hits(zone: Rect2, a: Vector2, b: Vector2) -> bool:
	for k in 5:
		if zone.has_point(a.lerp(b, k / 4.0)):
			return true
	return false


# --- Park etmiş araçlar ---

## Decor'un kaydettiği park yerleri: model ve renk yerden türetilir; tek birleşik mesh (materyal başına yüzey).
func _build_parked(spots: Array) -> void:
	var tools := {}
	var parked_models: Array[StringName] = [&"city_car", &"sedan", &"compact_suv", &"electric_car", &"sedan", &"city_car", &"delivery_van"]
	for spot: Dictionary in spots:
		var look: int = absi(spot.look)
		var model: StringName = parked_models[look % parked_models.size()]
		var mesh := VehicleLibrary.merged(model, VehicleLibrary.paint_for(model, look / 7))
		var xform := Transform3D(Basis(Vector3.UP, spot.yaw), spot.position)
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s)
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
			(tools[material] as SurfaceTool).append_from(mesh, s, xform)
	var mesh := ArrayMesh.new()
	for material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var instance := MeshInstance3D.new()
	instance.name = "Parked"
	instance.mesh = mesh
	instance.set_meta("count", spots.size())
	add_child(instance)
