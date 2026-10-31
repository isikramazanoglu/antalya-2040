class_name GlossaryTerm
extends Resource
## İklim sözlüğü kavramı (Prompt 8). Sahip: B. Kaynaklar doğrulanmadan eklenmez.

@export var id: StringName
@export var title: String
@export_multiline var definition: String
@export_multiline var example: String
## Oyunda nerede karşılaşıldığı.
@export_multiline var game_link: String
## Her satır: "Kurum, belge adı, yıl/kapsam, URL, erişim tarihi"
@export var sources: Array[String] = []
