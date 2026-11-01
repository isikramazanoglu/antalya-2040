extends Node3D
## Sahip: A. Görsel revizyon 8 · Yaşayan şehir: iskeletli ve animasyonlu insan karakterleri (yalnızca görsel).
## - Yürüyenler: kaldırım, kordon, meydan ve mahalle yollarındaki kapalı Path3D rotalarında PathFollow3D ile
##   yürür; Walk animasyonu (gerçek iskelet animasyonu), yürüme hızı adım uzunluğuyla eşleşir.
## - Oturan / ayakta duranlar: Decor'un (city_decor.gd) kaydettiği yerlere konur; uzaktakiler tek mesh'e
##   pişirilir (oturma ve bekleme pozu iskeletten alınır), meydanlardaki birkaç kişi canlı Idle animasyonu oynar.
## - Animasyon LOD: kameradan uzak ya da ekran dışındaki karakterlerin animasyonu durur, yürüyüş sürer;
##   en uzak zoom'da yürüyenler gizlenir.
## GameState, nüfus, ekonomi ve arayüzle bağlantısı yok; çarpışma şekli yok (arsa seçimini etkilemez).
## Karakterler: Quaternius "Ultimate Animated Character Pack" (CC0), bkz. docs/ASSET_LICENSES.md.

const CHARACTER_DIR := "res://assets/characters/pedestrians/"
## Karakter modeli → rolü (yaşlılar sakin yerlerde, takım elbiseliler ticari caddede ağırlıklı).
const CHARACTERS := {
	"qt_casual_male": &"casual", "qt_casual_female": &"casual", "qt_casual2_male": &"casual",
	"qt_casual2_female": &"casual", "qt_casual3_male": &"sport", "qt_casual3_female": &"casual",
	"qt_casual_bald": &"casual", "qt_old_classy_male": &"elder", "qt_old_classy_female": &"elder",
	"qt_suit_male": &"business", "qt_suit_female": &"business", "qt_doctor_female_young": &"business",
}
## Model 3,3 birim boyunda; şehir ölçeğinde (1 birim ≈ 2,3 m) yetişkin ≈ 0,78 birim ≈ 1,8 m.
const SCALE := 0.235
## Ayak kaymasın diye hız Walk animasyonundan ölçüldü: ayak yerdeyken model biriminde 2,31/sn geri gider,
## × ölçek 0,235 = 0,54 birim/sn (~1,25 m/sn). Kişiye özgü hız farkı animasyon hızıyla birlikte ölçeklenir.
const WALK_SPEED := 0.54
## Oturma pozu: SitDown animasyonunun son karesi; kök bankın yerel +z'sine bu kadar kaydırılır (diz oturak ucunda).
const SIT_POSE_TIME := 0.95
const SIT_FORWARD := 0.075
## Animasyon LOD (kamera uzaklığı, birim; zoom 22–105, açılış 90): yakında her kare, ortada 15 Hz,
## uzakta ya da ekran dışında durur (yürüyüş hareketi sürer; o uzaklıkta karakter birkaç piksel).
const NEAR_RANGE := 60.0
const MID_RANGE := 125.0
const MID_RATE := 1.0 / 15.0
## Canlı (animasyonlu) bekleyenler: kameraya en yakın meydan grupları; diğerleri pişmiş poz.
const MAX_LIVE_IDLE := 8
const LOD_INTERVAL := 0.25

const SKIN_TONES := [Color(0.96, 0.8, 0.68), Color(0.88, 0.69, 0.55), Color(0.76, 0.55, 0.41), Color(0.55, 0.38, 0.27)]
const SHIRT_COLORS := [Color(0.95, 0.95, 0.92), Color(0.55, 0.72, 0.86), Color(0.9, 0.5, 0.42), Color(0.95, 0.82, 0.42),
	Color(0.3, 0.6, 0.6), Color(0.25, 0.32, 0.5), Color(0.55, 0.62, 0.4), Color(0.88, 0.62, 0.7), Color(0.98, 0.7, 0.5)]
