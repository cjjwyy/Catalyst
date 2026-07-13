# 《催化剂》(Catalyst) 第一阶段原型设计

> 版本: v1.0 · 日期: 2026-07-13
> 范围: 仅第一阶段核心机制原型。完整 MVP 见原始规划文档 `docs/Catalyst-规划.md`。

## 1. 目标与非目标

### 目标
- 在 10 分钟内可跑通核心循环：**观察 → 布局 → 执行 → 看连锁**
- 验证"规则互相触发形成连锁屏"这一核心体验是否好玩
- 代码结构干净、可扩展，第二步扩展到完整 MVP 不需要重写

### 非目标(第一阶段不做)
- 催化剂尘雪球机制
- 多生物群落、多关卡
- 手牌保留机制、能量上限升级
- 粒子特效、音效、屏幕泛光
- 预演系统、扰动事件
- "混沌失控"失败判定
- 光尘、矿石、冰晶、带电、祝福等高级元素与状态

这些归第二步完整 MVP 实现。

## 2. 技术栈

- 引擎: Godot 4.x · 语言: GDScript
- 项目结构:
  ```
  catalyst/
  ├── project.godot
  ├── src/
  │   ├── core/          # Cell, Grid, Element, State
  │   ├── rules/         # RuleCard, RulePillar, RuleEngine, ChainReaction
  │   ├── player/        # HandManager, EnergySystem
  │   ├── world/         # LevelManager, BiomeSettings
  │   ├── ui/            # ChainCounter, GridRenderer, RuleCardView
  │   └── main/          # GameManager (Autoload)
  ├── data/              # 规则/元素/关卡 JSON
  ├── scenes/            # .tscn
  └── tests/             # GDScript 自检
  ```

## 3. 数据模型 (`src/core/`)

纯逻辑、不依赖 Godot 节点，可直接单测。

```gdscript
# Element.gd
class_name Element
enum { NONE, WATER, STONE, EARTH, STEAM, LAVA, PLANT }

# State.gd
class_name State
enum { NONE, BURNING, STEAMED, FROZEN, ASH }
# 第一阶段实际仅使用: STEAMED, BURNING。其余占位留给第二步。

# Cell.gd
class_name Cell
var element: int = Element.NONE
var states: Dictionary = {}   # state_enum -> 剩余回合数 (int)
var pillar = null              # RulePillar 或 null
var coord: Vector2i

func has_state(s: int) -> bool: return states.has(s)
func add_state(s: int, turns: int) -> void: states[s] = turns
func tick_states() -> void:
    for s in states.keys():
        states[s] -= 1
        if states[s] <= 0: states.erase(s)

# Grid.gd
class_name Grid
var w: int; var h: int
var cells: Array   # cells[y][x] = Cell
func get_cell(p: Vector2i) -> Cell
func neighbors(p: Vector2i) -> Array    # 4 连通,越界过滤
func all_cells() -> Array
func cells_in_radius(center: Vector2i, radius: int) -> Array  # 曼哈顿距离 ≤ radius
```

尺寸固定 6×6。状态用 Dictionary 便于叠加和按回合衰减。

## 4. 规则系统 (`src/rules/`)

组合而非继承: `RuleCard` 是数据, `RuleEngine` 是匹配逻辑, `ChainReaction` 是时序。

