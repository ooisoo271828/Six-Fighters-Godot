shader_type canvas_item;

/// Dissolve Shader — 基于噪声或径向距离的溶解消散效果
///
/// dissolve_mode:
///   0 = 噪声溶解（默认，随机消散）
///   1 = 边缘→中心溶解（从外圈往内圈逐步溶解）

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;  // 0=完整, 1=完全溶解
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);  // 溶解边缘颜色
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // 基础颜色
uniform float edge_width : hint_range(0.0, 0.3) = 0.05;
uniform sampler2D noise_texture;  // 外部噪声纹理
uniform int dissolve_mode : hint_range(0, 1) = 0;  // 0=噪声, 1=边缘→中心
uniform vec2 center = vec2(0.5, 0.5);  // 径向溶解的中心点

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float noise = texture(noise_texture, UV).r;

	// 应用基础颜色
	vec4 colored = tex * base_color;

	float dissolve_threshold;

	if (dissolve_mode == 1) {
		// 边缘→中心溶解：距离越远越先溶解
		float dist = length(UV - center) * 2.0;
		dissolve_threshold = (1.0 - dist) + noise * 0.15;
		float edge = smoothstep(dissolve_amount - edge_width, dissolve_amount, dissolve_threshold);
		float is_edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, dissolve_threshold) - edge;

		COLOR = colored;
		COLOR.a *= step(dissolve_amount, dissolve_threshold);
		COLOR.rgb += dissolve_color.rgb * is_edge * dissolve_color.a;
		COLOR.a = max(COLOR.a, is_edge * dissolve_color.a);
	} else {
		// 噪声溶解（默认）
		float edge = smoothstep(dissolve_amount - edge_width, dissolve_amount, noise);
		float is_edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise) - edge;

		COLOR = colored;
		COLOR.a *= step(dissolve_amount, noise);
		COLOR.rgb += dissolve_color.rgb * is_edge * dissolve_color.a;
		COLOR.a = max(COLOR.a, is_edge * dissolve_color.a);
	}
}
