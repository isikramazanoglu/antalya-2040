class_name InfoCard
extends Resource
## Bilgi kartı (bina, kriz, İklim Laboratuvarı). Sahip: B.

@export var id: StringName
@export var title: String
@export_multiline var body: String  ## BBCode serbest.
## Yatırım kartı özeti (Prompt 5): üç kısa cümle.
@export var benefit: String  ## Temel fayda
@export var climate_link: String  ## İklim bağlantısı
@export var strategic: String  ## Stratejik avantaj
## Her satır: "Kurum, belge adı, yıl, URL, erişim tarihi". Kaynaksız sayı yazılmaz.
@export var sources: Array[String] = []
