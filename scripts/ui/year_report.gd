extends Control
## Sahip: B. Yıl sonu raporu (final ekranı: FinalReport). Hesap yapmaz, yalnızca rapor sözlüğünü gösterir (sözleşme §6.7).
## "Son rapor" düğmesiyle son rapor yeniden açılabilir; bu görünümde report_closed yayılmaz.

## [anahtar, ad, yüksek iyi mi]
const ROWS := [
	["credits", "Bütçe", true], ["population", "Nüfus", true],
	["renewable_energy", "Yenilenebilir enerji üretimi", true], ["energy_demand", "Enerji tüketimi", false],
	["water_supply", "Su arzı", true], ["water_demand", "Su tüketimi", false], ["water_security", "Su güvenliği", true],
	["quality_of_life", "Yaşam kalitesi", true], ["ecosystem_health", "Ekosistem sağlığı", true],
	["emissions_total", "Yerel emisyon", false],
]

var _review_only := false  # "Son rapor" ile açıldıysa
var _last_report: Dictionary = {}


func _ready() -> void:
	add_to_group("ui_panel")
	add_to_group("year_report")
	hide()
	%ContinueButton.pressed.connect(_on_continue_pressed)
	EventBus.year_ended.connect(_on_year_ended)
	EventBus.game_over.connect(func(_s): hide())  # final ekranı FinalReport'ta (Prompt 10A)
	EventBus.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: StringName) -> void:
	if phase == &"build" or phase == &"crisis":
		hide()


## HUD "Son rapor": yalnızca inceleme.
func open() -> void:
	if _last_report.is_empty():
		return
	_review_only = true
	_render(_last_report)
	%ContinueButton.text = "Kapat"
	UiText.pop_in(self)


## Zorunlu rapor (report fazı) veya final ekranı başka panel açılınca kapanmaz.
func close() -> void:
	if _review_only:
		_review_only = false
		hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _review_only and event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_year_ended(report: Dictionary) -> void:
	_last_report = report
	_review_only = false
	_render(report)
	%ContinueButton.text = "Devam"
	UiText.pop_in(self)
	%ContinueButton.grab_focus()


func _render(report: Dictionary) -> void:
	var before: Dictionary = report.stats_before
	var after: Dictionary = report.stats_after
	%Title.text = "%d yıl sonu raporu" % report.year
	var crisis_cost := 0.0
	for r in report.crisis_results:
		crisis_cost -= r.damage.get("credits", 0.0)

	var t := "[color=#4dd9d1]%d yılı tamamlandı. Şehrinin yıllık raporu hazır.[/color]\n\n[b]Bütçe[/b]\n[table=2]" % report.year
	t += _pair("Başlangıç bütçesi", UiText.thousands(before.credits))
	t += _pair("Toplam gelir", "[color=#6bd185]+%s[/color]" % UiText.thousands(report.income))
	t += _pair("İşletme giderleri", "[color=#ff8c73]-%s[/color]" % UiText.thousands(report.upkeep))
	if report.get("investment_cost", 0) > 0:
		t += _pair("Yatırımlar", "[color=#ff8c73]-%s[/color]" % UiText.thousands(report.investment_cost))
	if crisis_cost > 0.0:
		t += _pair("Kriz giderleri", "[color=#ff8c73]-%s[/color]" % UiText.thousands(roundi(crisis_cost)))
	if report.missions.reward > 0:
		t += _pair("Görev ödülü", "[color=#6bd185]+%s[/color]" % UiText.thousands(report.missions.reward))
	t += _pair("[b]Yıl sonu bütçesi[/b]", "[b]%s[/b]" % UiText.thousands(after.credits))
	t += "[/table]\n\n[b]Şehir[/b]\n[table=4]"
	t += "[cell][color=#b8c4c2]Gösterge[/color][/cell][cell][color=#b8c4c2]Önce[/color][/cell][cell][color=#b8c4c2]Sonra[/color][/cell][cell][color=#b8c4c2]Değişim[/color][/cell]"
	for row in ROWS:
		var a: float = before[row[0]]
		var b: float = after[row[0]]
		var d := b - a
		# İşaret (+/−) renkten bağımsız da yönü gösterir.
		t += "[cell]%s      [/cell][cell]%s      [/cell][cell]%s      [/cell][cell][color=#%s]%s[/color][/cell]" % [
			row[1], UiText.thousands(roundi(a)), UiText.thousands(roundi(b)), UiText.delta_color(roundf(d), row[2]).to_html(false), UiText.format_delta(d)]
	t += "[/table]\n"

	if not report.built_this_year.is_empty():
		var names := PackedStringArray()
		for id in report.built_this_year:
			names.append(Catalog.get_building(id).display_name)
		t += "\n[b]Yeni yatırımlar[/b]\n" + ", ".join(names) + "\n"
	for result in report.crisis_results:
		t += "\n[b]İklim olayı[/b]\n%s\n" % result.summary_text
		if result.has("assessment"):
			var a: Dictionary = result.assessment
			t += "  [color=#b8c4c2]Şiddet %%%d · tehlike ×%.2f · maruziyet ×%.2f · hassasiyet ×%.2f · uyum −%%%d[/color]\n" % [
				roundi(result.severity * 100), a.hazard, a.exposure, a.vulnerability, roundi(a.mitigation * 100)]
		for key in result.damage:
			t += "  %s %s\n" % [UiText.STAT_NAMES.get(key, key), UiText.format_delta(result.damage[key])]
	for id in report.missions.completed:
		var m := _mission(id)
		t += "\n[color=#4dd9d1][b]Görev tamamlandı:[/b] %s (+%d kredi)[/color]\n" % [m.title, m.reward_credits]
	for id in report.missions.failed:
		t += "\n[color=#ff8c73][b]Görev kaçtı:[/b] %s[/color]\n" % _mission(id).title
	for w in report.new_warnings:
		var def := Catalog.get_event(w.event_id)
		t += "\n[color=#ffbf66][b]Uyarı:[/b] %s %d sonunda %s bekleniyor; hazırlanmak için bir yılın var.[/color]\n" % [def.warning_text, w.due_year, def.display_name]
	%Body.text = t
	%Body.scroll_to_line(0)


func _pair(label: String, value: String) -> String:
	return "[cell]%s        [/cell][cell]%s[/cell]" % [label, value]


func _on_continue_pressed() -> void:
	if _review_only:
		close()
		return
	hide()
	EventBus.report_closed.emit()


func _mission(id: StringName) -> MissionDefinition:
	for m in Catalog.data.missions:
		if m.id == id:
			return m
	return null
