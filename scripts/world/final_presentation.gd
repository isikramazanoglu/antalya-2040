class_name FinalPresentation
extends Node
## Sahip: A. Final şehir sunumu (Prompt 10B, docs/FINAL_VISUAL_CONTRACT.md). CityWorld'ün çocuğudur.
## final_presentation_requested(summary) ile başlar, dört sahne oynatır ve final_presentation_finished yayar:
##   1. 2040: binasız başlangıç şehri, genel görünüm.
##   2. Dönüşüm: yatırımlar inşa yılı sırasıyla (city_2052.builds) belirir; geçmiş krizler kısa tekrar
##      (GameState.crisis_log, koruma oranı Ekip B'nin değeri).
##   3. 2052: son yerleşim (city_2052.plots), kıyı / yeşil alan / altyapı / kent merkezi kamera turu.
##   4. Karşılaştırma: aynı açıdan 2040 görüntüsü ile canlı 2052 şehri arasında kayan perde.
## Yalnızca görsel: GameState'e yazmaz, puan ya da hasar hesaplamaz; gösterilen sayılar summary'den okunur.
## Sunum B'nin arayüzünün üstündeki kendi katmanında, aynı 3D dünyayı gösteren ayrı bir SubViewport'ta
## tam ekran çizilir; bu sürede ana görünümün 3D çizimi kapalıdır (şehir iki kez çizilmez).
## Esc (cancel) sunumu atlar. Toplam süre ~1 dakika (B'nin 120 sn yedeğinin altında).

## Sunum bitti (atlanınca da). EventBus.final_presentation_finished ile aynı anda.
signal finished

const OVERLAY_LAYER := 50
const UI_THEME := preload("res://assets/ui/theme.tres")
const WIPE_SHADER := preload("res://assets/shaders/compare_wipe.gdshader")
## 2040 ve 2052 aynı açıdan gösterilir.
const OVERVIEW := {"position": Vector3(-1.0, 0.0, -4.0), "zoom": 92.0, "yaw": 0.0}
const CLOSE_ZOOM := 34.0
const CRISIS_ZOOM := 62.0
## Dönüşüm sahnesinde yatırımların toplam süresi; yatırım başına süre bu bütçeden bölünür.
const BUILD_TIME_BUDGET := 20.0
const BUILD_DWELL_MIN := 1.3
const BUILD_DWELL_MAX := 2.4
const CRISIS_DWELL := 3.2
const CRISIS_FADE := 0.8
const REGION_HOLD := 3.4
const STEPS: Array[String] = ["2040", "Dönüşüm", "2052", "Karşılaştırma"]
const CATEGORY_NAMES := {
	&"energy": "Enerji", &"water": "Su", &"heat": "Sıcağa uyum", &"food": "Gıda",
	&"waste": "Atık", &"transport": "Ulaşım", &"coast": "Kıyı",
}
## 2052 kamera turunun bölgeleri (sırasıyla).
const REGIONS := [
	{"id": &"coast", "title": "Kıyı", "caption": "Restore edilen kıyı ekosistemi ve erken uyarı altyapısı taşkına karşı ilk savunma hattı."},
	{"id": &"green", "title": "Gölge ve yeşil alanlar", "caption": "Parklar ve serinleme merkezleri sıcak hava dalgalarında şehri serin tutar."},
	{"id": &"infra", "title": "Enerji, su ve gıda", "caption": "Kuzeydeki açık alanlarda yenilenebilir enerji, su güvenliği ve dayanıklı tarım."},
	{"id": &"center", "title": "Kent merkezi", "caption": "Verimli binalar, gıda kurtarma ve düşük emisyonlu ulaşım."},
]

var _city: Node3D
var _rig: CameraRig
var _fx: DisasterFX
var _playing := false
var _ending := false
var _token := 0
var _saved_view: Dictionary
var _saved_fades := Vector2.ZERO
var _replayed: Array[CrisisEffect] = []
var _image_2040: ImageTexture
var _fade_tween: Tween

var _layer: CanvasLayer
## Sunum görüntüsü: SubViewport'un dokusu tam ekran. SubViewport pencerenin gerçek piksel boyutunda çizer
## (proje 1920x1080 tabanla ölçeklendiği için kapsayıcıyla gerilen görünüm 720p'de 2,25 kat fazla piksel çiziyordu).
var _view: TextureRect
var _viewport: SubViewport
var _camera: Camera3D
var _before: TextureRect
var _divider: ColorRect
var _tag_before: Label
var _tag_after: Label
var _year: Label
var _title: Label
var _caption: Label
var _steps: Label
var _fade: ColorRect


