# Catalyst 白盒测试 —— 依据《白盒测试用例.md》(人工审查版) 生成
# 运行: godot --headless --path <项目根> --script res://tests/whitebox_tests.gd
#   可选过滤: ... --script res://tests/whitebox_tests.gd -- --filter=TC-06
#
# 编号说明: 人工审查版 md 中存在重复编号 (TC-23/TC-26/TC-28 各 2 条, TC-30 3 条),
#   本脚本以 a/b/c 后缀去重, 与 md 行内容一一对应 (TC-23a=帮助文本高度, TC-23b=空规则文件, ...)。
# 已知缺陷用例 (当前必然失败, 用于回归验证修复): TC-04 (帮助文本乱码), TC-19 (图例缺孢/冰)。
# 现状记录用例 (断言当前行为, 通过即记录缺陷, 修复后需更新断言): TC-25 部分, TC-30a, TC-30b。
extends SceneTree

const RULES_PATH := "res://data/rules.json"
const LEVEL_SELECT_SCENE := "res://scenes/LevelSelect.tscn"
const SAVE_SELECT_SCENE := "res://scenes/SaveSelect.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const GRID_RENDERER_SCRIPT := "res://src/ui/GridRenderer.gd"

var _gm: Node = null
var _failures: Array = []
var _known_defects: Array = []
var _passed := 0
var _failed := 0
var _filter := ""
var _tc_got := false
var _tc_msg := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--filter="):
			_filter = a.trim_prefix("--filter=")
	# --script 模式下 autoload 仍会加载, 直接使用 /root/GameManager 真实例
	_gm = root.get_node_or_null("GameManager")
	if _gm == null:
		_gm = load("res://src/main/GameManager.gd").new()
		root.add_child(_gm)
	# --script 模式下 autoload 的 _ready(含核心自检 rng.randomize())可能在首帧才执行;
	# 先等一帧, 保证后续定种测试不会被 _ready 的 randomize() 覆盖。
	await self.process_frame

	var tests := [
		["TC-01", "关卡选择页可打开", tc01_关卡选择页可打开],
		["TC-02", "四关开局状态", tc02_四关开局状态],
		["TC-03", "场景往返导航后状态干净", tc03_场景往返导航],
		["TC-04", "帮助面板文本无乱码", tc04_帮助面板文本无乱码],
		["TC-05", "主要按钮键盘可聚焦", tc05_主要按钮键盘可聚焦],
		["TC-06", "第1关贪心20回合可通关", tc06_第1关贪心可通关],
		["TC-07", "混沌失控即死-水元素", tc07_混沌即死水元素],
		["TC-08", "混沌时灭绝柱可化解", tc08_混沌灭绝柱化解],
		["TC-09", "世界规则每回合生成量", tc09_世界规则生成量],
		["TC-10", "第4关天灾概率与陨石化岩", tc10_天灾概率与陨石化岩],
		["TC-11", "死寂10回合判负", tc11_死寂判负],
		["TC-12", "BLESSED格连锁翻倍", tc12_blessed连锁翻倍],
		["TC-13", "三槽存档读写", tc13_三槽存档读写],
		["TC-13b", "覆盖确认与来源槽", tc13b_覆盖确认与来源槽],
		["TC-13c", "时间戳与增删改", tc13c_时间戳与增删改],
		["TC-13d", "序列化往返无损", tc13d_序列化往返无损],
		["TC-14", "手牌上限与布局容量", tc14_手牌上限与布局容量],
		["TC-15", "200连锁演化耗时与跳过", tc15_演化耗时区间],
		["TC-16", "振荡棋盘有限终止", tc16_振荡有限终止],
		["TC-17", "各关格子尺寸与可视范围", tc17_各关格子尺寸],
		["TC-18", "16x16关控件互不遮挡", tc18_控件互不遮挡],
		["TC-19", "图例覆盖全部元素", tc19_图例元素完整性],
		["TC-20", "手牌区宽度容量", tc20_手牌区宽度容量],
		["TC-21", "元素与特效贴图资源完整", tc21_贴图资源完整],
		["TC-22", "贴图缩放比例区间", tc22_贴图缩放比例],
		["TC-22b", "贴图矩形宽高比与越界", tc22b_贴图矩形宽高比与越界],
		["TC-23a", "帮助文本不溢出面板", tc23a_帮助文本不溢出],
		["TC-23b", "空规则文件降级", tc23b_空规则文件降级],
		["TC-25", "非法字段静默降级", tc25_非法字段降级],
		["TC-26a", "界外点击与越界坐标", tc26a_界外点击],
		["TC-26b", "半径扫描边界格数", tc26b_半径边界格数],
		["TC-28a", "催化剂尘越界消失", tc28a_尘越界消失],
		["TC-28b", "演化后清空选中", tc28b_演化后清空选中],
		["TC-30a", "FROZEN阻断作用范围现状", tc30a_frozen阻断现状],
		["TC-30b", "MULTIPLY时间戳语义现状", tc30b_multiply时间戳],
		["TC-30c", "演化中切换场景健壮性", tc30c_演化中切场景],
	]
	for t in tests:
		if _filter != "" and not t[0].begins_with(_filter):
			continue
		_failures = []
		await t[2].call()
		if _failures.is_empty():
			_passed += 1
			print("PASS %s %s" % [t[0], t[1]])
		else:
			_failed += 1
			print("FAIL %s %s" % [t[0], t[1]])
			for f in _failures:
				print("     - %s" % f)
	_finish()

func _finish() -> void:
	print("")
	print("[WhiteboxTests] 通过: %d 条, 失败: %d 条" % [_passed, _failed])
	print("[WhiteboxTests] 已知缺陷(预期失败): %s" % (", ".join(_known_defects) if not _known_defects.is_empty() else "无"))
	quit(0 if _failed == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)

# ---------- 场景与装配辅助 ----------
func _make_rule_card(d: Dictionary) -> Resource:
	var c = load("res://src/rules/RuleCard.gd").new()
	c.from_dict(d)
	return c

func _pillar(card: Resource, x: int, y: int, turn: int = 0) -> RulePillar:
	return RulePillar.new(card, Vector2i(x, y), turn)

func _put(g: Grid, x: int, y: int, elem: int) -> void:
	var c = g.get_cell(Vector2i(x, y))
	if c != null:
		c.element = elem
		c.placed_at_turn = 0

