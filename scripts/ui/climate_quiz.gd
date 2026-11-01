class_name ClimateQuiz
extends Control
## Sahip: B. Zorunlu iklim sorusu: her ay geçişinden (ve "Yıl sonuna atla"dan) önce açılır; doğru cevap verilmeden
## ay ilerlemez. Tam ekran ve kapatılamaz (Esc, başka düğme yok). Bir ayda tamamlanan soru o ay yeniden sorulmaz.
## Durum GameState.quiz_count / quiz_done_key (kayda girer); yazan GameController.

## [soru, [A, B, C, D], doğru indeks, kısa açıklama]
const QUESTIONS := [
	["Sera gazlarının atmosferdeki temel etkisi nedir?", ["Güneş ışığını tamamen engellemek", "Isının bir bölümünün atmosferde tutulmasına neden olmak", "Okyanusları temizlemek", "Rüzgârı durdurmak"], 1,
		"Sera gazları Dünya'dan uzaya kaçmak isteyen ısının bir kısmını tutar. Bu gazlar arttıkça Dünya ısınır."],
	["Kuraklık yaşayan bir şehirde su güvenliğini artırmak için hangi yöntem uygundur?", ["Atık suyun arıtılıp yeniden kullanılması", "Su kaçaklarının artırılması", "Yağmur suyu toplama sistemlerinin kapatılması", "Gereksiz su tüketiminin artırılması"], 0,
		"Arıtılan atık su sulama ve temizlikte yeniden kullanılır; böylece temiz içme suyu korunur."],
	["Şehirlerde ağaçlandırmanın önemli faydası nedir?", ["Hava sıcaklığını her koşulda artırmak", "Gölgelendirme ve buharlaşma yoluyla serinlemeye katkı sağlamak", "Yağışı tamamen durdurmak", "Trafiği artırmak"], 1,
		"Ağaçlar gölge yapar ve yapraklarından su buharlaştırır; bu da çevresini serinletir."],
	["Güneş panellerinin temel işlevi nedir?", ["Güneş ışığını elektrik enerjisine dönüştürmek", "Suyu tuzdan arındırmak", "Havadaki oksijeni artırmak", "Rüzgâr üretmek"], 0,
		"Güneş panelleri güneş ışığını doğrudan elektriğe çevirir; çalışırken karbon salmaz."],
	["Atıkların kaynağında ayrıştırılmasının faydası nedir?", ["Geri dönüşümü kolaylaştırmak", "Atık miktarını otomatik olarak sıfırlamak", "Enerji tüketimini zorunlu olarak artırmak", "Bütün atıkları tehlikeli hâle getirmek"], 0,
		"Kâğıt, plastik, cam ve organik atık en baştan ayrılırsa geri dönüşüm ve kompost çok daha kolay olur."],
	["Araç egzozlarından kaynaklanan bazı kirleticiler hangileridir?", ["Azot oksitler ve partikül maddeler", "Yalnızca su buharı", "Sadece oksijen", "Yalnızca helyum"], 0,
		"Benzinli ve dizel araçlar azot oksitler ve küçük toz parçacıkları (partikül madde) çıkarır; bunlar havayı kirletir."],
	["Geçirgen zeminlerin şehirlerdeki faydası nedir?", ["Yağmur suyunun toprağa sızmasını desteklemek", "Yağmur suyunu tamamen yok etmek", "Sıcaklığı sürekli artırmak", "Bütün yolları kapatmak"], 0,
		"Suyu geçiren zeminler yağmuru toprağa ulaştırır; sel riski azalır, yer altı suyu beslenir."],
	["Kıyı ekosistemlerinin korunması neden önemlidir?", ["Biyoçeşitliliği ve doğal ekosistem işlevlerini desteklemek", "Bütün canlıları bölgeden uzaklaştırmak", "Deniz kirliliğini artırmak", "Kıyı yapılaşmasını sınırsız artırmak"], 0,
		"Kumullar, kıyı bitkileri ve sığ deniz alanları pek çok canlıya yuva olur ve dalgaları yavaşlatır."],
	["Enerji verimliliği ne sağlar?", ["Aynı işi daha az enerjiyle yapabilmeyi", "Her durumda daha fazla enerji tüketmeyi", "Bütün enerji kaynaklarını yok etmeyi", "Enerji ihtiyacını otomatik olarak sınırsız artırmayı"], 0,
		"Yalıtımlı binalar ve verimli lambalar aynı işi daha az elektrikle yapar; harcanmayan enerji karbon da çıkarmaz."],
	["Erken uyarı sistemlerinin afet yönetimindeki temel amacı nedir?", ["Afetleri tamamen ortadan kaldırmak", "İnsanların önceden hazırlık yapmasını ve olası zararların azaltılmasını sağlamak", "Yağışları durdurmak", "Bütün doğal olayları engellemek"], 1,
		"Erken uyarı afeti durduramaz ama insanlara hazırlanma ve güvenli yere gitme zamanı kazandırır."],
]
const LETTERS := ["A", "B", "C", "D"]

