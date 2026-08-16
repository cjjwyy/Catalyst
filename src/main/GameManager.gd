extends Node

enum Phase { OBSERVE, LAYOUT, EVOLVE, RETAIN }

const DEAD_TURNS = 10
const RETAIN_LIMIT = 3  # T3.5: 回合结束保留至多 3 张
const RULES_PATH = "res://data/rules.json"
const TestsScript = preload("res://tests/run_tests.gd")
const WorldRulesScript = preload("res://src/world/WorldRules.gd")

const DIR_VECTORS = [
	Vector2i(0, -1),   # 0=N
	Vector2i(1, 0),    # 1=E
	Vector2i(0, 1),    # 2=S
	Vector2i(-1, 0),   # 3=W
]
const DIR_CHARS = ["^", ">", "v", "<"]
const DEFAULT_CHAOS_ELEMENTS = [Element.WATER, Element.STONE, Element.EARTH, Element.STEAM, Element.LAVA, Element.PLANT]
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
var chaos_elements: Array = DEFAULT_CHAOS_ELEMENTS.duplicate()

var grid: Grid
var pillars: Array = []
var hand: HandManager
var energy: EnergySystem
var all_card_defs: Array = []
var save_manager: SaveManager = SaveManager.new()
var auto_retention: bool = true  # T3.5
var game_seed: int = 0  # T3.8: 当前局种子; 0=未显式锁定
var rng: RngService = RngService.new()  # T1.2/T3.8: 可播种统一随机源(种子化前置)
var rules_data_error: String = ""  # T2.3: 规则文件加载失败原因; 非空表示本局处于明确失败态
var _running_runner = null  # T2.5: 当前演化 runner; start_game/load_game 置 cancelled 并清空
var _evolution_serial: int = 0  # T2.5: 演化代数; 旧协程完成时若代数不匹配则不写回
var turn_snapshots: Array = []  # T3.6: 每回合 world rules 前的完整快照栈
const MAX_TURN_SNAPSHOTS = 5

signal state_changed
signal reaction_applied(reaction)
signal game_over(won: bool, message: String)
signal flash_cell(coord: Vector2i)
signal level_complete(level_idx: int)

func _ready() -> void:
	Engine.get_main_loop().set_auto_accept_quit(true)
	if not TestsScript.run_all():
		push_error("Catalyst 自检失败")
	# T1.4: 应用持久化的全局通关进度; 不再自动开局(由选档/新游戏入口驱动)
	level_manager.unlocked = save_manager.get_unlocked()
	rng.randomize()  # 真实游戏随机; 测试通过 rng.seed 覆盖
	game_seed = rng.seed

# 统一随机入口: [0, n) 均匀随机; Godot 4.7 的 randi() 流不可播种, 全部走 rng
func _randi(n: int) -> int:
	if n <= 1:
		return 0
	return rng.randi_range(0, n - 1)

func _prepare_card_defs(lvl_idx: int) -> Array:
	all_card_defs = _load_rules()
	var lvl_n = lvl_idx + 1
	all_card_defs = all_card_defs.filter(func(c): return c.level == 0 or c.level == lvl_n)
	# 在副本上迭代避免 append 导致的无限循环
	var base = all_card_defs.duplicate()
	for c in base:
		if c.id == "steamify":
			for _i in range(2):
				all_card_defs.append(c)
		if c.id == "grow":
			for _i in range(2):
				all_card_defs.append(c)
		if c.id == "superheat":
			for _i in range(2):
				all_card_defs.append(c)
		if c.id == "ashify":
			for _i in range(2):
				all_card_defs.append(c)
		if c.id == "abyss_purge":
			all_card_defs.append(c)
	return all_card_defs

