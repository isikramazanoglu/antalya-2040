extends Node3D
## Sahip: A. Prompt A14 · Sanayi yerleri ve işletme görselleri (yalnızca görsel; işletme kurma, emisyon, ceza,
## denetim, kredi B'nin BusinessSimulator / GameController'ında). GameState'e yazmaz, hesap yapmaz.
## - Sanayi yerleri I01–I08: kuzeydeki sanayi şeridi (oyuncu arsalarının ve rezervuarın ötesinde), 6 × 6 beton saha.
## - EventBus v1.10: business_spawned → model; business_updated → duman / ışık / yükseltme / uyarı; business_removed → kaldır.
##   Aynı business_id için ikinci model kurulmaz; restored ise büyüme animasyonu yok.
## - Duman yalnızca smoke_intensity'den: yoğunluk 0 ya da askıda → duman yok (askıda ışıklar da sönük);
##   filtre → açık, beyaz, ince duman; violation_level ≥ 3 → kırmızı uyarı işareti.
## - 10 işletme türü 3 modele eşlenir (MODEL_FOR_VISUAL); tür adı data/businesses/*.tres → visual_id.

const SITE_SIZE := 6.0
const SITE_Z := -34.5
## Sanayi yerleri (x, z). Rezervuar Rect2(-6, -45, 12, 10) ve O arsaları (z -28..-20) dışında; açılış kamerasında görünür.
const SITES := {
	&"I01": Vector2(-39, SITE_Z), &"I02": Vector2(-30, SITE_Z), &"I03": Vector2(-21, SITE_Z), &"I04": Vector2(-12, SITE_Z),
	&"I05": Vector2(12, SITE_Z), &"I06": Vector2(21, SITE_Z), &"I07": Vector2(30, SITE_Z), &"I08": Vector2(39, SITE_Z),
}
const MODELS := {
	&"small_factory": "res://assets/industrial/small_factory.tscn",
	&"heavy_factory": "res://assets/industrial/heavy_factory.tscn",
	&"logistics_warehouse": "res://assets/industrial/logistics_warehouse.tscn",
}
## B'nin visual_id'leri → model. Eşleşmeyen / bilinmeyen visual_id küçük fabrikaya düşer.
const MODEL_FOR_VISUAL := {
	&"Industrial_SmallFactory": &"small_factory", &"Industrial_FoodFactory": &"small_factory",
	&"Industrial_TextilePlant": &"small_factory", &"Industrial_SmallWorkshop": &"small_factory",
	&"Industrial_HeavyFactory": &"heavy_factory", &"Industrial_ChemicalPlant": &"heavy_factory",
	&"Industrial_ConcretePlant": &"heavy_factory", &"Industrial_WasteFacility": &"heavy_factory",
	&"Industrial_LogisticsWarehouse": &"logistics_warehouse", &"Commercial_EnergyIntensive": &"logistics_warehouse",
}
const GROW_TIME := 0.7
## Beton sahanın üst yüzü; model bunun üstüne oturur.
const PAD_TOP := 0.08
const M_PAD := preload("res://assets/materials/concrete.tres")
const M_FENCE := preload("res://assets/materials/buildings/bld_metal_dark.tres")

## business_id → {node, site_id, info, smoke: [GPUParticles3D], sign: Label3D}
var _businesses := {}
var _smoke_texture: GradientTexture2D
var _dim_material: StandardMaterial3D


func _ready() -> void:
	_build_sites()
	_smoke_texture = _make_smoke_texture()
	_dim_material = StandardMaterial3D.new()
	_dim_material.albedo_color = Color(0.16, 0.18, 0.2)
	_dim_material.roughness = 0.4
	EventBus.business_spawned.connect(_on_business_spawned)
	EventBus.business_updated.connect(_on_business_updated)
	EventBus.business_removed.connect(_on_business_removed)
	# Sahne kayıttan sonra açıldıysa ve bildirimler bundan önce geldiyse: mevcut işletmeleri GameState'ten kur.
	_sync_from_state()