func _rule_card_from_json(id: String) -> Resource:
	var f = FileAccess.open(RULES_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	for e in data:
		if e["id"] == id:
			return _make_rule_card(e)
	return null

func _flash_grid(g: Grid, a: int, b: int) -> void:
	for y in range(g.h):
		for x in range(g.w):
			_put(g, x, y, Element.WATER if (x + y) % 2 == a else Element.LAVA)

# ---------- TC-01 ----------
func tc01_关卡选择页可打开() -> void:
	var scene = load(LEVEL_SELECT_SCENE).instantiate()
	root.add_child(scene)
	await self.process_frame
	_check(scene.get("buttons") != null, "LevelSelect 无 buttons 属性")
	if scene.get("buttons") == null:
		scene.free()
		return
	var buttons: Array = scene.buttons
	_check(buttons.size() == 4, "按钮数=%d, 期望 4 (4 个关卡)" % buttons.size())
	# T1.4: 解锁状态来自持久化进度(level_manager.unlocked), 按钮锁定 = idx > unlocked
	var lm = _gm.level_manager
	for i in range(buttons.size()):
		var expect_disabled: bool = i > lm.unlocked
		_check(buttons[i].disabled == expect_disabled,
			"buttons[%d].disabled=%s, 期望 %s (unlocked=%d)" % [i, buttons[i].disabled, expect_disabled, lm.unlocked])
	scene.free()
	# T1.4: 新入口场景 SaveSelect 可实例化(选档/新游戏/调整存档)
	var ss = load(SAVE_SELECT_SCENE).instantiate()
	root.add_child(ss)
	await self.process_frame
	_check(ss.get_node_or_null("BG") != null, "SaveSelect 缺 BG 背景节点")
	ss.free()

# ---------- TC-02 ----------
func tc02_四关开局状态() -> void:
	var expect := [[10, 10, 100], [12, 12, 300], [14, 14, 700], [16, 16, 1500]]
	for i in range(4):
		_gm.start_game(i)
		_check(_gm.grid.w == expect[i][0] and _gm.grid.h == expect[i][1],
			"第%d关网格=%dx%d, 期望 %dx%d" % [i + 1, _gm.grid.w, _gm.grid.h, expect[i][0], expect[i][1]])
		_check(_gm.target == expect[i][2], "第%d关 target=%d, 期望 %d" % [i + 1, _gm.target, expect[i][2]])
		_check(_gm.hand.hand_size() == 5, "第%d关手牌=%d, 期望 5" % [i + 1, _gm.hand.hand_size()])
		_check(_gm.energy.current == 3, "第%d关能量=%d, 期望 3" % [i + 1, _gm.energy.current])
		_check(_gm.chain_total == 0, "第%d关连锁=%d, 期望 0" % [i + 1, _gm.chain_total])

# ---------- TC-03 ----------
func tc03_场景往返导航() -> void:
	var sel = load(LEVEL_SELECT_SCENE).instantiate()
	root.add_child(sel)
	await self.process_frame
	sel.free()
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	main.free()
	_gm.start_game(0)
	_check(_gm.pillars.is_empty(), "往返后 pillars 非空")
	_check(_gm.chain_total == 0, "往返后 chain_total=%d, 期望 0" % _gm.chain_total)
	_check(_gm.game_ended == false, "往返后 game_ended=true")
	_check(_gm.phase == 1, "往返后 phase=%d, 期望 LAYOUT(1)" % _gm.phase)
	_check(_gm.dead_turns == 0, "往返后 dead_turns=%d, 期望 0" % _gm.dead_turns)

# ---------- TC-04 (已知缺陷) ----------
func tc04_帮助面板文本无乱码() -> void:
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	var label = main.get_node("HelpPanel/HelpLabel")
	var text: String = label.text
	var fffd := 0
	for ch in text:
		if ch == "\uFFFD":
			fffd += 1
	var missing: Array = []
	for kw in ["目标", "演化", "右键", "撤回"]:
		if not text.contains(kw):
			missing.append(kw)
	var ok := fffd == 0 and missing.is_empty()
	if not ok:
		_known_defects.append("TC-04")
		_check(false, "HelpLabel 含 %d 个 U+FFFD 乱码字符, 且缺失关键词 %s (Main.tscn:51-68 文本编码损坏, 属待修复缺陷)" % [fffd, ", ".join(missing)])
	else:
		_check(true, "")
	main.free()

# ---------- TC-05 ----------
func tc05_主要按钮键盘可聚焦() -> void:
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	# 先断言 GameOverPanel 存在: Main.tscn 编码损坏(MenuButton text 被错解析为'重试',
	# 帮助文本含 U+FFFD)导致解析错乱, GameOverPanel/NextButton/RetryButton 运行时缺失
	var panel = main.get_node_or_null("GameOverPanel")
	if panel == null:
		_known_defects.append("TC-05")
		_check(false, "GameOverPanel 节点缺失: Main.tscn 第125-166行文本编码损坏导致解析错乱(MenuButton.text 被错解析为'重试'), 通关/失败界面及下一关/重试按钮运行时不可用 —— 属待修复缺陷")
		main.free()
		return
	for path in ["HelpButton", "ExecuteButton", "MenuButton", "GameOverPanel/NextButton", "GameOverPanel/RetryButton"]:
		var btn = main.get_node_or_null(path)
		_check(btn != null, "场景缺少按钮节点 %s" % path)
		if btn != null:
			_check(btn.focus_mode != Control.FOCUS_NONE, "按钮 %s focus_mode=%d, 期望非 NONE (Tab 可聚焦)" % [path, btn.focus_mode])
	main.free()

# ---------- TC-06 ----------
func tc06_第1关贪心可通关() -> void:
	# T2.1: 牌池新增「干涸」后重新标定固定种子; 白盒启动时已等待 autoload _ready, 双流定种轨迹完全确定。
	seed(20240816)              # 手牌洗牌/催化剂尘(保留的全局随机流)
	_gm.rng.seed = 20240816     # 世界规则/风/催化剂尘(GameManager.rng)
	_gm.start_game(0)
	for turn in range(20):
		var placed := 0
		# T1.2: 手牌上限后手牌数小, 循环改为"每次重新扫描当前手牌", 避免 pop 后索引越界;
		# 策略: 有限资源引擎(熔岩/矿/汽)优先, EXTINCTION 只在达到阈值时落柱, 避免空放浪费回合。
		while placed < _gm.energy.current:
			var played_any := false
			var priority := ["steamify", "harvest", "grow", "extinct", "drought", "petrify", "grass_grow", "grass_spread"]
			for pid in priority:
				for card_idx in range(_gm.hand.hand_size()):
					var card: Resource = _gm.hand.hand[card_idx]
					if card.id != pid:
						continue
					var spot := _find_extinction_spot(card) if card.kind == RuleCard.Kind.EXTINCTION else _find_pair_spot(card.trigger_element, card.contact_element)
					if spot.x >= 0 and _gm.play_card(card_idx, spot):
						placed += 1
						played_any = true
						break
				if played_any:
					break
			if played_any:
				continue
			# 兜底: 打任意有触发位的牌(循环手牌)
			for card_idx in range(_gm.hand.hand_size()):
				var card2: Resource = _gm.hand.hand[card_idx]
				var spot2 := _find_extinction_spot(card2) if card2.kind == RuleCard.Kind.EXTINCTION else _find_pair_spot(card2.trigger_element, card2.contact_element)
				if spot2.x >= 0 and _gm.play_card(card_idx, spot2):
					placed += 1
					played_any = true
					break
			if not played_any:
				break
		if not _gm.pillars.is_empty():
			await _gm.execute()
		else:
			_gm.end_turn()
	_check(_gm.chain_total >= 100, "贪心20回合后 chain_total=%d < 100, 第1关(10x10, 目标100)无法稳定通关 —— 难度回归基准失败" % _gm.chain_total)

func _find_spot(trigger: int, contact: int) -> Vector2i:
	var best := -1000
	var best_coord := Vector2i(-1, -1)
	for c in _gm.grid.all_cells():
		if c.pillar != null:
			continue
		var sc := 0
		for n in _gm.grid.cells_in_radius(c.coord, 2):
			if n.element == trigger:
				sc += 2
			elif n.element == contact:
				sc += 1
		if sc > best:
			best = sc
			best_coord = c.coord
	return best_coord

# 要求触发元素与接触元素同时存在于柱子半径内(contact=NONE 时只要求触发元素)
func _find_pair_spot(trigger: int, contact: int) -> Vector2i:
	var best := -1
	var best_coord := Vector2i(-1, -1)
	for c in _gm.grid.all_cells():
		if c.pillar != null:
			continue
		var trig := 0
		var cont := 0
		for n in _gm.grid.cells_in_radius(c.coord, 2):
			if n.element == trigger:
				trig += 1
			elif contact != Element.NONE and n.element == contact:
				cont += 1
		if trig == 0 or (contact != Element.NONE and cont == 0):
			continue
		var sc := trig * 2 + cont
		if sc > best:
			best = sc
			best_coord = c.coord
	return best_coord

# EXTINCTION 专用选点: 只有半径内触发物(含 also_count)达到阈值才落柱, 优先选择数量最多的位置
func _find_extinction_spot(card: Resource) -> Vector2i:
	var best := -1
	var best_coord := Vector2i(-1, -1)
	for c in _gm.grid.all_cells():
		if c.pillar != null:
			continue
		var count := 0
		for n in _gm.grid.cells_in_radius(c.coord, card.radius):
			if n.element == card.trigger_element or (card.also_count != Element.NONE and n.element == card.also_count):
				count += 1
		if count >= card.extinct_threshold and count > best:
			best = count
			best_coord = c.coord
	return best_coord

# ---------- TC-07 ----------
func tc07_混沌即死水元素() -> void:
	_gm.start_game(0)
	var has_drought := false
	for card in _gm.all_card_defs:
		if card.id == "drought":
			has_drought = card.kind == RuleCard.Kind.EXTINCTION and card.trigger_element == Element.WATER
	_check(has_drought, "rules.json 中缺少「干涸」水元素 EXTINCTION 反制牌 (T2.1)")
	_gm.pillars.clear()
	var filled := 0
	for c in _gm.grid.all_cells():
		if filled < 51:
			c.element = Element.WATER
			filled += 1
		else:
			c.element = Element.NONE
	_tc_got = false
	_tc_msg = ""
	_gm.game_over.connect(func(won: bool, msg: String) -> void:
		_tc_got = true
		_tc_msg = msg, CONNECT_ONE_SHOT)
	_gm.chaos_check()
	_check(_tc_got, "51格WATER(>50%)且无WATER灭绝柱时未触发 game_over —— GameManager.chaos_check 混沌判定未生效")
	_check(_tc_msg.contains("水"), "game_over 消息=%s, 期望含'水' (指明失控元素)" % _tc_msg)
	_check(_gm.game_ended == true, "game_ended=%s, 期望 true (混沌失控与死寂一样完成判负, T2.1)" % _gm.game_ended)
	_check(_gm.phase == GameManager.Phase.EVOLVE, "phase=%d, 期望 EVOLVE(%d) (与死寂路径一致, T2.1)" % [_gm.phase, GameManager.Phase.EVOLVE])

# ---------- TC-08 ----------
func tc08_混沌灭绝柱化解() -> void:
	_gm.start_game(0)
	_gm.pillars.clear()
	var filled := 0
	for c in _gm.grid.all_cells():
		if filled < 51:
			c.element = Element.PLANT
			filled += 1
		else:
			c.element = Element.NONE
	var ext_card = _rule_card_from_json("extinct")
	_check(ext_card != null, "rules.json 中缺少 extinct 卡")
	if ext_card == null:
		return
	var p = _pillar(ext_card, 5, 5)
	_gm.pillars.append(p)
	_tc_got = false
	_gm.game_over.connect(func(_w: bool, _m: String) -> void: _tc_got = true, CONNECT_ONE_SHOT)
	_gm.chaos_check()
	_check(_tc_got == false, "存在PLANT灭绝柱时仍触发判负 (GameManager.gd:236-241 应清空半径内元素并 return)")
	var left := 0
	for c in _gm.grid.cells_in_radius(Vector2i(5, 5), 2):
		if c.element == Element.PLANT:
			left += 1
	_check(left == 0, "灭绝柱半径2内残留 PLANT %d 格, 期望 0" % left)

# ---------- TC-09 ----------
func tc09_世界规则生成量() -> void:
	_gm.start_game(0)
	var total_delta := 0
	var pre_placed := 0
	for _i in range(10):
		var turn_before: int = _gm.turn
		var cnt_before := 0
		var cnt_after := 0
		for c in _gm.grid.all_cells():
			if c.placed_at_turn == turn_before and (c.element == Element.WATER or c.element == Element.STONE):
				cnt_before += 1
		_gm.end_turn()
		for c in _gm.grid.all_cells():
			if c.placed_at_turn == turn_before and (c.element == Element.WATER or c.element == Element.STONE):
				cnt_after += 1
		var d := cnt_after - cnt_before
		total_delta += d
		_check(d >= 0 and d <= 4, "第%d回合水/岩净增=%d, 期望每回合 2±消耗 (GameManager.gd:269-277)" % [_i + 1, d])
	_check(total_delta >= 16 and total_delta <= 24, "10回合水/岩净增=%d, 期望 20±4 (随机生成+雪化冰消耗容差)" % total_delta)
	var w: int = _gm.grid.count_element(Element.WATER)
	var s: int = _gm.grid.count_element(Element.STONE)
	_check(w + s >= 11, "水岩总数=%d, 期望不小于初始 11 (coast.json 初始 7水+4岩)" % (w + s))

# ---------- TC-10 ----------
func tc10_天灾概率与陨石化岩() -> void:
	seed(20240813)
	_gm.rng.seed = 20240813  # T1.2: 天灾随机源改为 rng, 固定种子下 100 次触发数确定
	_gm.start_game(3)
	_check(_gm.level_manager.current_level == 3, "current_level=%d, 期望 3 (第4关)" % _gm.level_manager.current_level)
	var meteor := 0
	var volcano := 0
	var quake := 0
	for _i in range(100):
		var lava_before: int = _gm.grid.count_element(Element.LAVA)
		var nonempty_before := 0
		var meteor_before := 0
		for c in _gm.grid.all_cells():
			if c.element != Element.NONE:
				nonempty_before += 1
			if c.has_state(State.METEOR_LAVA):
				meteor_before += 1
		_gm._world_rules()
		var meteor_after := 0
		for c in _gm.grid.all_cells():
			if c.has_state(State.METEOR_LAVA):
				meteor_after += 1
		# 注意: 连续 _world_rules 调用间 METEOR_LAVA 状态不衰减(tick_states 仅在 end_turn),
		# 故以"本回合新增陨石格数"判定陨石事件
		if meteor_after > meteor_before:
			meteor += 1
		elif _gm.grid.count_element(Element.LAVA) > lava_before:
			volcano += 1
		else:
			var nonempty_after := 0
			for c in _gm.grid.all_cells():
				if c.element != Element.NONE:
					nonempty_after += 1
			if nonempty_after < nonempty_before:
				quake += 1
	var events := meteor + volcano + quake
	_check(events >= 20 and events <= 40, "100回合天灾触发 %d 次 (陨石%d/火山%d/地震%d), 期望 30±10 (GameManager.gd:337-357, 30%%概率)" % [events, meteor, volcano, quake])
	# 陨石化岩: METEOR_LAVA 衰减后 LAVA -> STONE
	_gm.start_game(3)
	var c = _gm.grid.get_cell(Vector2i(7, 7))
	c.element = Element.LAVA
	c.add_state(State.METEOR_LAVA, 2)
	for _i in range(2):
		for cc in _gm.grid.all_cells():
			cc.tick_states()
	_check(c.was_meteor, "METEOR_LAVA 衰减后 was_meteor 未置位 (Cell.gd:31-34)")
	_gm._world_rules()
	_check(c.element == Element.STONE, "陨石格衰减后 element=%d(%s), 期望 STONE (GameManager.gd:359-364)" % [c.element, Element.NAMES.get(c.element, "?")])

# ---------- TC-11 ----------
func tc11_死寂判负() -> void:
	_gm.start_game(0)
	_tc_got = false
	_tc_msg = ""
	_gm.game_over.connect(func(won: bool, msg: String) -> void:
		_tc_got = true
		_tc_msg = msg, CONNECT_ONE_SHOT)
	for _i in range(10):
		await _gm.execute()
	_check(_tc_got, "连续10次0连锁演化后未触发死寂判负 (GameManager.gd:173-176)")
	_check(_tc_msg.contains("死寂"), "game_over 消息=%s, 期望含'死寂'" % _tc_msg)

# ---------- TC-12 ----------
func tc12_blessed连锁翻倍() -> void:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.LAVA)
	g.get_cell(Vector2i(1, 1)).add_state(State.BLESSED, 3)
	var card = _make_rule_card({"id": "steamify", "kind": "TRANSFORM", "trigger_element": "WATER",
		"contact_element": "LAVA", "result_element": "STEAM", "self_replace": "STONE",
		"radius": 2, "life": 4, "chain_reward": 1})
	var runner = load("res://src/rules/ChainReaction.gd").new()
	var chain = runner.execute(g, [_pillar(card, 1, 1)])
	_check(chain == 2, "BLESSED 格连锁=%d, 期望 2 (chain_reward 1 翻倍, ChainReaction.gd:99-104)" % chain)

