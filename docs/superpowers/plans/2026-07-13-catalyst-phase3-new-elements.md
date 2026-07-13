# 第三阶段：新元素 + 自然规则 实现计划

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 加 ORE/GRASS 元素、4 张新牌、世界自然衰减/生成，不改引擎核心匹配逻辑。

**Architecture:** 数据驱动：Element 枚举 +2、RuleCard +1 字段(also_count)、Cell +1 字段(decay_timer)、GameManager +1 方法(_world_rules)、RuleEngine/Reaction 各改 2 行。

**Tech Stack:** Godot 4.x GDScript

## 全局约束
- 不改 RuleEngine._match_in_scope 的 TRANSFORM/MULTIPLY 分支
- `also_count` 只在 EXTINCTION 生效
- `_world_rules()` 在 `end_turn()` 末尾、`state_changed.emit()` 之前调用
- `placed_at_turn` 复用（Cell 已有），不需 new field
- 所有新逻辑必须加 assert 测试

---

### Task 1: Element + Cell — ORE/GRASS 枚举 + decay_timer

**Files:**
- Modify: `src/core/Element.gd` (enum + NAMES)
- Modify: `src/core/Cell.gd` (加 decay_timer 字段)
- Modify: `src/ui/GridRenderer.gd` (加两色 + 字标)

**Produces:** `Element.ORE`, `Element.GRASS`, `Cell.decay_timer`, 两色块渲染

- [ ] **Step 1: Element.gd 加枚举值**

```gdscript
enum { NONE, WATER, STONE, EARTH, STEAM, LAVA, PLANT, ORE, GRASS }

const NAMES = {
	NONE: "NONE", WATER: "WATER", STONE: "STONE", EARTH: "EARTH",
	STEAM: "STEAM", LAVA: "LAVA", PLANT: "PLANT", ORE: "ORE", GRASS: "GRASS"
}
```

- [ ] **Step 2: Cell.gd 加 decay_timer**

在 `var placed_at_turn: int = 0` 后加:
```gdscript
var decay_timer: int = 0   # 草连续无邻树回合计数
```

- [ ] **Step 3: GridRenderer.gd 加颜色和字标**

COLORS dict 加:
```gdscript
Element.ORE: Color(0.85, 0.7, 0.2),
Element.GRASS: Color(0.4, 0.9, 0.4),
```

LABELS dict 加:
```gdscript
Element.ORE: "矿",
Element.GRASS: "草",
```

- [ ] **Step 4: 运行自检确认编译**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: ALL PASS

---

### Task 2: RuleCard + RuleEngine + Reaction — also_count

**Files:**
- Modify: `src/rules/RuleCard.gd` (加字段 + from_dict)
- Modify: `src/rules/RuleEngine.gd` (EXTINCTION 统计也数 also_count)
- Modify: `src/rules/Reaction.gd` (EXTINCTION 清空也清 also_count)

**Produces:** `RuleCard.also_count`, EXTINCTION 合并计数/清空

- [ ] **Step 1: RuleCard.gd 加字段**

在 `@export var add_state_turns` 之后加:
```gdscript
@export var also_count: int = Element.NONE   # EXTINCTION: 计数时也包含此元素
```

在 `from_dict()` 末尾 `also_clear = ...` 之后加:
```gdscript
also_count = Element.from_string(d.get("also_count", "NONE"))
```

- [ ] **Step 2: RuleEngine.gd EXTINCTION 统计改**

在 `_match_in_scope` 的 `RuleCard.Kind.EXTINCTION:` 分支，替换计数循环:
```gdscript
var count = 0
for c in scope:
	if c.element == card.trigger_element:
		count += 1
	elif card.also_count != Element.NONE and c.element == card.also_count:
		count += 1
```

- [ ] **Step 3: Reaction.gd EXTINCTION apply 改**

在 `RuleCard.Kind.EXTINCTION:` apply 中，替换判定条件:
```gdscript
if c.element == card.trigger_element or \
   (card.also_count != Element.NONE and c.element == card.also_count):
	c.element = Element.NONE
	c.clear_states()
	affected.append(c.coord)
```

(保持原 `candidates` 收集逻辑不变—— candidates 仍只收 `trigger_element` 用于数量检查；清空时用上述扩大条件)

