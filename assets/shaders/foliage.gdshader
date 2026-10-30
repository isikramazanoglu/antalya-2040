// Sahip: A. Ağaç tacı ve palmiye yaprağı: düz renk + çok hafif rüzgâr salınımı.
// Dekor MultiMesh ile çizilir; her ağaç dünya konumuna göre farklı fazda sallanır.
// DisasterFX kuraklıkta `albedo` parametresini sarı tona çeker.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.42, 0.52, 0.26, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
// Mesh'in tepesindeki en büyük kayma (mesh birimi).
uniform float sway = 0.05;
uniform float speed = 1.1;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// Birim mesh'ler merkezde; alt kısım sabit, tepe daha çok sallanır.
	float weight = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float t = TIME * speed + origin.x * 0.31 + origin.z * 0.17;
	VERTEX.x += sin(t) * sway * weight;
	VERTEX.z += cos(t * 0.8) * sway * 0.6 * weight;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness_value;
}