```gdscript
# RuleCard.gd (Resource,从 data/ 加载)
class_name RuleCard
enum Kind { TRANSFORM, MULTIPLY, EXTINCTION }
var kind: int
var trigger_element: int        # 主元素(被作用对象)
var trigger_state: int = State.NONE   # 附加状态条件,NONE 表示无需
var contact_element: int = Element.NONE   # "接触"元素(相邻存在),NONE 表示不检查
var result_element: int          # trigger_element 转化结果
var self_replace: int = Element.NONE     # contact_element 自身转化结果
var radius: int = 1              # 规则柱作用半径(曼哈顿距离)
var life: int = 4                # 生命周期(回合)
var chain_reward: int = 1
var extinct_threshold: int = 5   # EXTINCTION 触发所需半径内同元素个数

# RulePillar.gd
class_name RulePillar
var card: RuleCard
var coord: Vector2i           # 锚定格
var life_remaining: int

# RuleEngine.gd
func evaluate(grid) -> Array:          # 返回 Reaction[],详见下文
func evaluate_restricted(grid, changed) -> Array:   # 只检查 changed 涉及的 pillar

# ChainReaction.gd
const MAX = 1000
func execute(grid, pillars) -> int:
    var chain = 0
    var changed = pillars.map(lambda p: p.coord)   # 首轮所有锚定格视为"变化"
    var reactions = engine.evaluate_restricted(grid, changed)
    while reactions and chain < MAX:
        var new_changed = []
        for r in reactions:
            r.apply(grid)
            new_changed.append_array(r.affected)
            chain += r.card.chain_reward
        reactions = engine.evaluate_restricted(grid, new_changed)
    return chain
```

### 4.1 Reaction (规则触发结果)

```gdscript
class_name Reaction
var card: RuleCard
var anchor: Vector2i           # 触发它的 pillar 锚定点
var target_coord: Vector2i     # 被作用的格子
var affected: Array            # 此 Reaction 改变的坐标列表(供下一轮 restricted 检测)

func apply(grid) -> void:
    var cell = grid.get_cell(target_coord)
    match card.kind:
        Kind.TRANSFORM:
            cell.element = card.result_element
            # 如有 self_replace,找到接触元素所在格并替换
        Kind.MULTIPLY:
            for n in grid.neighbors(target_coord):
                if n.element == Element.NONE:
                    n.element = card.result_element
                    affected.append(n.coord)
        Kind.EXTINCTION:
            cell.element = Element.NONE
```

### 4.1.1 EXTINCTION 触发条件(消除歧义)

EXTINCTION 与其他 kind 都走**局部生效**统一路径,无全局特殊分支:
- 匹配条件仍由 `RulePillar` 半径范围决定
- 触发判定:在该 pillar 半径范围内,统计 `trigger_element` 格子数 ≥ `card.extinct_threshold`(默认 5),即每过阈值一次产出一个 Reaction
- 但 `target_coord` 是范围中**最旧的一个** `trigger_element` 格(最先放置的优先消失)
- 原型 `card.extinct_threshold = 5`,半径 radius=1 → 范围 5 格内 ≥5 个植物时触发

简化原型实现: 半径内 `trigger_element` 数 ≥ `extinct_threshold` → 每轮消除一个最旧的,产出 1 个 Reaction 与 1 连锁。

### 4.2 局部生效规则

`RulePillar` 锚定某格, 作用范围 = `cells_in_radius(coord, radius)`。匹配条件:
1. 该格 `element == card.trigger_element`
2. 若 `card.trigger_state != NONE`, 该格 `has_state(trigger_state)` 为真
3. 若 `card.contact_element != NONE`, 锚定格半径内存在相邻格含 `contact_element`

满足上述 → 产出 `Reaction`, 由 `ChainReaction` 在演化阶段统一执行。

### 4.3 初始 3 张规则牌

| 牌名 | kind | trigger | state | contact | result | self_replace | 说明 |
|------|------|---------|-------|---------|--------|--------------|------|
| 蒸汽化 | TRANSFORM | WATER | NONE | LAVA | STEAM | STONE | 水体相邻熔岩 → 蒸汽,熔岩冷却为岩石 |
| 加速生长 | MULTIPLY | PLANT | STEAMED | NONE | PLANT | NONE | 植物被蒸汽笼罩 → 向相邻空格复制自身 |
| 丛林灭绝 | EXTINCTION | PLANT | NONE | NONE | NONE | NONE | pillar 半径内 ≥5 个植物时消失一个(threshold=5,见 4.1.1) |