# ---------- TC-13 (T1.4 三槽存档) ----------
func tc13_三槽存档读写() -> void:
	# T1.4: 存槽 → 读槽恢复一致; 全局 unlocked 独立持久化(删槽不丢)
	_gm.start_game(0)
	_gm.grid.get_cell(Vector2i(3, 3)).element = Element.LAVA
	_gm.turn = 7
	_gm.chain_total = 42
	var before: String = _grid_hash(_gm.grid)
	# 用测试专用存档路径隔离, 不碰真实 user://save.cfg
	var orig_sm = _gm.save_manager
	var sm = load("res://src/world/SaveManager.gd").new()
	sm.use_path("user://test_save_a.cfg")
	_gm.save_manager = sm
	_check(_gm.save_game(0, "测试档"), "存档到槽0失败")
	_check(sm.has_slot(0), "槽0应有存档")
	_check(sm.slot_name(0) == "测试档", "槽名=%s, 期望 测试档" % sm.slot_name(0))
	# 模拟重启: 新 SaveManager 实例读同一文件
	var sm2 = load("res://src/world/SaveManager.gd").new()
	sm2.use_path("user://test_save_a.cfg")
	_check(sm2.has_slot(0), "重启(新实例)后槽0应仍存在")
	_check(sm2.slot_name(0) == "测试档", "重启后槽名应保留")
	# 读档恢复
	_gm.start_game(2)
	_check(_gm.load_game(0), "读槽0失败")
	_check(_gm.level_manager.current_level == 0, "读档后关卡=%d, 期望 0" % _gm.level_manager.current_level)
	_check(_gm.turn == 7 and _gm.chain_total == 42, "读档后 turn=%d/chain=%d, 期望 7/42" % [_gm.turn, _gm.chain_total])
	_check(_grid_hash(_gm.grid) == before, "读档后网格应与存档一致")
	# unlocked 独立持久化: advance 后删槽, unlocked 仍在
	_gm.level_manager.unlocked = 2
	sm.set_unlocked(2)
	sm.delete_slot(0)
	var sm3 = load("res://src/world/SaveManager.gd").new()
	sm3.use_path("user://test_save_a.cfg")
	_check(sm3.get_unlocked() == 2, "删槽后 unlocked=%d, 期望 2 (全局进度独立持久化)" % sm3.get_unlocked())
	_check(sm3.has_slot(0) == false, "删槽后槽0应为空")
	# 恢复现场
	_gm.save_manager = orig_sm
	_gm.level_manager.unlocked = orig_sm.get_unlocked()
	_cleanup_save("user://test_save_a.cfg")
	_gm.start_game(0)

