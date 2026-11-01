class_name CameraRig
extends Node3D
## Sahip: A. İzometrik kamera (mimari §2.4). Kök = bakılan nokta, Y ekseninde döner;
## Pitch sabit eğim; yakınlaştırma Camera3D'yi Pitch ekseninde ileri geri iter.
## WASD ve ok tuşlarıyla ekran yönünde kaydırma, tekerlek yakınlaştırma, orta tuşla zemini tutup sürükleme.
## Q/E döndürme rotate_limit_deg ile sınırlanır (CameraRig.tscn'de 0: sabit açı).
## Fare girdisi _unhandled_input'tan gelir: arayüzün tükettiği tıklama/sürükleme haritayı oynatmaz.
## Sinematik modda (final sunumu) oyuncu girdisi yok sayılır; kamerayı glide_to / play_tour yönetir.

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
## Ekranın arayüz panellerince kapatılmayan kısmı (oran olarak x, y, genişlik, yükseklik).
## Seçilen arsa bunun dışında kalırsa kamera onu içeri kaydırır.
@export var safe_area := Rect2(0.23, 0.1, 0.48, 0.76)

@onready var _camera: Camera3D = $Pitch/Camera3D

var _target_pos: Vector3
var _target_zoom: float
var _base_yaw: float
var _yaw_offset := 0.0
var _dragging := false
## true iken oyuncu girdisi kamerayı oynatmaz (final sunumu).
var cinematic := false
var _glide: Tween


func _ready() -> void:
	_target_pos = position
	_target_zoom = _camera.position.z
	_base_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if cinematic:
		return
	if event.is_action_pressed("cam_zoom_in"):
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("cam_zoom_out"):
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		# Orta tuş arayüzün üstünde bırakıldıysa bırakma olayı buraya gelmez; tuş durumundan anla.
		if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			_dragging = false
			return
		_drag(event.position, event.relative)


func _process(delta: float) -> void:
	var input := _pan_input()
	if input != Vector2.ZERO:
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
	_target_pos += delta
	position += Vector3(delta.x, 0.0, delta.z)


## Kamerayı bir noktaya yumuşakça götürür (CitySandbox ve ileride odaklama için).
func focus_on(point: Vector3) -> void:
	_target_pos = Vector3(point.x, position.y, point.z)


## Kameranın hedef görünümü: bakılan nokta, yakınlık, döndürme (radyan). set_view ile geri yüklenir.
func get_view() -> Dictionary:
	return {"position": _target_pos, "zoom": _target_zoom, "yaw": _yaw_offset}


## Görünümü geri yükler; instant ise yumuşatmadan hemen oraya geçer (kesme).
func set_view(view: Dictionary, instant := false) -> void:
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
