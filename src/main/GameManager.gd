extends Node

enum Phase { OBSERVE, LAYOUT, EVOLVE }

const DEAD_TURNS = 10
const RULES_PATH = "res://data/rules.json"
const LEVEL_PATH = "res://data/coast.json"
const TestsScript = preload("res://tests/run_tests.gd")

const DIR_VECTORS = [
	Vector2i(0, -1),   # 0=N
	Vector2i(1, 0),    # 1=E
	Vector2i(0, 1),    # 2=S
	Vector2i(-1, 0),   # 3=W
]
const DIR_CHARS = ["^", ">", "v", "<"]
const CHAOS_ELEMENTS = [Element.WATER, Element.STONE, Element.EARTH, Element.STEAM, Element.LAVA, Element.PLANT]
const CHAOS_NAME = {Element.WATER:"水",Element.STONE:"岩",Element.EARTH:"土",Element.STEAM:"汽",Element.LAVA:"熔",Element.PLANT:"植"}

var phase: int = Phase.LAYOUT
var game_ended: bool = false
var level_manager: LevelManager = LevelManager.new()
var target: int = 100
var wind_dir: int = 0
var wind_speed: int = 1
var turn: int = 0
var chain_total: int = 0
var dead_turns: int = 0

var grid: Grid
var pillars: Array = []
var hand: HandManager
var energy: EnergySystem
var all_card_defs: Array = []

signal state_changed
signal reaction_applied(reaction)
signal game_over(won: bool, message: String)
signal flash_cell(coord: Vector2i)
signal level_complete(level_idx: int)

func _ready() -> void:
	Engine.get_main_loop().set_auto_accept_quit(true)
	# ponytail: 启动时跑自检,失败立即报错
	if not TestsScript.run_all():
		push_error("Catalyst 自检失败")
	start_game()

func start_game(level_idx: int = -1) -> void:
	if level_idx >= 0:
		level_manager.current_level = level_idx
	var lvl = level_manager.get_current()
	target = int(lvl.target)
	all_card_defs = _load_rules()
	# 按关卡筛牌: level=0 全关通用, level=N 仅第N关出现
	var lvl_idx = level_manager.current_level + 1
	all_card_defs = all_card_defs.filter(func(c): return c.level == 0 or c.level == lvl_idx)
	grid = _load_level(lvl.path)
	hand = HandManager.new()
	hand.fill_draw_pile(all_card_defs)
	hand.refill_to(5)
	energy = EnergySystem.new(3)
	chain_total = 0
	dead_turns = 0
	game_ended = false
	phase = Phase.LAYOUT
	_reroll_wind()
	state_changed.emit()

func _load_rules() -> Array:
	var f = FileAccess.open(RULES_PATH, FileAccess.READ)
	if f == null:
		push_warning("无法打开 %s" % RULES_PATH)
		return []
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_ARRAY:
		return []
	var out: Array = []
	for entry in data:
		var c = RuleCard.new()
		c.from_dict(entry)
		out.append(c)
	return out

func _load_level(path: String) -> Grid:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("无法打开 %s,使用默认 6x6" % path)
		return Grid.new(6, 6)
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return Grid.new(6, 6)
	var size = data.get("size", [6, 6])
	var g = Grid.new(int(size[0]), int(size[1]))
	var elems = data.get("elements", [])
	for entry in elems:
		var coord = entry["coord"]
		var c = g.get_cell(Vector2i(int(coord[0]), int(coord[1])))
		if c == null:
			continue
		c.element = Element.from_string(entry["element"])
		c.placed_at_turn = 0
	return g

func can_play_card() -> bool:
	return not game_ended and phase == Phase.LAYOUT and energy.can_play() and hand.hand_size() > 0

func play_card(hand_idx: int, coord: Vector2i) -> bool:
	if not can_play_card():
		return false
	var target = grid.get_cell(coord)
	if target == null or target.pillar != null:
		return false
	var card = hand.play(hand_idx, coord)
	if card == null:
		return false
	var p = RulePillar.new(card, coord, turn)
	# pillar 出现时也占用"格子上层"标记,仍允许元素在底层。
	target.pillar = p
	pillars.append(p)
	energy.spend()
	state_changed.emit()
	return true

func remove_pillar(coord: Vector2i) -> bool:
	if phase != Phase.LAYOUT:
		return false
	var cell = grid.get_cell(coord)
	if cell == null or cell.pillar == null:
		return false
	var p = cell.pillar
	pillars.erase(p)
	cell.pillar = null
	hand.hand.append(p.card)   # 卡牌回到手牌
	energy.current = min(energy.max_value, energy.current + 1)
	state_changed.emit()
	return true

func execute() -> void:
	if phase != Phase.LAYOUT or game_ended:
		return
	phase = Phase.EVOLVE
	state_changed.emit()
	var runner = ChainReaction.new()
	runner.reaction_applied.connect(_on_reaction)
	var gained = await runner.execute_async(grid, pillars, 0.1)
	runner.reaction_applied.disconnect(_on_reaction)
	chain_total += gained
	if gained == 0:
		dead_turns += 1
	else:
		dead_turns = 0
	if chain_total >= target:
		game_ended = true
		level_complete.emit(level_manager.current_level)
		return
	if dead_turns >= DEAD_TURNS:
		game_ended = true
		game_over.emit(false, "失败: 世界进入死寂")
		return
	end_turn()