## Sanayi yerinin dünya merkezi (y = 0); bilinmeyen yer için Vector3.INF.
func site_position(site_id: StringName) -> Vector3:
	if not SITES.has(site_id):
		return Vector3.INF
	var p: Vector2 = SITES[site_id]
	return Vector3(p.x, 0.0, p.y)


## Test ve araçlar için: işletmenin görsel düğümü (yoksa null).
func get_business_node(business_id: StringName) -> Node3D:
	return _businesses[business_id].node if _businesses.has(business_id) else null


func get_business_smoke(business_id: StringName) -> Array:
	return _businesses[business_id].smoke if _businesses.has(business_id) else []


func business_count() -> int:
	return _businesses.size()


# --- Sinyaller ---

func _on_business_spawned(info: Dictionary) -> void:
	var id: StringName = info.get("business_id", &"")
	var site: StringName = info.get("site_id", &"")
	if id == &"" or not SITES.has(site):
		push_warning("Industry: işletme görseli kurulamadı (%s, yer %s)" % [id, site])
		return
	if _businesses.has(id):
		_apply(id, info)  # ikinci model kurulmaz; bilgi güncellenir
		return
	var model: StringName = MODEL_FOR_VISUAL.get(info.get("visual_id", &""), &"small_factory")
	var node: Node3D = (load(MODELS[model]) as PackedScene).instantiate()
	node.name = String(id)
	node.position = site_position(site) + Vector3(0, PAD_TOP, 0)
	add_child(node)
	var smoke := []
	for marker in node.get_children():
		if marker is Marker3D and marker.name.begins_with("Smoke_"):
			smoke.append(_make_smoke(marker))
	_businesses[id] = {"node": node, "site_id": site, "model": model, "info": {}, "smoke": smoke, "sign": null}
	_apply(id, info)
	if not info.get("restored", false):
		node.scale = Vector3(1.0, 0.02, 1.0)
		create_tween().tween_property(node, "scale", Vector3.ONE, GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_business_updated(info: Dictionary) -> void:
	var id: StringName = info.get("business_id", &"")
	if not _businesses.has(id):
		_on_business_spawned(info)  # güncelleme kurulumdan önce geldiyse
		return
	_apply(id, info)


func _on_business_removed(business_id: StringName, _site_id: StringName) -> void:
	if not _businesses.has(business_id):
		return
	var node: Node3D = _businesses[business_id].node
	_businesses.erase(business_id)
	if is_instance_valid(node):
		node.queue_free()


func _sync_from_state() -> void:
	var list = GameState.get("businesses")
	if not (list is Array) or (list as Array).is_empty():
		return
	for b in list:
		var t = BusinessSimulator.get_type(Catalog.data.business_types, b.business_type)
		var info: Dictionary = BusinessSimulator.visual_info(b, t, Catalog.data.balance)
		info["restored"] = true
		_on_business_spawned(info)


# --- Görsel durum ---

## Duman, ışıklar, yükseltmeler ve uyarı işareti bilgiden kurulur (hesap yok).
func _apply(id: StringName, info: Dictionary) -> void:
	var entry: Dictionary = _businesses[id]
	entry.info = info.duplicate()
	var node: Node3D = entry.node
	var active: bool = info.get("operational_status", &"active") == &"active"
	var intensity: float = clampf(float(info.get("smoke_intensity", 0.0)), 0.0, 1.0)
	var upgrades: Dictionary = info.get("upgrades", {})
	var filtered: bool = upgrades.get("filter", false)
	for p: GPUParticles3D in entry.smoke:
		_set_smoke(p, intensity if active else 0.0, filtered)
	var windows := node.get_node_or_null("Windows") as MeshInstance3D
	if windows:
		windows.material_override = null if active else _dim_material
	for key in ["clean_energy", "treatment"]:
		var extra := node.get_node_or_null("Upgrade_" + key) as Node3D
		if extra:
			extra.visible = upgrades.get(key, false)
	var warn: bool = int(info.get("violation_level", 0)) >= 3
	if warn and entry.sign == null:
		entry.sign = _make_sign(node)
	if entry.sign:
		(entry.sign as Label3D).visible = warn


## Duman seviyesi: 0 → kapalı; düşük → az ve açık; yüksek → yoğun ve koyu gri. Filtre: beyaz, ince, saydam.
func _set_smoke(p: GPUParticles3D, intensity: float, filtered: bool) -> void:
	p.emitting = intensity > 0.02
	p.amount_ratio = lerpf(0.25, 1.0, intensity)
	var pm := p.process_material as ParticleProcessMaterial
	var gray := 0.95 if filtered else lerpf(0.86, 0.38, intensity)
	var alpha := 0.35 if filtered else lerpf(0.45, 0.8, intensity)
	pm.color = Color(gray, gray, gray * 1.02, alpha)
	pm.scale_min = (0.35 if filtered else 0.45) + intensity * 0.2
	pm.scale_max = pm.scale_min + 0.3


## Baca dumanı: yukarı yükselir, rüzgârla doğuya kayar, büyür ve saydamlaşır. Işıktan etkilenmez, gölge düşürmez.
func _make_smoke(marker: Marker3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 4.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(14, 12, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.32, 0.12, 0.06)  # hafif rüzgâr + kaldırma
	pm.damping_min = 0.15
	pm.damping_max = 0.3
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.35))
	growth.add_point(Vector2(1.0, 2.6))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = growth
	pm.scale_curve = scale_tex
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.12, Color(1, 1, 1, 0.9))
	fade.add_point(0.55, Color(1, 1, 1, 0.5))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _smoke_texture
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	marker.add_child(p)
	return p