**扩展性约定**: 新牌只需在 `data/rules.json` 加配置, 不需要改 `RuleEngine`。第二步加光尘/矿石/冰晶等仅扩展 `Element`/`State` 枚举值与数据, 引擎代码不动。

## 5. 玩家系统 (`src/player/`)

```gdscript
# HandManager.gd
var hand: Array = []
var draw_pile: Array = []
func draw(n): void
func play(idx: int, coord: Vector2i): bool   # 移出手并落柱

# EnergySystem.gd
var current: int = 3; var max: int = 3
func can_play(_card) -> bool: return current > 0   # 原型所有牌 cost=1
func spend(): void: current -= 1
func refill(): void: current = max
```

**Ponytail 简化**: 所有牌 `energy_cost=1`, `can_play` 只看 `current>0`。避开成本差异化的二次设计, 第二步按需扩展。

## 6. 游戏总控 (`src/main/GameManager.gd`, Autoload)

```gdscript
enum Phase { OBSERVE, LAYOUT, EVOLVE }
var phase: int = Phase.OBSERVE
var turn: int = 0
var chain_total: int = 0
var dead_turns: int = 0
var pillars: Array = []

func start_game():
    grid = load_level("coast")
    hand.refill_to(5); energy.refill()
    enter_layout()

func enter_layout():
    phase = Phase.LAYOUT

func play_card(hand_idx, coord):
    if phase != Phase.LAYOUT or not energy.can_play(): return
    var card = hand.hand[hand_idx]
    if hand.play(hand_idx, coord):
        var p = RulePillar.new(); p.card = card; p.coord = coord; p.life_remaining = card.life
        pillars.append(p)
        grid.get_cell(coord).pillar = p
        energy.spend()

func execute():
    phase = Phase.EVOLVE
    var gained = ChainReaction.execute(grid, pillars)
    chain_total += gained
    if gained == 0: dead_turns += 1
    else: dead_turns = 0
    decay_pillars()
    # 终局检测
    if chain_total >= TARGET: win()
    elif dead_turns >= 10: lose()
    else: end_turn()

func decay_pillars():
    for p in pillars:
        p.life_remaining -= 1
        if p.life_remaining <= 0:
            grid.get_cell(p.coord).pillar = null
    pillars = pillars.filter(lambda p: p.life_remaining > 0)

func end_turn():
    turn += 1
    hand.draw(3); energy.refill()
    chain_counter.text = "连锁: %d" % chain_total
    enter_layout()
```

初始手牌数 5, 每回合抽 3, 能量上限 3, 规则柱生命 4, 连锁稳定性判定改为"无新反应即停"(第二轮 while 退出)。

**目标连击数(原型单关卡)**: `TARGET = 100`

## 7. UI 与反馈 (`src/ui/` + `scenes/Main.tscn`)

最简可玩 UI, 不做美术:

```gdscript
# GridRenderer.gd (Node2D)
const COLORS = {
    Element.NONE: Color(0.1, 0.1, 0.1),
    Element.WATER: Color.BLUE, Element.STONE: Color.GRAY,
    Element.EARTH: Color.BROWN, Element.STEAM: Color(0.8,0.8,0.9),
    Element.LAVA: Color.RED, Element.PLANT: Color.GREEN,
}
func _draw():
    for y in grid.h: for x in grid.w:
        var c = grid.get_cell(Vector2i(x,y))
        draw_rect(rect, COLORS[c.element], true)
        if c.pillar: draw_outline(rect, Color.YELLOW, 2)
        if c.has_state(State.STEAMED): draw_overlay(rect, Color(0.9,0.9,1,0.3))
        if c.has_state(State.BURNING): draw_overlay(rect, Color(1,0.3,0,0.3))

# ChainCounter.gd (Label)
func add(n): text = "连锁: %d" % n; pop_anim()

# RuleCardView.gd (Button)
var card: RuleCard
func _on_pressed(): game_manager.select_card(self)
```

