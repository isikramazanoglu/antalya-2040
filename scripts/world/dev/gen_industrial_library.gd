extends SceneTree
## Sahip: A. Prompt A14 · Endüstriyel işletme modelleri (Blender ya da harici model yok).
## Çıktı: assets/industrial/<model>.tscn — Body (gövde), Windows (ışıklı pencereler; askıda sönük), Smoke_* (baca ağzı
## işaretleri; duman industry.gd'de), Upgrade_clean_energy (çatı güneş paneli), Upgrade_treatment (arıtma tankı).
## Ölçek: 1 birim ≈ 2,3 m; sanayi yeri 6 × 6; pivot taban merkezi (y = 0), ön cephe +z.
## Çalıştırma: <godot> --headless --path . --script res://scripts/world/dev/gen_industrial_library.gd

const PALETTE := {
	"wall_light": [Color(0.8, 0.81, 0.82), 0.6, 0.25],
	"wall_dark": [Color(0.42, 0.45, 0.48), 0.6, 0.3],
	"concrete": [Color(0.78, 0.75, 0.68), 0.9, 0.0],
	"brick": [Color(0.66, 0.4, 0.31), 0.9, 0.0],
	"roof_metal": [Color(0.56, 0.59, 0.62), 0.45, 0.5],
	"door": [Color(0.66, 0.68, 0.7), 0.5, 0.4],
	"door_line": [Color(0.36, 0.38, 0.4), 0.6, 0.3],
	"glass": [Color(0.42, 0.6, 0.66), 0.15, 0.3],
	"accent_teal": [Color(0.24, 0.55, 0.58), 0.5, 0.2],
	"accent_orange": [Color(0.88, 0.5, 0.18), 0.5, 0.1],
	"stripe_red": [Color(0.75, 0.16, 0.12), 0.6, 0.0],
	"stripe_white": [Color(0.94, 0.94, 0.92), 0.6, 0.0],
	"pipe": [Color(0.62, 0.64, 0.66), 0.35, 0.7],
	"dark": [Color(0.18, 0.19, 0.2), 0.8, 0.1],
	"yard": [Color(0.5, 0.5, 0.49), 0.95, 0.0],
	"solar": [Color(0.12, 0.2, 0.34), 0.3, 0.5],
	"water": [Color(0.3, 0.55, 0.6), 0.1, 0.2],
	"window_light": [Color(1.0, 0.86, 0.55), 0.4, 0.0],
}

var mats := {}
var tools := {}
var BOX := BoxMesh.new()
var CYL := CylinderMesh.new()
var CONE := CylinderMesh.new()


func _initialize() -> void:
	CYL.top_radius = 0.5
	CYL.bottom_radius = 0.5
	CYL.height = 1.0
	CYL.radial_segments = 14
	CYL.rings = 0
	CONE.top_radius = 0.0
	CONE.bottom_radius = 0.5
	CONE.height = 1.0
	CONE.radial_segments = 14
	CONE.rings = 0
	_save_palette()
	var models := {"small_factory": _small_factory, "heavy_factory": _heavy_factory, "logistics_warehouse": _warehouse}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/industrial"))
	for model: String in models:
		var parts: Dictionary = models[model].call()  # {"smoke": [Vector3], "solar": Callable, "treatment": Callable}
		var root := Node3D.new()
		root.name = model.to_pascal_case()
		_add_mesh(root, "Body", parts.body)
		_add_mesh(root, "Windows", parts.windows)
		for k in parts.optional:
			var node := _add_mesh(root, k, parts.optional[k])
			node.visible = false
		var i := 0
		for p: Vector3 in parts.smoke:
			var marker := Marker3D.new()
			marker.name = "Smoke_%d" % i
			marker.position = p
			root.add_child(marker)
			marker.owner = root
			i += 1
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene, "res://assets/industrial/%s.tscn" % model)
		var aabb: AABB = parts.body.get_aabb()
		print("%-22s taban %.1f x %.1f  yükseklik %.1f  baca %d" % [model, aabb.size.x, aabb.size.z, aabb.end.y, parts.smoke.size()])
		root.free()
	quit()