func start_game(level_idx: int = -1) -> void:
	_cancel_evolution()  # T2.5: 新局开工前先中止旧演化, 防止旧协程写回新网格
	if level_idx >= 0:
		level_manager.current_level = level_idx
	var lvl = level_manager.get_current()
	target = clampi(int(lvl.get("target", 100)), 1, 99999)
	_prepare_card_defs(level_manager.current_level)
	grid = _load_level(lvl.path)
	pillars.clear()  # T2.5: 新网格必须搭配空柱数组, 旧演化/旧局柱子不得残留
	turn_snapshots.clear()  # T3.6: 新局不继承旧局撤销栈
	hand = HandManager.new()
	hand.rng = rng  # T3.8: 手牌洗牌与逻辑共用同一种子流
	hand.fill_draw_pile(all_card_defs)
	hand.refill_to(5)
	energy = EnergySystem.new(3)
	turn = 0
	chain_total = 0
	dead_turns = 0
	game_ended = false
	phase = Phase.LAYOUT
	auto_retention = true  # T3.5: 直接调用 start_game(测试/无 UI)默认自动保留; Main 随后改手动
	if not rules_data_error.is_empty():
		# T2.3: 规则数据损坏时已 emit game_over, 这里同步置位, 不让 UI/逻辑落入静默死锁
		game_ended = true
		phase = Phase.EVOLVE
	_reroll_wind()
	state_changed.emit()

func _cancel_evolution() -> void:
	_evolution_serial += 1
	if _running_runner != null:
		_running_runner.cancelled = true
	_running_runner = null

# T3.6: 回滚到上一回合 world rules/抽牌前; 玩家可右键撤回柱子拿回卡与能量
func can_undo() -> bool:
	return not turn_snapshots.is_empty() and phase == Phase.LAYOUT and not game_ended

func undo_turn() -> bool:
	if not can_undo():
		return false
	_cancel_evolution()
	var snap: Dictionary = turn_snapshots.pop_back()
	if not _restore_snapshot(snap):
		return false
	state_changed.emit()
	return true


# T3.7: 预演"我算到了" —— 耗 1 能量, 在副本网格上同步跑一遍当前布局, 不改真实网格
func preview_evolution() -> Dictionary:
	if phase != Phase.LAYOUT or game_ended or grid == null or pillars.is_empty():
		return {}
	if not energy.can_play():
		return {}
	var sim := _clone_game_for_preview()
	var preview_rng: RngService = rng.fork()  # T3.8: 从当前随机流分叉, 预演不消耗真实 rng
	var runner := ChainReaction.new()
	var affected: Dictionary = {}
	runner.reaction_applied.connect(func(r):
		for c in r.affected:
			affected[c] = true)
	var chain: int = runner.execute(sim["grid"], sim["pillars"], turn, preview_rng)
	energy.spend()
	state_changed.emit()
	return {"chain_delta": chain, "affected": affected.keys()}

func _clone_game_for_preview() -> Dictionary:
	var src: Grid = grid
	var g := Grid.new(src.w, src.h)
	for sc in src.all_cells():
		var dc = g.get_cell(sc.coord)
		dc.element = sc.element
		dc.placed_at_turn = sc.placed_at_turn
		dc.decay_timer = sc.decay_timer
		dc.states = sc.states.duplicate()
		dc.frozen_original = sc.frozen_original
		dc.was_burning = sc.was_burning
		dc.was_meteor = sc.was_meteor
	var cloned_pillars: Array = []
	for p in pillars:
		var np := RulePillar.new(p.card, p.coord, turn)
		np.life_remaining = p.life_remaining
		cloned_pillars.append(np)
		var pc = g.get_cell(np.coord)
		if pc != null:
			pc.pillar = np
	return {"grid": g, "pillars": cloned_pillars}

func _auto_retain() -> void:
	while hand.hand_size() > RETAIN_LIMIT:
		hand.discard_from_hand(_worst_card_idx())

func _worst_card_idx() -> int:
	var priority := ["abyss_purge", "ashify", "superheat", "steamify", "harvest", "grow", "drought", "extinct", "petrify", "grass_grow", "grass_spread", "sporify", "spore_bloom", "freeze", "melt", "bless", "meteor_strike"]
	var worst := 0
	var worst_rank := -1
	for i in range(hand.hand_size()):
		var card = hand.hand[i]
		var rank: int = priority.find(card.id)
		if rank == -1:
			rank = 999
		if rank > worst_rank:
			worst_rank = rank
			worst = i
	return worst

# T3.5: Main 保留阶段点击一张手牌 → 弃掉; 弃到 3 张后自动回到布局阶段
func discard_for_retention(idx: int) -> bool:
	if phase != Phase.RETAIN or hand.hand_size() <= RETAIN_LIMIT:
		return false
	if hand.discard_from_hand(idx) == null:
		return false
	if hand.hand_size() <= RETAIN_LIMIT:
		phase = Phase.LAYOUT
	state_changed.emit()
	return true

