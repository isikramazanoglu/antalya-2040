extends CrisisEffect
## Sahip: A. Aşırı sıcak: güneş ve sis ölçülü biçimde ısınır, uzak bölgelerde ısı pusu.
## Serinleme merkezi ve park gibi sıcağa karşı koruyan binaların çevresinde serin turkuaz hare.
## Şehir turuncuya boyanmaz; parklar kurumaz (bina materyallerine dokunulmaz).

const HEAT_SUN := Color(1.0, 0.78, 0.55)
const HEAT_FOG := Color(1.0, 0.8, 0.6)

@onready var _haze_layer: CanvasLayer = $HeatHaze
@onready var _haze: ColorRect = $HeatHaze/Haze


func contribute(a: Dictionary) -> void:
	var s := strength()
	# Görsel revizyon 3: taban güneşi artık daha parlak ve sıcak; katkılar buna göre ölçülü (turuncuya boyamaz).
	a.sun_color = (a.sun_color as Color).lerp(HEAT_SUN, s * 0.3)
	a.sun_energy *= 1.0 + 0.08 * s
	a.fog_color = (a.fog_color as Color).lerp(HEAT_FOG, s * 0.45)
	a.fog_density += 0.0016 * s
	a.saturation *= 1.0 + 0.04 * s
	a.contrast *= 1.0 + 0.04 * s
	a.weight = maxf(a.weight, s)


func apply_local() -> void:
	var s := strength()
	_haze_layer.visible = s > 0.01
	(_haze.material as ShaderMaterial).set_shader_parameter("strength", s)