const TROUSER_COLORS := [Color(0.82, 0.76, 0.62), Color(0.22, 0.27, 0.4), Color(0.33, 0.43, 0.6), Color(0.45, 0.45, 0.46),
	Color(0.93, 0.92, 0.88), Color(0.42, 0.45, 0.32)]
const SUIT_COLORS := [Color(0.2, 0.22, 0.27), Color(0.33, 0.35, 0.38), Color(0.72, 0.66, 0.55), Color(0.25, 0.3, 0.42)]
const HAIR_COLORS := [Color(0.1, 0.08, 0.07), Color(0.25, 0.16, 0.1), Color(0.42, 0.28, 0.16), Color(0.55, 0.3, 0.18), Color(0.8, 0.66, 0.42)]
const HAIR_ELDER := [Color(0.82, 0.82, 0.8), Color(0.62, 0.62, 0.6)]

@export var decor_path: NodePath = ^"../Decor"
@export var camera_rig_path: NodePath = ^"../CameraRig"
## Görsel revizyon 9: yaya geçidinde araç varsa bekleme (Traffic düğümü; yoksa yayalar beklemeden yürür).
@export var traffic_path: NodePath = ^"../Traffic"

var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _materials := {}
## Yürüyenler: {follow: PathFollow3D, speed, body: Node3D, player: AnimationPlayer, tier (0 yakın, 1 orta, 2 dur), acc, meshes}
var _walkers: Array[Dictionary] = []
## Canlı bekleyenler: {body, player, tier, acc, meshes}
var _idlers: Array[Dictionary] = []
var _lod_timer := 0.0
var _traffic: Node
## Aynı rota + aynı şerit kayması grupları (öndekine çok yaklaşan bekler): {route: Path3D, offset} → yürüyenler.
var _lanes := {}
## Geçitte bekleme ve sıraya girme (yürüyen biri durunca arkadakiler araya mesafe bırakır).
const QUEUE_GAP := 0.4
const CROSSING_LOOK := 0.35


func _ready() -> void:
	_rng.seed = 2040
	for file in CHARACTERS:
		var scene: PackedScene = load(CHARACTER_DIR + file + ".glb")
		_scenes[file] = scene
		_prepare_animations(scene)
	var decor := get_node_or_null(decor_path)
	var spots: Array = decor.get("people_spots") if decor else []
	_build_routes()
	_place_people(spots)
	_update_lod()


func _process(delta: float) -> void:
	if _traffic == null:
		_traffic = get_node_or_null(traffic_path)
	for key in _lanes:
		var lane: Array = _lanes[key]
		var length: float = ((lane[0].follow as PathFollow3D).get_parent() as Path3D).curve.get_baked_length()
		for i in lane.size():
			var w: Dictionary = lane[i]
			var follow: PathFollow3D = w.follow
			var go := not _must_wait(follow)
			if go and lane.size() > 1:
				var leader: PathFollow3D = lane[(i + 1) % lane.size()].follow
				go = fposmod(leader.progress - follow.progress, length) > QUEUE_GAP
			if go:
				follow.progress += w.speed * delta
			_set_walking(w, go)
	for w in _walkers:
		_advance(w, delta)
	for a in _idlers:
		_advance(a, delta)
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_INTERVAL
		_update_lod()


## Görünen yürüyen ve canlı karakter sayısı (test ve FPS raporu için).
func get_counts() -> Dictionary:
	var animating := 0
	for a in _walkers + _idlers:
		if a.tier == 0 or a.tier == 1:
			animating += 1
	return {"walkers": _walkers.size(), "live_idle": _idlers.size(), "animating": animating,
		"baked": get_node("Baked").get_child_count() if has_node("Baked") else 0}


# --- Rotalar ---