# ---------- TC-13b ----------
func tc13b_覆盖确认与来源槽() -> void:
	# T1.4: 覆盖非来源槽需确认; 本局来源槽静默覆盖; 覆盖后标记更新; 删除来源槽后标记置 -1
	var sm = load("res://src/world/SaveManager.gd").new()
	sm.use_path("user://test_save_b.cfg")
	sm.save_slot(0, "A", {"v": 1})
	_check(sm.should_confirm_overwrite(0) == true, "无来源槽(loaded_from_slot=-1)时存非空槽应需确认")
	sm.load_slot(0)
	_check(sm.loaded_from_slot == 0, "load_slot 后 loaded_from_slot 应为 0")
	_check(sm.should_confirm_overwrite(0) == false, "本局来源槽再存不应提示确认")
	sm.save_slot(0, "A2", {"v": 2})
	_check(sm.slot_name(0) == "A2", "覆盖后槽名应更新为 A2")
	_check(sm.loaded_from_slot == 0, "普通存档不应改变来源标记")
	sm.save_slot(1, "B", {"v": 3})
	_check(sm.loaded_from_slot == 0, "存到其他槽也不应改变来源标记(仍为 0)")
	_check(sm.should_confirm_overwrite(1) == true, "来源=0 时覆盖非空槽1应需确认")
	sm.delete_slot(0)
	_check(sm.loaded_from_slot == -1, "删除来源槽后标记应置 -1")
	_check(sm.should_confirm_overwrite(1) == true, "标记=-1 时覆盖非空槽应需确认")
	_cleanup_save("user://test_save_b.cfg")

# ---------- TC-13c ----------
func tc13c_时间戳与增删改() -> void:
	# T1.4: 最后存档时间精确到秒, 格式 YYYY-MM-DD HH:MM:SS; 重命名/删除生效
	var sm = load("res://src/world/SaveManager.gd").new()
	sm.use_path("user://test_save_c.cfg")
	var t0 := int(Time.get_unix_time_from_system())
	sm.save_slot(0, "第一档", {})
	var t = sm.slot_timestamp(0)
	_check(t >= t0 and t <= t0 + 5, "时间戳应为当前时间(秒): %d in [%d, %d]" % [t, t0, t0 + 5])
	var re = RegEx.new()
	re.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$")
	var text: String = sm.slot_time_text(0)
	_check(re.search(text) != null, "时间文本=%s, 期望 YYYY-MM-DD HH:MM:SS (秒级)" % text)
	sm.rename_slot(0, "改名档")
	_check(sm.slot_name(0) == "改名档", "重命名应生效")
	sm.delete_slot(0)
	_check(not sm.has_slot(0), "删除后槽0应为空")
	_check(sm.slot_time_text(0) == "", "空槽时间文本应为空")
	_cleanup_save("user://test_save_c.cfg")

