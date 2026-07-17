# 燃烧+孢子 实现计划

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 加 SPORE 元素 + 激活 BURNING 状态 + 2 张新牌 + 2 条世界规则 + 尘边界改回消失。

**Architecture:** Element +1(SPORE), State 激活已有 BURNING, Cell +1字段(was_burning), GameManager._world_rules +2逻辑(点燃蔓延/孢子飘散), push_dust 改回越界消失, data/rules.json +2牌, RuleCardView/GridRenderer +1映射。

**Tech Stack:** Godot 4.x GDScript

## 全局约束
- SPORE 是元素(不是状态), 占格子 element 字段
- BURNING 是状态, 叠加在格子 states 字典上
- 孢子飘散: 孢子作为元素随风向移动 1 格, 越界消失, 目标非空则孢子消失(被挡)
- 尘边界改回: push_dust 中越界→移除(不再反弹)
- 所有新逻辑加 assert 测试

---

### Task 1: Element + State + Cell — SPORE + was_burning

**Files:**
- Modify: `src/core/Element.gd` (enum + NAMES 加 SPORE)
- Modify: `src/core/Cell.gd` (加 was_burning 字段)
- Modify: `src/ui/GridRenderer.gd` (COLORS + LABELS 加 SPORE)
- Modify: `src/ui/RuleCardView.gd` (CN 字典加 SPORE)

**Produces:** `Element.SPORE`, `Cell.was_burning`, SPORE 渲染

- [ ] **Step 1: Element.gd 加 SPORE**

enum 末尾加 `SPORE`，NAMES 加 `SPORE: "SPORE"`。

- [ ] **Step 2: Cell.gd 加 was_burning**

在 `var decay_timer: int = 0` 后加:
```gdscript
var was_burning: bool = false   # BURNING 衰减后标记, 供 _world_rules 检查
```

- [ ] **Step 3: GridRenderer.gd 加 SPORE 颜色和字标**

COLORS 加: `Element.SPORE: Color(0.6, 0.8, 0.5)`
LABELS 加: `Element.SPORE: "孢"`

- [ ] **Step 4: RuleCardView.gd CN 加 SPORE**

CN 字典加: `Element.SPORE: "孢"`

- [ ] **Step 5: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 17/17 ALL PASS

- [ ] **Step 6: Commit**

```bash
git add src/core/Element.gd src/core/Cell.gd src/ui/GridRenderer.gd src/ui/RuleCardView.gd
git commit -m "feat: add SPORE element + was_burning field + rendering"
```

---

### Task 2: GameManager — 燃烧蔓延 + 孢子飘散 世界规则

**Files:**
- Modify: `src/main/GameManager.gd` (_world_rules 追加逻辑, push_dust 改回消失)

- [ ] **Step 1: _world_rules 末尾追加燃烧蔓延逻辑**

在现有 `_world_rules()` 的"自然生成"逻辑之后追加:

```gdscript
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
```

- [ ] **Step 2: Cell.tick_states 加 was_burning 标记**

修改 `src/core/Cell.gd` 的 `tick_states()` 方法，在状态被移除时检查 BURNING:

```gdscript
func tick_states() -> void:
	var to_remove = []
	for s in states.keys():
		states[s] -= 1
		if states[s] <= 0:
			to_remove.append(s)
	for s in to_remove:
		states.erase(s)
		if s == State.BURNING:
			was_burning = true
```

- [ ] **Step 3: _world_rules 追加孢子飘散逻辑**

在燃烧逻辑之后追加:

```gdscript
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
```

- [ ] **Step 4: push_dust 改回越界消失**

在 `push_dust()` 方法中, 把"碰边界 break(反弹)"改回"越界标记消失":

找到:
```gdscript
			for _i in range(wind_speed):
				var nx = dst + dir_vec
				if not grid.is_in_bounds(nx):
					break    # 反弹: 碰到边界停下来,不下桌
				dst = nx
			moves.append([c.coord, dst])
```
改为:
```gdscript
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
```

- [ ] **Step 5: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 17/17 ALL PASS

- [ ] **Step 6: Commit**

```bash
git add src/main/GameManager.gd src/core/Cell.gd
git commit -m "feat: burning spread + spore wind drift world rules, dust falls off edge"
```

---

### Task 3: 数据 — rules.json 加 2 张新牌

**Files:**
- Modify: `data/rules.json` (追加 sporify + spore_bloom)

- [ ] **Step 1: 在 rules.json 数组末尾追加 2 张牌**

```json
  {
    "id": "sporify", "name": "结孢子", "kind": "MULTIPLY",
    "trigger_element": "STEAM", "contact_element": "PLANT",
    "result_element": "SPORE", "radius": 2, "life": 4, "chain_reward": 1
  },
  {
    "id": "spore_bloom", "name": "孢子萌发", "kind": "MULTIPLY",
    "trigger_element": "WATER", "contact_element": "SPORE",
    "result_element": "PLANT", "radius": 2, "life": 4, "chain_reward": 1
  }
```

- [ ] **Step 2: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 17/17 ALL PASS

- [ ] **Step 3: Commit**

