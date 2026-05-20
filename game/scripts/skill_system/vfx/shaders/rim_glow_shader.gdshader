shader_type canvas_item;

// 边缘发光 Shader — 命中后目标身体边缘短暂发光
// 基于 alpha 通道梯度检测边缘，叠加发光色

uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = smoothstep(0.3, 0.5, tex.a) * (1.0 - smoothstep(0.7, 1.0, tex.a));
	COLOR = tex;
	COLOR.rgb += rim_color.rgb * edge * rim_strength;
}