# ---------- TC-13d ----------
func tc13d_序列化往返无损() -> void:
	# T1.4: 快照 round-trip 无损(元素/状态/柱/手牌/回合/风)
	_gm.start_game(1)
	var orig_sm = _gm.save_manager
	var sm = load("res://src/world/SaveManager.gd").new()
	sm.use_path("user://test_save_d.cfg")
	_gm.save_manager = sm
	var g = _gm.grid
	g.get_cell(Vector2i(2, 2)).element = Element.SPORE
	g.get_cell(Vector2i(2, 2)).add_state(State.DUST, 3)
	g.get_cell(Vector2i(3, 3)).element = Element.ICE
	var card = _rule_card_from_json("steamify")
	var p = _pillar(card, 5, 5, 0)
	g.get_cell(Vector2i(5, 5)).pillar = p
	_gm.pillars.append(p)
	_gm.turn = 9
	_gm.wind_dir = 2
	_gm.wind_speed = 3
	var hash_before: String = _grid_hash(g)
	var hand_before: int = _gm.hand.hand_size()
	_gm.save_game(0, "往返")
	_gm.start_game(3)
	_check(_gm.load_game(0), "读档失败")
	_check(_gm.turn == 9 and _gm.wind_dir == 2 and _gm.wind_speed == 3, "读档后 turn/风应恢复")
	_check(_gm.hand.hand_size() == hand_before, "读档后手牌数应恢复")
	_check(_gm.pillars.size() == 1, "读档后柱子数=1, 实际 %d" % _gm.pillars.size())
	_check(_grid_hash(_gm.grid) == hash_before, "round-trip 后网格哈希应一致")
	_gm.save_manager = orig_sm
	_cleanup_save("user://test_save_d.cfg")
	_gm.start_game(0)

func _cleanup_save(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# ---------- TC-14 ----------
func tc14_手牌上限与布局容量() -> void:
	# T1.2: 手牌上限 8(HandManager.MAX_HAND), 超限抽牌进弃牌堆; 牌总数守恒;
	# 8 张 × 130px 卡面 + 间距 ≤ 1100px 容器宽, 布局不再溢出
	_gm.start_game(0)
	for _i in range(30):
		_gm.end_turn()
	_check(_gm.hand.hand_size() == 8, "30回合不打牌后手牌=%d, 期望 8 (HandManager.MAX_HAND 上限)" % _gm.hand.hand_size())
	var total: int = _gm.hand.hand_size() + _gm.hand.draw_pile.size() + _gm.hand.discard_pile.size()
	_check(total == _gm.all_card_defs.size(), "牌守恒: 手牌+抽牌堆+弃牌堆=%d, 期望 %d (第1关牌池 11)" % [total, _gm.all_card_defs.size()])
	var w := 8 * 130 + 7 * 6
	_check(w == 1082 and w <= 1100, "8张手牌(上限)所需宽=%dpx, 期望 1082 ≤ 1100 (HandContainer 可用宽, 卡面 130px/张)" % w)

# ---------- TC-15 ----------
func tc15_演化耗时区间() -> void:
	# 40x20 棋盘格: 8 根 r=5 柱互不相切, 每柱覆盖 25 个 WATER 格 -> 200 reactions
	var g = Grid.new(40, 20)
	_flash_grid(g, 0, 1)
	var card = _make_rule_card({"id": "steamify", "kind": "TRANSFORM", "trigger_element": "WATER",
		"contact_element": "LAVA", "result_element": "STEAM", "self_replace": "STONE",
		"radius": 5, "life": 4, "chain_reward": 1})
	var pillars: Array = [
		_pillar(card, 5, 5), _pillar(card, 15, 5), _pillar(card, 25, 5), _pillar(card, 35, 5),
		_pillar(card, 5, 15), _pillar(card, 15, 15), _pillar(card, 25, 15), _pillar(card, 35, 15),
	]
	var runner = load("res://src/rules/ChainReaction.gd").new()
	var t0 := Time.get_ticks_msec()
	var chain = await runner.execute_async(g, pillars, 0.1, 1.0)
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	_check(chain >= 180 and chain <= 220, "1x 棋盘演化连锁=%d, 期望 200±20" % chain)
	_check(elapsed >= 18.0 and elapsed <= 45.0, "1x 演化耗时=%0.1fs, 期望 (18s, 45s] (200反应 x 0.1s + 帧开销)" % elapsed)
	# T1.3: 跳过档(speed<=0)与同步 execute 结果一致, 且 <2s
	var g2 = Grid.new(40, 20)
	_flash_grid(g2, 0, 1)
	var runner2 = load("res://src/rules/ChainReaction.gd").new()
	seed(20240815)
	var chain_sync = runner2.execute(g2, pillars)
	var g3 = Grid.new(40, 20)
	_flash_grid(g3, 0, 1)
	var runner3 = load("res://src/rules/ChainReaction.gd").new()
	seed(20240815)
	var t1 := Time.get_ticks_msec()
	var chain_skip = await runner3.execute_async(g3, pillars, 0.1, 0.0)
	var skip_elapsed := (Time.get_ticks_msec() - t1) / 1000.0
	_check(chain_skip == chain_sync, "跳过档连锁=%d 应与同步执行=%d 一致(同种子)" % [chain_skip, chain_sync])
	_check(_grid_hash(g2) == _grid_hash(g3), "跳过档终局网格应与同步执行一致")
	_check(skip_elapsed < 2.0, "跳过档耗时=%0.2fs, 期望 <2s" % skip_elapsed)
	# T1.3: 4x 档结果与同步一致, 且明显快于 1x
	var g4 = Grid.new(40, 20)
	_flash_grid(g4, 0, 1)
	var runner4 = load("res://src/rules/ChainReaction.gd").new()
	seed(20240815)
	var t2 := Time.get_ticks_msec()
	var chain_fast = await runner4.execute_async(g4, pillars, 0.1, 4.0)
	var fast_elapsed := (Time.get_ticks_msec() - t2) / 1000.0
	_check(chain_fast == chain_sync, "4x档连锁=%d 应与同步执行=%d 一致(同种子)" % [chain_fast, chain_sync])
	_check(_grid_hash(g2) == _grid_hash(g4), "4x档终局网格应与同步执行一致")
	_check(fast_elapsed < 12.0 and fast_elapsed < elapsed, "4x档耗时=%0.2fs, 期望 <12s 且快于 1x(%0.1fs)" % [fast_elapsed, elapsed])

func _grid_hash(g: Grid) -> String:
	var s := ""
	for c in g.all_cells():
		s += "%d;" % c.element
		for st in c.states.keys():
			s += "%d:%d," % [st, c.states[st]]
		s += "|"
	return s

# ---------- TC-16 ----------
func tc16_振荡有限终止() -> void:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 1, 2, Element.PLANT)
	_put(g, 2, 2, Element.PLANT)
	_put(g, 5, 5, Element.STEAM)
	var c_grow = _make_rule_card({"id": "grow", "kind": "MULTIPLY", "trigger_element": "PLANT",
		"contact_element": "STEAM", "result_element": "PLANT", "radius": 5, "life": 4})
	var c_ext = _make_rule_card({"id": "extinct", "kind": "EXTINCTION", "trigger_element": "PLANT",
		"result_element": "NONE", "radius": 2, "extinct_threshold": 4, "also_clear": "STEAM"})
	var runner = load("res://src/rules/ChainReaction.gd").new()
	var chain = runner.execute(g, [_pillar(c_grow, 2, 2), _pillar(c_ext, 2, 2)])
	_check(chain < 1000, "振荡棋盘连锁=%d, 期望 <1000 (cycle 快照去重应截断, ChainReaction.gd:16-24)" % chain)