func _ready() -> void:
	_city = get_parent()
	_build_overlay()
	set_process(false)


func _exit_tree() -> void:
	if _playing:
		_restore()


func is_playing() -> bool:
	return _playing


## Sözleşme v1.9 final_presentation_requested. Eksik veride sunum atlanır ve hemen bitiş yayılır.
func play(summary: Dictionary) -> void:
	if _playing:
		return
	var city_2052 = summary.get("city_2052")
	if not (city_2052 is Dictionary and city_2052.get("plots") is Dictionary):
		push_warning("FinalPresentation: summary.city_2052 yok, sunum atlandı")
		_announce_finished.call_deferred()
		return
	_rig = _city.get_camera_rig()
	_fx = _city.get_disaster_fx()
	_playing = true
	_token += 1
	_run(summary, _token)


## Esc ya da dışarıdan çağrı: sunumu kısa bir kararmayla bitirir.
func skip() -> void:
	if _playing and not _ending:
		_end(0.35)


func _input(event: InputEvent) -> void:
	if _playing and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		skip()


func _process(_delta: float) -> void:
	_sync_camera()
	var width := _before.size.x
	var split: float = (_before.material as ShaderMaterial).get_shader_parameter("split")
	_divider.position.x = split * width - 2.0
	_tag_before.position.x = split * width - _tag_before.size.x - 24.0
	_tag_after.position.x = split * width + 24.0


# --- Sahneler ---

func _run(summary: Dictionary, token: int) -> void:
	var city_2052: Dictionary = summary.city_2052
	var final_plots: Dictionary = city_2052.plots
	var start_plots: Dictionary = {}
	var city_2040 = summary.get("city_2040", {})
	if city_2040 is Dictionary and city_2040.get("plots") is Dictionary:
		start_plots = city_2040.plots
	var builds := _sorted_builds(city_2052.get("builds", []))
	var timeline := _timeline(builds, GameState.crisis_log)

	# Hazırlık (karanlıkta): kamera ve şehir 2040 hâline, 2040 görüntüsü saklanır.
	_layer.visible = true
	_fade.color.a = 0.0
	_tween_fade(1.0, 0.5)
	if not await _hold(0.5, token):
		return
	_setup(start_plots)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not _alive(token):
		return
	_image_2040 = ImageTexture.create_from_image(_viewport.get_texture().get_image())

	# 1 · 2040
	_show_step(0)
	_set_texts("2040", "Başlangıç", "Akdeniz kıyısında Antalya. Henüz hiçbir iklim yatırımı yapılmadı.")
	_rig.glide_to(OVERVIEW.position, OVERVIEW.zoom - 8.0, 6.0, 5.5)
	_tween_fade(0.0, 0.8)
	if not await _hold(4.6, token):
		return

	# 2 · Dönüşüm
	_show_step(1)
	var build_count := builds.size()
	var dwell := clampf(BUILD_TIME_BUDGET / maxi(build_count, 1), BUILD_DWELL_MIN, BUILD_DWELL_MAX)
	if builds.is_empty():
		_set_texts("2040–2052", "Dönüşüm", "Bu dönemde yatırım yapılmadı; şehir 2040'taki gibi kaldı.")
		if not await _hold(3.0, token):
			return
	for item in timeline:
		if item.type == &"build":
			if not await _play_build(item, dwell, token):
				return
		elif not await _play_crisis(item, token):
			return

	# 3 · 2052
	_show_step(2)
	_city.show_city_state(final_plots, true)
	_set_texts("2052", "Dönüşen şehir", _result_line(summary, final_plots.size()))
	_rig.glide_to(OVERVIEW.position, OVERVIEW.zoom, 0.0, 2.4)
	if not await _hold(3.0, token):
		return
	for region in _regions(final_plots):
		_set_texts("2052", region.title, region.caption)
		_rig.glide_to(region.center, region.zoom, region.yaw, 2.2)
		if not await _hold(REGION_HOLD, token):
			return
	_set_texts("2052", "Dönüşen şehir", _result_line(summary, final_plots.size()))
	_rig.glide_to(OVERVIEW.position, OVERVIEW.zoom, 0.0, 2.4)
	if not await _hold(2.6, token):
		return

	# 4 · Karşılaştırma: aynı açı, 2040 görüntüsü canlı 2052 şehrinin üstünde, perde sağdan sola açılır.
	_show_step(3)
	_rig.set_view(OVERVIEW, true)
	_sync_camera()
	_before.texture = _image_2040
	var wipe := _before.material as ShaderMaterial
	wipe.set_shader_parameter("split", 1.0)
	_before.visible = true
	_divider.visible = true
	_tag_before.visible = true
	_tag_after.visible = true
	_set_texts("2040 ↔ 2052", "Aynı şehir, aynı açı", _result_line(summary, final_plots.size()))
	# 2052 tarafında yatırım yapılan arsalar hafifçe parlar; göz değişimi hemen bulur.
	for plot in _city.get_plots():
		if plot.is_occupied():
			plot.set_showcase(true)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.6)
	tween.tween_method(func(v: float): wipe.set_shader_parameter("split", v), 1.0, 0.0, 2.8)
	tween.tween_interval(0.5)
	tween.tween_method(func(v: float): wipe.set_shader_parameter("split", v), 0.0, 0.5, 1.4)
	if not await _hold(8.0, token):
		return
	_end(0.8)


