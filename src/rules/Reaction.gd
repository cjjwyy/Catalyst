class_name Reaction
extends RefCounted

var card: RuleCard
var anchor: Vector2i           # 触发它的 pillar 锚定点
var target_coord: Vector2i     # 被作用的格子
var contact_coord: Vector2i = Vector2i(-1, -1)  # 接触元素所在(如有)
var affected: Array = []        # 此 Reaction 改变的坐标列表

func _init(c: RuleCard = null, a: Vector2i = Vector2i.ZERO, t: Vector2i = Vector2i.ZERO) -> void:
	card = c
	anchor = a
	target_coord = t

func apply(grid: Grid) -> void:
	affected.clear()
	var cell = grid.get_cell(target_coord)
	if cell == null or card == null or cell.has_state(State.FROZEN):
		return
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			var old_elem = cell.element
			cell.element = card.result_element
			cell.clear_states()
			affected.append(target_coord)
			if card.contact_element != Element.NONE:
				# 在锚定范围内找第一个匹配 contact_element 的格子替换之
				for n in grid.cells_in_radius(anchor, card.radius):
					if n.coord == target_coord:
						continue
					if n.element == card.contact_element:
						n.element = card.self_replace
						affected.append(n.coord)
			if card.add_state != State.NONE and card.add_state_turns > 0:
				cell.add_state(card.add_state, card.add_state_turns)
		RuleCard.Kind.MULTIPLY:
			for n in grid.neighbors(target_coord):
				if n.element == Element.NONE:
					n.element = card.result_element
					n.placed_at_turn = grid.get_cell(target_coord).placed_at_turn + 1
					affected.append(n.coord)
		RuleCard.Kind.EXTINCTION:
			# 灭绝事件: 半径内 trigger_element 数 >= threshold 时,
			# 清空范围内所有 trigger_element 格子,并清掉 also_clear 元素
			# (断掉 feeding 规则的燃料,避免 oscillation 刷连锁)。
			var scope = grid.cells_in_radius(anchor, card.radius)
			var candidates: Array = []
			for c in scope:
				if c.element == card.trigger_element or \
				   (card.also_count != Element.NONE and c.element == card.also_count):
					candidates.append(c)
			if candidates.size() >= card.extinct_threshold:
				for c in candidates:
					c.element = Element.NONE
					c.clear_states()
					affected.append(c.coord)
				if card.also_clear != Element.NONE:
					for c in scope:
						if c.element == card.also_clear:
							c.element = Element.NONE
							c.clear_states()
							affected.append(c.coord)