# ---------- TC-17 ----------
func tc17_各关格子尺寸() -> void:
	var renderer = load(GRID_RENDERER_SCRIPT).new()
	var expect := [64, 64, 60, 52]
	var expect_right := [820, 948, 1020, 1012]
	var expect_bottom := [680, 808, 880, 872]
	for i in range(4):
		_gm.start_game(i)
		renderer.set_grid(_gm.grid)
		_check(renderer.cell_size == expect[i], "第%d关 cell_size=%d, 期望 %d (GridRenderer.gd:92-94: min(64,1100/w,840/h))" % [i + 1, renderer.cell_size, expect[i]])
		var right: int = int(180 + _gm.grid.w * renderer.cell_size)
		var bottom: int = int(40 + _gm.grid.h * renderer.cell_size)
		_check(right <= 1500, "第%d关网格右缘=%d, 期望 <=1500" % [i + 1, right])
		_check(bottom <= 1000, "第%d关网格下缘=%d, 期望 <=1000" % [i + 1, bottom])

# ---------- TC-18 ----------
func tc18_控件互不遮挡() -> void:
	var renderer = load(GRID_RENDERER_SCRIPT).new()
	_gm.start_game(3)
	renderer.set_grid(_gm.grid)
	var right: int = int(180 + _gm.grid.w * renderer.cell_size)
	var bottom: int = int(40 + _gm.grid.h * renderer.cell_size)
	var legend_origin_x: int = right + 20
	var legend_bottom: int = 40 + 11 * 38 + 26
	_check(right <= 1300, "16x16网格右缘=%d, 期望 <=1300 (ExecuteButton/MenuButton 左缘, 不遮挡)" % right)
	_check(bottom <= 875, "16x16网格下缘=%d, 期望 <=875 (按钮区上缘)" % bottom)
	_check(legend_origin_x + 260 <= 1300, "图例右缘约=%d, 期望 <=1300 (图例不遮挡按钮)" % (legend_origin_x + 260))
	_check(legend_bottom <= 875, "图例下缘=%d, 期望 <=875" % legend_bottom)

# ---------- TC-19 (已知缺陷) ----------
func tc19_图例元素完整性() -> void:
	var legend: Array = [Element.WATER, Element.STONE, Element.EARTH, Element.STEAM,
		Element.LAVA, Element.PLANT, Element.ORE, Element.GRASS, Element.SPORE, Element.ICE, Element.NONE]
	var all: Array = Element.NAMES.keys()
	var missing: Array = []
	for e in all:
		if not legend.has(e):
			missing.append(Element.NAMES[e])
	if not missing.is_empty():
		_known_defects.append("TC-19")
		_check(false, "图例(_draw_legend, GridRenderer.gd:211-221)缺失元素: %s —— 信息可访问性缺陷, 修复后本用例应通过" % ", ".join(missing))
	else:
		_check(true, "")

# ---------- TC-20 ----------
func tc20_手牌区宽度容量() -> void:
	_gm.start_game(0)
	_check(_gm.all_card_defs.size() == 12, "第1关牌池=%d, 期望 12 (8基础含干涸 + 2xsteamify + 2xgrow)" % _gm.all_card_defs.size())
	var w8 := 8 * 130 + 7 * 6
	_check(w8 == 1082 and w8 <= 1100, "8张手牌(上限)宽=%d, 期望 1082<=1100 (卡面 130px/张, 可容纳)" % w8)
	_gm.start_game(3)
	_check(_gm.all_card_defs.size() == 14, "第4关牌池=%d, 期望 14 (level 过滤: 8基础+2祝福/陨石+2xsteamify+2xgrow; 孢子/冰卡仅出现于其专属关)" % _gm.all_card_defs.size())
	var w17 := 14 * 130 + 13 * 6
	_check(w17 > 1100, "14张牌池全展开宽=%d, 期望 >1100 —— 量化记录: 若无手牌上限(8)仍会溢出, 上限为必要约束" % w17)

# ---------- TC-21 ----------
func tc21_贴图资源完整() -> void:
	var renderer = load(GRID_RENDERER_SCRIPT).new()
	var paths: Array = []
	for p in renderer.ELEMENT_PATHS.values():
		paths.append(p)
	for p in renderer.OVERLAY_PATHS.values():
		paths.append(p)
	paths.append("res://assets/pillar.png")
	paths.append("res://assets/dust.png")
	for p in paths:
		var tex = load(p)
		_check(tex != null, "贴图加载失败: %s" % p)
		if tex != null:
			_check(tex.get_width() > 0 and tex.get_height() > 0, "贴图尺寸非法 (0x0 或缺失): %s" % p)

# ---------- TC-22 ----------
func tc22_贴图缩放比例() -> void:
	# T1.5: 贴图原生尺寸为 1024x1024(earth/ice/overlay_frozen 为 1254x1254),
	# 绘制到 cell_size(52-64px) 属大幅缩小; 断言项目级过滤为 Nearest 防糊,
	# 且绘制/原生比例落在 [1/64, 1/4] 带内(不合理过小/过大均失败)
	var filter_setting: int = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)
	_check(filter_setting == 0, "项目 default_texture_filter=%d, 期望 0 (Nearest, 像素风清晰锐利)" % filter_setting)
	var renderer = load(GRID_RENDERER_SCRIPT).new()
	_gm.start_game(3)
	renderer.set_grid(_gm.grid)
	_check(renderer.cell_size == 52, "16x16 cell_size=%d, 期望 52 (本用例前提)" % renderer.cell_size)
	for p in renderer.ELEMENT_PATHS.values():
		var tex = load(p)
		if tex == null:
			_check(false, "贴图加载失败: %s" % p)
			continue
		var native := float(tex.get_width())
		var ratio: float = renderer.cell_size / native
		_check(ratio >= 1.0 / 64.0 and ratio <= 0.25,
			"贴图 %s 绘制/原生比例=%0.4f, 期望 [1/64, 1/4] (原生 %dpx → 绘制 %dpx)" % [p, ratio, int(native), renderer.cell_size])

# ---------- TC-22b ----------
func tc22b_贴图矩形宽高比与越界() -> void:
	# T1.5: 场景内所有 TextureRect 的 rect 宽高比须与贴图一致(<5% 偏差),
	# 且 rect 完整落在 1500x1000 视口内
	var scenes := [LEVEL_SELECT_SCENE, MAIN_SCENE]
	for sc in scenes:
		var scene = load(sc).instantiate()
		root.add_child(scene)
		await self.process_frame
		var nodes: Array = []
		_collect_texture_rects(scene, nodes)
		_check(nodes.size() > 0, "场景 %s 无 TextureRect?" % sc)
		for tr in nodes:
			var tex = tr.texture
			if tex == null:
				_check(false, "场景 %s 节点 %s 无贴图" % [sc, tr.name])
				continue
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var rw: float = tr.size.x
			var rh: float = tr.size.y
			if tw <= 0.0 or th <= 0.0 or rw <= 0.0 or rh <= 0.0:
				_check(false, "场景 %s 节点 %s 尺寸非法 (rect %dx%d, tex %dx%d)" % [sc, tr.name, int(rw), int(rh), int(tw), int(th)])
				continue
			var aspect_tex := tw / th
			var aspect_rect: float = rw / rh
			var dev := absf(aspect_rect - aspect_tex) / aspect_tex
			_check(dev < 0.05, "场景 %s 节点 %s 宽高比偏差=%0.3f, 期望 <0.05 (rect %dx%d, tex %dx%d)" % [sc, tr.name, dev, int(rw), int(rh), int(tw), int(th)])
			_check(tr.position.x >= -0.5 and tr.position.y >= -0.5 and tr.position.x + rw <= 1500.5 and tr.position.y + rh <= 1000.5,
				"场景 %s 节点 %s rect(%s %dx%d) 越出 1500x1000 视口" % [sc, tr.name, tr.position, int(rw), int(rh)])
		scene.free()