## Kapalı rotalar: her rotada gidiş ve dönüş şeridi (sağdan yürüme), uçlar haritanın kamera sınırı dışında.
## Noktalar city_decor.gd'deki kaldırım / kordon ölçülerinden; araç yolu yalnızca yaya geçidi hizasında geçilir.
func _build_routes() -> void:
	var walk_top := 0.05  # kordon taş döşemesi
	var side_top := 0.09  # kaldırım
	# Ad, nokta listesi (XZ), yükseklik, yürüyen sayısı, yan yana yürüyen çift sayısı, model rol tercihi.
	var routes := [
		# Kordon: açık taş orta şerit, banklar (z 7,75) ve aydınlatma (z 6,1) arasında iki şerit.
		["Kordon", [Vector2(-54, 6.7), Vector2(54, 6.7), Vector2(54, 7.3), Vector2(-54, 7.3)], walk_top, 22, 5, &""],
		# Ana cadde: kuzey ve güney kaldırımlarının bina tarafı (ağaç ve lambalar bordür tarafında).
		["AnaCadde", [Vector2(-54, -6.4), Vector2(54, -6.4), Vector2(54, -1.6), Vector2(-54, -1.6)], side_top, 13, 2, &"business"],
		# Kuzey yolu: güney kaldırımı ve otoparkın kuzeyindeki kaldırım.
		["KuzeyYolu", [Vector2(-37, -13.85), Vector2(37, -13.85), Vector2(37, -19.15), Vector2(-37, -19.15)], side_top, 5, 0, &""],
		# Mahalle yolları (kuzey-güney): yolun iki kaldırımı, uçlarda yaya geçidinden karşıya.
		# Şerit kaldırımın ortasında (0,75 genişlik): arsa kenarına (yoldan 0,5) taşmaz.
		["BatiSokak", [Vector2(-22.15, -14.2), Vector2(-22.15, 5.5), Vector2(-18.85, 5.5), Vector2(-18.85, -14.2)], side_top, 3, 0, &""],
		["OrtaSokak", [Vector2(-1.85, -14.2), Vector2(-1.85, 5.5), Vector2(1.85, 5.5), Vector2(1.85, -14.2)], side_top, 3, 0, &""],
		["DoguSokak", [Vector2(18.85, -14.2), Vector2(18.85, 5.5), Vector2(22.15, 5.5), Vector2(22.15, -14.2)], side_top, 3, 0, &""],
	]
	for r in routes:
		_add_route(r[0], r[1], r[2], r[3], r[4], r[5])
	# Belediye meydanı: çeşmenin çevresinde, havuz (r 1,1) ile banklar (r 1,9) arasında halka.
	var fountain := Vector2(-28.5, -8.2)
	var ring: Array[Vector2] = []
	for k in 24:
		var a := TAU * k / 24.0
		ring.append(fountain + Vector2(cos(a), sin(a)) * 1.45)
	_add_route("MeydanCesme", ring, 0.06, 2, 0, &"elder", true)


func _add_route(route_name: String, points: Array, y: float, count: int, pairs: int, prefer: StringName, smooth := false) -> void:
	var path := Path3D.new()
	path.name = "Route_" + route_name
	var curve := Curve3D.new()
	for p: Vector2 in points:
		curve.add_point(Vector3(p.x, y, p.y))
	curve.add_point(Vector3(points[0].x, y, points[0].y))
	if not smooth:
		_round_corners(curve)
	path.curve = curve
	add_child(path)
	var length := curve.get_baked_length()
	# Eşit aralık + küçük sapma; aynı rotadaki herkes aynı hızda (birbirinin içinden geçmez).
	var speed := WALK_SPEED * _rng.randf_range(0.93, 1.05)
	for i in count:
		var progress := length * (i + _rng.randf_range(0.1, 0.6)) / count
		var file := _pick_model(prefer)
		_add_walker(path, progress, speed, file, 0.0)
		if i < pairs:
			# Yan yana yürüyen ikinci kişi (rota dışına değil, şeridin içine 0,22 birim).
			_add_walker(path, progress + 0.05, speed, _pick_model(prefer), -0.22)


## Köşelerde ani dönüş olmasın: her köşeye yay tutamakları.
func _round_corners(curve: Curve3D) -> void:
	for i in range(1, curve.point_count - 1):
		var prev := curve.get_point_position(i - 1)
		var here := curve.get_point_position(i)
		var next := curve.get_point_position(i + 1)
		var r := minf(0.5, minf(prev.distance_to(here), here.distance_to(next)) * 0.3)
		curve.set_point_in(i, (prev - here).normalized() * r)
		curve.set_point_out(i, (next - here).normalized() * r)


