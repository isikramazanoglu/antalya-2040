class_name UiText
extends RefCounted
## Sahip: B. Arayüzde görünen Türkçe adlar tek yerde.

const STAT_NAMES := {
	"credits": "Kredi",
	"population": "Nüfus",
	"water_security": "Su güvenliği",
	"energy_security": "Enerji güvenliği",
	"quality_of_life": "Yaşam kalitesi",
	"ecosystem_health": "Ekosistem",
	"emissions_total": "Emisyon",
}

const PLOT_KINDS := {&"urban": "Kent arsası", &"open": "Açık alan", &"coastal": "Kıyı arsası"}

const REJECT_REASONS := {
	&"not_enough_credits": "Bu yatırımı gerçekleştirmek için yeterli bütçen yok.",
	&"plot_occupied": "Bu inşaat alanı zaten kullanılıyor.",
	&"wrong_plot_kind": "Seçilen arsa bu yatırım türüne uygun değil.",
	&"max_count_reached": "Bu yatırımdan zaten var.",
	&"wrong_phase": "Şu an inşaat yapılamaz.",
	&"unknown_building": "Tanımsız yatırım.",
	&"scene_unavailable": "Bu yatırımın şehir modeli yüklenemedi; işlem yapılmadı.",
	&"unknown_plot": "Seçilen inşaat alanı bulunamadı.",
}


static func format_value(value) -> String:
	if value is float:
		return str(roundi(value))
	return str(value)


static func format_delta(value: float) -> String:
	var n := roundi(value)
	return ("+%d" % n) if n > 0 else str(n)


# --- Prompt 5: ortak görsel dil ---

const C_GOOD := Color(0.42, 0.82, 0.52)
const C_WARN := Color(0.98, 0.82, 0.35)
const C_HIGH := Color(1.0, 0.6, 0.3)
const C_CRIT := Color(1.0, 0.4, 0.38)
const C_INFO := Color(0.45, 0.72, 1.0)
const C_ACCENT := Color(0.3, 0.85, 0.82)
const C_MUTED := Color(0.85, 0.88, 0.87, 0.7)

const PLOT_KIND_SHORT := {&"urban": "kent", &"open": "açık alan", &"coastal": "kıyı"}
const CATEGORY_THEME := {
	&"energy": "Temiz enerji", &"water": "Su güvenliği", &"heat": "Aşırı sıcağa uyum", &"food": "Gıda ve döngüsel ekonomi",
	&"waste": "Atık ve döngüsel ekonomi", &"transport": "Sürdürülebilir ulaşım", &"coast": "Kıyı ekosistemi ve uyum", &"synergy": "Kombinasyon",
}
const SECTOR_NAMES := {"energy": "Enerji", "transport": "Ulaşım", "buildings": "Binalar", "waste": "Atık"}
const RISK_NAMES := {"drought": "Kuraklık", "heat": "Aşırı sıcak", "coastal_flood": "Kıyı taşkını"}


## 0-100 gösterge için durum: renk tek başına anlam taşımasın diye yazıyla birlikte döner.
static func status(value: float) -> Array:
	if value >= 70.0:
		return ["İyi", C_GOOD]
	if value >= 50.0:
		return ["Orta", C_WARN]
	if value >= 30.0:
		return ["Yüksek risk", C_HIGH]
	return ["Kritik", C_CRIT]


## 1000 → "1.000", -250 → "-250"
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func delta_color(value: float, higher_is_better := true) -> Color:
	if is_zero_approx(value):
		return C_MUTED
	return C_GOOD if (value > 0.0) == higher_is_better else C_CRIT


static func icon(name: String) -> Texture2D:
	return load("res://assets/ui/icons/%s.svg" % name)


## Panel açılışı: hafif büyüyerek belirir. Animasyon işlemi bekletmez.
static func pop_in(control: Control) -> void:
	control.show()
	control.pivot_offset = control.size / 2.0
	control.modulate.a = 0.0
	control.scale = Vector2(0.97, 0.97)
	var t := control.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(control, "modulate:a", 1.0, 0.16)
	t.tween_property(control, "scale", Vector2.ONE, 0.16)