## Yatırımın arsasına yaklaşılır ve bina inşa animasyonuyla belirir. false: sunum kesildi.
func _play_build(item: Dictionary, dwell: float, token: int) -> bool:
	var plot: BuildPlot = _city.find_plot(item.plot_id)
	var def := Catalog.get_building(item.building_id)
	if plot == null or def == null:
		push_warning("FinalPresentation: '%s' / '%s' sunumda atlandı" % [item.plot_id, item.building_id])
		return _alive(token)
	_set_texts(str(item.year), def.display_name, "%s · %s arsası" % [
		CATEGORY_NAMES.get(def.category, String(def.category)), item.plot_id])
	_rig.glide_to(plot.global_position, CLOSE_ZOOM + (plot.size - 6.0) * 2.0, 0.0, minf(1.1, dwell * 0.6))
	if not await _hold(dwell * 0.45, token):
		return false
	_city.show_plot_state(item.plot_id, item.building_id, true)
	return await _hold(dwell * 0.55, token)


## Geçmiş krizin kısa tekrarı: efekt Ekip B'nin kaydındaki şiddet ve koruma oranıyla oynatılır.
func _play_crisis(item: Dictionary, token: int) -> bool:
	var entry: Dictionary = item.entry
	var event := Catalog.get_event(StringName(entry.get("event_id", &"")))
	var effect: CrisisEffect = _fx.get_effect(event.visual_effect_id) if event else null
	if effect == null:
		return _alive(token)
	var mitigation := float(entry.get("mitigation", 0.0))
	var advantages: Array = entry.get("assessment", {}).get("advantages", [])
	var info := {
		"severity": float(entry.get("severity", 0.5)), "due_year": item.year,
		"visual_effect_id": event.visual_effect_id, "affected_area": event.affected_area,
		"affected_plot_kinds": event.affected_plot_kinds.duplicate(), "progress": 0.5,
		"mitigation": mitigation, "advantages": advantages,
	}
	var names: Array[String] = []
	for id in advantages:
		var def := Catalog.get_building(StringName(id))
		if def and names.size() < 2:
			names.append(def.display_name)
	var caption := "Yatırımların koruması: %%%d" % roundi(mitigation * 100.0)
	caption += (" · %s" % ", ".join(names)) if not names.is_empty() else " · koruyucu yatırım yoktu"
	_set_texts(str(item.year), event.display_name, caption)
	_rig.glide_to(effect.focus_point, CRISIS_ZOOM, 0.0, 1.2)
	_fx.set_stage(&"active", info)
	if not _replayed.has(effect):
		_replayed.append(effect)
	if not await _hold(CRISIS_DWELL, token):
		return false
	_fx.set_stage(&"ended", info)
	return await _hold(CRISIS_FADE, token)


# --- Başlangıç, bitiş ---

func _setup(start_plots: Dictionary) -> void:
	_saved_view = _rig.get_view()
	_rig.cinematic = true
	_saved_fades = Vector2(_fx.fade_in_time, _fx.fade_out_time)
	_fx.fade_in_time = CRISIS_FADE
	_fx.fade_out_time = CRISIS_FADE
	_fx.stop()
	_city.set_plot_labels_visible(false)
	_city.show_city_state(start_plots, false)
	_rig.set_view(OVERVIEW, true)
	_fit_viewport()
	_view.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_city.get_viewport().disable_3d = true
	_sync_camera()
	set_process(true)


