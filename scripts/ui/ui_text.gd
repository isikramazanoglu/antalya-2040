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
	&"not_enough_credits": "Bütçe yetmiyor.",
	&"plot_occupied": "Bu arsa dolu.",
	&"wrong_plot_kind": "Bu yatırım bu arsa türüne yapılamaz.",
	&"max_count_reached": "Bu yatırımdan zaten var.",
	&"wrong_phase": "Şu an inşaat yapılamaz.",
	&"unknown_building": "Tanımsız yatırım.",
}


static func format_value(value) -> String:
	if value is float:
		return str(roundi(value))
	return str(value)


static func format_delta(value: float) -> String:
	var n := roundi(value)
	return ("+%d" % n) if n > 0 else str(n)
