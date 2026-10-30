class_name InfoCard
extends Resource
## Bilgi kartı (bina, kriz, İklim Laboratuvarı). Sahip: B.

@export var id: StringName
@export var title: String
@export_multiline var body: String  ## BBCode serbest.
## Her satır: "Kurum, belge adı, yıl, URL, erişim tarihi". Kaynaksız sayı yazılmaz.
@export var sources: Array[String] = []
