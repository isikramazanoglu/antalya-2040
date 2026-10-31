// Sahip: A. Sıcak hava dalgası: ekranın 3D kısmına ısı pusu ve sıcak renk tonu.
// DisasterFX/HeatHaze katmanında; arayüz katmanının altında kalır, fareyi engellemez.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.32, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// Pus uzak bölgelerde (ekranın üst kısmı) belirgin, yakında neredeyse yok; şehir okunur kalır.
	float mask = 1.0 - smoothstep(0.05, 0.6, uv.y);
	float wave = sin(uv.y * 140.0 + TIME * 5.0) * cos(uv.x * 90.0 + TIME * 3.5);
	uv += vec2(wave * 0.0022, wave * 0.0012) * strength * mask;
	vec3 c = texture(screen_tex, uv).rgb;
	c = mix(c, c * tint.rgb * 1.3, 0.15 * strength);
	COLOR = vec4(c, 1.0);
}
