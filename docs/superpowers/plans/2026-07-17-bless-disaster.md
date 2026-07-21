# 祝福+天灾 实现计划

> **For agentic workers:** Use superpowers:subagent-driven-development.

**Goal:** 加 BLESSED/METEOR_LAVA 状态 + 2 张第4关专属牌 + 天灾事件世界规则 + BLESSED 反应奖励翻倍。

**Architecture:** State +2, Cell +1(was_meteor), ChainReaction +BLESSED 检查, GameManager._world_rules +天灾/METEOR_LAVA, data/rules.json +2牌(level=4), GridRenderer +2渲染。

**Tech Stack:** Godot 4.x GDScript

## 全局约束
- BLESSED 和 METEOR_LAVA 是状态，叠加在 states 字典
- BLESSED 格的反应 chain_reward ×2 (ChainReaction 检查 affected 格)
- METEOR_LAVA 衰减后熔岩→岩石 (was_meteor 标记)
- 天灾仅第4关触发 (level_manager.current_level == 3)
- 所有新逻辑加 assert 测试

---

### Task 1: State + Cell + 渲染

**Files:**
- Modify: `src/core/State.gd` (enum +2, NAMES +2)
- Modify: `src/core/Cell.gd` (+was_meteor)
- Modify: `src/ui/GridRenderer.gd` (BLESSED 金边, METEOR_LAVA 脉冲+▲)

- [ ] **Step 1: State.gd 加 BLESSED + METEOR_LAVA**

```gdscript
enum { NONE, BURNING, STEAMED, FROZEN, ASH, DUST, SNOW, BLESSED, METEOR_LAVA }
```
NAMES 加: `BLESSED: "BLESSED"`, `METEOR_LAVA: "METEOR_LAVA"`

- [ ] **Step 2: Cell.gd 加 was_meteor**

```gdscript
var was_meteor: bool = false
```

- [ ] **Step 3: Cell.tick_states 加 METEOR_LAVA 标记**

在 `if s == State.BURNING: was_burning = true` 后加:
```gdscript
if s == State.METEOR_LAVA:
    was_meteor = true
```

- [ ] **Step 4: GridRenderer.gd 加 BLESSED + METEOR_LAVA 渲染**

在格子渲染循环中(其他状态检查之后)加:
```gdscript
if c.has_state(State.BLESSED):
    draw_rect(rect.grow(-3), Color(1, 0.85, 0.3), false, 2)
if c.has_state(State.METEOR_LAVA):
    var cx = rect.position.x + cell_size / 2.0
    var cy = rect.position.y + cell_size / 2.0
    var mr = 8.0 + 3.0 * sin(Time.get_ticks_msec() / 200.0)
    draw_circle(Vector2(cx, cy), mr, Color(0.5, 0.15, 0.1, 0.5))
    draw_string(_font(), rect.position + Vector2(cell_size / 2.0 - 4, 14), "^", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 0.4, 0.2))
```

- [ ] **Step 5: 运行自检 + commit**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 25/25 ALL PASS

---

### Task 2: ChainReaction — BLESSED 奖励翻倍

**Files:**
- Modify: `src/rules/ChainReaction.gd` (execute + execute_async 的 chain += 处)

- [ ] **Step 1: execute() 中 chain += 处加 BLESSED 检查**

原: `chain += r.card.chain_reward if r.card != null else 1`
改为:
```gdscript
var reward = r.card.chain_reward if r.card != null else 1
for coord in r.affected:
    var bc = grid.get_cell(coord)
    if bc != null and bc.has_state(State.BLESSED):
        reward *= 2
        break
chain += reward
```

- [ ] **Step 2: execute_async() 中同样修改**

- [ ] **Step 3: 运行自检 + commit**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 25/25 ALL PASS

---

### Task 3: GameManager — 天灾事件 + METEOR_LAVA 衰减

**Files:**
- Modify: `src/main/GameManager.gd` (_world_rules 追加)

- [ ] **Step 1: _world_rules 末尾追加天灾事件**

```gdscript
	# 天灾事件 (仅第4关)
	if level_manager.current_level == 3:
		if randi() % 100 < 30:
			var event = randi() % 3
			if event == 0:  # 陨石
				var cells = grid.all_cells()
				var c = cells[randi() % cells.size()]
				c.element = Element.LAVA
				c.add_state(State.METEOR_LAVA, 2)
				c.placed_at_turn = turn
			elif event == 1:  # 地震
				var non_empty = grid.all_cells().filter(func(c2): return c2.element != Element.NONE)
				for _i in range(min(2, non_empty.size())):
					var sc = non_empty.pop_at(randi() % non_empty.size())
					sc.element = Element.NONE
					sc.clear_states()
			else:  # 火山喷发
				var empties = grid.all_cells().filter(func(c2): return c2.element == Element.NONE)
				if not empties.is_empty():
					var c = empties[randi() % empties.size()]
					c.element = Element.LAVA
					c.placed_at_turn = turn
	# METEOR_LAVA 衰减→熔岩变岩石
	for c in grid.all_cells():
		if c.was_meteor:
			if c.element == Element.LAVA:
				c.element = Element.STONE
				c.placed_at_turn = turn
			c.was_meteor = false
```

