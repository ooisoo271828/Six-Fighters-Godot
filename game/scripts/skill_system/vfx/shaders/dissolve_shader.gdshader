shader_type canvas_item;

/// Dissolve Shader — 基于噪声的溶解消散效果
/// 用于弹体消亡、命中消融等需要"魔法消散"感的场景。
///
/// 使用方式：
///   1. 创建 ShaderMaterial，设置 shader 为此文件
///   2. 设置 noise_texture 为一张噪声纹理（或用 NoiseTexture2D 程序化生成）
///   3. Tween 驱动 dissolve_amount 从 0.0 → 1.0
///   4. 调整 dissolve_color 和 edge_width 控制溶解边缘颜色和宽度

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;  // 0=完整, 1=完全溶解
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);  // 溶解边缘颜色
uniform float edge_width : hint_range(0.0, 0.3) = 0.05;
uniform sampler2D noise_texture;  // 外部噪声纹理

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float noise = texture(noise_texture, UV).r;

	// 噪声值低于溶解阈值的部分被丢弃
	float edge = smoothstep(dissolve_amount - edge_width, dissolve_amount, noise);
	float is_edge = smoothstep(dissolve_amount, dissolve_amount + edge_width, noise) - edge;

	// 基础颜色
	COLOR = tex;

	// 溶解：噪声值低于阈值的像素变为透明
	COLOR.a *= step(dissolve_amount, noise);

	// 溶解边缘高亮：在溶解边界处叠加发光色
	COLOR.rgb += dissolve_color.rgb * is_edge * dissolve_color.a;
	COLOR.a = max(COLOR.a, is_edge * dissolve_color.a);
}