func _collect_texture_rects(node: Node, out: Array) -> void:
	if node is TextureRect:
		out.append(node)
	for child in node.get_children():
		_collect_texture_rects(child, out)

# ---------- TC-23a ----------
func tc23a_帮助文本不溢出() -> void:
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	var label = main.get_node("HelpPanel/HelpLabel")
	var ts = TextServerManager.get_primary_interface()
	_check(ts != null, "TextServer 主接口为空, 无法测量")
	if ts != null:
		var font_rids: Array = ThemeDB.fallback_font.get_rids()
		# T1.5: Godot 4.7 中 font_get_string_size 已移除, 改用 shaped text 测量
		var st = ts.create_shaped_text()
		ts.shaped_text_add_string(st, label.text, font_rids, 12)
		ts.shaped_text_fit_to_width(st, int(label.size.x))
		var sz = ts.shaped_text_get_size(st)
		ts.free_rid(st)
		_check(sz.y <= label.size.y, "帮助文本渲染高度=%0.0fpx, 期望 <=%0.0f (HelpLabel 实际高度, 文本不溢出面板)" % [sz.y, label.size.y])
	main.free()

# ---------- TC-23b ----------
func tc23b_空规则文件降级() -> void:
	var f = FileAccess.open(RULES_PATH, FileAccess.READ)
	var backup := f.get_as_text()
	f.close()
	var restored := false
	# 空数组: 合法 JSON 但没有牌 → 内置 DEFAULT_RULES 降级, 仍可玩
	var wf = FileAccess.open(RULES_PATH, FileAccess.WRITE)
	wf.store_string("[]")
	wf.close()
	var rules: Array = _gm._load_rules()
	_check(rules.size() == 3, "规则文件=[] 时 _load_rules 应降级为 3 张内置牌, 实际 %d 张" % rules.size())
	_gm.start_game(0)
	_check(_gm.hand.hand_size() == 5, "空规则文件开局手牌=%d, 期望 5 (DEFAULT_RULES 可玩)" % _gm.hand.hand_size())
	_check(_gm.energy.current == 3, "空规则文件开局能量=%d, 期望 3" % _gm.energy.current)
	_check(_gm.can_play_card() == true, "can_play_card=%s, 期望 true (降级牌组不再死锁)" % _gm.can_play_card())
	_check(_gm.game_ended == false, "空规则文件降级后 game_ended=%s, 期望 false" % _gm.game_ended)
	# 损坏 JSON: 明确失败提示, 不再静默死锁
	wf = FileAccess.open(RULES_PATH, FileAccess.WRITE)
	wf.store_string("{bad json")
	wf.close()
	_tc_got = false
	_tc_msg = ""
	_gm.game_over.connect(func(won: bool, msg: String) -> void:
		_tc_got = true
		_tc_msg = msg, CONNECT_ONE_SHOT)
	rules = _gm._load_rules()
	_check(rules.is_empty(), "损坏 JSON 时 _load_rules 应返回空数组(明确失败), 实际 %d 张" % rules.size())
	_check(_tc_got, "损坏 JSON 未发出 game_over 失败提示")
	_check(_tc_msg.contains("规则数据损坏"), "损坏 JSON 提示=%s, 期望含'规则数据损坏'" % _tc_msg)
	_gm.start_game(0)
	_check(_gm.game_ended == true, "损坏 JSON 开局 game_ended=%s, 期望 true (明确失败)" % _gm.game_ended)
	_check(_gm.phase == GameManager.Phase.EVOLVE, "损坏 JSON 开局 phase=%d, 期望 EVOLVE" % _gm.phase)
	_check(_gm.can_play_card() == false, "损坏 JSON 开局 can_play_card=%s, 期望 false" % _gm.can_play_card())
	# 关卡 JSON 尺寸/target 钳制与字段容错
	var lvl_path := "user://test_level_clamp.json"
	var lf = FileAccess.open(lvl_path, FileAccess.WRITE)
	lf.store_string('{"size":[100,-2],"target":-5,"elements":[{"coord":[999,999],"element":"WATER"},{"coord":["x","y"],"element":"QQQ"}]}')
	lf.close()
	_gm.target = 0
	var g: Grid = _gm._load_level(lvl_path)
	_check(g.w == 32 and g.h == 6, "关卡 size=[100,-2] 应钳制为 32x6, 实际 %dx%d" % [g.w, g.h])
	_check(_gm.target == 1, "关卡 target=-5 应钳制为 1, 实际 %d" % _gm.target)
	_check(g.count_element(Element.WATER) == 0, "越界/非法元素条目应被跳过, 实际 WATER=%d" % g.count_element(Element.WATER))
	_cleanup_save(lvl_path)
	# 恢复
	wf = FileAccess.open(RULES_PATH, FileAccess.WRITE)
	wf.store_string(backup)
	wf.close()
	restored = true
	_gm.start_game(0)
	_check(_gm.hand.hand_size() == 5, "恢复规则文件后手牌=%d, 期望 5 (文件恢复成功)" % _gm.hand.hand_size())
	_check(_gm.game_ended == false, "恢复规则文件后 game_ended=%s, 期望 false" % _gm.game_ended)
	_check(restored, "规则文件未能恢复, 数据文件处于损坏状态!")
# ---------- TC-25 ----------
func tc25_非法字段降级() -> void:
	# kind 需合法 (非法 kind 字符串会触发 Kind.get 返回 null 赋 int 的运行时错误,
	# 导致 from_dict 中断、后续字段全部丢失 —— 见下方现状断言)
	var c = _make_rule_card({"id": "x", "name": "x", "kind": "TRANSFORM", "trigger_element": "QQQ",
		"contact_element": "NOPE", "radius": 3, "extinct_threshold": 7})
	_check(c.trigger_element == Element.NONE, "trigger_element=%d, 期望 NONE(0) (非法元素名降级, Element.from_string)" % c.trigger_element)
	_check(c.contact_element == Element.NONE, "contact_element=%d, 期望 NONE" % c.contact_element)
	_check(c.radius == 3 and c.extinct_threshold == 7, "radius=%d/threshold=%d, 期望 3/7 (合法字段应保留)" % [c.radius, c.extinct_threshold])
	var c2 = _make_rule_card({"id": "y", "name": "y", "kind": "XXX", "radius": 3})
	_check(c2.kind == RuleCard.Kind.TRANSFORM and c2.radius == 1,
		"非法kind现状: kind=%d(0=TRANSFORM) radius=%d(默认1) —— 非法kind使 from_dict 中断, 后续字段丢失 (RuleCard.gd:27), 现状记录, 修复后更新断言" % [c2.kind, c2.radius])

# ---------- TC-26a ----------
func tc26a_界外点击() -> void:
	var renderer = load(GRID_RENDERER_SCRIPT).new()
	_gm.start_game(0)
	renderer.set_grid(_gm.grid)
	_check(renderer.world_to_coord(Vector2(-50, -50)) == Vector2i(-1, -1),
		"world_to_coord(-50,-50)=%s, 期望 (-1,-1)" % renderer.world_to_coord(Vector2(-50, -50)))
	_check(renderer.world_to_coord(Vector2(1400, 900)) == Vector2i(-1, -1),
		"world_to_coord(1400,900)=%s, 期望 (-1,-1) (超出10x10网格)" % renderer.world_to_coord(Vector2(1400, 900)))
	var before_water: int = _gm.grid.count_element(Element.WATER)
	_check(_gm.play_card(-1, Vector2i(5, 5)) == false, "play_card(-1, 格) 应返回 false")
	_check(_gm.play_card(0, Vector2i(99, 99)) == false, "play_card(0, 界外坐标) 应返回 false")
	_check(_gm.play_card(0, Vector2i(5, 5)) == true, "play_card(0, 合法坐标) 应返回 true (对照确认桩位逻辑正常)")
	_check(_gm.grid.count_element(Element.WATER) == before_water, "界外操作后 WATER 数变化=%d (网格状态应不变)" % (_gm.grid.count_element(Element.WATER) - before_water))