- [ ] **Step 2: 运行自检 + commit**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 25/25 ALL PASS

---

### Task 4: data/rules.json — 2 张新牌

**Files:**
- Modify: `data/rules.json` (追加 bless + meteor_strike)

- [ ] **Step 1: 在数组末尾追加**

```json
  {
    "id": "bless", "name": "祝福", "kind": "TRANSFORM",
    "trigger_element": "STEAM", "contact_element": "PLANT",
    "result_element": "NONE", "self_replace": "NONE",
    "add_state": "BLESSED", "add_state_turns": 3,
    "radius": 2, "life": 4, "chain_reward": 1, "level": 4
  },
  {
    "id": "meteor_strike", "name": "陨石术", "kind": "EXTINCTION",
    "trigger_element": "LAVA", "result_element": "NONE",
    "radius": 2, "life": 4, "extinct_threshold": 3,
    "also_clear": "PLANT", "chain_reward": 1, "level": 4
  }
```

- [ ] **Step 2: 运行自检 + commit**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 25/25 ALL PASS

---

### Task 5: 测试 — 4 新用例

**Files:**
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: run_all() 加 4 个调用**

```gdscript
ok = ok and _test_bless_bonus()
ok = ok and _test_meteor_strike()
ok = ok and _test_meteor_event()
ok = ok and _test_disaster_earthquake()
```

- [ ] **Step 2: _test_bless_bonus**

```gdscript
static func _test_bless_bonus() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.LAVA)
	g.get_cell(Vector2i(1,1)).add_state(State.BLESSED, 3)
	var card = _make_card({
		"id":"steamify","name":"蒸汽化","kind":"TRANSFORM",
		"trigger_element":"WATER","contact_element":"LAVA",
		"result_element":"STEAM","self_replace":"STONE",
		"radius":2,"life":4,"chain_reward":1
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	# BLESSED 格 reaction chain_reward 1x2 = 2
	assert(chain == 2, "BLESSED should double chain_reward, got %d" % chain)
	print("test_bless_bonus OK (chain=%d)" % chain)
	return true
```

- [ ] **Step 3: _test_meteor_strike**

```gdscript
static func _test_meteor_strike() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.LAVA)
	_put(g, 2, 1, Element.LAVA)
	_put(g, 3, 1, Element.LAVA)
	_put(g, 2, 2, Element.PLANT)
	var card = _make_card({
		"id":"meteor_strike","name":"陨石术","kind":"EXTINCTION",
		"trigger_element":"LAVA","result_element":"NONE",
		"radius":2,"extinct_threshold":3,"also_clear":"PLANT"
	})
	var p = RulePillar.new(card, Vector2i(2,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	assert(g.count_element(Element.LAVA) == 0, "all lava cleared")
	assert(g.count_element(Element.PLANT) == 0, "all plants cleared via also_clear")
	print("test_meteor_strike OK (chain=%d)" % chain)
	return true
```

- [ ] **Step 4: _test_meteor_event**

```gdscript
static func _test_meteor_event() -> bool:
	var g = Grid.new(6, 6)
	var c = g.get_cell(Vector2i(2, 2))
	c.element = Element.LAVA
	c.add_state(State.METEOR_LAVA, 2)
	# 模拟 tick_states 两次
	for _i in range(2):
		for cc in g.all_cells():
			cc.tick_states()
	# was_meteor 应为 true
	assert(c.was_meteor, "was_meteor should be set")
	# 衰减后熔岩→岩石
	if c.was_meteor:
		if c.element == Element.LAVA:
			c.element = Element.STONE
		c.was_meteor = false
	assert(g.get_cell(Vector2i(2,2)).element == Element.STONE, "meteor lava should become stone")
	print("test_meteor_event OK")
	return true
```

- [ ] **Step 5: _test_disaster_earthquake**

```gdscript
static func _test_disaster_earthquake() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 2, Element.PLANT)
	_put(g, 3, 3, Element.STONE)
	# 模拟地震: 随机清空2格
	var non_empty = g.all_cells().filter(func(c2): return c2.element != Element.NONE)
	for _i in range(min(2, non_empty.size())):
		var sc = non_empty.pop_at(randi() % non_empty.size())
		sc.element = Element.NONE
		sc.clear_states()
	var remaining = 0
	for c in g.all_cells():
		if c.element != Element.NONE:
			remaining += 1
	assert(remaining == 1, "earthquake should clear 2 of 3, remaining %d" % remaining)
	print("test_disaster_earthquake OK")
	return true
```

- [ ] **Step 6: 运行全量自检 (29/29) + commit**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 29/29 ALL PASS

---

### Task 6: 端到端手动验证

用 Godot F5，选第4关「火山口·终局」:
1. 手牌含"祝福"和"陨石术"（level=4 专属）
2. 放祝福牌在蒸汽旁有植物处→蒸汽格加金色边框(BLESSED)
3. 该格后续反应连锁×2
4. 陨石术: 半径内≥3熔岩→清空所有熔岩和植物
5. 每30%概率天灾: 陨石(暗红脉冲+"▲")→2回合后变岩; 地震(2格清空); 火山(空格变灰岩)