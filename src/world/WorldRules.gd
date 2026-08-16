class_name WorldRules
extends RefCounted

const DIR_VECTORS = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

# T4.1: 从 GameManager 拆出的世界规则注册表。
# 保持顺序与原 _world_rules 完全一致, 保证行为逐项等价。
func apply_all(grid: Grid, level: int, turn: int, wind_dir: int, wind_speed: int, rng: RandomNumberGenerator, pillars: Array = []) -> void:
	_steam_evaporate(grid, turn)
	_grass_and_earth(grid, turn)
	_generate_water_stone(grid, turn, rng)
	_burning(grid, turn)
	_frozen_contact(grid, turn)
	_spore_wind(grid, turn, wind_dir)
	_snow(grid, turn, rng)
	_disaster(grid, level, turn, rng, pillars)
	_meteor_decay(grid, turn)

func _steam_evaporate(grid: Grid, turn: int) -> void:
	for c in grid.all_cells():
		if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
			c.element = Element.NONE
			c.placed_at_turn = turn

func _grass_and_earth(grid: Grid, turn: int) -> void:
	for c in grid.all_cells():
		if c.element == Element.GRASS:
			var has_friend := false
			for n in grid.neighbors(c.coord):
				if n.element in [Element.PLANT, Element.GRASS]:
					has_friend = true
					break
			if not has_friend:
				c.decay_timer += 1
			else:
				c.decay_timer = 0
			if c.decay_timer >= 2:
				c.element = Element.EARTH
				c.decay_timer = 0
				c.placed_at_turn = turn
		elif c.element == Element.EARTH and turn - c.placed_at_turn >= 2:
			c.element = Element.STONE
			c.placed_at_turn = turn

func _generate_water_stone(grid: Grid, turn: int, rng: RandomNumberGenerator) -> void:
	var empty: Array = []
	for c in grid.all_cells():
		if c.element == Element.NONE:
			empty.append(c)
	var count: int = min(2, empty.size())
	for _i in range(count):
		var c = empty.pop_at(rng.randi_range(0, empty.size() - 1))
		c.element = Element.WATER if rng.randi_range(0, 1) == 0 else Element.STONE
		c.placed_at_turn = turn

func _burning(grid: Grid, turn: int) -> void:
	for c in grid.all_cells():
		if c.element == Element.PLANT and not c.has_state(State.BURNING):
			for n in grid.neighbors(c.coord):
				if n.element == Element.LAVA:
					c.add_state(State.BURNING, 2)
					break
	for c in grid.all_cells():
		if c.has_state(State.BURNING):
			for n in grid.neighbors(c.coord):
				if n.element == Element.PLANT and not n.has_state(State.BURNING):
					n.add_state(State.BURNING, 2)
	for c in grid.all_cells():
		if c.was_burning:
			if c.element == Element.PLANT:
				c.element = Element.NONE
				c.placed_at_turn = turn
			c.was_burning = false

func _spore_wind(grid: Grid, turn: int, wind_dir: int) -> void:
	var spore_dir: Vector2i = DIR_VECTORS[wind_dir]
	var spore_moves: Array = []
	for c in grid.all_cells():
		if c.element == Element.SPORE:
			var nx: Vector2i = c.coord + spore_dir
			if not grid.is_in_bounds(nx):
				spore_moves.append([c.coord, null])
			else:
				spore_moves.append([c.coord, nx])
	for m in spore_moves:
		var src = grid.get_cell(m[0])
		src.element = Element.NONE
		if m[1] != null:
			var dst_cell = grid.get_cell(m[1])
			if dst_cell.element == Element.NONE:
				dst_cell.element = Element.SPORE
				dst_cell.placed_at_turn = turn

func _snow(grid: Grid, turn: int, rng: RandomNumberGenerator) -> void:
	var sn_cells: Array = []
	for c in grid.all_cells():
		if not c.has_state(State.SNOW):
			sn_cells.append(c)
	for _i in range(min(2, sn_cells.size())):
		sn_cells.pop_at(rng.randi_range(0, sn_cells.size() - 1)).add_state(State.SNOW, 2)
	for c in grid.all_cells():
		if c.has_state(State.SNOW) and c.element == Element.WATER:
			c.element = Element.ICE
			c.remove_state(State.SNOW)
			c.placed_at_turn = turn
	for c in grid.all_cells():
		if c.has_state(State.SNOW):
			for n in grid.neighbors(c.coord):
				if n.element in [Element.LAVA, Element.STEAM]:
					c.remove_state(State.SNOW)
					break

func _frozen_contact(grid: Grid, turn: int) -> void:
	# T4.5: 冰邻水 → 水加 FROZEN
	var to_freeze: Array = []
	for c in grid.all_cells():
		if c.element == Element.WATER and not c.has_state(State.FROZEN):
			for n in grid.neighbors(c.coord):
				if n.element == Element.ICE:
					to_freeze.append(c)
					break
	for c in to_freeze:
		c.add_state(State.FROZEN, 2)

func _disaster(grid: Grid, level: int, turn: int, rng: RandomNumberGenerator, pillars: Array) -> void:
	if level == 4:
		if rng.randi_range(0, 99) < 30:
			if rng.randi_range(0, 1) == 0:
				for c in grid.all_cells():
					c.clear_states()
			elif not pillars.is_empty():
				var p = pillars[rng.randi_range(0, pillars.size() - 1)]
				var old = grid.get_cell(p.coord)
				if old != null:
					old.pillar = null
				var empties: Array = []
				for c in grid.all_cells():
					if c.pillar == null:
						empties.append(c)
				if not empties.is_empty():
					var dst = empties[rng.randi_range(0, empties.size() - 1)]
					p.coord = dst.coord
					dst.pillar = p
		return
	if level != 3:
		return
	if rng.randi_range(0, 99) < 30:
		var event := rng.randi_range(0, 2)
		if event == 0:
			var cells = grid.all_cells()
			var c = cells[rng.randi_range(0, cells.size() - 1)]
			c.element = Element.LAVA
			c.add_state(State.METEOR_LAVA, 2)
			c.placed_at_turn = turn
		elif event == 1:
			var non_empty = grid.all_cells().filter(func(c2): return c2.element != Element.NONE)
			for _i in range(min(2, non_empty.size())):
				var sc = non_empty.pop_at(rng.randi_range(0, non_empty.size() - 1))
				sc.element = Element.NONE
				sc.clear_states()
		else:
			var empties = grid.all_cells().filter(func(c2): return c2.element == Element.NONE)
			if not empties.is_empty():
				var c = empties[rng.randi_range(0, empties.size() - 1)]
				c.element = Element.LAVA
				c.placed_at_turn = turn

func _meteor_decay(grid: Grid, turn: int) -> void:
	for c in grid.all_cells():
		if c.was_meteor:
			if c.element == Element.LAVA:
				c.element = Element.STONE
				c.placed_at_turn = turn
			c.was_meteor = false