func end_turn() -> void:
	decay_pillars()
	for c in grid.all_cells():
		c.tick_states()
	push_dust()
	chaos_check()
	_world_rules()
	_reroll_wind()
	turn += 1
	hand.draw(3)
	energy.refill()
	phase = Phase.LAYOUT
	state_changed.emit()

func _reroll_wind() -> void:
	wind_dir = randi() % 4
	wind_speed = randi() % 3 + 1

func push_dust() -> void:
	var dir_vec = DIR_VECTORS[wind_dir]
	var moves: Array = []  # [[from, to_or_null]]
	for c in grid.all_cells():
		if c.has_state(State.DUST):
			# 新鲜尘(剩余>1回合)不会被风推动,给它一回合"落地"
			if c.states.get(State.DUST, 0) > 1:
				continue
			var dst = c.coord
			var fell_off = false
			for _i in range(wind_speed):
				var nx = dst + dir_vec
				if not grid.is_in_bounds(nx):
					fell_off = true
					break
				dst = nx
			if fell_off:
				moves.append([c.coord, null])
			else:
				moves.append([c.coord, dst])
	for m in moves:
		var src = grid.get_cell(m[0])
		var turns_left = src.states.get(State.DUST, 0)
		src.remove_state(State.DUST)
		if m[1] != null:
			var dst_cell = grid.get_cell(m[1])
			var exist = dst_cell.states.get(State.DUST, 0)
			dst_cell.add_state(State.DUST, max(exist, turns_left))

func chaos_check() -> void:
	var total = grid.w * grid.h
	for elem in CHAOS_ELEMENTS:
		var n = grid.count_element(elem)
		if n > total / 2:
			var ext_pillar = null
			for p in pillars:
				if p.card.kind == RuleCard.Kind.EXTINCTION and p.card.trigger_element == elem:
					ext_pillar = p
					break
			if ext_pillar != null:
				for c in grid.cells_in_radius(ext_pillar.coord, ext_pillar.card.radius):
					if c.element == elem:
						c.element = Element.NONE
						c.clear_states()
				return
			else:
				game_over.emit(false, "混沌失控 — %s 超过 50%%" % CHAOS_NAME.get(elem,"??"))
				return

func _world_rules() -> void:
	for c in grid.all_cells():
		if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
			c.element = Element.NONE
			c.placed_at_turn = turn
	for c in grid.all_cells():
		if c.element == Element.GRASS:
			var has_friend = false
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
	var empty: Array = []
	for c in grid.all_cells():
		if c.element == Element.NONE:
			empty.append(c)
	var count = min(2, empty.size())
	for _i in range(count):
		var c = empty.pop_at(randi() % empty.size())
		c.element = Element.WATER if randi() % 2 == 0 else Element.STONE
		c.placed_at_turn = turn
	# 4. 燃烧蔓延: 植物相邻熔岩→点燃; 燃烧蔓延相邻植物
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
	# 5. was_burning 检查: BURNING 衰减后植物烧完
	for c in grid.all_cells():
		if c.was_burning:
			if c.element == Element.PLANT:
				c.element = Element.NONE
				c.placed_at_turn = turn
			c.was_burning = false
	# 6. 孢子飘散: 随风向移动 1 格, 越界消失
	var spore_dir = DIR_VECTORS[wind_dir]
	var spore_moves: Array = []
	for c in grid.all_cells():
		if c.element == Element.SPORE:
			var nx = c.coord + spore_dir
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

	# 7. 降雪: 随机1-2格(无SNOW) +SNOW
	var sn_cells: Array = []
	for c in grid.all_cells():
		if not c.has_state(State.SNOW):
			sn_cells.append(c)
	for _i in range(min(2, sn_cells.size())):
		sn_cells.pop_at(randi() % sn_cells.size()).add_state(State.SNOW, 2)
	# 8. 雪化冰: SNOW+水→冰
	for c in grid.all_cells():
		if c.has_state(State.SNOW) and c.element == Element.WATER:
			c.element = Element.ICE
			c.remove_state(State.SNOW)
			c.placed_at_turn = turn
	# 9. 雪融: SNOW邻熔岩/汽→消散
	for c in grid.all_cells():
		if c.has_state(State.SNOW):
			for n in grid.neighbors(c.coord):
				if n.element in [Element.LAVA, Element.STEAM]:
					c.remove_state(State.SNOW)
					break

func decay_pillars() -> void:
	for p in pillars:
		p.life_remaining -= 1
		if p.life_remaining <= 0:
			var c = grid.get_cell(p.coord)
			if c != null:
				c.pillar = null
	pillars = pillars.filter(func(p): return p.life_remaining > 0)

func _on_reaction(reaction) -> void:
	reaction_applied.emit(reaction)
	for c in reaction.affected:
		flash_cell.emit(c)