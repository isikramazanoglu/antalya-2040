extends SceneTree
## Sahip: B. Prompt 8'in 20 testi: İklim Laboratuvarı (A–D), sözlük, eğitim kartları, öğrenme görevleri.
## Pencere gerektirir: <godot> --path . --resolution 1280x720 --script res://tests/test_education.gd (ayrıca 1920x1080)

var f := 0
var fails := 0
var bus: Node
var gs: Node
var cat: Node
var lab: Node
var edu: Node


func _initialize() -> void:
	change_scene_to_file("res://scenes/main/Game.tscn")


func _check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  HATA ") + m)
	if not c:
		fails += 1


func _text(tab: String) -> String:
	lab.open_tab(tab)
	var t := ""
	for r in lab.find_children("*", "RichTextLabel", true, false):
		if r.is_visible_in_tree():
			t += r.get_parsed_text() + "\n"
	return t


func _build(plot: StringName, kind: StringName, id: StringName) -> void:
	bus.plot_selected.emit(plot, kind, true)
	bus.build_requested.emit(plot, id)


func _overflow() -> Array:
	var screen := root.get_visible_rect().grow(1.0)
	var out := []
	for c in current_scene.get_node("UI").find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.size != Vector2.ZERO and not screen.encloses(c.get_global_rect()) and not _in_scroll(c):
			out.append(c.name)
	return out


func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer or p is RichTextLabel:
			return true
		p = p.get_parent()
	return false


func _process(_d: float) -> bool:
	f += 1
	match f:
		20:
			bus = root.get_node("EventBus")
			gs = root.get_node("GameState")
			cat = root.get_node("Catalog")
			lab = current_scene.get_node("UI/ClimateLab")
			edu = current_scene.get_node("UI/EducationCard")
			current_scene.get_node("UI/HUD").find_child("LabButton", true, false).pressed.emit()
		30:
			_check(lab.visible, "1) İklim Laboratuvarı açıldı")
			var a := _text("A · Emisyonlar")
			_check(a.contains("Yerel emisyon endeksi") and a.contains(str(roundi(gs.stats.emissions_total))) and a.contains("tCO₂e değildir"), "2) emisyon endeksi doğru ve tCO₂e olmadığı yazıyor")
			_check(a.contains("OYUN SİMÜLASYONU") and not a.contains("BİLİMSEL ÖLÇÜM"), "4) A bölümü oyun simülasyonu etiketli")
			lab.close()
			_build(&"O01", &"open", &"solar_plant")
		45:
			_check(edu.visible and edu.find_child("EduTitle", true, false).text == cat.get_building(&"solar_plant").info_card.title, "10) güneş yatırımından sonra güneş bilgi kartı açıldı")
			edu.hide()
			edu._on_build_approved(&"O01", &"solar_plant")
			_check(not edu.visible, "11) aynı kart ikinci kez açılmadı")
			var c := _text("C · Kaynaklar")
			_check(c.contains("Yenilenebilir üretim") and c.contains("yenilenebilir payı %40") and c.contains("Şebeke"), "3) güneş sonrası enerji bölümü güncel (pay %40)")
			var chart = lab.find_child("ResourceChart", true, false)
			_check(chart and chart.series[1].values[-1] == gs.stats.renewable_energy, "15) enerji grafiği GameState değerini çiziyor (%d)" % gs.stats.renewable_energy)
			_check(c.contains("Su arzı %d" % roundi(gs.stats.water_supply)) and c.contains("su talebi %d" % roundi(gs.stats.water_demand)), "7) su arzı ve talebi doğru")
			_check(c.contains("Atık kaynaklı emisyon: %d" % roundi(gs.stats.emissions_by_sector.waste)) and c.contains("Toplam atık miktarı (ton) simülasyonda yok"), "8) atık göstergesi gerçek veriden; olmayan veri uydurulmuyor")
			var b := _text("B · Küresel CO₂")
			_check(b.contains("ppm") and b.contains("BİLİMSEL ÖLÇÜM") and b.contains("NOAA"), "5/19) CO₂ grafiği ppm, bilimsel ölçüm etiketi ve NOAA kaynağıyla")
			_check(b.contains("Gelecek senaryosu verisi henüz eklenmedi") and gs.stats.global_co2_ppm == -1.0, "6) gelecek için uydurma ppm yok, açıklama var")
			_check(b.contains("anında değişmez"), "4) yerel emisyon ile küresel CO₂ ayrı anlatılıyor")
			var d := _text("D · Riskler ve dayanıklılık")
			var b_cfg: BalanceConfig = cat.data.balance
			var raw := roundi(ClimateSimulator.raw_risk(&"heat", gs.stats.year, b_cfg))
			_check(d.contains("Aşırı sıcak dayanıklılığı") and d.contains("ham risk %d" % raw) and d.contains("Öneri"), "9) risk bölümü ClimateSimulator ile aynı (sıcak ham risk %d)" % raw)
			var gl := _text("Sözlük")
			_check(gl.contains("Kaynak:") and gl.contains("Oyundaki bağlantısı"), "14/19) sözlük açıldı, kavramda kaynak ve oyun bağlantısı var")
			lab.find_child("Sözlük", true, false).find_children("*", "Button", true, false)[5].pressed.emit()
			_check(edu.viewed_terms.size() == 2, "13a) incelenen kavramlar sayılıyor (%d)" % edu.viewed_terms.size())
			var missing := []
			for g in cat.data.glossary:
				if g.sources.is_empty():
					missing.append(g.id)
			_check(missing.is_empty() and cat.data.glossary.size() >= 16, "19) %d kavramın hepsi kaynaklı" % cat.data.glossary.size())
			lab.close()
			bus.end_turn_requested.emit()
		60:
			_check(gs.missions.get(&"learn_clean_energy") == &"done", "12) \"Temiz enerjiye geçiş\" görevi tamamlandı")
			bus.report_closed.emit()
			current_scene.get_node("UI/HUD").find_child("CityInfoButton", true, false).pressed.emit()
		70:
			current_scene.get_node("UI/HUD").find_child("GlossaryButton", true, false).pressed.emit()
		80:
			_check(lab.visible and lab.find_child("Tabs", true, false).current_tab == 4, "14) \"Bilgi arşivi\" düğmesi sözlüğü açtı")
			var l := _text("Öğrenme")
			_check(l.contains("Tamamlandı · Temiz enerjiye geçiş") and l.contains("öğrendiğini ölçmez"), "13/16) görev durumu korunuyor; ilerleme öğrenme ölçümü değil diye yazıyor")
			_check(edu.progress().sections_viewed == 4 and edu.progress().cards_seen == 1, "16) panel değişince ilerleme korunuyor (4 bölüm, 1 kart)")
			var font: Font = lab.get_theme_default_font()
			var miss := ""
			for ch in "ğüşıöçİĞÜŞÖÇ₂":
				if not font.has_char(ch.unicode_at(0)):
					miss += ch
			_check(miss == "", "17) Türkçe karakterler ve ₂ yazı tipinde var %s" % miss)
			_check(_overflow().is_empty(), "18) Laboratuvar açıkken taşma yok %s" % str(_overflow()))
			lab.close()
			bus.end_turn_requested.emit()
		90:
			_check(gs.phase == &"report" and gs.stats.credits >= 0, "20) yıl akışı bozulmadı")
			print("SONUÇ: ", "TAMAM" if fails == 0 else "%d HATA" % fails)
			quit(1 if fails else 0)
			return true
	return false