# T1.4: 由 Main 调用 —— 若无进行中的局则按当前关卡开局(支持读档后跳过重开)
func ensure_game_started() -> void:
	if grid == null:
		start_game(level_manager.current_level)

func persist_unlock() -> void:
	save_manager.set_unlocked(level_manager.unlocked)

# ---------- T3.8 种子化 ----------
func set_seed(seed_value: int) -> void:
	game_seed = seed_value
	rng.seed = seed_value

func get_seed() -> int:
	return game_seed

func start_game_with_seed(level_idx: int, seed_value: int) -> void:
	set_seed(seed_value)
	start_game(level_idx)

func daily_seed() -> int:
	var date_text: String = Time.get_date_string_from_system().replace("-", "")
	var v := int(date_text)
	return v % 2147483000

func start_daily_challenge(level_idx: int) -> void:
	start_game_with_seed(level_idx, daily_seed())

# ---------- T1.4 存档 ----------
func _snapshot_game() -> Dictionary:
	var cells: Array = []
	for c in grid.all_cells():
		var states_arr: Array = []
		for s in c.states.keys():
			states_arr.append([int(s), int(c.states[s])])
		var pillar_data = null
		if c.pillar != null:
			pillar_data = {"card": c.pillar.card.id, "life": c.pillar.life_remaining}
		cells.append({
			"x": c.coord.x, "y": c.coord.y,
			"elem": c.element, "states": states_arr,
			"placed": c.placed_at_turn, "decay": c.decay_timer,
			"pillar": pillar_data,
		})
	var hand_ids: Array = []
	for c in hand.hand:
		hand_ids.append(c.id)
	var draw_ids: Array = []
	for c in hand.draw_pile:
		draw_ids.append(c.id)
	var disc_ids: Array = []
	for c in hand.discard_pile:
		disc_ids.append(c.id)
	return {
		"version": 1,
		"level": level_manager.current_level,
		"target": target,
		"turn": turn,
		"chain_total": chain_total,
		"dead_turns": dead_turns,
		"wind_dir": wind_dir,
		"wind_speed": wind_speed,
		"energy": energy.current,
		"hand": hand_ids, "draw": draw_ids, "discard": disc_ids,
		"cells": cells,
	}

func save_game(slot: int, slot_name: String) -> bool:
	if grid == null or game_ended:
		return false
	return save_manager.save_slot(slot, slot_name, _snapshot_game())

func load_game(slot: int) -> bool:
	_cancel_evolution()  # T2.5: 读档也会替换网格, 同样需要中止旧演化
	turn_snapshots.clear()  # T3.6: 读档不继承撤销栈
	var snap = save_manager.load_slot(slot)
	if typeof(snap) != TYPE_DICTIONARY or snap.is_empty():
		return false
	level_manager.current_level = int(snap.get("level", 0))
	_prepare_card_defs(level_manager.current_level)
	return _restore_snapshot(snap)

func _restore_snapshot(snap: Dictionary) -> bool:
	var cells: Array = snap.get("cells", [])
	var w := 0
	var h := 0
	for ce in cells:
		w = max(w, int(ce.get("x", 0)) + 1)
		h = max(h, int(ce.get("y", 0)) + 1)
	if w <= 0 or h <= 0:
		return false
	target = int(snap.get("target", 100))
	grid = Grid.new(w, h)
	var card_by_id: Dictionary = {}
	for c in all_card_defs:
		card_by_id[c.id] = c
	pillars.clear()
	for ce in cells:
		var c = grid.get_cell(Vector2i(int(ce.get("x", 0)), int(ce.get("y", 0))))
		if c == null:
			continue
		c.element = int(ce.get("elem", Element.NONE))
		c.placed_at_turn = int(ce.get("placed", 0))
		c.decay_timer = int(ce.get("decay", 0))
		for st in ce.get("states", []):
			c.add_state(int(st[0]), int(st[1]))
		var pd = ce.get("pillar")
		if pd != null:
			var card = card_by_id.get(str(pd.get("card", "")), null)
			if card != null:
				var p = RulePillar.new(card, c.coord, turn)
				p.life_remaining = int(pd.get("life", card.life))
				c.pillar = p
				pillars.append(p)
	turn = int(snap.get("turn", 0))
	chain_total = int(snap.get("chain_total", 0))
	dead_turns = int(snap.get("dead_turns", 0))
	wind_dir = int(snap.get("wind_dir", 0))
	wind_speed = int(snap.get("wind_speed", 1))
	energy = EnergySystem.new(3)
	energy.current = int(snap.get("energy", 3))
	hand = HandManager.new()
	hand.rng = rng  # T3.8: 手牌洗牌与逻辑共用同一种子流
	hand.fill_draw_pile(all_card_defs)
	hand.hand = _ids_to_cards(snap.get("hand", []), card_by_id)
	hand.draw_pile = _ids_to_cards(snap.get("draw", []), card_by_id)
	hand.discard_pile = _ids_to_cards(snap.get("discard", []), card_by_id)
	game_ended = false
	phase = Phase.LAYOUT
	state_changed.emit()
	return true

