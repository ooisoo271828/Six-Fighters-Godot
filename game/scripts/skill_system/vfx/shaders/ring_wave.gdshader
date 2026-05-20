shader_type canvas_item;

/// Ring Wave Shader — 扩散环形冲击波
/// 用于命中冲击、AOE 范围指示等需要"波纹扩散"感的场景。
///
/// 使用方式：
///   1. 创建 ShaderMaterial，设置 shader 为此文件
///   2. Tween 驱动 progress 从 0.0 → 1.0
///   3. 调整 ring_color、ring_width、fade_start 控制外观
///   4. 搭配 ColorRect 使用（覆盖目标区域）

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0=中心, 1=完全扩散
uniform vec4 ring_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float ring_width : hint_range(0.01, 0.5) = 0.08;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;  // 开始淡出的进度

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;  // 归一化到 0-1

	// 环形：距离在 [progress - width, progress + width] 范围内
	float ring = smoothstep(progress - ring_width, progress, dist)
		- smoothstep(progress, progress + ring_width, dist);

	// 淡出：progress 超过 fade_start 后逐渐透明
	float fade = 1.0 - smoothstep(fade_start, 1.0, progress);

	COLOR = ring_color;
	COLOR.a = ring * fade;
}
