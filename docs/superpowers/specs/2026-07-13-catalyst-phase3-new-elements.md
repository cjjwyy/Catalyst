# 《催化剂》第三阶段：新元素 + 自然规则 + 世界动态

> 版本: v1.0 · 日期: 2026-07-13
> 引擎改动: 轻度（4 处，每处 ≤10 行）

## 1. 目标

新增 2 种元素、4 张规则牌、世界自然衰减/生成，不改 RuleEngine 核心匹配逻辑。

## 2. 新元素

| 枚举 | 中文 | 颜色 | 字标 |
|------|------|------|------|
| ORE | 矿石 | 金 | 矿 |
| GRASS | 草 | 浅绿 | 草 |

裸土复用现有 `EARTH`（土），不新增。

## 3. 新规则牌（4 张，data/rules.json）

| id | 牌名 | kind | trigger | contact | result | self_replace | chain_reward | 说明 |
|----|------|------|---------|---------|--------|--------------|--------------|------|
| petrify | 岩化 | TRANSFORM | 岩 | 植 | 土 | — | 1 | 岩石遇树 → 裸土 |
| grass_grow | 草生 | MULTIPLY | 土 | 植 | 草 | — | 1 | 裸土旁有树 → 空格生草 |
| harvest | 采掘 | TRANSFORM | 植 | 矿 | 空 | 空 | 5 | 矿石旁树被采→两者消失，+5 连锁 |
| grass_spread | 草殖 | MULTIPLY | 草 | 草 | 草 | — | 1 | 草向空格扩散 |

## 4. 丛林灭绝牌修改

现有 丛林灭绝 `extinct_threshold=5`，改加字段：

| 新增字段 | 值 | 说明 |
|----------|-----|------|
| `also_count` | GRASS | 统计时草+树合并和 threshold 比，清空时两种都清 |

## 5. 世界规则（`GameManager._world_rules()`，每回合 end_turn 调用）

| 规则 | 条件 | 效果 |
|------|------|------|
| 汽消散 | `element==STEAM` 且 `turn - placed_at_turn >= 2` | → NONE |
| 草枯 | `element==GRASS` 且 4 邻格无植/草，`decay_timer >= 2` | → 土，重置 placed_at_turn |
| 土硬化 | `element==EARTH` 且 `turn - placed_at_turn >= 2` | → 岩 |
| 自然生成 | 随机 1~2 个 NONE 格 | → 50%水 / 50%岩 |

**Cell 新增字段**：
```gdscript
var decay_timer: int = 0   # 草连续无邻树回合计数 (已有 placed_at_turn)
```

## 6. RuleCard 新增字段

```gdscript
@export var also_count: int = Element.NONE  # EXTINCTION: 阈值统计时也计入此元素
```

`from_dict` 加行: `also_count = Element.from_string(d.get("also_count", "NONE"))`

## 7. RuleEngine 改动

`_match_in_scope` 中 EXTINCTION 分支，原统计：
```gdscript
for c in scope:
    if c.element == card.trigger_element:
        count += 1
```
改为：
```gdscript
for c in scope:
    if c.element == card.trigger_element or \
       (card.also_count != Element.NONE and c.element == card.also_count):
        count += 1
```

## 8. Reaction 改动

`RuleCard.Kind.EXTINCTION` apply 中，清空逻辑原清 `trigger_element`，改为也清 `also_count`：
```gdscript
# 原有: if c.element == card.trigger_element → 清空
# 新增:
if c.element == card.trigger_element or \
   (card.also_count != Element.NONE and c.element == card.also_count):
    c.element = Element.NONE; c.clear_states(); affected.append(c.coord)
```

## 9. GameManager `_world_rules()` 实现

```gdscript
func _world_rules() -> void:
    # 汽消失
    for c in grid.all_cells():
        if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
            c.element = Element.NONE
    # 草枯 & 土硬化
    for c in grid.all_cells():
        if c.element == Element.GRASS:
            var has_friend = false
            for n in grid.neighbors(c.coord):
                if n.element in [Element.PLANT, Element.GRASS]:
                    has_friend = true; break
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
            c.last_changed_turn = turn
    # 自然生成
    var empty = []
    for c in grid.all_cells():
        if c.element == Element.NONE:
            empty.append(c)
    if not empty.is_empty():
        for _i in range(min(2, empty.size())):
            var c = empty.pop_at(randi() % empty.size())
            c.element = Element.WATER if randi() % 2 == 0 else Element.STONE
            c.placed_at_turn = turn
```

## 10. 初始地图调整

`coast.json` 加 2~3 格矿石、1 格岩石（供岩化用）、现有植物/水/熔岩保留不变。

## 11. 自检

新增测试：
1. `_test_ore_harvest` — 植物邻矿 → 两者消失，chain=5
2. `_test_grass_wither` — 草无邻树 3 回合 → 变土
3. `_test_steam_evaporate` — 蒸汽 2 回合后消失
4. `_test_extinct_counts_grass` — also_count 让丛林灭绝合并计数草

## 12. 不在本阶段

- 冰晶、光尘状态、带电、祝福
- 多关卡、预演、音效/粒子
- 能量差异化、手牌保留、扰动事件