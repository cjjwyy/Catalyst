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
		var expanded_scope = _expand_scope_for_dust(grid, scope)
		out.append_array(_match_in_scope(grid, card, pillar.coord, expanded_scope))
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
		var expanded_scope = _expand_scope_for_dust(grid, scope)
		# 只在 changed 命中该 pillar 范围时才检测
		var hit = false
		for c in scope:
			if changed_set.has(c.coord):
				hit = true
				break
		if not hit:
			continue
		out.append_array(_match_in_scope(grid, card, pillar.coord, expanded_scope))
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

func _compute_components(grid: Grid) -> Dictionary:
	var comp: Dictionary = {}
	var visited: Dictionary = {}
	var nid = 0
	for c in grid.all_cells():
		if c.has_state(State.DUST) and not visited.has(c.coord):
			var queue: Array = [c.coord]
			visited[c.coord] = true
			while not queue.is_empty():
				var cur = queue.pop_front()
				comp[cur] = nid
				for nb in grid.neighbors(cur):
					var nc = grid.get_cell(nb.coord)
					if nc != null and nc.has_state(State.DUST) and not visited.has(nb.coord):
						visited[nb.coord] = true
						queue.append(nb.coord)
			nid += 1
	return comp

func _expand_scope_for_dust(grid: Grid, scope: Array) -> Array:
	var has_dust = false
	var seen_coords: Dictionary = {}
	var expanded: Array = []
	for c in scope:
		expanded.append(c)
		seen_coords[c.coord] = true
		if c.has_state(State.DUST):
			has_dust = true
	if not has_dust:
		return expanded
	var components = _compute_components(grid)
	for c in scope:
		if c.has_state(State.DUST) and components.has(c.coord):
			var cid = components[c.coord]
			for coord in components.keys():
				if components[coord] == cid and not seen_coords.has(coord):
					var dc = grid.get_cell(coord)
					if dc != null:
						expanded.append(dc)
						seen_coords[coord] = true
	return expanded