func _end(fade_time: float) -> void:
	_ending = true
	_token += 1
	_tween_fade(1.0, fade_time)
	await get_tree().create_timer(fade_time).timeout
	_restore()
	_announce_finished()
	_tween_fade(0.0, 0.45)
	await get_tree().create_timer(0.45).timeout
	if not _playing:
		_layer.visible = false


## Her şeyi sunum öncesine döndürür: binalar, kamera, efektler, ana görünüm.
func _restore() -> void:
	set_process(false)
	for effect in _replayed:
		effect.animate_to(0.0, 0.05)
	_replayed.clear()
	if _fx and _saved_fades != Vector2.ZERO:
		_fx.fade_in_time = _saved_fades.x
		_fx.fade_out_time = _saved_fades.y
	_city.restore_city_state()
	for plot in _city.get_plots():
		plot.set_showcase(false)
	if _rig:
		if not _saved_view.is_empty():
			_rig.set_view(_saved_view, true)
		_rig.cinematic = false
	_city.get_viewport().disable_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for node: CanvasItem in [_view, _before, _divider, _tag_before, _tag_after]:
		node.visible = false
	_playing = false
	_ending = false


func _announce_finished() -> void:
	EventBus.final_presentation_finished.emit()
	finished.emit()


# --- Yardımcılar ---

func _alive(token: int) -> bool:
	return _playing and not _ending and token == _token


