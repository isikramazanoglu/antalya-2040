extends Control
## Sahip: B.

const GAME_SCENE := "res://scenes/main/Game.tscn"


func _ready() -> void:
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%QuitButton.pressed.connect(get_tree().quit)
	%NewGameButton.grab_focus()


func _on_new_game_pressed() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)
