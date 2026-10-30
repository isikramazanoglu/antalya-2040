extends Control
## Sahip: B. Ana menü: Yeni oyun, Oyun hakkında, Çıkış.
## Arka planda Ekip A'nın şehri yalnızca görüntü olarak durur (process_mode kapalı, girdi almaz).

const GAME_SCENE := "res://scenes/main/Game.tscn"


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%AboutButton.pressed.connect(%About.show)
	%AboutCloseButton.pressed.connect(%About.hide)
	%QuitButton.pressed.connect(get_tree().quit)
	%About.hide()
	%NewGameButton.grab_focus()
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if %About.visible and event.is_action_pressed("cancel"):
		%About.hide()
		get_viewport().set_input_as_handled()


## Hafif giriş animasyonu: menü paneli soldan kayarak belirir.
func _play_intro() -> void:
	var panel: Control = %MenuPanel
	var target_x := panel.position.x
	panel.modulate.a = 0.0
	panel.position.x = target_x - 40.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.8)
	tween.tween_property(panel, "position:x", target_x, 0.8)


func _on_new_game_pressed() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)
