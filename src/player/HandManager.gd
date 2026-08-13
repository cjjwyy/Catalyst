class_name HandManager
extends RefCounted

const MAX_HAND: int = 8  # T1.2: 手牌上限, 超限抽牌进弃牌堆

var hand: Array = []        # Array[RuleCard]
var draw_pile: Array = []
var discard_pile: Array = []  # T1.2: 弃牌堆, 抽牌堆耗尽时循环重洗
var _deck_pool: Array = []    # 初始牌池(兜底重洗用)

func _init() -> void:
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()

func fill_draw_pile(cards: Array) -> void:
	_deck_pool = cards.duplicate()
	draw_pile = cards.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()

func _ensure_pile() -> void:
	if not draw_pile.is_empty():
		return
	if not discard_pile.is_empty():
		# T1.2: 抽牌堆耗尽 → 弃牌堆循环重洗
		draw_pile = discard_pile.duplicate()
		draw_pile.shuffle()
		discard_pile.clear()
	elif not _deck_pool.is_empty():
		draw_pile = _deck_pool.duplicate()
		draw_pile.shuffle()

func draw(n: int) -> void:
	for i in range(n):
		_ensure_pile()
		if draw_pile.is_empty():
			break
		var card = draw_pile.pop_back()
		if hand.size() >= MAX_HAND:
			discard_pile.append(card)   # T1.2: 手牌满 → 弃牌
		else:
			hand.append(card)

func refill_to(n: int) -> void:
	while hand.size() < min(n, MAX_HAND) and not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())

func play(idx: int, _coord: Vector2i) -> RuleCard:
	if idx < 0 or idx >= hand.size():
		return null
	return hand.pop_at(idx)

func hand_size() -> int:
	return hand.size()

func hand_capacity() -> int:
	return MAX_HAND

func discard_size() -> int:
	return discard_pile.size()
