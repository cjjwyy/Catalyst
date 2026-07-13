class_name EnergySystem
extends RefCounted

var current: int = 3
var max_value: int = 3

func _init(m: int = 3) -> void:
	max_value = m
	current = m

func can_play(_card: RuleCard = null) -> bool:
	return current > 0

func spend(amount: int = 1) -> void:
	current = max(0, current - amount)

func refill() -> void:
	current = max_value

func text() -> String:
	return "能量: %d/%d" % [current, max_value]