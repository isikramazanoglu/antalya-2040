extends PanelContainer
## Sahip: B. Akıllı eğitim kartı ve öğrenme ilerlemesi (Prompt 8 §7, §10).
## Bir yatırım ilk kez yapıldığında küçük, kapatılabilir bir kart gösterir; aynı kart bir oyunda bir kez çıkar.
## Oyun durumunu değiştirmez; yalnızca görüntülenenleri sayar. Görüntülemek öğrenmek demek değildir.

const AUTO_HIDE := 14.0

var seen_cards: Dictionary = {}  # InfoCard.id -> true
var viewed_terms: Dictionary = {}  # GlossaryTerm.id -> true
var viewed_sections: Dictionary = {}  # Laboratuvar bölümü adı -> true
var _hide_timer: SceneTreeTimer


func save_state() -> Dictionary:
	return {"seen_cards": seen_cards.duplicate(), "viewed_terms": viewed_terms.duplicate(), "viewed_sections": viewed_sections.duplicate()}


func _ready() -> void:
	if not GameState.restored_education.is_empty():
		var e: Dictionary = GameState.restored_education
		seen_cards = e.get("seen_cards", {})
		viewed_terms = e.get("viewed_terms", {})
		viewed_sections = e.get("viewed_sections", {})
		GameState.restored_education = {}
	add_to_group("education")
	hide()
	%EduClose.pressed.connect(hide)
	%EduMore.toggled.connect(func(on): %EduBody.visible = on)
	EventBus.build_approved.connect(_on_build_approved)
	EventBus.phase_changed.connect(func(phase): if phase != &"build": hide())


func _on_build_approved(_plot_id: StringName, building_id: StringName) -> void:
	var def := Catalog.get_building(building_id)
	if def == null or def.info_card == null or seen_cards.has(def.info_card.id):
		return
	show_card(def.info_card)


func show_card(card: InfoCard) -> void:
	seen_cards[card.id] = true
	%EduTitle.text = card.title
	%EduSummary.text = "%s\n[color=#4dd9d1]İklime faydası:[/color] %s" % [card.benefit, card.climate_link] if card.benefit != "" else card.body
	var body := card.body
	for s in card.sources:
		body += "\n[font_size=12][color=#b8c4c2]Kaynak: %s[/color][/font_size]" % s
	%EduBody.text = body
	%EduMore.set_pressed_no_signal(false)
	%EduBody.visible = false
	UiText.pop_in(self)
	_hide_timer = get_tree().create_timer(AUTO_HIDE)
	var timer := _hide_timer
	timer.timeout.connect(func(): if timer == _hide_timer and not %EduMore.button_pressed: hide())


func mark_term(id: StringName) -> void:
	viewed_terms[id] = true


func mark_section(section: String) -> void:
	viewed_sections[section] = true


func progress() -> Dictionary:
	var learning := Catalog.data.missions.filter(func(m): return m.category == &"learning")
	return {
		"tasks_done": learning.filter(func(m): return GameState.missions.get(m.id) == &"done").size(),
		"tasks_total": learning.size(),
		"cards_seen": seen_cards.size(),
		"cards_total": Catalog.data.buildings.size(),
		"terms_viewed": viewed_terms.size(),
		"terms_total": Catalog.data.glossary.size(),
		"sections_viewed": viewed_sections.size(),
		"sections_total": 4,
	}
