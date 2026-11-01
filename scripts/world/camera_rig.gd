class_name CameraRig
extends Node3D
## Sahip: A. İzometrik kamera (mimari §2.4). Kök = bakılan nokta, Y ekseninde döner;
## Pitch sabit eğim; yakınlaştırma Camera3D'yi Pitch ekseninde ileri geri iter.
## WASD ve ok tuşlarıyla ekran yönünde kaydırma, tekerlek yakınlaştırma, orta tuşla zemini tutup sürükleme.
## Sol tuşla sürükleme (A11): basılıyken imleç drag_threshold pikselden fazla giderse harita sürüklenir; kısa tıklama
## arsa seçimi olarak kalır (CityWorld seçimi tuş bırakılınca yapar ve was_left_drag() ile sürüklemeyi ayırır).
## Q/E döndürme rotate_limit_deg ile sınırlanır (CameraRig.tscn'de 0: sabit açı).
## Fare girdisi _unhandled_input'tan gelir: arayüzün tükettiği tıklama/sürükleme haritayı oynatmaz.
## Sinematik modda (final sunumu) oyuncu girdisi yok sayılır; kamerayı glide_to / play_tour yönetir.
## İnşaat gösterimi (A12): showcase() yeni binaya yaklaşır, kısa süre gösterir, önceki görünüme döner; oyuncu kamerayı
## elle oynatırsa (WASD / oklar, tekerlek, sol ya da orta sürükleme, arsa seçimi) gösterim olduğu yerde biter.

@export var pan_speed := 30.0
## Bakılan noktanın gezebileceği alan (x, z, genişlik, derinlik).
@export var bounds := Rect2(-34.0, -30.0, 68.0, 44.0)
@export var zoom_min := 22.0
@export var zoom_max := 95.0
@export var zoom_step := 6.0
@export var rotate_limit_deg := 30.0
@export var rotate_speed_deg := 70.0
## Yumuşatma hızı; büyüdükçe kamera hedefe daha çabuk varır.
@export var smoothing := 8.0
@export var drag_sensitivity := 0.0022
## Sol tuşla sürüklemenin başlaması için basıldığı yerden en az bu kadar (viewport pikseli) gidilmeli;
## altında kalan titreşimler tıklama sayılır.
@export var drag_threshold := 8.0
## Ekranın arayüz panellerince kapatılmayan kısmı (oran olarak x, y, genişlik, yükseklik).
## Seçilen arsa bunun dışında kalırsa kamera onu içeri kaydırır.
@export var safe_area := Rect2(0.23, 0.1, 0.48, 0.76)
## İnşaat gösterimi süreleri (sn): yaklaşma, bekleme, dönüş.
@export var showcase_in := 0.9
@export var showcase_hold := 2.0
@export var showcase_out := 0.9
## Gösterim yakınlığı = kadraj ölçüsü × bu katsayı (zoom_min'den yakın olmaz); büyük yapı daha geniş kadraj.
@export var showcase_zoom_per_unit := 3.2

@onready var _camera: Camera3D = $Pitch/Camera3D

var _target_pos: Vector3
var _target_zoom: float
var _base_yaw: float
var _yaw_offset := 0.0
var _dragging := false
## Sol tuş: haritada basıldı mı, nereden, eşik aşılıp sürüklemeye geçildi mi, son basış sürükleme miydi.
var _left_down := false
var _left_start := Vector2.ZERO
var _left_dragging := false
var _left_was_drag := false
## true iken oyuncu girdisi kamerayı oynatmaz (final sunumu).
var cinematic := false
var _glide: Tween
## İnşaat gösterimi sürüyor mu ve gösterim bitince dönülecek görünüm (art arda gösterimlerde ilk görünüm korunur).
var _showcasing := false
var _showcase_home: Dictionary = {}


func _ready() -> void:
	_target_pos = position
	_target_zoom = _camera.position.z
	_base_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if cinematic:
		return
	if event.is_action_pressed("cam_zoom_in"):
		cancel_showcase()
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("cam_zoom_out"):
		cancel_showcase()
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			cancel_showcase()
		_dragging = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Arayüzün tükettiği tıklama buraya gelmez: panel / düğme üstünde basış sürükleme başlatmaz.
		if event.pressed:
			_left_down = true
			_left_start = event.position
			_left_dragging = false
			_left_was_drag = false
		else:
			_left_was_drag = _left_dragging
			_left_down = false
			_left_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		# Orta tuş arayüzün üstünde bırakıldıysa bırakma olayı buraya gelmez; tuş durumundan anla.
		if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			_dragging = false
			return
		_drag(event.position, event.relative)
	elif event is InputEventMouseMotion and _left_down:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_left_down = false  # bırakma arayüzde ya da pencere dışında oldu
			_left_dragging = false
			return
		if _left_dragging:
			_drag(event.position, event.relative)
		elif event.position.distance_to(_left_start) > drag_threshold:
			# Eşik aşıldı: basılan noktadan bu yana birikmiş hareket tek seferde uygulanır, zemin imleçle gider.
			cancel_showcase()
			_left_dragging = true
			_drag(event.position, event.position - _left_start)