func _ids_to_cards(ids: Array, card_by_id: Dictionary) -> Array:
	var out: Array = []
	for id in ids:
		var c = card_by_id.get(str(id), null)
		if c != null:
			out.append(c)
	return out

func _load_rules() -> Array:
	var f = FileAccess.open(RULES_PATH, FileAccess.READ)
	if f == null:
		rules_data_error = "无法打开 %s" % RULES_PATH
		push_error("规则数据损坏: %s" % rules_data_error)
		game_over.emit(false, "规则数据损坏,请重新下载游戏")
		return []
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_ARRAY:
		rules_data_error = "JSON 解析失败或根节点不是数组"
		push_error("规则数据损坏: %s" % rules_data_error)
		game_over.emit(false, "规则数据损坏,请重新下载游戏")
		return []
	rules_data_error = ""
	var out: Array = []
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("rules.json 中存在非对象条目, 已跳过")
			continue
		var c = RuleCard.new()
		if c.from_dict(entry):
			out.append(c)
	if out.is_empty():
		push_warning("rules.json 为空或无有效规则牌, 启用内置降级牌组")
		return _default_rules()
	return out

func _default_rules() -> Array:
	var defs := [
		{"id": "steamify", "name": "蒸汽化", "kind": "TRANSFORM",
			"desc": "水触熔岩:水→汽,首个熔岩→岩", "tip": "把柱子放在水与熔岩都覆盖到的空格上",
			"trigger_element": "WATER", "contact_element": "LAVA",
			"result_element": "STEAM", "self_replace": "STONE",
			"radius": 2, "life": 4, "chain_reward": 1},
		{"id": "grow", "name": "加速生长", "kind": "MULTIPLY",
			"desc": "植触蒸汽:植物周围空格→植物", "tip": "先用蒸汽化造汽,再落加速生长扩散植物",
			"trigger_element": "PLANT", "contact_element": "STEAM",
			"result_element": "PLANT", "radius": 2, "life": 4, "chain_reward": 1},
		{"id": "extinct", "name": "丛林灭绝", "kind": "EXTINCTION",
			"desc": "半径内植物+草≥5:全部清空,并清汽", "tip": "植物过半时用它断掉生长燃料",
			"trigger_element": "PLANT", "result_element": "NONE",
			"radius": 2, "life": 4, "extinct_threshold": 5,
			"also_count": "GRASS", "also_clear": "STEAM", "chain_reward": 1},
	]
	var out: Array = []
	for d in defs:
		var c = RuleCard.new()
		c.from_dict(d)
		out.append(c)
	return out

func _load_level(path: String) -> Grid:
	chaos_elements = DEFAULT_CHAOS_ELEMENTS.duplicate()
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("无法打开 %s,使用默认 6x6" % path)
		target = clampi(target, 1, 99999)
		return Grid.new(6, 6)
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("关卡 JSON 无效 %s,使用默认 6x6" % path)
		target = clampi(target, 1, 99999)
		return Grid.new(6, 6)
	_parse_chaos_elements(data)
	var w := 6
	var h := 6
	var size = data.get("size", [6, 6])
	if typeof(size) == TYPE_ARRAY and size.size() >= 2:
		w = clampi(int(size[0]), 6, 32)
		h = clampi(int(size[1]), 6, 32)
	else:
		push_warning("关卡 %s 缺少合法 size, 使用默认 6x6" % path)
	var raw_target = data.get("target")
	if typeof(raw_target) == TYPE_INT or typeof(raw_target) == TYPE_FLOAT:
		target = clampi(int(raw_target), 1, 99999)
	else:
		target = clampi(target, 1, 99999)
	var g = Grid.new(w, h)
	var elems = data.get("elements", [])
	if typeof(elems) != TYPE_ARRAY:
		return g
	for entry in elems:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var coord = entry.get("coord")
		if typeof(coord) != TYPE_ARRAY or coord.size() < 2:
			continue
		var cell = g.get_cell(Vector2i(int(coord[0]), int(coord[1])))
		if cell == null:
			continue
		cell.element = Element.from_string(str(entry.get("element", "NONE")))
		cell.placed_at_turn = 0
	return g