## --script ile çalışan testlerde kapalı (testler ay geçişini elle sürer); oyunda açık.
static var enabled := not OS.get_cmdline_args().has("--script")

var _on_pass: Callable
var _q: Array = []
var _choice := -1
var _passed := false
var _answers: Array[Button] = []
var _title: Label
var _text: Label
var _feedback: RichTextLabel
var _check: Button
var _next: Button


func _ready() -> void:
	add_to_group("climate_quiz")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # arkadaki düğmelere tıklanamaz
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SolidPanel"
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", UiText.C_ACCENT)
	box.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 20)
	box.add_child(_text)
	var group := ButtonGroup.new()
	for i in 4:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): _choice = i; _check.disabled = _passed)
		box.add_child(b)
		_answers.append(b)
	_feedback = RichTextLabel.new()
	_feedback.bbcode_enabled = true
	_feedback.fit_content = true
	box.add_child(_feedback)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_check = Button.new()
	_check.text = "Cevabı kontrol et"
	_check.pressed.connect(_on_check)
	row.add_child(_check)
	_next = Button.new()
	_next.text = "Devam et"
	_next.pressed.connect(_on_next)
	row.add_child(_next)
	hide()


## Ay geçişi istendi: bu ay soru zaten çözüldüyse hemen geçer; değilse soru açılır, doğru cevaptan sonra on_pass bir kez çalışır.
func ask(on_pass: Callable) -> void:
	var GameState := get_node("/root/GameState")  # çalışma anında (sınıf autoload'lardan önce derlense de)
	if not enabled or GameState.quiz_done_key == GameState.stats.year * 12 + GameState.month:
		on_pass.call()
		return
	if visible:
		return  # zaten açık; ikinci geçiş isteği yok sayılır
	_on_pass = on_pass
	_q = QUESTIONS[(GameState.quiz_count + GameState.rng_seed) % QUESTIONS.size()]
	_choice = -1
	_passed = false
	_title.text = "İklim sorusu · %s %d" % [UiText.MONTHS[GameState.month - 1], GameState.stats.year]
	_text.text = _q[0]
	for i in 4:
		_answers[i].text = "%s) %s" % [LETTERS[i], _q[1][i]]
		_answers[i].button_pressed = false
		_answers[i].disabled = false
	_feedback.text = "[color=#b8c4c2]Bir sonraki aya geçmek için doğru cevabı bul.[/color]"
	_check.disabled = true
	_next.disabled = true
	show()


func _on_check() -> void:
	if _choice < 0 or _passed:
		return
	var correct: int = _q[2]
	if _choice == correct:
		_passed = true
		_feedback.text = "[color=#6bd185][b]Doğru![/b][/color] %s" % _q[3]
		for b in _answers:
			b.disabled = true
		_check.disabled = true
		_next.disabled = false
	else:
		_feedback.text = "[color=#ff8c73][b]Yanlış.[/b][/color] Doğru cevap: [b]%s) %s[/b]. %s\n[color=#b8c4c2]Tekrar dene.[/color]" % [LETTERS[correct], _q[1][correct], _q[3]]
		_check.disabled = true


func _on_next() -> void:
	if not _passed:
		return
	hide()
	var gc := get_tree().get_first_node_in_group("game_controller")
	if gc:
		gc.quiz_passed()
	var cb := _on_pass
	_on_pass = Callable()
	if cb.is_valid():
		cb.call()  # ay geçişi yalnızca bir kez


## Esc ve diğer kısayollar soru açıkken işlemez.
func _input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event.is_action("cancel")):
		if event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			return  # odaktaki düğmeye basma serbest
		get_viewport().set_input_as_handled()