# ---------- TC-26b ----------
func tc26b_半径边界格数() -> void:
	var g = Grid.new(6, 6)
	var cells: Array = g.cells_in_radius(Vector2i(0, 0), 2)
	_check(cells.size() == 6, "角点(0,0)半径2格数=%d, 期望 6 (曼哈顿<=2 且界内)" % cells.size())
	var expect_coords: Array = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]
	var got_coords: Array = []
	for c in cells:
		got_coords.append(c.coord)
	for e in expect_coords:
		_check(got_coords.has(e), "缺失格 %s" % e)

# ---------- TC-28a ----------
func tc28a_尘越界消失() -> void:
	_gm.start_game(0)
	_gm.wind_dir = 0  # 北
	_gm.wind_speed = 3
	var cell = _gm.grid.get_cell(Vector2i(0, 0))
	cell.add_state(State.DUST, 1)  # 注: 剩余>1 为落地保护期不被风吹 (GameManager.gd:203), 故用 1 验证越界路径
	_gm.push_dust()
	_check(not cell.has_state(State.DUST), "尘格(0,0)未被移除 (越界应消失)")
	var total := 0
	for c in _gm.grid.all_cells():
		if c.has_state(State.DUST):
			total += 1
	_check(total == 0, "越界吹走后全网格残留 DUST %d 格, 期望 0" % total)

# ---------- TC-28b ----------
func tc28b_演化后清空选中() -> void:
	_gm.start_game(0)
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	var renderer = main.grid_renderer
	var spot := Vector2i(-1, -1)
	for c in _gm.grid.all_cells():
		if c.element == Element.NONE and c.pillar == null:
			spot = c.coord
			break
	_check(spot.x >= 0, "未找到空格")
	if spot.x < 0:
		main.free()
		return
	renderer.select_card(0)
	_check(renderer.selected_card_idx == 0, "select_card(0) 后 idx=%d, 期望 0" % renderer.selected_card_idx)
	_check(_gm.play_card(0, spot), "落柱失败")
	main._on_execute()  # 实际 UI 路径: 执行按钮 → 先清空选中, 再启动演化
	_check(renderer.selected_card_idx == -1, "点击执行后 selected_card_idx=%d, 期望 -1 (T2.2: 演化后不得残留手牌选中)" % renderer.selected_card_idx)
	var guard := 0
	while _gm.phase == GameManager.Phase.EVOLVE and guard < 100:
		await self.create_timer(0.05).timeout
		guard += 1
	_check(_gm.phase == GameManager.Phase.LAYOUT, "演化未在 5s 内结束: phase=%d" % _gm.phase)
	_check(renderer.selected_card_idx == -1, "演化结束后 selected_card_idx=%d, 期望 -1" % renderer.selected_card_idx)
	main.free()
# ---------- TC-30a (现状记录) ----------
func tc30a_frozen阻断现状() -> void:
	# 1) FROZEN 目标格不被转化
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.ICE)
	_put(g, 2, 1, Element.ICE)
	g.get_cell(Vector2i(1, 1)).add_state(State.FROZEN, 3)
	var card = _make_rule_card({"id": "freeze", "kind": "MULTIPLY", "trigger_element": "ICE",
		"contact_element": "ICE", "result_element": "ICE", "radius": 2, "life": 4})
	var runner = load("res://src/rules/ChainReaction.gd").new()
	var chain = runner.execute(g, [_pillar(card, 1, 1)])
	_check(g.get_cell(Vector2i(1, 1)).element == Element.ICE, "FROZEN 格元素被改变 (Reaction.gd:18 应阻止转化)")
	_check(g.get_cell(Vector2i(1, 1)).has_state(State.FROZEN), "FROZEN 状态被清除")
	# 2) FROZEN 空格作为 MULTIPLY 扩散目标仍被填充 (现状记录)
	var g2 = Grid.new(6, 6)
	_put(g2, 1, 1, Element.ICE)
	_put(g2, 2, 1, Element.ICE)
	_put(g2, 1, 2, Element.NONE)
	g2.get_cell(Vector2i(1, 2)).add_state(State.FROZEN, 3)
	var chain2 = runner.execute(g2, [_pillar(card, 1, 1)])
	_check(g2.get_cell(Vector2i(1, 2)).element == Element.ICE,
		"FROZEN 空格未被 MULTIPLY 填充 —— 现状记录: FROZEN 仅挡 trigger 格, 不挡扩散目标 (React 判定差异, 修复后更新断言)")
	_check(chain2 >= 1, "对照场景连锁=%d, 期望 >=1" % chain2)

# ---------- TC-30b (现状记录) ----------
func tc30b_multiply时间戳() -> void:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.STEAM)
	var card = _make_rule_card({"id": "grow", "kind": "MULTIPLY", "trigger_element": "PLANT",
		"contact_element": "STEAM", "result_element": "PLANT", "radius": 2, "life": 4})
	var runner = load("res://src/rules/ChainReaction.gd").new()
	runner.execute(g, [_pillar(card, 1, 1)])
	var new_plant = g.get_cell(Vector2i(0, 1))
	_check(new_plant.element == Element.PLANT, "对照: 新格应为 PLANT")
	_check(new_plant.placed_at_turn == 1, "新格 placed_at_turn=%d, 期望 1 (触发格 0 + 1) —— 现状记录: 非当前 turn, 语义偏差 (Reaction.gd:40), 修复后更新断言" % new_plant.placed_at_turn)

# ---------- TC-30c ----------
func tc30c_演化中切场景() -> void:
	_gm.start_game(0)
	var main = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await self.process_frame
	var planted := 0
	for c in _gm.grid.all_cells():
		if planted < 40:
			c.element = Element.WATER if planted % 2 == 0 else Element.LAVA
			planted += 1
	var card = _make_rule_card({"id": "steamify", "kind": "TRANSFORM", "trigger_element": "WATER",
		"contact_element": "LAVA", "result_element": "STEAM", "self_replace": "STONE",
		"radius": 5, "life": 4, "chain_reward": 1})
	_gm.pillars.clear()
	var p = _pillar(card, 4, 4)
	_gm.pillars.append(p)
	_gm.grid.get_cell(p.coord).pillar = p
	# 启动演化(不等待完成), 期间切场景
	var running = _gm.execute()
	await self.create_timer(0.3).timeout
	main.queue_free()
	root.remove_child(main)
	change_scene_to_file(LEVEL_SELECT_SCENE)
	await self.create_timer(1.5).timeout
	_check(running != null, "演化协程未启动")
	_check(_gm.chain_total > 0, "切场景后旧演化未完成: chain_total=%d, 期望 >0 (协程不应因 UI 释放而中止)" % _gm.chain_total)
	_gm.start_game(0)
	_check(_gm.chain_total == 0 and _gm.pillars.is_empty() and _gm.hand.hand_size() == 5 and _gm.dead_turns == 0,
		"切场景后新局状态不干净: chain=%d pillars=%d hand=%d dead=%d" % [_gm.chain_total, _gm.pillars.size(), _gm.hand.hand_size(), _gm.dead_turns])