**更正**: candidates 收集也要扩大，否则数量统计和清空对不上。把 candidates 收集也改成:
```gdscript
for c in scope:
	if c.element == card.trigger_element or \
	   (card.also_count != Element.NONE and c.element == card.also_count):
		candidates.append(c)
```

然后在检查 `candidates.size() >= card.extinct_threshold` 后统一清空 candidates。

- [ ] **Step 4: 运行自检确认现有 11 个测试全过**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: ALL PASS

---

### Task 3: GameManager — _world_rules()

**Files:**
- Modify: `src/main/GameManager.gd` (加方法 + end_turn 调用)

**Produces:** 4 条世界规则在每回合结束自动运行

- [ ] **Step 1: 加 `_world_rules()` 方法**

在 GameManager 类中（`chaos_check()` 之后或 `decay_pillars()` 附近）加:

```gdscript
func _world_rules() -> void:
	# 1. 蒸汽 2 回合后消散
	for c in grid.all_cells():
		if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
			c.element = Element.NONE
			c.placed_at_turn = turn
	# 2. 草枯 & 土硬化
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
	# 3. 自然生成: 随机 1~2 格变水或岩
	var empty: Array = []
	for c in grid.all_cells():
		if c.element == Element.NONE:
			empty.append(c)
	var count = min(2, empty.size())
	for _i in range(count):
		var c = empty.pop_at(randi() % empty.size())
		c.element = Element.WATER if randi() % 2 == 0 else Element.STONE
		c.placed_at_turn = turn
```

- [ ] **Step 2: 在 `end_turn()` 中调用**

在 `end_turn()` 的 `chaos_check()` 之后、`_reroll_wind()` 之前加:
```gdscript
_world_rules()
```

- [ ] **Step 3: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: ALL PASS

---

### Task 4: 数据 — rules.json + coast.json

**Files:**
- Modify: `data/rules.json` (4 新牌 + 改灭绝)
- Modify: `data/coast.json` (加矿石、岩石)

- [ ] **Step 1: rules.json — 加入 4 张新牌 + 改灭绝**

完整文件内容:

```json
[
  {
    "id": "steamify", "name": "蒸汽化", "kind": "TRANSFORM",
    "trigger_element": "WATER", "contact_element": "LAVA",
    "result_element": "STEAM", "self_replace": "STONE",
    "radius": 2, "life": 4, "chain_reward": 1
  },
  {
    "id": "grow", "name": "加速生长", "kind": "MULTIPLY",
    "trigger_element": "PLANT", "contact_element": "STEAM",
    "result_element": "PLANT", "radius": 2, "life": 4, "chain_reward": 1
  },
  {
    "id": "extinct", "name": "丛林灭绝", "kind": "EXTINCTION",
    "trigger_element": "PLANT", "result_element": "NONE",
    "radius": 2, "life": 4, "extinct_threshold": 5,
    "also_count": "GRASS", "also_clear": "STEAM", "chain_reward": 1
  },
  {
    "id": "petrify", "name": "岩化", "kind": "TRANSFORM",
    "trigger_element": "STONE", "contact_element": "PLANT",
    "result_element": "EARTH", "self_replace": "NONE",
    "radius": 2, "life": 4, "chain_reward": 1
  },
  {
    "id": "grass_grow", "name": "草生", "kind": "MULTIPLY",
    "trigger_element": "EARTH", "contact_element": "PLANT",
    "result_element": "GRASS", "radius": 2, "life": 4, "chain_reward": 1
  },
  {
    "id": "harvest", "name": "采掘", "kind": "TRANSFORM",
    "trigger_element": "PLANT", "contact_element": "ORE",
    "result_element": "NONE", "self_replace": "NONE",
    "radius": 2, "life": 4, "chain_reward": 5
  },
  {
    "id": "grass_spread", "name": "草殖", "kind": "MULTIPLY",
    "trigger_element": "GRASS", "contact_element": "GRASS",
    "result_element": "GRASS", "radius": 2, "life": 4, "chain_reward": 1
  }
]
```

- [ ] **Step 2: coast.json — 加入矿石和岩石**

在 elements 数组中追加:
```json
{"coord": [0, 5], "element": "ORE"},
{"coord": [5, 0], "element": "ORE"},
{"coord": [0, 0], "element": "STONE"}
```