### 交互流程
1. **OBSERVE** → 自动 1.5s 后进 LAYOUT (原型可省略, 直接进 LAYOUT)
2. **LAYOUT**:
   - 点手牌高亮选中 → 鼠标悬停网格时 `GridRenderer` 显示预览框(将放置的格子黄色描边)
   - 点击网格空格放置: 消耗能量 1, 落柱
   - 可继续放置直到能量耗尽
   - 点"执行"按钮 → 进入 EVOLVE
3. **EVOLVE**:
   - `ChainReaction.execute` 每触发一次 `Reaction`, `GridRenderer._draw()` 重绘 + `ChainCounter.add(1)`
   - 每次 Reaction 之间 `await get_tree().create_timer(0.1).timeout`, 让玩家看见连锁过程
   - 连锁稳定(无新 Reaction)→ 结算 → `end_turn()`

### 反馈分档(Ponytail)
- 第一档(已含): 格子变色、数字弹跳、规则柱黄边、状态半透明覆盖
- 第二档(第二步): 粒子、音效、屏幕泛光

## 8. 初始关卡数据 (`data/coast.json`)

6×6, 简单散布水体/岩石/土壤, 中间一两个熔岩格子保证连锁能起步。

```json
{
  "name": "海岸·教学",
  "size": [6, 6],
  "target": 100,
  "elements": [
    {"coord": [2,2], "element": "LAVA"},
    {"coord": [1,2], "element": "WATER"},
    {"coord": [3,2], "element": "WATER"},
    {"coord": [2,3], "element": "WATER"},
    {"coord": [5,5], "element": "PLANT"},
    {"coord": [0,0], "element": "STONE"}
  ]
}
```

(其余格子默认 NONE / EARTH。完整散布在实现时填充。)

## 9. 终局条件 (原型)

- **胜利**: `chain_total >= TARGET` (100)
- **失败**: `dead_turns >= 10` (连续 10 回合无任何连锁)
- 不做"混沌失控"判定(单一元素填满全部格子)

## 10. 自检约定

非平凡逻辑必须有最小可跑检查:

- `RuleEngine.evaluate` / `ChainReaction.execute`: 在 `tests/` 写一个 `run_tests.gd`, 用 `assert` 验证:
  - 蒸汽化牌在相邻有水+熔岩时产出 1 个 Reaction
  - 同一场景三条规则链式触发(水→蒸汽→触发生长→树木满图触发灭绝)能跑出 chain > 0
  - 半径外的格子不被触发
- 网格半径、邻居、状态衰减: 每个 Cell、Grid 方法一个 `assert` 自检 case
- 一次性函数与渲染一-liner 不测。

`tests/run_tests.gd` 暴露一个 `run_all()` 入口, `GameManager._ready` 里调用; 验证通过打印 "OK", 失败立即报错。

## 11. 第二步扩展点 (留口, 不实现)

- `Element`/`State` 枚举添加新值, `RuleEngine` 不变
- 新规则牌只动 `data/`, 不改代码
- `ChainReaction` 加催化剂尘播撒钩子: 每达到 10 的倍数 `chain` 时向随机格子 `add_state`
- 关卡系统 `LevelManager` 接管多 biome 与目标分递增
- 失败检测加"单一元素超 50%"触发灭绝强制
- 预演系统: `ChainReaction.execute` 复制 grid 后跑一遍返回预测

## 12. 关键参数表 (实现时按需调整)

| 参数 | 值 |
|------|----|
| 网格尺寸 | 6 × 6 |
| 初始手牌 | 5 |
| 每回合抽牌 | 3 |
| 能量上限 | 3 |
| 牌均能量消耗 | 1 |
| 规则柱生命 | 4 回合 |
| 规则柱半径 | 1 (曼哈顿) |
| 连锁单帧间隔 | 100ms |
| 原型目标分数 | 100 |
| 失败死寂阈值 | 10 回合无连锁 |
| 连锁上限(MAX) | 1000 |

---

**附: 原始规划文档**位于 `docs/Catalyst-规划.md`(待用户放入仓库); 本规格与其一致, 仅做第一阶段范围裁剪。