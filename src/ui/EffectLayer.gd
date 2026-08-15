class_name EffectLayer
extends Node2D

# T3.4: 轻量 CPU 粒子演出层。跳过/加速时由 Main 控制调用频率, 避免大棋盘卡顿。
# 视觉观感不做自动化断言, 白盒只验证节点/粒子创建与里程碑闪光存在。

var particles: Array = []
var flash_layer: CanvasLayer
var flash_rect: ColorRect

func _ready() -> void:
	z_index = 20
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 30
	flash_layer.name = "MilestoneFlash"
	add_child(flash_layer)
	flash_rect = ColorRect.new()
	flash_rect.name = "EdgeFlash"
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.9, 0.3, 0.0)
	flash_layer.add_child(flash_rect)

func burst_at(pos: Vector2, color: Color, amount: int = 8, velocity: float = 70.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = velocity * 0.55
	p.initial_velocity_max = velocity
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	add_child(p)
	p.emitting = true
	particles.append(p)
	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func():
		if is_instance_valid(p):
			particles.erase(p)
			p.queue_free())
	return p

func reaction_burst(pos: Vector2) -> void:
	burst_at(pos, Color(1, 0.92, 0.45), 8, 80.0)

func dust_at(pos: Vector2) -> void:
	burst_at(pos, Color(0.95, 0.85, 0.25), 6, 46.0)

func meteor_at(pos: Vector2) -> void:
	burst_at(pos, Color(0.55, 0.18, 0.08), 16, 120.0)

func bless_at(pos: Vector2) -> void:
	burst_at(pos, Color(1, 0.88, 0.35), 12, 60.0)

func fire_at(pos: Vector2) -> void:
	burst_at(pos, Color(1, 0.32, 0.08), 10, 55.0)

func milestone(chain: int) -> void:
	if flash_rect == null:
		return
	var strength := 0.22
	if chain >= 1000:
		strength = 0.5
	elif chain >= 500:
		strength = 0.42
	elif chain >= 100:
		strength = 0.34
	elif chain >= 50:
		strength = 0.28
	flash_rect.color = Color(1, 0.9, 0.3, strength)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.55).set_ease(Tween.EASE_OUT)