func _make_smoke_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## İhlal uyarısı: binanın üstünde kırmızı "!" (kameraya döner).
func _make_sign(node: Node3D) -> Label3D:
	var label := Label3D.new()
	label.name = "Warning"
	label.text = "!"
	label.font_size = 160
	label.outline_size = 36
	label.modulate = Color(0.95, 0.2, 0.15)
	label.outline_modulate = Color(1, 1, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	var top := 0.0
	var body := node.get_node_or_null("Body") as MeshInstance3D
	if body:
		top = body.mesh.get_aabb().end.y
	label.position = Vector3(0.4, top + 1.6, 1.8)  # bacaların önünde ve üstünde
	node.add_child(label)
	return label


# --- Sanayi şeridi zemini ---

## Decor (city_decor.gd) bu dikdörtgenlere ağaç / ekin koymaz.
static func blocked_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-43.0, SITE_Z + SITE_SIZE * 0.5 + 0.2, 86.0, 1.4)]
	for site in SITES:
		var p: Vector2 = SITES[site]
		out.append(Rect2(p.x - SITE_SIZE * 0.5, p.y - SITE_SIZE * 0.5, SITE_SIZE, SITE_SIZE).grow(0.8))
	return out


## Her yer için beton saha ve köşelerde çit direkleri; şeridin önünde servis yolu (yalnızca görsel).
func _build_sites() -> void:
	var pads := Node3D.new()
	pads.name = "Sites"
	add_child(pads)
	var road := MeshInstance3D.new()
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(84.0, 0.05, 1.2)
	road.mesh = road_mesh
	road.material_override = preload("res://assets/materials/city/road_local.tres")
	road.position = Vector3(0, 0.03, SITE_Z + SITE_SIZE * 0.5 + 0.9)
	pads.add_child(road)
	for site in SITES:
		var c := site_position(site)
		var pad := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(SITE_SIZE + 0.2, PAD_TOP, SITE_SIZE + 0.2)
		pad.mesh = pm
		pad.material_override = M_PAD
		pad.position = c + Vector3(0, PAD_TOP * 0.5, 0)
		pad.name = "Site_" + String(site)
		pads.add_child(pad)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.08, 0.5, 0.08)
				post.mesh = bm
				post.material_override = M_FENCE
				post.position = c + Vector3(sx * (SITE_SIZE * 0.5 + 0.05), 0.25, sz * (SITE_SIZE * 0.5 + 0.05))
				pads.add_child(post)
