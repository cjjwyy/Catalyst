class_name Cell
extends RefCounted

var element: int = Element.NONE
var states: Dictionary = {}  # state_enum -> 剩余回合数
var pillar = null             # RulePillar 或 null
var coord: Vector2i = Vector2i.ZERO
var placed_at_turn: int = 0   # 用于 EXTINCTION "最旧" 判定
var decay_timer: int = 0   # 草连续无邻树回合计数
var was_burning: bool = false   # BURNING 衰减后标记, 供 _world_rules 检查

func has_state(s: int) -> bool:
	return states.has(s)

func add_state(s: int, turns: int) -> void:
	states[s] = turns

func remove_state(s: int) -> void:
	states.erase(s)

func tick_states() -> void:
	var to_remove = []
	for s in states.keys():
		states[s] -= 1
		if states[s] <= 0:
			to_remove.append(s)
	for s in to_remove:
		states.erase(s)
		if s == State.BURNING:
			was_burning = true

func clear_states() -> void:
	states.clear()