func _process(delta: float) -> void:
	var input := _pan_input()
	if input != Vector2.ZERO:
		cancel_showcase()
		var speed := pan_speed * (_target_zoom / 50.0)
		_target_pos += (_flat_right() * input.x + _flat_back() * input.y) * speed * delta
	var turn := 0.0 if cinematic else Input.get_axis("cam_rotate_right", "cam_rotate_left")
	if turn != 0.0:
		var limit := deg_to_rad(rotate_limit_deg)
		_yaw_offset = clampf(_yaw_offset + turn * deg_to_rad(rotate_speed_deg) * delta, -limit, limit)

	_target_pos.x = clampf(_target_pos.x, bounds.position.x, bounds.end.x)
	_target_pos.z = clampf(_target_pos.z, bounds.position.y, bounds.end.y)

	var t := 1.0 - exp(-smoothing * delta)
	position = position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _base_yaw + _yaw_offset, t)
	_camera.position.z = lerpf(_camera.position.z, _target_zoom, t)


## Klavye kaydırma yönü: WASD (Input Map) + ok tuşları. Ok tuşları Input Map'te tanımlı değil
## (project.godot Ekip B'nin), bu yüzden fiziksel tuş olarak okunur. Yazı alanı odaktayken yok sayılır.
func _pan_input() -> Vector2:
	if cinematic:
		return Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return Vector2.ZERO
	var v := Input.get_vector("cam_left", "cam_right", "cam_forward", "cam_back")
	v.x += float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
	v.y += float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	return v.limit_length(1.0)


## Zemini tutup sürükleme: imlecin altındaki zemin noktası imleçle birlikte gider (perspektifte de birebir).
## Kamera hedefi ve konumu birlikte kayar; açı ve yakınlık değişmez. Sınırlar _process'te uygulanır.
func _drag(screen: Vector2, relative: Vector2) -> void:
	var before = _ground_at(screen - relative)
	var after = _ground_at(screen)
	var delta := Vector3.ZERO
	if before != null and after != null:
		delta = before - after
	else:
		var motion := relative * _target_zoom * drag_sensitivity
		delta = -(_flat_right() * motion.x + _flat_back() * motion.y)
	# Sınır burada da uygulanır: sürükleme sınırın dışına taşıp geri yaylanmaz, kenarda durur.
	var clamped := Vector3(clampf(_target_pos.x + delta.x, bounds.position.x, bounds.end.x), _target_pos.y,
			clampf(_target_pos.z + delta.z, bounds.position.y, bounds.end.y))
	delta = clamped - _target_pos
	_target_pos = clamped
	position += Vector3(delta.x, 0.0, delta.z)


## Sol tuşla harita şu an sürükleniyor mu (CityWorld fare üstü vurgusunu kapatır).
func is_left_dragging() -> bool:
	return _left_dragging


## Son sol tuş basışı sürüklemeye dönüştü mü (bırakıldıktan sonra da true kalır; CityWorld bu bırakmayı tıklama saymaz).
func was_left_drag() -> bool:
	return _left_was_drag


## Kamerayı bir noktaya yumuşakça götürür (CitySandbox ve ileride odaklama için).
func focus_on(point: Vector3) -> void:
	_target_pos = Vector3(point.x, position.y, point.z)


## Kameranın hedef görünümü: bakılan nokta, yakınlık, döndürme (radyan). set_view ile geri yüklenir.
func get_view() -> Dictionary:
	return {"position": _target_pos, "zoom": _target_zoom, "yaw": _yaw_offset}


## Görünümü geri yükler; instant ise yumuşatmadan hemen oraya geçer (kesme).
func set_view(view: Dictionary, instant := false) -> void:
	_showcasing = false
	if _glide:
		_glide.kill()
	_target_pos = view.position
	_target_zoom = view.zoom
	_yaw_offset = view.yaw
	if instant:
		position = Vector3(_target_pos.x, position.y, _target_pos.z)
		rotation.y = _base_yaw + _yaw_offset
		_camera.position.z = _target_zoom