func _add_walker(path: Path3D, progress: float, speed: float, file: String, lateral: float) -> void:
	var follow := PathFollow3D.new()
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	follow.loop = true
	follow.h_offset = lateral
	path.add_child(follow)
	follow.progress = progress
	var body := _make_character(file, _rng.randi())
	body.rotation.y = PI  # model +z'ye bakar, PathFollow3D ileri yönü -z
	follow.add_child(body)
	var player: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
	player.play("Walk")
	player.seek(_rng.randf() * 1.25, true)  # herkes aynı adım fazında olmasın
	player.speed_scale = speed / WALK_SPEED
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lane_key := "%s|%.2f" % [path.name, lateral]
	if not _lanes.has(lane_key):
		_lanes[lane_key] = []
	_walkers.append({"follow": follow, "speed": speed, "body": body, "player": player, "tier": -1, "acc": 0.0, "walking": true,
		"meshes": body.find_children("*", "MeshInstance3D", true, false)})
	_lanes[lane_key].append(_walkers[-1])
	(_lanes[lane_key] as Array).sort_custom(func(a, b): return (a.follow as PathFollow3D).progress < (b.follow as PathFollow3D).progress)


## Geçide girmek üzereyken (henüz girmemiş) geçitte araç varsa bekle.
func _must_wait(follow: PathFollow3D) -> bool:
	if _traffic == null:
		return false
	var crossings: Array = _traffic.get("crossings")
	var pos := follow.global_position
	var ahead := pos - follow.global_transform.basis.z * CROSSING_LOOK
	for i in crossings.size():
		var zone: Rect2 = crossings[i]
		if zone.has_point(Vector2(ahead.x, ahead.z)) and not zone.has_point(Vector2(pos.x, pos.z)) and _traffic.vehicle_in_zone(i):
			return true
	return false


## Beklerken Idle, yürürken Walk (kısa geçişle).
func _set_walking(w: Dictionary, value: bool) -> void:
	if w.walking == value:
		return
	w.walking = value
	var player: AnimationPlayer = w.player
	player.play("Walk" if value else "Idle", 0.25)


## Trafik sistemi için yürüyenlerin dünya konumları.
func walker_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_walkers.size())
	for i in _walkers.size():
		out[i] = (_walkers[i].follow as PathFollow3D).global_position
	return out


# --- Oturan ve bekleyenler ---

func _place_people(spots: Array) -> void:
	var baked := Node3D.new()
	baked.name = "Baked"
	add_child(baked)
	var tools := {}
	var stand_spots: Array = []
	for spot: Dictionary in spots:
		if spot.pose == &"stand":
			stand_spots.append(spot)
	# Kameraya (başlangıç görünümü) en yakın bekleyenler canlı Idle animasyonu oynar.
	var rig := get_node_or_null(camera_rig_path) as Node3D
	var focus := rig.global_position if rig else Vector3.ZERO
	stand_spots.sort_custom(func(a, b): return a.position.distance_to(focus) < b.position.distance_to(focus))
	var live := stand_spots.slice(0, MAX_LIVE_IDLE)
	for spot: Dictionary in spots:
		var look: Array = spot.look
		var file: String = CHARACTERS.keys()[look[0] % CHARACTERS.size()]
		if spot.pose == &"sit" and CHARACTERS[file] == &"sport":
			file = "qt_old_classy_male"
		var body := _make_character(file, look[1] + look[2])
		var basis := Basis(Vector3.UP, spot.yaw)
		var pos: Vector3 = spot.position
		if spot.pose == &"sit":
			pos += basis * Vector3(0, 0, SIT_FORWARD)
		add_child(body)
		body.global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * SCALE), pos)
		var player: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
		if spot in live:
			player.play("Idle")
			player.seek(_rng.randf() * 4.0, true)
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			_idlers.append({"body": body, "player": player, "tier": -1, "acc": 0.0,
				"meshes": body.find_children("*", "MeshInstance3D", true, false)})
			continue
		if spot.pose == &"sit":
			player.play("SitDown")
			player.seek(SIT_POSE_TIME, true)
		else:
			player.play("Idle")
			player.seek(_rng.randf() * 4.0, true)
		_bake(body, tools)
		body.free()
	for material in tools:
		var mesh := ArrayMesh.new()
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(0, material)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		baked.add_child(instance)