func _add_mesh(root: Node3D, node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var path := "res://assets/industrial/%s_%s.tres" % [root.name.to_snake_case(), node_name.to_snake_case()]
	ResourceSaver.save(mesh, path)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = load(path)
	root.add_child(mi)
	mi.owner = root
	return mi


func _save_palette() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/industrial/materials"))
	for key: String in PALETTE:
		var p: Array = PALETTE[key]
		var m := StandardMaterial3D.new()
		m.resource_name = "ind_" + key
		m.albedo_color = p[0]
		m.roughness = p[1]
		m.metallic = p[2]
		if key == "window_light":
			m.emission_enabled = true
			m.emission = p[0]
			m.emission_energy_multiplier = 0.6
		var path := "res://assets/industrial/materials/ind_%s.tres" % key
		ResourceSaver.save(m, path)
		mats[key] = load(path)


## Geçerli araç takımını ArrayMesh'e çevirip takımı sıfırlar (bir sahnede birden çok mesh için).
func _take() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key: String in tools:
		(tools[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	tools.clear()
	return mesh


func _st(m: String) -> SurfaceTool:
	if not tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[m] = st
	return tools[m]


## İlkel mesh'i indekssiz üçgen olarak ekler (aynı yüzeyde elle üçgenle karışmasın diye; araç üreticisiyle aynı).
func _append(m: String, mesh: PrimitiveMesh, xform: Transform3D) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nbasis := xform.basis.inverse().transposed()
	var st := _st(m)
	var order := indices if indices.size() > 0 else PackedInt32Array(range(verts.size()))
	for i in order:
		var n := (nbasis * normals[i]).normalized()
		st.set_normal(n)
		st.set_tangent(Plane(n.cross(Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT).normalized(), 1.0))
		st.set_uv(uvs[i] if uvs.size() > i else Vector2.ZERO)
		st.add_vertex(xform * verts[i])


func box(m: String, c: Vector3, s: Vector3, rot := Vector3.ZERO) -> void:
	_append(m, BOX, Transform3D(Basis.from_euler(rot) * Basis.from_scale(s), c))


func cyl(m: String, c: Vector3, r: float, h: float, axis := "y") -> void:
	var rot := Vector3.ZERO
	if axis == "x":
		rot = Vector3(0, 0, PI * 0.5)
	elif axis == "z":
		rot = Vector3(PI * 0.5, 0, 0)
	_append(m, CYL, Transform3D(Basis.from_euler(rot) * Basis.from_scale(Vector3(r * 2, h, r * 2)), c))


func cone(m: String, c: Vector3, r: float, h: float) -> void:
	_append(m, CONE, Transform3D(Basis.from_scale(Vector3(r * 2, h, r * 2)), c))


# --- Ortak parçalar ---

## Kepenkli sanayi kapısı (ön +z yüzünde): kasa, kepenk, yatay çizgiler, üstte uyarı şeridi.
func roll_door(x: float, z: float, w: float, h: float) -> void:
	box("dark", Vector3(x, (h + 0.08) * 0.5, z + 0.005), Vector3(w + 0.1, h + 0.08, 0.02))
	box("door", Vector3(x, h * 0.5, z + 0.015), Vector3(w, h, 0.02))
	for k in int(h / 0.08):
		box("door_line", Vector3(x, 0.05 + k * 0.08, z + 0.027), Vector3(w - 0.02, 0.012, 0.005))
	box("accent_orange", Vector3(x, h + 0.07, z + 0.02), Vector3(w + 0.1, 0.05, 0.02))


## Kırmızı-beyaz bantlı baca; ağız yüksekliği döndürülür (duman işareti).
func chimney(x: float, z: float, base_y: float, h: float, r: float) -> Vector3:
	cyl("concrete", Vector3(x, base_y + h * 0.5, z), r, h)
	for k in 3:
		var y := base_y + h - 0.18 - k * 0.42
		cyl("stripe_red" if k % 2 == 0 else "stripe_white", Vector3(x, y, z), r + 0.01, 0.2)
	cyl("dark", Vector3(x, base_y + h + 0.03, z), r * 0.8, 0.06)
	return Vector3(x, base_y + h + 0.06, z)


## Pencere bandı (ışıklı yüzey ayrı mesh'te toplanır: windows=true).
func window_row(x0: float, x1: float, y: float, z: float, n: int, w: float, h: float) -> void:
	for i in n:
		var x := lerpf(x0, x1, (i + 0.5) / n)
		box("dark", Vector3(x, y, z + 0.005), Vector3(w + 0.05, h + 0.05, 0.015))
		box("window_light", Vector3(x, y, z + 0.013), Vector3(w, h, 0.01))


func vent(c: Vector3) -> void:
	box("roof_metal", c + Vector3(0, 0.08, 0), Vector3(0.22, 0.16, 0.22))
	cyl("pipe", c + Vector3(0, 0.2, 0), 0.08, 0.08)


func solar_panels(cx: float, cz: float, y: float, w: float, d: float) -> void:
	var cols := int(w / 0.55)
	var rows := int(d / 0.45)
	for i in cols:
		for j in rows:
			box("solar", Vector3(cx - w * 0.5 + (i + 0.5) * w / cols, y + 0.07, cz - d * 0.5 + (j + 0.5) * d / rows),
				Vector3(w / cols - 0.06, 0.03, d / rows - 0.06), Vector3(deg_to_rad(-18), 0, 0))


func treatment_tank(c: Vector3) -> void:
	cyl("concrete", c + Vector3(0, 0.15, 0), 0.6, 0.3)
	cyl("water", c + Vector3(0, 0.31, 0), 0.52, 0.02)
	box("pipe", c + Vector3(0.75, 0.15, 0), Vector3(0.5, 0.06, 0.06))


# --- Modeller: {body, windows, optional {Upgrade_*: mesh}, smoke [Vector3]} ---

## Küçük üretim fabrikası: testere dişli çatılı üretim holü (kuzey camları), önde iki katlı ofis, kepenkli kapı,
## tek bant boyalı baca, çatı havalandırmaları, yan yük alanı.
func _small_factory() -> Dictionary:
	var hall_w := 3.6
	var hall_d := 3.0
	var hz := -0.5
	var h := 1.5
	box("yard", Vector3(0, 0.02, 0.2), Vector3(5.6, 0.04, 5.2))
	box("wall_light", Vector3(0, h * 0.5, hz), Vector3(hall_w, h, hall_d))
	box("accent_teal", Vector3(0, 0.12, hz), Vector3(hall_w + 0.02, 0.24, hall_d + 0.02))
	# Testere dişli çatı: üç diş, dik yüzler cam (kuzey).
	for k in 3:
		var z := hz - hall_d * 0.5 + (k + 0.5) * hall_d / 3.0
		box("roof_metal", Vector3(0, h + 0.28, z + 0.05), Vector3(hall_w + 0.1, 0.06, 1.12), Vector3(deg_to_rad(28), 0, 0))
		box("glass", Vector3(0, h + 0.28, z - 0.47), Vector3(hall_w, 0.5, 0.03))
	roll_door(0.9, hz + hall_d * 0.5, 1.0, 0.95)
	window_row(-1.6, -0.4, 1.1, hz + hall_d * 0.5, 3, 0.26, 0.3)
	# Ofis (öne çıkık, iki kat) ve giriş saçağı.
	box("concrete", Vector3(-1.05, 0.7, 1.4), Vector3(1.5, 1.4, 0.8))
	box("dark", Vector3(-1.05, 1.42, 1.4), Vector3(1.56, 0.05, 0.86))
	window_row(-1.7, -0.4, 0.45, 1.8, 3, 0.28, 0.3)
	window_row(-1.7, -0.4, 1.05, 1.8, 3, 0.28, 0.3)
	box("glass", Vector3(-1.05, 0.0 + 0.35, 1.81), Vector3(0.3, 0.6, 0.01))
	box("accent_teal", Vector3(-1.05, 0.72, 1.98), Vector3(0.6, 0.04, 0.35))
	for p: Vector3 in [Vector3(-0.8, h + 0.55, -1.4), Vector3(0.6, h + 0.55, -1.4)]:
		vent(p)
	var smoke := chimney(1.55, -1.75, 0.0, 3.0, 0.17)
	# Yük alanı: palet yığınları.
	for k in 3:
		box("door_line" if k % 2 == 0 else "accent_orange", Vector3(2.35, 0.1 + k * 0.0, 0.6 + k * 0.32), Vector3(0.3, 0.2, 0.26))
	var body := _take_body()
	window_row(-1.6, -0.4, 1.1, hz + hall_d * 0.5, 3, 0.26, 0.3)
	window_row(-1.7, -0.4, 0.45, 1.8, 3, 0.28, 0.3)
	window_row(-1.7, -0.4, 1.05, 1.8, 3, 0.28, 0.3)
	var windows := _windows_only()
	solar_panels(0, hz, h + 0.38, hall_w - 0.4, hall_d - 0.4)
	var solar := _take()
	treatment_tank(Vector3(2.1, 0, -1.6))
	var tank := _take()
	return {"body": body, "windows": windows, "optional": {"Upgrade_clean_energy": solar, "Upgrade_treatment": tank}, "smoke": [smoke]}


## Ağır sanayi tesisi: yüksek tuğla ana bina, yan çelik hol, iki büyük bantlı baca, iki silo (konik başlık),
## borular ve eğik konveyör; geniş kepenk.
func _heavy_factory() -> Dictionary:
	box("yard", Vector3(0, 0.02, 0), Vector3(5.8, 0.04, 5.8))
	box("brick", Vector3(-0.6, 1.25, -0.6), Vector3(3.0, 2.5, 3.0))
	box("dark", Vector3(-0.6, 2.53, -0.6), Vector3(3.1, 0.06, 3.1))
	box("wall_dark", Vector3(1.6, 0.9, 0.2), Vector3(1.6, 1.8, 3.6))
	box("roof_metal", Vector3(1.6, 1.85, 0.2), Vector3(1.7, 0.1, 3.7), Vector3(0, 0, deg_to_rad(-6)))
	roll_door(1.6, 2.0, 1.1, 1.25)
	roll_door(-0.6, 0.9, 1.4, 1.4)
	window_row(-1.9, 0.7, 1.95, 0.9, 5, 0.32, 0.42)
	var smoke := [chimney(-1.4, -1.5, 2.5, 3.2, 0.3), chimney(-0.1, -1.5, 2.5, 2.6, 0.24)]
	for p: Vector3 in [Vector3(-1.6, 0, 2.0), Vector3(-0.7, 0, 2.0)]:
		cyl("wall_light", p + Vector3(0, 0.9, 0), 0.38, 1.8)
		cone("roof_metal", p + Vector3(0, 2.0, 0), 0.4, 0.4)
		box("pipe", p + Vector3(0, 1.0, -0.5), Vector3(0.08, 0.08, 0.6))
	box("pipe", Vector3(0.6, 2.2, -1.5), Vector3(1.4, 0.1, 0.1))
	cyl("pipe", Vector3(1.3, 1.2, -1.5), 0.06, 2.0)
	box("accent_orange", Vector3(2.3, 1.1, -1.4), Vector3(0.18, 0.06, 2.4), Vector3(deg_to_rad(-30), 0, 0))
	var body := _take_body()
	window_row(-1.9, 0.7, 1.95, 0.9, 5, 0.32, 0.42)
	var windows := _windows_only()
	solar_panels(1.6, 0.2, 1.88, 1.4, 3.3)
	var solar := _take()
	treatment_tank(Vector3(2.0, 0, 2.2))
	var tank := _take()
	return {"body": body, "windows": windows, "optional": {"Upgrade_clean_energy": solar, "Upgrade_treatment": tank}, "smoke": smoke}


## Lojistik deposu: uzun alçak depo, hafif eğimli çatı, dört yükleme rampası (saçak, tampon), köşede camlı ofis,
## çatıda havalandırma bacası (hafif egzoz), önde geniş beton saha.
func _warehouse() -> Dictionary:
	var w := 5.2
	var d := 3.0
	var h := 1.35
	var z0 := -1.0
	box("yard", Vector3(0, 0.02, 0.0), Vector3(5.9, 0.04, 5.8))
	box("wall_light", Vector3(0, h * 0.5, z0), Vector3(w, h, d))
	box("accent_teal", Vector3(0, h - 0.12, z0), Vector3(w + 0.02, 0.18, d + 0.02))
	box("roof_metal", Vector3(0, h + 0.08, z0), Vector3(w + 0.12, 0.08, d + 0.12), Vector3(deg_to_rad(4), 0, 0))
	var front := z0 + d * 0.5
	for i in 4:
		var x := -1.9 + i * 1.05
		box("concrete", Vector3(x, 0.15, front + 0.2), Vector3(0.9, 0.3, 0.4))
		roll_door(x, front, 0.7, 0.8)
		box("dark", Vector3(x, 1.0, front + 0.25), Vector3(0.95, 0.04, 0.5), Vector3(deg_to_rad(-8), 0, 0))
		for s: float in [-1.0, 1.0]:
			box("dark", Vector3(x + s * 0.3, 0.2, front + 0.42), Vector3(0.08, 0.12, 0.06))
	box("glass", Vector3(2.3, 0.6, front + 0.01), Vector3(0.5, 0.9, 0.02))
	window_row(1.9, 2.5, 1.05, front + 0.01, 2, 0.22, 0.2)
	for p: Vector3 in [Vector3(-1.6, h + 0.12, z0), Vector3(0.0, h + 0.12, z0), Vector3(1.6, h + 0.12, z0)]:
		vent(p)
	var smoke := chimney(2.1, -2.0, h + 0.1, 0.9, 0.11)
	# Saha çizgileri.
	for k in 5:
		box("stripe_white", Vector3(-2.2 + k * 1.1, 0.045, 1.6), Vector3(0.04, 0.01, 1.2))
	var body := _take_body()
	window_row(1.9, 2.5, 1.05, front + 0.01, 2, 0.22, 0.2)
	var windows := _windows_only()
	solar_panels(0, z0, h + 0.14, w - 0.6, d - 0.5)
	var solar := _take()
	treatment_tank(Vector3(-2.3, 0, 1.8))
	var tank := _take()
	return {"body": body, "windows": windows, "optional": {"Upgrade_clean_energy": solar, "Upgrade_treatment": tank}, "smoke": [smoke]}


## Yalnızca ışıklı cam yüzeyleri tutar (çerçeveler gövdede kaldı).
func _windows_only() -> ArrayMesh:
	for key in tools.keys():
		if key != "window_light":
			tools.erase(key)
	return _take()


## Gövde: ışıklı camlar ayrı mesh'te (Windows) olsun diye gövdeden çıkarılır.
func _take_body() -> ArrayMesh:
	tools.erase("window_light")
	return _take()
