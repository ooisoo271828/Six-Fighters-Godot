# comp_explosion.gd
# 命中爆炸组件 — 在弹体销毁时生成火花爆发 + 屏幕震动
class_name CompExplosion
extends ProjectileComponent

var _impact: ImpactVisual
var _core_texture: Texture2D
var _tex_manager: VFXTextureManager

func configure(visual_def: SkillVisualDef, _chain: ExecutionChain, tex_manager: VFXTextureManager) -> void:
	_impact = visual_def.get_impact()
	_tex_manager = tex_manager
	# 加载爆炸纹理（优先用 impact 的，回退 body 的 tex_explosion_path）
	var body := visual_def.get_body()
	if body.tex_explosion_path != "" and ResourceLoader.exists(body.tex_explosion_path):
		_core_texture = load(body.tex_explosion_path)


func on_destroy(parent: Node2D) -> void:
	if not _impact:
		return

	var impact_color: Color = _impact.spark_color
	var spark_count: int = randi_range(_impact.spark_count_min, _impact.spark_count_max)
	spark_count = clampi(spark_count, 1, 64)

	var tex: Texture2D = _core_texture if _core_texture else _tex_manager.get_texture(VFXTextureManager.CIRCLE)
	var tex_size := tex.get_size() if tex else Vector2(16, 16)

	for i in range(spark_count):
		var angle := float(i) / float(spark_count) * TAU
		angle += randf_range(-0.15, 0.15)
		var dir := Vector2(cos(angle), sin(angle))

		var spark := Sprite2D.new()
		spark.texture = tex
		spark.scale = Vector2.ONE * randf_range(0.3, 0.8) / (tex_size.x / 16.0)
		spark.modulate = impact_color
		spark.global_position = parent.global_position
		parent.get_tree().root.add_child(spark)

		var tw := parent.create_tween()
		tw.set_parallel(true)
		var target_pos := spark.global_position + dir * randf_range(
			_impact.spark_speed_min * 0.2, _impact.spark_speed_max * 0.2
		)
		var dur := randf_range(_impact.spark_life_min, _impact.spark_life_max)
		tw.tween_property(spark, "global_position", target_pos, dur)
		tw.tween_property(spark, "modulate:a", 0.0, dur).set_delay(dur * 0.2)
		tw.tween_callback(spark.queue_free).set_delay(dur + 0.05)

	# 屏幕震动
	if _impact.shake_strength > 0:
		var camera = parent.get_viewport().get_camera_2d()
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(_impact.shake_strength * 0.1)


func reset() -> void:
	_impact = null
	_core_texture = null


func is_active() -> bool:
	return _impact != null