```bash
git add data/rules.json
git commit -m "feat: add sporify + spore_bloom cards"
```

---

### Task 4: 测试 — 4 新用例

**Files:**
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: run_all() 加 4 个调用**

```gdscript
ok = ok and _test_sporify()
ok = ok and _test_spore_bloom()
ok = ok and _test_burning_ignite()
ok = ok and _test_spore_wind_move()
```

- [ ] **Step 2: _test_sporify**

```gdscript
static func _test_sporify() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.STEAM)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 0, 1, Element.NONE)
	var card = _make_card({
		"id":"sporify","name":"结孢子","kind":"MULTIPLY",
		"trigger_element":"STEAM","contact_element":"PLANT",
		"result_element":"SPORE","radius":2,"life":4
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	# 汽和植保留, 空格变孢
	assert(g.get_cell(Vector2i(1,1)).element == Element.STEAM, "steam kept")
	assert(g.get_cell(Vector2i(2,1)).element == Element.PLANT, "plant kept")
	var spore_count = 0
	for c in g.all_cells():
		if c.element == Element.SPORE:
			spore_count += 1
	assert(spore_count >= 1, "should produce >=1 spore, got %d" % spore_count)
	print("test_sporify OK (chain=%d, spores=%d)" % [chain, spore_count])
	return true
```

- [ ] **Step 3: _test_spore_bloom**

```gdscript
static func _test_spore_bloom() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.SPORE)
	_put(g, 0, 1, Element.NONE)
	var card = _make_card({
		"id":"spore_bloom","name":"孢子萌发","kind":"MULTIPLY",
		"trigger_element":"WATER","contact_element":"SPORE",
		"result_element":"PLANT","radius":2,"life":4
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	# 水和孢保留, 空格变植
	assert(g.get_cell(Vector2i(1,1)).element == Element.WATER, "water kept")
	assert(g.get_cell(Vector2i(2,1)).element == Element.SPORE, "spore kept")
	var plant_count = 0
	for c in g.all_cells():
		if c.element == Element.PLANT:
			plant_count += 1
	assert(plant_count >= 1, "should produce >=1 plant, got %d" % plant_count)
	print("test_spore_bloom OK (chain=%d, plants=%d)" % [chain, plant_count])
	return true
```

- [ ] **Step 4: _test_burning_ignite**

```gdscript
static func _test_burning_ignite() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.LAVA)
	var c = g.get_cell(Vector2i(1,1))
	# 模拟点燃逻辑
	for n in g.neighbors(c.coord):
		if n.element == Element.LAVA:
			c.add_state(State.BURNING, 2)
			break
	assert(c.has_state(State.BURNING), "plant should ignite near lava")
	# 蔓延: 燃烧的植物让相邻植物也燃烧
	_put(g, 0, 1, Element.PLANT)
	for n in g.neighbors(c.coord):
		if n.element == Element.PLANT and not n.has_state(State.BURNING):
			n.add_state(State.BURNING, 2)
	assert(g.get_cell(Vector2i(0,1)).has_state(State.BURNING), "fire should spread")
	print("test_burning_ignite OK")
	return true
```

- [ ] **Step 5: _test_spore_wind_move**

```gdscript
static func _test_spore_wind_move() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(2, 3)).element = Element.SPORE
	# 模拟风向: N(0) speed=1
	var dir = Vector2i(0, -1)
	var nx = Vector2i(2, 3) + dir
	var fell = false
	if not g.is_in_bounds(nx):
		fell = true
	if fell:
		g.get_cell(Vector2i(2,3)).element = Element.NONE
	else:
		g.get_cell(Vector2i(2,3)).element = Element.NONE
		var dst = g.get_cell(nx)
		if dst.element == Element.NONE:
			dst.element = Element.SPORE
	assert(g.get_cell(Vector2i(2,2)).element == Element.SPORE, "spore should move to (2,2)")
	assert(g.get_cell(Vector2i(2,3)).element == Element.NONE, "old cell cleared")
	# 越界: 在 (0,0) 向北
	g.get_cell(Vector2i(0,0)).element = Element.SPORE
	nx = Vector2i(0,0) + dir
	fell = false
	if not g.is_in_bounds(nx):
		fell = true
	if fell:
		g.get_cell(Vector2i(0,0)).element = Element.NONE
	assert(g.get_cell(Vector2i(0,0)).element == Element.NONE, "spore off-edge should vanish")
	print("test_spore_wind_move OK")
	return true
```

- [ ] **Step 6: 运行全量自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 21/21 ALL PASS

- [ ] **Step 7: Commit**

```bash
git add tests/run_tests.gd
git commit -m "test: add sporify/spore_bloom/burning_ignite/spore_wind_move tests"
```

---

### Task 5: 端到端手动验证

用 Godot F5，选第2关「丛林·生长」:
1. 手牌含"结孢子"和"孢子萌发"（随机抽到）
2. 在蒸汽旁放结孢子 → 空格出现孢子(浅黄绿字"孢")
3. 在孢子旁放孢子萌发→空格出现植物
4. 放植物在熔岩旁→植物变燃烧(橙红叠加)→下回合蔓延→烧完变空
5. 孢子每回合随风移动，越界消失