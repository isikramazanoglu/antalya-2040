extends SceneTree
## Sahip: A. 12 bina modelinden yatırım kartı küçük resimlerini (320×220, şeffaf PNG) üretir.
## Çalıştırma: <godot> --path . --script res://scripts/world/dev/render_thumbnails.gd -- <çıktı klasörü>
## Çıktı `assets/ui/thumbnails/<id>.png` ile aynı adlarda; o klasör Ekip B'nindir, kopyalamayı B yapar.

const SIZE := Vector2i(320, 220)
const VIEW_PITCH := -32.0
const VIEW_YAW := 35.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("thumbnails")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 40, 0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)

	for def in root.get_node("Catalog").data.buildings:
		var building: Node3D = def.scene.instantiate()
		viewport.add_child(building)
		# Kadraj: arsa karesi + modelin yüksekliği (yüksek binaların çatısı kesilmesin).
		var footprint: float = building.footprint
		var height := 0.0
		for mesh in building.find_children("*", "MeshInstance3D", true, false):
			height = maxf(height, ((mesh as MeshInstance3D).transform * (mesh as MeshInstance3D).get_aabb()).end.y)
		camera.size = footprint * 1.02 + height * 0.42
		camera.rotation_degrees = Vector3(VIEW_PITCH, VIEW_YAW, 0)
		camera.position = Vector3(0, height * 0.45, 0) + camera.basis.z * 40.0
		for i in 3:
			await RenderingServer.frame_post_draw
		var path := out_dir.path_join("%s.png" % def.id)
		viewport.get_texture().get_image().save_png(path)
		print("küçük resim: ", path)
		building.queue_free()
		await process_frame
	quit()
