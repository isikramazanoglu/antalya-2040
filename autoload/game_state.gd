extends Node
## Sahip: B. Oyun verisinin tek kaynağı; hesap ve kural yok.
## Yazma yetkisi yalnızca GameController'da (mimari §3). Diğerleri getter kullanır.

var stats: Dictionary = {}
var plots: Dictionary = {}  # plot_id (StringName) -> building_id (StringName)
var pending_crises: Array = []  # sözleşme §5.2 warning sözlükleri
var history: Array = []  # her yıl sonunun stats kopyası
var missions: Dictionary = {}  # mission id -> &"active" | &"done" | &"failed"
var crisis_log: Array = []  # yaşanan krizlerin sonuçları (+ "year"), İklim Laboratuvarı ve şehir bilgileri için
var build_log: Array = []  # Prompt 10A: {"plot_id", "building_id", "year", "cost"} her onaylanan inşaat
var year_reports: Array = []  # Prompt 10A: her yıl sonu raporunun kopyası (sözleşme §5.4)
var phase: StringName = &"build"
var month: int = 1  # takvim ayı 1–12; yıllık hesapları etkilemez
## Prompt 13: kendiliğinden kurulan işletmeler (docs/BUSINESS_SYSTEM.md §3). Kimlik sayacı ve bu ayki denetim sayısı.
var businesses: Array = []
var business_seq: int = 0
var inspections_used: int = 0
## Zorunlu iklim sorusu: çözülen soru sayısı ve en son çözüldüğü ay (yıl × 12 + ay).
var quiz_count: int = 0
var quiz_done_key: int = 0
## Yol kenarı araç denetimi (teslim MVP): son durdurulan araç ve plaka -> ceza kesilen ay (yıl × 12 + ay).
var vehicle_check: Dictionary = {}
var vehicle_fines: Dictionary = {}
## Kayıttan yüklenen oyunda TurnManager'ın iç durumu (start_game bunu kullanır, sonra boşaltır).
var restored_turn: Dictionary = {}
var restored_education: Dictionary = {}

const SNAPSHOT_KEYS := ["stats", "plots", "pending_crises", "history", "missions", "crisis_log", "build_log",
		"year_reports", "month", "rng_seed", "businesses", "business_seq", "inspections_used", "quiz_count", "quiz_done_key", "vehicle_check", "vehicle_fines"]
var rng_seed: int = 0


func _ready() -> void:
	reset()


func reset() -> void:
	var b: BalanceConfig = Catalog.data.balance
	stats = {
		"year": b.start_year,
		"credits": b.start_credits,
		"population": b.start_population,
		"water_security": b.start_water_security,
		"energy_security": b.start_energy_security,
		"quality_of_life": b.start_quality_of_life,
		"ecosystem_health": b.start_ecosystem_health,
		"emissions_total": 0.0,
		"emissions_by_sector": b.base_emissions.merged({"industry": 0.0}),  # v1.10: işletmelerin sera gazı
		"risks": b.start_risks.duplicate(),
		"global_co2_ppm": -1.0,
		# v1.2 kaynak akışları; değerleri TurnManager.start_game ve her inşaat sonrası EconomySimulator hesaplar.
		"energy_demand": 0.0,
		"renewable_energy": 0.0,
		"renewable_share": 0.0,
		"water_demand": 0.0,
		"water_supply": 0.0,
		"recycled_water": 0.0,
		"recycled_water_used": 0.0,
		"waste_recovery": 0.0,  # v1.9: atık azaltma oranı 0..1
		"climate_resilience": 0.0,  # v1.9: üç risk için ortalama koruma 0..0.8
		"air_pollution": 0.0,  # v1.10: işletmelerden yerel hava kirliliği 0..100 (sera gazından ayrı)
		"waste_pollution": 0.0,  # v1.10: işletmelerden atık ve atık su yükü 0..100
	}
	var total := 0.0
	for value in b.base_emissions.values():
		total += value
	stats["emissions_total"] = total
	plots.clear()
	pending_crises.clear()
	history.clear()
	missions.clear()
	crisis_log.clear()
	build_log.clear()
	year_reports.clear()
	phase = &"build"
	month = 1
	businesses.clear()
	business_seq = 0
	inspections_used = 0
	quiz_count = 0
	quiz_done_key = 0
	vehicle_check = {}
	vehicle_fines = {}
	restored_turn = {}
	restored_education = {}
	rng_seed = randi()
	EventBus.stats_changed.emit(get_stats())


