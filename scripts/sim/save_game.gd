class_name SaveGame
extends RefCounted
## Sahip: B. Tek kayıt yuvası (Prompt 13 §13). user:// altında Godot ikili biçimi (store_var):
## StringName gibi türler korunur, nesne yüklenmez (get_var(false)). Sürüm numaralı; bilinmeyen sürüm yüklenmez.
## Yalnızca build fazında kaydedilir: kriz/rapor ortasındaki yarım işlem kayda girmez, ödül/ceza çoğalmaz.

const VERSION := 1
## Testler oyuncunun kaydına dokunmasın: --script ile çalışırken kayıt kapalı; kayıt testi kendi dosyasını açar.
static var path := "user://antalya2040_save.dat"
static var enabled := not OS.get_cmdline_args().has("--script")


## GameState autoload'una çalışma anında erişir (sınıf, autoload'lardan önce derlenen test betiklerinde de çalışsın).
static func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


static func exists() -> bool:
	return enabled and FileAccess.file_exists(path)


static func delete() -> void:
	if enabled and exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## turn: TurnManager.save_state(), education: EducationManager.save_state() (yoksa {}).
static func save(turn: Dictionary, education: Dictionary) -> bool:
	if not enabled or _gs().phase != &"build":
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: yazılamadı (%s)" % FileAccess.get_open_error())
		return false
	f.store_var({"version": VERSION, "game_state": _gs().to_snapshot(), "turn": turn, "education": education}, false)
	return true


## Kaydı GameState'e yükler (oyun sahnesi açılmadan önce). Başarısızsa GameState değişmez.
static func load_into_state() -> bool:
	if not exists():
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data = f.get_var(false)
	if not (data is Dictionary) or data.get("version", 0) != VERSION or not data.has("game_state") or not data.has("turn"):
		push_warning("SaveGame: kayıt okunamadı ya da sürümü farklı")
		return false
	_gs().apply_snapshot(data.game_state, data.turn, data.get("education", {}))
	return true
