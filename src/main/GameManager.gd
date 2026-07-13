extends Node

enum Phase { OBSERVE, LAYOUT, EVOLVE }

const TARGET = 100
const DEAD_TURNS = 10
const RULES_PATH = "res://data/rules.json"
const LEVEL_PATH = "res://data/coast.json"
const TestsScript = preload("res://tests/run_tests.gd")

var phase: int = Phase.LAYOUT
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

func _ready() -> void:
	Engine.get_main_loop().set_auto_accept_quit(true)
	# ponytail: 启动时跑自检,失败立即报错
	if not TestsScript.run_all():
		push_error("Catalyst 自检失败")
	start_game()

func start_game() -> void:
	all_card_defs = _load_rules()
	grid = _load_level(LEVEL_PATH)
	hand = HandManager.new()
	hand.fill_draw_pile(all_card_defs)
	hand.refill_to(5)
	energy = EnergySystem.new(3)
	phase = Phase.LAYOUT
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
	return phase == Phase.LAYOUT and energy.can_play() and hand.hand_size() > 0

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

func execute() -> void:
	if phase != Phase.LAYOUT:
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
	decay_pillars()
	# 状态衰减
	for c in grid.all_cells():
		c.tick_states()
	if chain_total >= TARGET:
		game_over.emit(true, "胜利! 达成 %d 连锁" % chain_total)
		phase = Phase.LAYOUT
		state_changed.emit()
		return
	if dead_turns >= DEAD_TURNS:
		game_over.emit(false, "失败: 世界进入死寂")
		phase = Phase.LAYOUT
		state_changed.emit()
		return
	end_turn()

func end_turn() -> void:
	turn += 1
	hand.draw(3)
	energy.refill()
	phase = Phase.LAYOUT
	state_changed.emit()

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