## Süre kadar bekler; sunum bu arada kesildiyse false.
func _hold(seconds: float, token: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return _alive(token)


## Kararma; önceki kararma sürüyorsa durdurulur (biten sunumun açılışı yeni sunumla çakışmasın).
func _tween_fade(alpha: float, time: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, time)


func _sync_camera() -> void:
	var source := _rig.get_node("Pitch/Camera3D") as Camera3D if _rig else null
	if source:
		_camera.global_transform = source.global_transform
		_camera.fov = source.fov


## İnşa sırası: yıla göre, aynı yıl içinde kayıt sırasıyla.
func _sorted_builds(raw) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw is Array:
		return result
	for i in raw.size():
		var e = raw[i]
		if e is Dictionary and e.has("plot_id") and e.has("building_id"):
			result.append({"type": &"build", "plot_id": StringName(e.plot_id), "building_id": StringName(e.building_id),
				"year": int(e.get("year", 0)), "order": i})
	result.sort_custom(func(a, b): return a.year < b.year or (a.year == b.year and a.order < b.order))
	return result


## Yatırımlar ve krizler tek zaman çizelgesinde; aynı yıl önce yatırımlar (kriz o yılın binalarını görür).
func _timeline(builds: Array[Dictionary], crisis_log: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = builds.duplicate()
	for i in crisis_log.size():
		var entry = crisis_log[i]
		if entry is Dictionary and entry.has("year") and entry.has("event_id"):
			items.append({"type": &"crisis", "year": int(entry.year), "order": 1000 + i, "entry": entry})
	items.sort_custom(func(a, b): return a.year < b.year or (a.year == b.year and a.order < b.order))
	return items


## 2052 turu: yalnızca yatırım olan bölgeler; her bölgenin merkezi ve kapsayacak yakınlığı.
func _regions(plots: Dictionary) -> Array[Dictionary]:
	var groups := {}
	for plot in _city.get_plots():
		var id := StringName(plots.get(plot.plot_id, plots.get(String(plot.plot_id), &"")))
		var def := Catalog.get_building(id) if id != &"" else null
		if def == null:
			continue
		var group := &"center"
		if def.category == &"coast" or plot.plot_kind == &"coastal":
			group = &"coast"
		elif def.category == &"heat":
			group = &"green"
		elif plot.plot_kind == &"open":
			group = &"infra"
		if not groups.has(group):
			groups[group] = []
		groups[group].append(plot.global_position)
	var result: Array[Dictionary] = []
	for region in REGIONS:
		var points: Array = groups.get(region.id, [])
		if points.is_empty():
			continue
		var center := Vector3.ZERO
		for p in points:
			center += p
		center /= points.size()
		var spread := 0.0
		for p in points:
			spread = maxf(spread, (p - center).length())
		var entry: Dictionary = region.duplicate()
		entry.center = center
		entry.zoom = clampf(30.0 + spread * 1.6, 30.0, 64.0)
		entry.yaw = -8.0 if result.size() % 2 == 0 else 8.0
		result.append(entry)
	return result


## Ekip B'nin değerleriyle tek satırlık sonuç (hesap yok, yalnızca gösterim).
func _result_line(summary: Dictionary, building_count: int) -> String:
	var parts: Array[String] = ["%d yatırım" % building_count]
	if summary.has("emission_reduction_pct"):
		var pct := int(summary.emission_reduction_pct)
		parts.append("kişi başı emisyon %%%d %s" % [absi(pct), "azaldı" if pct >= 0 else "arttı"])
	if summary.has("score") and summary.has("grade"):
		parts.append("değerlendirme %d · %s" % [int(summary.score), summary.grade])
	return " · ".join(parts)


func _set_texts(year: String, title: String, caption: String) -> void:
	_year.text = year
	_title.text = title
	_caption.text = caption


func _show_step(index: int) -> void:
	var parts: Array[String] = []
	for i in STEPS.size():
		parts.append(("●  " if i == index else "○  ") + STEPS[i])
	_steps.text = "      ".join(parts)


# --- Katman ---

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = OVERLAY_LAYER
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.theme = UI_THEME
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # sunum sırasında arkadaki arayüze tıklanmasın
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)

	_viewport = SubViewport.new()
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var main := get_viewport()
	_viewport.msaa_3d = main.msaa_3d
	_viewport.screen_space_aa = main.screen_space_aa
	_viewport.use_taa = main.use_taa
	_viewport.use_debanding = main.use_debanding
	_viewport.scaling_3d_mode = main.scaling_3d_mode
	_viewport.scaling_3d_scale = main.scaling_3d_scale
	add_child(_viewport)  # CityWorld'ün dünyasını paylaşır (own_world_3d kapalı)
	get_window().size_changed.connect(_fit_viewport)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.visible = false
	root.add_child(_view)
	root.move_child(_view, 0)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.near = 0.5
	_camera.far = 700.0
	_viewport.add_child(_camera)

	_before = TextureRect.new()
	_before.set_anchors_preset(Control.PRESET_FULL_RECT)
	_before.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_before.stretch_mode = TextureRect.STRETCH_SCALE
	_before.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wipe := ShaderMaterial.new()
	wipe.shader = WIPE_SHADER
	wipe.set_shader_parameter("split", 1.0)
	_before.material = wipe
	_before.visible = false
	root.add_child(_before)
	_divider = ColorRect.new()
	_divider.color = Color(1, 1, 1, 0.9)
	_divider.anchor_bottom = 1.0
	_divider.offset_right = 4.0
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.visible = false
	root.add_child(_divider)
	_tag_before = _make_label(root, 64, "2040")
	_tag_after = _make_label(root, 64, "2052")
	for tag in [_tag_before, _tag_after]:
		tag.anchor_top = 1.0
		tag.anchor_bottom = 1.0
		tag.offset_top = -230.0
		tag.offset_bottom = -140.0
		tag.visible = false

	# Okunabilirlik: üstte ve altta yumuşak karartma.
	_add_shade(root, true, 360.0, 0.55)
	_add_shade(root, false, 140.0, 0.6)
	var box := VBoxContainer.new()
	box.position = Vector2(64, 48)
	box.custom_minimum_size.x = 1100.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)
	_year = _make_label(box, 104, "")
	_title = _make_label(box, 44, "")
	_caption = _make_label(box, 30, "")
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size.x = 1100.0
	_steps = _make_label(root, 26, "")
	_steps.anchor_top = 1.0
	_steps.anchor_bottom = 1.0
	_steps.anchor_right = 1.0
	_steps.offset_top = -78.0
	_steps.offset_bottom = -40.0
	_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _make_label(root, 24, "Esc · Atla")
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -220.0
	hint.offset_right = -48.0
	hint.offset_top = -74.0
	hint.offset_bottom = -44.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate.a = 0.75

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


## SubViewport pencerenin piksel boyutunda çizer; ekrana TextureRect gerer.
func _fit_viewport() -> void:
	var size := get_window().size
	_viewport.size = Vector2i(maxi(size.x, 64), maxi(size.y, 64))


func _make_label(parent: Control, font_size: int, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.1, 0.75))
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	parent.add_child(label)
	return label


func _add_shade(parent: Control, top: bool, height: float, alpha: float) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.07, 0.1, alpha if top else 0.0))
	gradient.set_color(1, Color(0.02, 0.07, 0.1, 0.0 if top else alpha))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_right = 1.0
	if top:
		shade.offset_bottom = height
	else:
		shade.anchor_top = 1.0
		shade.anchor_bottom = 1.0
		shade.offset_top = -height
	parent.add_child(shade)
