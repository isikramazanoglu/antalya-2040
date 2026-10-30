extends Control
## Sahip: B. Yıl sonu raporu ve final ekranı. Hesap yapmaz, yalnızca gösterir (sözleşme §6.7).

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const REPORT_STATS: Array[String] = ["population", "water_security", "energy_security",
		"quality_of_life", "ecosystem_health", "emissions_total"]

var _game_over := false


func _ready() -> void:
	hide()
	%ContinueButton.pressed.connect(_on_continue_pressed)
	EventBus.year_ended.connect(_on_year_ended)
	EventBus.game_over.connect(_on_game_over)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: StringName) -> void:
	if phase == &"build" or phase == &"crisis":
		hide()


func _on_year_ended(report: Dictionary) -> void:
	var before: Dictionary = report.stats_before
	var after: Dictionary = report.stats_after
	%Title.text = "%d yıl sonu raporu" % report.year
	var t := "[b]Bütçe[/b]\nGelir  +%d\nİşletme gideri  -%d\nNet  %s\nKasa  %d kredi\n\n" % [
		report.income, report.upkeep, UiText.format_delta(report.income - report.upkeep), after.credits]
	t += "[b]Şehir[/b]\n"
	for key in REPORT_STATS:
		t += "%s  %s → %s\n" % [UiText.STAT_NAMES[key],
				UiText.format_value(before[key]), UiText.format_value(after[key])]
	t += "Yenilenebilir enerji payı  %%%d → %%%d\nSu arzı / talebi  %d / %d\n" % [
		roundi(before.renewable_share * 100), roundi(after.renewable_share * 100), roundi(after.water_supply), roundi(after.water_demand)]
	if not report.built_this_year.is_empty():
		var names := PackedStringArray()
		for id in report.built_this_year:
			names.append(Catalog.get_building(id).display_name)
		t += "\n[b]Bu yıl yapılanlar[/b]\n" + ", ".join(names) + "\n"
	for result in report.crisis_results:
		t += "\n[b]Kriz[/b]\n%s\n" % result.summary_text
		for key in result.damage:
			t += "%s  %s\n" % [UiText.STAT_NAMES.get(key, key), UiText.format_delta(result.damage[key])]
	for id in report.missions.completed:
		var m := _mission(id)
		t += "\n[color=#4dd9d1][b]Görev tamamlandı:[/b] %s (+%d kredi)[/color]\n" % [m.title, m.reward_credits]
	for id in report.missions.failed:
		t += "\n[color=#ff8c73][b]Görev kaçtı:[/b] %s[/color]\n" % _mission(id).title
	for w in report.new_warnings:
		var def := Catalog.get_event(w.event_id)
		t += "\n[color=#ffbf66][b]Uyarı:[/b] %d sonunda %s bekleniyor. Hazırlanmak için bir yılın var.[/color]\n" % [w.due_year, def.display_name]
	%Body.text = t
	%ContinueButton.text = "Devam"
	show()


func _on_game_over(summary: Dictionary) -> void:
	_game_over = true
	var s: Dictionary = summary.final_stats
	%Title.text = "2052 · Şehrin geleceği"
	var t := "[b]Puan: %d[/b]\n[b]%s[/b]\nKişi başı emisyon azalması: %%%d\nTamamlanan görev: %d / %d\n\n" % [
		summary.score, summary.grade, summary.emission_reduction_pct,
		GameState.missions.values().count(&"done"), Catalog.data.missions.size()]
	for key in REPORT_STATS:
		t += "%s  %s\n" % [UiText.STAT_NAMES[key], UiText.format_value(s[key])]
	%Body.text = t
	%ContinueButton.text = "Ana menü"
	show()


func _on_continue_pressed() -> void:
	if _game_over:
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	hide()
	EventBus.report_closed.emit()


func _mission(id: StringName) -> MissionDefinition:
	for m in Catalog.data.missions:
		if m.id == id:
			return m
	return null