## Karakteri o anki iskelet pozunda statik mesh'e çevirip malzeme başına birleştirir (çok az draw call).
func _bake(body: Node3D, tools: Dictionary) -> void:
	var skeleton: Skeleton3D = body.find_child("Skeleton3D", true, false)
	skeleton.force_update_all_bone_transforms()
	for mesh_instance: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		var posed := mesh_instance.bake_mesh_from_current_skeleton_pose()
		var xform := global_transform.affine_inverse() * mesh_instance.global_transform
		for s in posed.get_surface_count():
			var material := mesh_instance.get_surface_override_material(s)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(s)
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
			(tools[material] as SurfaceTool).append_from(posed, s, xform)


# --- Karakter kurulumu ---

func _pick_model(prefer: StringName) -> String:
	var files: Array = CHARACTERS.keys()
	if prefer != &"" and _rng.randf() < 0.45:
		var matching := files.filter(func(f): return CHARACTERS[f] == prefer)
		if not matching.is_empty():
			return matching[_rng.randi() % matching.size()]
	return files[_rng.randi() % files.size()]


## Model + kişiye özgü renkler (ten, gömlek, pantolon / takım, saç). Çarpışma şekli yok.
func _make_character(file: String, look: int) -> Node3D:
	var body: Node3D = _scenes[file].instantiate()
	body.scale = Vector3.ONE * SCALE
	var role: StringName = CHARACTERS[file]
	var pick := func(list: Array, salt: int) -> Color:
		return list[absi(hash(look + salt * 7919)) % list.size()]
	for mesh_instance: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(s)
			var slot := source.resource_name if source else ""
			var color: Variant = null
			match slot:
				"Skin":
					color = pick.call(SKIN_TONES, 1)
				"Shirt":
					color = pick.call(SHIRT_COLORS, 2)
				"Pants":
					color = pick.call(TROUSER_COLORS, 3)
				"Black":
					color = pick.call(SUIT_COLORS, 4)
				"Hair":
					color = pick.call(HAIR_ELDER if role == &"elder" else HAIR_COLORS, 5)
			if color != null:
				mesh_instance.set_surface_override_material(s, _material(color))
	return body


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


## İçe aktarılan animasyonlar döngüsüz gelir; Walk ve Idle döngüye alınır (sahne kaynağı paylaşıldığı için bir kez).
func _prepare_animations(scene: PackedScene) -> void:
	var probe := scene.instantiate()
	var player: AnimationPlayer = probe.find_child("AnimationPlayer", true, false)
	for anim_name in ["Walk", "Idle"]:
		var anim := player.get_animation(anim_name)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
	probe.free()


# --- Animasyon LOD ---

func _update_lod() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var eye := camera.global_position
	for actor in _walkers + _idlers:
		var pos: Vector3 = (actor.body as Node3D).global_position + Vector3(0, 0.4, 0)
		var dist := eye.distance_to(pos)
		var tier := 2
		if camera.is_position_in_frustum(pos) and dist <= MID_RANGE:
			tier = 0 if dist < NEAR_RANGE else 1
		if tier != actor.tier:
			# Gölge yalnızca yakındakilerde (orta uzaklıkta gölge birkaç piksel; gölge geçişindeki draw call'ları azaltır).
			for mesh_instance: MeshInstance3D in actor.meshes:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.tier = tier


## Animasyonu elle ilerletir: yakın her kare, orta 15 Hz (birikmiş süreyle, hız aynı kalır), uzak hiç.
func _advance(actor: Dictionary, delta: float) -> void:
	if actor.tier == 2 or actor.tier < 0:
		return
	actor.acc += delta
	if actor.tier == 0 or actor.acc >= MID_RATE:
		(actor.player as AnimationPlayer).advance(actor.acc)
		actor.acc = 0.0
