shader_type canvas_item;

/// Glow Shader — 基于 alpha 通道的边缘发光效果
/// 用于弹体核心层、命中闪光等需要自发光感的场景。
///
/// 使用方式：
///   1. 创建 ShaderMaterial，设置 shader 为此文件
///   2. 设置 glow_color 为期望的发光颜色
///   3. 调整 glow_strength 和 glow_radius 控制强度和范围
///   4. 如需呼吸效果，设置 pulse_speed > 0

uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float glow_strength : hint_range(0.0, 3.0) = 1.5;
uniform float glow_radius : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;  // 0 = no pulse
uniform float time_offset : hint_range(0.0, 6.28) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	// 边缘检测：alpha 梯度越大 = 越接近边缘
	// smoothstep 在 alpha 的低值和高值区间各做一个过渡
	// 两者相乘得到"边缘区域"的遮罩
	float edge = smoothstep(0.0, 0.3, alpha) * (1.0 - smoothstep(0.7, 1.0, alpha));

	// 呼吸脉冲（pulse_speed > 0 时启用）
	float pulse = pulse_speed > 0.0 ? 0.5 + 0.5 * sin(TIME * pulse_speed + time_offset) : 1.0;

	// 混合：原始颜色 + 发光颜色 × 边缘遮罩 × 强度 × 脉冲
	COLOR = mix(tex, glow_color, edge * glow_strength * pulse);

	// alpha 通道：保留原始透明度 + 边缘区域增加半透明发光
	COLOR.a = alpha + edge * glow_strength * pulse * 0.5;
}
