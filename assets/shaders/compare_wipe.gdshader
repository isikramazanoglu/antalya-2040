shader_type canvas_item;
// Sahip: A. Final sunumu karşılaştırması: 2040 görüntüsü ekranın solundan `split` oranına kadar çizilir,
// sağında canlı 2052 şehri görünür. Kenarda ince yumuşak geçiş.

uniform float split : hint_range(0.0, 1.0) = 1.0;
uniform float feather = 0.002;

void fragment() {
	float mask = 1.0 - smoothstep(split - feather, split + feather, UV.x);
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(c.rgb, c.a * mask);
}
