class_name BalanceConfig
extends Resource
## Başlangıç değerleri ve katsayılar. Sayılar docs/GAME_DESIGN.md §3-4'ten. Sahip: B.

@export_group("Takvim")
@export var start_year: int = 2040
@export var end_year: int = 2052
## Ayın gerçek zamanda süresi (sn, hız ×1). İklim ve ekonomi hesapları yıllık kalır; ay yalnızca takvimdir.
@export var seconds_per_month: float = 4.0

@export_group("Başlangıç")
@export var start_credits: int = 1000
@export var start_population: int = 500
@export var start_water_security: float = 60.0
@export var start_energy_security: float = 50.0
@export var start_quality_of_life: float = 50.0
@export var start_ecosystem_health: float = 60.0

@export_group("Ekonomi")
@export var tax_per_capita: float = 0.5
@export var city_base_upkeep: int = 100
@export var population_growth_pivot: float = 45.0
@export var population_growth_divisor: float = 1000.0
@export var population_growth_min: float = -0.03
@export var population_growth_max: float = 0.04

@export_group("Kaynak akışları")
## Kişi başı yıllık enerji ve su talebi (oyun birimi). Talebin yenilenebilirle karşılanmayan kısmı şebekeden (fosil) gelir.
@export var energy_per_capita: float = 0.1
@export var water_per_capita: float = 0.1
## Binalardan bağımsız mevcut su arzı (baraj, kuyu).
@export var base_water_supply: float = 55.0
## Su talebinin içme dışı (sulama, temizlik) kısmı: geri kazanılmış su en fazla bu kadarını karşılar.
@export var non_potable_water_share: float = 0.3

@export_group("İklim")
## 500 nüfus için sektör taban emisyonu (oyun birimi).
@export var base_emissions: Dictionary = {"energy": 40.0, "transport": 25.0, "buildings": 20.0, "waste": 15.0}
@export var emission_floor: float = 0.2
@export var start_risks: Dictionary = {"drought": 40.0, "heat": 45.0, "coastal_flood": 30.0}
@export var risk_growth_per_year: Dictionary = {"drought": 2.0, "heat": 2.0, "coastal_flood": 1.5}
@export var max_mitigation: float = 0.8

@export_group("İşletmeler ve çevre denetimi (Prompt 13)")
## Sanayi bölgesindeki yerler. Görsel konumları Ekip A belirler (docs/BUSINESS_SYSTEM.md).
@export var industrial_sites: Array[StringName] = [&"I01", &"I02", &"I03", &"I04", &"I05", &"I06", &"I07", &"I08"]
@export var max_businesses: int = 8
## Uygun koşullarda her ay yeni işletme gelme olasılığı (nüfus, boş yer ve doluluğa göre ölçeklenir).
@export var business_spawn_chance: float = 0.08
## Hava kirliliği endeksi bunu aşarsa çok kirleten türlerin gelme olasılığı düşer.
@export var air_pollution_soft_cap: float = 50.0
## İşletmelerin hava ve atık yükünün 0–100 endekslere çevrilmesi.
@export var air_index_per_unit: float = 2.5
@export var waste_index_per_unit: float = 2.0
## Endekslerin yıllık etkisi (endeks puanı başına).
@export var air_quality_of_life_per_point: float = 0.03
@export var waste_ecosystem_per_point: float = 0.03
## Denetim kapasitesi: her ay ücretsiz hak, ek denetim bedeli, aynı işletmeyi yeniden denetleme aralığı (ay).
@export var inspections_per_month: int = 3
@export var extra_inspection_cost: int = 20
@export var inspection_cooldown_months: int = 3
## Oyun standartları (gerçek mevzuat değil): hava ve atık yükü bunları aşarsa ihlal.
@export var air_standard: float = 4.0
@export var waste_standard: float = 4.0
## Ceza = taban × büyüklük × seviye çarpanı × (1 + önceki cezalar × tekrar katsayısı), en çok tavan.
@export var fine_base: int = 5
@export var fine_level_multipliers: Array[float] = [0.0, 1.0, 2.0, 3.0, 5.0]
@export var fine_repeat_factor: float = 0.5
@export var fine_cap: int = 120
## Aynı işletmeye bir takvim yılında en çok bu kadar ceza (ceza bir gelir kaynağına dönüşmesin).
@export var fines_per_business_per_year: int = 1
## Kararların süresi (ay) ve etkisi (ilgili kirleticiyi bu oranda azaltır; sıfırlamaz).
@export var order_months: Dictionary = {"filter": 4, "clean_energy": 6, "treatment": 4, "grace": 3}
@export var order_reduction: Dictionary = {"filter": 0.6, "clean_energy": 0.6, "treatment": 0.6}
## Dönüşüm sürerken işletmenin belediyeye katkısındaki düşüş (yatırım maliyetini işletme öder).
@export var order_contribution_cut: float = 0.3
## Faaliyeti durdurulan işletmenin kalan emisyon payı ve çalışan başına yaşam kalitesi kaybı.
@export var suspended_emission_share: float = 0.1
@export var quality_loss_per_100_employees: float = 2.0
## Durdurulmuş işletme bu kadar ay sonra kapanır.
@export var closure_after_suspended_months: int = 12
## Yıllık üretim dalgalanması (±).
@export var production_drift: float = 0.1
