class_name HitVFXNode
extends Node2D

## 池化命中特效节点 — 支持 Sprite2D / GPUParticles2D / ColorRect(Shader) 三种模式
## 生命周期：acquire → setup → play → (自动) → release

signal finished(node: HitVFXNode)

enum Mode { SPRITE, PARTICLES, SHADER_RECT }

var _pool: HitVFXPool
var _mode: Mode = Mode.SPRITE
var _lifetime: float = 0.3
var _elapsed: float = 0.0
var _playing: bool = false

# 子节点（延迟创建，复用）
var _sprite: Sprite2D
var _particles: GPUParticles2D
var _shader_rect: ColorRect


func _ready() -> void:
	# 池模式：_ready 时创建子节点
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.visible = false
		add_child(_sprite)
		_particles = GPUParticles2D.new()
		_particles.emitting = false
		_particles.one_shot = true
		_particles.visible = false
		add_child(_particles)
		_shader_rect = ColorRect.new()
		_shader_rect.visible = false
		add_child(_shader_rect)
	set_process(false)


## 确保节点和子节点都在场景树中（无池 fallback 时使用）
func _ensure_in_tree() -> void:
	if not _sprite:
		_sprite = Sprite2D.new()
		_sprite.visible = false
		_particles = GPUParticles2D.new()
		_particles.emitting = false
		_particles.one_shot = true
		_particles.visible = false
		_shader_rect = ColorRect.new()
		_shader_rect.visible = false
	if not is_inside_tree():
		var scene = Engine.get_main_loop().current_scene
		if scene:
			add_child(_sprite)
			add_child(_particles)
			add_child(_shader_rect)
			scene.add_child(self)
	elif not _sprite.is_inside_tree():
		add_child(_sprite)
		add_child(_particles)
		add_child(_shader_rect)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= _lifetime:
		_playing = false
		set_process(false)
		finished.emit(self)


## 初始化为精灵模式
func setup_sprite(tex: Texture2D, color: Color, scale_val: Vector2, pos: Vector2, life: float) -> void:
	_ensure_in_tree()
	_hide_all()
	_mode = Mode.SPRITE
	_sprite.texture = tex
	_sprite.modulate = color
	_sprite.scale = scale_val
	_sprite.visible = true
	global_position = pos
	_lifetime = life
	_elapsed = 0.0


## 初始化为粒子模式
func setup_particles(process_mat: ParticleProcessMaterial, tex: Texture2D, amount: int, pos: Vector2, life: float) -> void:
	_ensure_in_tree()
	_hide_all()
	_mode = Mode.PARTICLES
	_particles.process_material = process_mat
	_particles.texture = tex
	_particles.amount = amount
	_particles.emitting = true
	_particles.visible = true
	global_position = pos
	_lifetime = life
	_elapsed = 0.0


## 初始化为 Shader 模式（用于 ring / shockwave 等 Shader 驱动效果）
func setup_shader_rect(shader_mat: ShaderMaterial, size: Vector2, pos: Vector2, life: float) -> void:
	_ensure_in_tree()
	_hide_all()
	_mode = Mode.SHADER_RECT
	_shader_rect.material = shader_mat
	_shader_rect.size = size
	_shader_rect.position = -size * 0.5  # 居中
	_shader_rect.visible = true
	global_position = pos
	_lifetime = life
	_elapsed = 0.0


## 获取子节点引用（用于 Tween 动画）
func get_sprite() -> Sprite2D:
	return _sprite

func get_particles() -> GPUParticles2D:
	return _particles

func get_shader_rect() -> ColorRect:
	return _shader_rect


## 开始播放（启动生命周期计时）
func play() -> void:
	_playing = true
	_elapsed = 0.0
	set_process(true)


## 强制停止并归还到池
func stop() -> void:
	_playing = false
	set_process(false)
	_hide_all()
	if _pool:
		_pool.release(self)


## 设置池引用
func set_pool(pool: HitVFXPool) -> void:
	_pool = pool


func _hide_all() -> void:
	_sprite.visible = false
	_particles.emitting = false
	_particles.visible = false
	_shader_rect.visible = false
	# 清理 material（避免泄漏到下次使用）
	_shader_rect.material = null
	_sprite.material = null
