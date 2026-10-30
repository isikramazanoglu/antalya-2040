// Sahip: A. Turkuaz Akdeniz suyu: dalga, derinliğe göre renk, kıyıda köpük.
// Deniz (Sea) ve taşkın suyu (DisasterFX/FloodWater) aynı shader'ı farklı parametrelerle kullanır.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.18, 0.80, 0.78, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.33, 0.47, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
// Rengin sığdan derine geçtiği su derinliği (metre).
uniform float depth_fade = 3.0;
uniform float foam_width = 0.5;
uniform float wave_height = 0.08;
uniform float wave_speed = 0.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.06;
uniform float normal_scale = 0.05;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.7;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = sin(wp.x * 0.35 + t * 1.3) * 0.6
			+ sin(wp.z * 0.5 - t * 1.7) * 0.4
			+ sin((wp.x + wp.z) * 0.9 + t * 2.3) * 0.2;
	VERTEX.y += h * wave_height;
	world_pos = wp;
}

void fragment() {
	vec2 uv1 = world_pos.xz * normal_scale + vec2(TIME * 0.020, TIME * 0.012);
	vec2 uv2 = world_pos.xz * normal_scale * 1.7 - vec2(TIME * 0.015, -TIME * 0.020);
	NORMAL_MAP = mix(texture(normal_a, uv1).rgb, texture(normal_b, uv2).rgb, 0.5);
	NORMAL_MAP_DEPTH = 0.6;

	// Suyun altındaki zeminin uzaklığı (Forward+, ters z).
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(-view.z - (-VERTEX.z), 0.0);

	float d = clamp(water_depth / depth_fade, 0.0, 1.0);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, d);
	float foam = 1.0 - smoothstep(0.0, foam_width, water_depth);
	foam *= 0.65 + 0.35 * sin(TIME * 2.0 + world_pos.x * 1.5 + world_pos.z);
	ALBEDO = mix(color, foam_color.rgb, clamp(foam, 0.0, 1.0));
	ALPHA = mix(min_alpha, 1.0, d);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.6;
}
