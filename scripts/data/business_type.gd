class_name BusinessType
extends Resource
## Sahip: B. Oyuncunun kurmadığı, şehir büyüdükçe sanayi yerlerine kendiliğinden gelen işletme türü (Prompt 13).
## Bütün sayılar oyun dengeleme değeridir; gerçek emisyon ya da mevzuat sınırı değildir (docs/BUSINESS_SYSTEM.md).

@export var id: StringName
@export var display_name: String
## Görsel eşleştirme anahtarı (Ekip A modeli bunu kullanır): ör. &"Industrial_SmallFactory".
@export var visual_id: StringName
## 1 küçük, 2 orta, 3 büyük: ceza ve çalışan etkisini ölçekler.
@export_range(1, 3) var size: int = 1
@export var employees: int = 40
## Belediyeye yıllık katkı (kredi, vergi ve harç).
@export var yearly_contribution: int = 20
## Yıllık enerji ve su tüketimi (oyun birimi; şehir talebine eklenir).
@export var energy_use: float = 2.0
@export var water_use: float = 1.0
## Sera gazı: karbon salımına "sanayi" kalemi olarak eklenir (oyun birimi).
@export var ghg: float = 2.0
## Bunun ne kadarı enerji kaynaklı (temiz enerjiye geçişle azalabilen kısım), 0..1.
@export_range(0.0, 1.0) var ghg_energy_share: float = 0.5
## Yerel hava kirliliği ve atık/atık su yükü (0–10 oyun ölçeği). Denetim standartları bunlarla karşılaştırılır.
@export var air: float = 3.0
@export var waste: float = 2.0
## Kurulma ağırlığı ve en az nüfus.
@export var spawn_weight: float = 1.0
@export var min_population: int = 450
## "Lojistik" türleri nüfus büyüdükçe daha olası.
@export var logistics := false
@export_multiline var description: String
