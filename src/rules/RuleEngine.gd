class_name RuleEngine
extends RefCounted

# 检测所有可触发的 Reaction(全量扫描)
func evaluate(grid: Grid, pillars: Array) -> Array:
	var out: Array = []
	for pillar in pillars:
		var card = pillar.card
		if card == null:
			continue
		var scope = grid.cells_in_radius(pillar.coord, card.radius)
		out.append_array(_match_in_scope(grid, card, pillar.coord, scope))
	return out

# 只检查 changed 坐标涉及到的 pillar(仍按 pillar 半径判定)
func evaluate_restricted(grid: Grid, pillars: Array, changed: Array) -> Array:
	if changed.is_empty():
		return []
	var changed_set: Dictionary = {}
	for p in changed:
		changed_set[p] = true
	var out: Array = []
	for pillar in pillars:
		var card = pillar.card
		if card == null:
			continue
		var scope = grid.cells_in_radius(pillar.coord, card.radius)
		# 只在 changed 命中该 pillar 范围时才检测
		var hit = false
		for c in scope:
			if changed_set.has(c.coord):
				hit = true
				break
		if not hit:
			continue
		out.append_array(_match_in_scope(grid, card, pillar.coord, scope))
	return out

func _match_in_scope(grid: Grid, card: RuleCard, anchor: Vector2i, scope: Array) -> Array:
	var out: Array = []
	match card.kind:
		RuleCard.Kind.TRANSFORM, RuleCard.Kind.MULTIPLY:
			for c in scope:
				if _match_cell(grid, card, c, scope):
					out.append(Reaction.new(card, anchor, c.coord))
		RuleCard.Kind.EXTINCTION:
			var count = 0
			for c in scope:
				if c.element == card.trigger_element:
					count += 1
			if count >= card.extinct_threshold:
				# 每轮最多产出一个EXTINCTION Reaction
				out.append(Reaction.new(card, anchor, anchor))
	return out

func _match_cell(grid: Grid, card: RuleCard, c: Cell, scope: Array) -> bool:
	if c.element != card.trigger_element:
		return false
	if card.trigger_state != State.NONE and not c.has_state(card.trigger_state):
		return false
	if card.contact_element != Element.NONE:
		var found = false
		for n in scope:
			if n.coord == c.coord:
				continue
			if n.element == card.contact_element:
				found = true
				break
		if not found:
			return false
	return true