## Kayıt (SaveGame): oyun verisinin tam kopyası.
func to_snapshot() -> Dictionary:
	var d := {}
	for key in SNAPSHOT_KEYS:
		var v = get(key)
		d[key] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d


## Kayıttan yükleme: oyun sahnesi açılmadan önce SaveGame çağırır (GameController henüz yok).
## Eksik anahtar (eski kayıt) varsayılan değerde kalır; yeni oyun gibi sıfırlanıp üstüne yazılır.
func apply_snapshot(d: Dictionary, turn: Dictionary, education: Dictionary) -> void:
	reset()
	for key in SNAPSHOT_KEYS:
		if d.has(key):
			set(key, d[key])
	stats.merge({"air_pollution": 0.0, "waste_pollution": 0.0}, false)
	phase = &"build"
	restored_turn = turn
	restored_education = education
	EventBus.stats_changed.emit(get_stats())


## Sözleşme §4: salt okunur kopya.
func get_stats() -> Dictionary:
	return stats.duplicate(true)


## Sözleşme §4: boşsa &"".
func get_building_on(plot_id: StringName) -> StringName:
	return plots.get(plot_id, &"")


# --- Yazma fonksiyonları: yalnızca GameController çağırır ---

const INDEX_STATS: Array[String] = ["water_security", "energy_security", "quality_of_life", "ecosystem_health"]


## {"credits": -400, "energy_security": 20} gibi değişimleri uygular; göstergeler 0..100 arası kalır.
func apply_deltas(deltas: Dictionary) -> void:
	for key in deltas:
		if key == "credits":
			stats.credits += int(deltas[key])
		elif key == "population":
			stats.population = maxi(0, stats.population + int(deltas[key]))
		elif key in INDEX_STATS:
			stats[key] = clampf(stats[key] + float(deltas[key]), 0.0, 100.0)
		else:
			push_warning("GameState: bilinmeyen gösterge '%s'" % key)
	EventBus.stats_changed.emit(get_stats())


func place_building(plot_id: StringName, building_id: StringName) -> void:
	plots[plot_id] = building_id


func set_phase(new_phase: StringName) -> void:
	phase = new_phase


func set_month(value: int) -> void:
	month = value


## İşletmeyi kimliğiyle günceller ya da ekler (aynı kimlik iki kez kaydedilmez).
func set_business(b: Dictionary) -> void:
	for i in businesses.size():
		if businesses[i].business_id == b.business_id:
			businesses[i] = b
			return
	businesses.append(b)


func remove_business(business_id: StringName) -> void:
	businesses = businesses.filter(func(b): return b.business_id != business_id)


func set_business_counters(seq: int, used: int) -> void:
	business_seq = seq
	inspections_used = used


func get_business(business_id: StringName) -> Dictionary:
	for b in businesses:
		if b.business_id == business_id:
			return b.duplicate(true)
	return {}


func advance_year() -> void:
	month = 1
	stats.year += 1
	EventBus.stats_changed.emit(get_stats())


func record_history() -> void:
	history.append(get_stats())


## İklim adımının hesapladığı değerler (delta değil, yeni değer).
func set_climate(climate: Dictionary) -> void:
	stats.emissions_by_sector = climate.emissions_by_sector
	stats.emissions_total = climate.emissions_total
	stats.risks = climate.risks
	stats.global_co2_ppm = climate.global_co2_ppm
	EventBus.stats_changed.emit(get_stats())


## Kaynak akışlarının yeni değerleri (delta değil).
func set_resources(resources: Dictionary) -> void:
	stats.merge(resources, true)
	EventBus.stats_changed.emit(get_stats())


func set_mission_state(mission_id: StringName, state: StringName) -> void:
	missions[mission_id] = state


func log_build(entry: Dictionary) -> void:
	build_log.append(entry)


func record_report(report: Dictionary) -> void:
	year_reports.append(report.duplicate(true))


func log_crisis(result: Dictionary) -> void:
	crisis_log.append(result)


func add_pending(warning: Dictionary) -> void:
	pending_crises.append(warning)


func remove_pending(warning: Dictionary) -> void:
	pending_crises.erase(warning)


# --- Salt okunur yardımcılar ---

## Kurulu binalar + etkin kombinasyonlar (SynergyDefinition). Simülatörler bu tek listeyi kullanır.
func built_definitions() -> Array[BuildingDefinition]:
	var result: Array[BuildingDefinition] = []
	var ids := plots.values()
	for building_id in ids:
		var def := Catalog.get_building(building_id)
		if def:
			result.append(def)
	for syn in Catalog.data.synergies:
		if syn.requires.all(func(id): return ids.has(id)):
			result.append(syn)
	return result
