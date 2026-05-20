shader_type canvas_item;

// 预警区域 Shader — 从外向内渐显填充 + 脉冲呼吸 + 边框高亮
// 用于 BOSS 施法前的地面预警区域

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0=开始, 1=完全填充
uniform vec4 fill_color : source_color = vec4(1.0, 0.2, 0.2, 0.3);
uniform vec4 border_color : source_color = vec4(1.0, 0.3, 0.3, 0.8);
uniform float border_width : hint_range(0.0, 0.2) = 0.03;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	// 填充：从外向内填充
	float fill = smoothstep(1.0, progress, dist);
	// 边框
	float border = smoothstep(1.0 - border_width, 1.0, dist);
	// 脉冲
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	COLOR = mix(fill_color, border_color, border);
	COLOR.a *= fill * (0.5 + 0.5 * pulse);
}
