class_name RulePillar
extends RefCounted

var card: RuleCard
var coord: Vector2i = Vector2i.ZERO
var life_remaining: int = 0

func _init(c: RuleCard = null, p: Vector2i = Vector2i.ZERO, turn: int = 0) -> void:
	card = c
	coord = p
	life_remaining = card.life if card != null else 4