extends PanelContainer
## Sahip: B. Ayarlar: yalnızca gerçekten çalışan seçenekler (tam ekran, dikey senkron).


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("settings")
	hide()
	%CloseButton.pressed.connect(close)
	%Fullscreen.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	%VSync.toggled.connect(func(on): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	%Fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	%VSync.set_pressed_no_signal(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	UiText.pop_in(self)
	%Fullscreen.grab_focus()


func close() -> void:
	hide()