(完整 coast.json 已有水/熔/植等，追加 2 矿 + 1 岩即可)

- [ ] **Step 3: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: ALL PASS (手牌 pool 从 3 变 7，draw 逻辑不受影响)

---

### Task 5: 测试 — 4 新用例

**Files:**
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: run_all() 加调用**

```gdscript
ok = ok and _test_ore_harvest()
ok = ok and _test_grass_wither()
ok = ok and _test_steam_evaporate()
ok = ok and _test_extinct_counts_grass()
```

- [ ] **Step 2: _test_ore_harvest**

```gdscript
static func _test_ore_harvest() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.ORE)
	var card = _make_card({
		"id":"harvest","name":"采掘","kind":"TRANSFORM",
		"trigger_element":"PLANT","contact_element":"ORE",
		"result_element":"NONE","self_replace":"NONE",
		"radius":2,"life":4,"chain_reward":5
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	assert(chain == 5, "harvest should give 5 chain, got %d" % chain)
	assert(g.get_cell(Vector2i(1,1)).element == Element.NONE, "plant gone")
	assert(g.get_cell(Vector2i(2,1)).element == Element.NONE, "ore gone")
	print("test_ore_harvest OK (chain=%d)" % chain)
	return true
```

- [ ] **Step 3: _test_grass_wither**

```gdscript
static func _test_grass_wither() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(2,2)).element = Element.GRASS
	g.get_cell(Vector2i(2,2)).decay_timer = 0
	# 模拟 3 回合无邻树: decay_timer 0→1→2→变土
	# turn 1: check, no neighbor, decay_timer=1
	# turn 2: check, no neighbor, decay_timer=2 → >=2 触发
	var c = g.get_cell(Vector2i(2,2))
	for _i in range(2):
		var hf = false
		for n in g.neighbors(c.coord):
			if n.element in [Element.PLANT, Element.GRASS]:
				hf = true; break
		if not hf: c.decay_timer += 1
		else: c.decay_timer = 0
		if c.decay_timer >= 2:
			c.element = Element.EARTH
			c.decay_timer = 0
	assert(g.get_cell(Vector2i(2,2)).element == Element.EARTH, "grass should wither to earth")
	print("test_grass_wither OK")
	return true
```

- [ ] **Step 4: _test_steam_evaporate**

```gdscript
static func _test_steam_evaporate() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(3,3)).element = Element.STEAM
	g.get_cell(Vector2i(3,3)).placed_at_turn = 0
	# turn=2: placed_at_turn=0, 2-0 >= 2 → 消失
	var turn = 2
	for c in g.all_cells():
		if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
			c.element = Element.NONE
	assert(g.get_cell(Vector2i(3,3)).element == Element.NONE, "steam should vanish")
	print("test_steam_evaporate OK")
	return true
```

- [ ] **Step 5: _test_extinct_counts_grass**

```gdscript
static func _test_extinct_counts_grass() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 1, 2, Element.PLANT)
	_put(g, 2, 2, Element.GRASS)
	_put(g, 0, 1, Element.GRASS)
	var card = _make_card({
		"id":"extinct","name":"丛林灭绝","kind":"EXTINCTION",
		"trigger_element":"PLANT","result_element":"NONE",
		"radius":2,"extinct_threshold":5,"also_count":"GRASS"
	})
	var p = RulePillar.new(card, Vector2i(2,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	var p_left = g.count_element(Element.PLANT)
	var g_left = g.count_element(Element.GRASS)
	assert(p_left == 0, "all plants cleared (got %d)" % p_left)
	assert(g_left == 0, "all grass cleared (got %d)" % g_left)
	print("test_extinct_counts_grass OK (chain=%d)" % chain)
	return true
```

- [ ] **Step 6: 运行全量自检 (15 用例: 原 11 + 新 4)**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 15/15 ALL PASS

---

### Task 6: 端到端手动验证

用 Godot F5，验证:
1. 初始地图有矿石（金色 `矿` 字）
2. 手牌 5 张从 7 张池随机抽
3. 新牌可打出、tooltip 正确
4. 采掘矿旁树 → +5 闪白
5. 蒸汽 2 回合后自动消失
6. 每回合有随机水/岩自然生成