func _parse_chaos_elements(data: Dictionary) -> void:
	var raw = data.get("chaos_elements", [])
	if typeof(raw) != TYPE_ARRAY or raw.is_empty():
		chaos_elements = DEFAULT_CHAOS_ELEMENTS.duplicate()
		return
	var out: Array = []
	for item in raw:
		var elem = Element.from_string(str(item))
		if elem != Element.NONE and not out.has(elem):
			out.append(elem)
	chaos_elements = out if not out.is_empty() else DEFAULT_CHAOS_ELEMENTS.duplicate()

func can_play_card() -> bool:
	return not game_ended and phase == Phase.LAYOUT and energy.can_play() and hand.hand_size() > 0

func get_hand_card(idx: int) -> RuleCard:
	if idx < 0 or idx >= hand.hand_size():
		return null
	return hand.hand[idx]

func play_card(hand_idx: int, coord: Vector2i) -> bool:
	if not can_play_card():
		return false
	var cell = grid.get_cell(coord)
	if cell == null or cell.pillar != null:
		return false
	var card = hand.play(hand_idx, coord)
	if card == null:
		return false
	var p = RulePillar.new(card, coord, turn)
	# pillar 出现时也占用"格子上层"标记,仍允许元素在底层。
	cell.pillar = p
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

func execute(speed: float = 1.0) -> void:
	if phase != Phase.LAYOUT or game_ended:
		return
	_evolution_serial += 1
	var serial := _evolution_serial
	phase = Phase.EVOLVE
	state_changed.emit()
	var runner = ChainReaction.new()
	runner.cancelled = false
	_running_runner = runner
	runner.reaction_applied.connect(_on_reaction)
	var gained = await runner.execute_async(grid, pillars, 0.1, speed, turn, rng)
	if runner.reaction_applied.is_connected(_on_reaction):
		runner.reaction_applied.disconnect(_on_reaction)
	if serial != _evolution_serial or runner.cancelled:
		return  # T2.5: 旧演化已被 start_game/load_game 取消, 结果作废
	if _running_runner == runner:
		_running_runner = null
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
	if grid != null and not game_ended:
		turn_snapshots.append(_snapshot_game())
		if turn_snapshots.size() > MAX_TURN_SNAPSHOTS:
			turn_snapshots.pop_front()
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
	if hand.hand_size() > RETAIN_LIMIT:
		if auto_retention:
			_auto_retain()
			phase = Phase.LAYOUT
		else:
			phase = Phase.RETAIN  # T3.5: 等玩家点击弃牌
	else:
		phase = Phase.LAYOUT
	state_changed.emit()

func _reroll_wind() -> void:
	wind_dir = _randi(4)
	wind_speed = _randi(3) + 1

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
	if grid == null:
		return
	var total = grid.w * grid.h
	var check_elems: Array = chaos_elements
	if check_elems.is_empty():
		check_elems = DEFAULT_CHAOS_ELEMENTS
	for elem in check_elems:
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
				game_ended = true
				phase = Phase.EVOLVE
				var counter: String = str({Element.WATER: "干涸", Element.PLANT: "丛林灭绝", Element.LAVA: "陨石术", Element.GRASS: "丛林灭绝"}.get(elem, ""))
				var hint: String = (" 反制:%s" % counter) if counter != "" else ""
				game_over.emit(false, "混沌失控 — %s 超过 50%%%s" % [CHAOS_NAME.get(elem,"??"), hint])
				return

func _world_rules() -> void:
	# T4.1: 世界规则已拆到 WorldRules.apply_all, 保留同名包装供测试与既有调用
	WorldRulesScript.new().apply_all(grid, level_manager.current_level, turn, wind_dir, wind_speed, rng, pillars)

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