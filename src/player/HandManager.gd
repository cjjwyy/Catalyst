class_name HandManager
extends RefCounted

var hand: Array = []       # Array[RuleCard]
var draw_pile: Array = []
var _deck_pool: Array = []  # ponytail: 牌库耗尽时自动重洗的循环池

func _init() -> void:
	hand.clear()
	draw_pile.clear()

func fill_draw_pile(cards: Array) -> void:
	_deck_pool = cards.duplicate()
	draw_pile = cards.duplicate()
	draw_pile.shuffle()

func _ensure_pile() -> void:
	if draw_pile.is_empty() and not _deck_pool.is_empty():
		draw_pile = _deck_pool.duplicate()
		draw_pile.shuffle()

func draw(n: int) -> void:
	for i in range(n):
		_ensure_pile()
		if draw_pile.is_empty():
			break
		hand.append(draw_pile.pop_back())

func refill_to(n: int) -> void:
	while hand.size() < n and not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())

func play(idx: int, _coord: Vector2i) -> RuleCard:
	if idx < 0 or idx >= hand.size():
		return null
	return hand.pop_at(idx)

func hand_size() -> int:
	return hand.size()