## Sinematik geçiş: hedef nokta, yakınlık ve döndürmeye (derece, açılış açısına göre) yumuşak gider.
## Sınır ve yakınlık limitleri oyuncu kamerasıyla aynıdır. Dönen Tween beklenebilir (await tween.finished).
func glide_to(point: Vector3, zoom: float, yaw_deg := 0.0, duration := 2.0) -> Tween:
	_showcasing = false
	if _glide:
		_glide.kill()
	var target := Vector3(clampf(point.x, bounds.position.x, bounds.end.x), position.y,
			clampf(point.z, bounds.position.y, bounds.end.y))
	_glide = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glide.tween_property(self, "_target_pos", target, duration)
	_glide.tween_property(self, "_target_zoom", clampf(zoom, zoom_min, zoom_max), duration)
	_glide.tween_property(self, "_yaw_offset", deg_to_rad(yaw_deg), duration)
	return _glide


## Final görsel sözleşmesi §D: noktaları sırayla gezen kamera turu (toplam süre eşit bölünür).
func play_tour(points: Array[Vector3], duration: float, zoom := 40.0) -> void:
	if points.is_empty():
		return
	var step := duration / points.size()
	for point in points:
		await glide_to(point, zoom, 0.0, step).finished


## Nokta ekranın güvenli alanı dışındaysa kamerayı yalnızca alanın içine girecek kadar kaydırır;
## içindeyse dokunmaz. Kamera gereksiz yere zıplamaz, şehrin geri kalanı yerinde kalır.
func bring_into_view(point: Vector3) -> void:
	cancel_showcase()
	var view := get_viewport().get_visible_rect().size
	var safe := Rect2(safe_area.position * view, safe_area.size * view)
	var screen := _camera.unproject_position(point)
	if safe.has_point(screen) and not _camera.is_position_behind(point):
		return
	var margin := view * 0.04
	var inner := safe.grow_individual(-margin.x, -margin.y, -margin.x, -margin.y)
	var from = _ground_at(screen)
	var to = _ground_at(screen.clamp(inner.position, inner.end))
	if from != null and to != null:
		_target_pos += from - to


## İnşaat gösterimi (A12): kadraj kutusunun (dünya AABB) merkezine yumuşakça yaklaşır, showcase_hold kadar gösterir,
## gösterim öncesi görünüme döner. Açı değişmez; hedef sınırlar içinde kalır (kenardaki arsada en yakın kadraj).
## Gösterim sürerken yeni istek gelirse en son yapı gösterilir ve dönüş yine ilk görünüme olur. Tek Tween (_glide)
## kullanılır; iptal / yeni istek eski Tween'i ve geri çağrılarını öldürür. Sinematik modda (final sunumu) yok sayılır.
func showcase(box: AABB) -> void:
	if cinematic or not is_inside_tree():
		return
	if not _showcasing:
		_showcase_home = get_view()
	_showcasing = true
	if _glide:
		_glide.kill()
	var center := box.get_center()
	var target := Vector3(clampf(center.x, bounds.position.x, bounds.end.x), position.y,
			clampf(center.z, bounds.position.y, bounds.end.y))
	var zoom := showcase_zoom_for(box)
	var home: Dictionary = _showcase_home
	_glide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glide.tween_property(self, "_target_pos", target, showcase_in)
	_glide.parallel().tween_property(self, "_target_zoom", zoom, showcase_in)
	_glide.tween_interval(showcase_hold)
	_glide.tween_property(self, "_target_pos", home.position, showcase_out)
	_glide.parallel().tween_property(self, "_target_zoom", home.zoom, showcase_out)
	_glide.tween_callback(_end_showcase)


## Kadraj ölçüsü: yatay en büyük kenar ya da yüksekliğin 1,3 katı, çevresiyle birlikte (+2); yakınlık sınırları içinde.
func showcase_zoom_for(box: AABB) -> float:
	var extent := maxf(maxf(box.size.x, box.size.z), box.size.y * 1.3) + 2.0
	return clampf(extent * showcase_zoom_per_unit, zoom_min, zoom_max)


func is_showcasing() -> bool:
	return _showcasing


## Oyuncu kamerayı elle oynattı: gösterim olduğu yerde biter, kamera o anki konum ve yakınlıkta kalır (sıçrama yok).
func cancel_showcase() -> void:
	if not _showcasing:
		return
	_showcasing = false
	if _glide:
		_glide.kill()
	_target_pos = Vector3(position.x, position.y, position.z)
	_target_zoom = _camera.position.z


func _end_showcase() -> void:
	_showcasing = false


## Ekran noktasının y = 0 zemin düzlemindeki karşılığı; düzleme bakmıyorsa null.
func _ground_at(screen: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	if dir.y > -0.01:
		return null
	var hit := origin + dir * (-origin.y / dir.y)
	return Vector3(hit.x, 0.0, hit.z)


func _flat_right() -> Vector3:
	return Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized()


func _flat_back() -> Vector3:
	return Vector3(global_basis.z.x, 0.0, global_basis.z.z).normalized()
