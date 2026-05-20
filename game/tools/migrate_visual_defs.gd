@tool
extends RefCounted

## 迁移脚本：将 SkillVisualDef 的旧格式 .tres 拆分为子 Resource 文件
## 用法：通过 Hastur 插件执行此脚本

func execute(ctx):
	var base_path := "res://resources/skills/skill_visual_defs/"
	var skills := ["fireball_basic", "missile_storm"]

	for skill_id in skills:
		var tres_path: String = base_path + skill_id + ".tres"
		if not ResourceLoader.exists(tres_path):
			ctx.output("SKIP", skill_id + " not found")
			continue

		var vis := ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if vis == null:
			ctx.output("FAIL", "load " + skill_id)
			continue

		# ── 创建 ProjectileVisual ──
		var pv := ProjectileVisual.new()
		pv.core_color = vis.core_color
		pv.core_width = vis.core_width
		pv.core_height = vis.core_height
		pv.core_radius = vis.core_radius
		pv.inner_enabled = vis.core_inner_enabled
		pv.inner_color = vis.core_inner_color
		pv.inner_width = vis.core_inner_width
		pv.inner_height = vis.core_inner_height
		pv.inner_offset = vis.core_inner_offset
		pv.hotspot_enabled = vis.core_hotspot_enabled
		pv.hotspot_color = vis.core_hotspot_color
		pv.hotspot_width = vis.core_hotspot_width
		pv.hotspot_height = vis.core_hotspot_height
		pv.hotspot_offset = vis.core_hotspot_offset
		pv.nose_enabled = vis.core_nose_enabled
		pv.nose_color = vis.core_nose_color
		pv.nose_length = vis.core_nose_length
		pv.nose_width = vis.core_nose_width
		pv.glow_radius = vis.core_glow_radius
		pv.glow_color = vis.core_glow_color
		pv.glow_alpha = vis.core_glow_alpha
		pv.glow2_radius = vis.core_glow2_radius
		pv.glow2_color = vis.core_glow2_color
		pv.glow2_alpha = vis.core_glow2_alpha
		pv.jitter_enabled = vis.jitter_enabled
		pv.jitter_amplitude = vis.jitter_amplitude
		pv.jitter_freq_x = vis.jitter_freq_x
		pv.jitter_freq_y = vis.jitter_freq_y
		pv.tex_core_path = vis.tex_core_path
		pv.tex_glow_path = vis.tex_glow_path
		pv.tex_explosion_path = vis.tex_explosion_path
		pv.tex_nose_path = vis.tex_nose_path
		pv.projectile_scale = vis.projectile_scale

		var pv_path: String = base_path + skill_id + "_projectile.tres"
		ResourceSaver.save(pv, pv_path)
		ctx.output("SAVED", pv_path)

		# ── 创建 TrailVisual ──
		var tv := TrailVisual.new()
		tv.trail_enabled = vis.trail_particle_enabled
		tv.trail_count = vis.trail_particle_count
		tv.trail_lifetime = vis.trail_particle_lifetime
		tv.trail_back_dist_min = vis.trail_back_dist_min
		tv.trail_back_dist_max = vis.trail_back_dist_max
		tv.trail_spread_min = vis.trail_spread_min
		tv.trail_spread_max = vis.trail_spread_max
		tv.trail_radius_min = vis.trail_radius_min
		tv.trail_radius_max = vis.trail_radius_max
		tv.trail_color_1 = vis.trail_color_1
		tv.trail_color_2 = vis.trail_color_2
		tv.trail_color_3 = vis.trail_color_3
		tv.trail_life_min = vis.trail_life_min
		tv.trail_life_max = vis.trail_life_max
		tv.tex_trail_path = vis.tex_trail_path if vis.tex_trail_path != "" else vis.trail_texture_path
		tv.flame_enabled = vis.front_flame_enabled
		tv.flame_count = vis.front_flame_count
		tv.flame_inner_min = vis.front_flame_inner_min
		tv.flame_inner_max = vis.front_flame_inner_max
		tv.flame_outer_min = vis.front_flame_outer_min
		tv.flame_outer_max = vis.front_flame_outer_max
		tv.flame_color_1 = vis.front_flame_color_1
		tv.flame_color_2 = vis.front_flame_color_2
		tv.flame_life_min = vis.front_flame_life_min
		tv.flame_life_max = vis.front_flame_life_max
		tv.tex_flame_path = vis.tex_front_flame_path
		tv.comet_enabled = vis.comet_enabled
		tv.comet_max_samples = vis.comet_max_samples
		tv.comet_outer_width = vis.comet_outer_width
		tv.comet_outer_color = vis.comet_outer_color
		tv.comet_outer_alpha = vis.comet_outer_alpha
		tv.comet_mid_width = vis.comet_mid_width
		tv.comet_mid_color = vis.comet_mid_color
		tv.comet_mid_alpha = vis.comet_mid_alpha
		tv.comet_inner_width = vis.comet_inner_width
		tv.comet_inner_color = vis.comet_inner_color
		tv.comet_inner_alpha = vis.comet_inner_alpha
		tv.comet_sway_freq = vis.comet_sway_freq
		tv.comet_sway_amplitude = vis.comet_sway_amplitude
		tv.comet_width_fade_start = vis.comet_width_fade_start
		tv.comet_width_fade_mid = vis.comet_width_fade_mid
		tv.comet_width_fade_end = vis.comet_width_fade_end

		var tv_path: String = base_path + skill_id + "_trail.tres"
		ResourceSaver.save(tv, tv_path)
		ctx.output("SAVED", tv_path)

		# ── 创建 ImpactVisual ──
		var iv := ImpactVisual.new()
		iv.spark_count_min = vis.impact_spark_count_min
		iv.spark_count_max = vis.impact_spark_count_max
		iv.spark_speed_min = vis.impact_speed_min
		iv.spark_speed_max = vis.impact_speed_max
		iv.spark_life_min = vis.impact_life_min
		iv.spark_life_max = vis.impact_life_max
		iv.spark_color = vis.impact_color
		iv.spark_particle_count = vis.impact_particle_count
		iv.spark_lifetime = vis.impact_lifetime
		iv.spark_radius_mult = vis.impact_radius_mult
		iv.shake_strength = vis.impact_shake_strength
		iv.shake_duration = vis.impact_shake_duration
		iv.impact_effect_kind = vis.impact_effect_kind

		var iv_path: String = base_path + skill_id + "_impact.tres"
		ResourceSaver.save(iv, iv_path)
		ctx.output("SAVED", iv_path)

		# ── 创建 VFXOverride ──
		var vo := VFXOverride.new()
		vo.tier_A = vis.hit_vfx_tier_A
		vo.tier_B = vis.hit_vfx_tier_B
		vo.tier_C = vis.hit_vfx_tier_C
		vo.custom_layers = vis.custom_hit_layers

		var vo_path: String = base_path + skill_id + "_vfx_override.tres"
		ResourceSaver.save(vo, vo_path)
		ctx.output("SAVED", vo_path)

		# ── 更新主 .tres：设置子 Resource 引用 ──
		vis.projectile_visual = load(pv_path)
		vis.trail_visual = load(tv_path)
		vis.impact_visual = load(iv_path)
		vis.vfx_override = load(vo_path)
		ResourceSaver.save(vis, tres_path)
		ctx.output("UPDATED", tres_path)

	ctx.output("DONE", "Migration complete")
