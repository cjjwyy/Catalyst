# 《催化剂》第四阶段子项目-4: 第4关(祝福+天灾)

> 版本: v1.0 · 日期: 2026-07-17
> 范围: BLESSED/METEOR_LAVA 状态 + 2 张新牌 + 天灾事件世界规则
> 引擎改动: 轻度 (State +2, ChainReaction +BLESSED 检查, GameManager._world_rules +天灾/METEOR_LAVA)

## 1. 新状态

| 枚举 | 中文 | 视觉 | 说明 |
|------|------|------|------|
| BLESSED | 祝福 | 金色光晕边框 | 该格反应 chain_reward ×2 |
| METEOR_LAVA | 陨石熔岩 | 暗红脉冲圈+"▲" | 衰减后熔岩→岩石 |

## 2. 新规则牌（2 张, level=4, data/rules.json 追加）

| id | 牌名 | kind | trigger | contact | result | add_state | add_state_turns | radius | life | chain_reward | 说明 |
|----|------|------|---------|---------|--------|-----------|-----------------|--------|------|--------------|------|
| bless | 祝福 | TRANSFORM | 汽 | 植 | 空 | BLESSED | 3 | 2 | 4 | 1 | 汽接触植→汽变空，汽格加 BLESSED，该格反应连锁×2 |
| meteor_strike | 陨石术 | EXTINCTION | 熔 | — | — | — | — | 2 | 4 | 1 | 半径内熔≥3→清空所有熔岩和植 |

### 卡牌中文介绍

**祝福**: `转化\n汽 接触 植\n→ 空\n(半径2格, 4回合)` + tooltip `转化: 柱子的扫描范围(r2)内,\n每格汽 若其邻1格有 植 → 变 空 + 加祝福\n祝福格反应连锁×2\n寿命 4 回合`

**陨石术**: `灭绝\n熔 ≥3个\n→ 清空所有熔+植\n(半径2格, 4回合)` + tooltip

## 3. ChainReaction BLESSED 检查

在 execute / execute_async 的 `chain += r.card.chain_reward` 处加:

```gdscript
var reward = r.card.chain_reward if r.card != null else 1
# BLESSED 格反应奖励翻倍
for coord in r.affected:
    var c = grid.get_cell(coord)
    if c != null and c.has_state(State.BLESSED):
        reward *= 2
        break
chain += reward
```

## 4. 天灾事件（GameManager._world_rules 追加，第4关专属）

```gdscript
# 天灾事件 (仅第4关)
if level_manager.current_level == 3:  # 0-indexed, 3 = 第4关
    if randi() % 100 < 30:  # 30% 概率
        var event = randi() % 3
        if event == 0:  # 陨石
            var cells = grid.all_cells()
            var c = cells[randi() % cells.size()]
            c.element = Element.LAVA
            c.add_state(State.METEOR_LAVA, 2)
            c.placed_at_turn = turn
        elif event == 1:  # 地震
            var none_cells = grid.all_cells().filter(func(c2): return c2.element != Element.NONE)
            for _i in range(min(2, none_cells.size())):
                var sc = none_cells.pop_at(randi() % none_cells.size())
                sc.element = Element.NONE
                sc.clear_states()
        else:  # 火山喷发
            var empties = grid.all_cells().filter(func(c2): return c2.element == Element.NONE)
            if not empties.is_empty():
                var c = empties[randi() % empties.size()]
                c.element = Element.LAVA
                c.placed_at_turn = turn
```

## 5. METEOR_LAVA 衰减→熔岩→岩石

在 _world_rules 的 SMOKE/BURNING/was_burning 检查之后加:

```gdscript
# METEOR_LAVA 衰减→熔岩变岩石
for c in grid.all_cells():
    if c.was_meteor:
        if c.element == Element.LAVA:
            c.element = Element.STONE
            c.placed_at_turn = turn
        c.was_meteor = false
```

Cell.tick_states 中 METEOR_LAVA 衰减时设 `was_meteor = true`。

Cell 新增字段: `var was_meteor: bool = false`

## 6. State 枚举改动

```gdscript
enum { NONE, BURNING, STEAMED, FROZEN, ASH, DUST, SNOW, BLESSED, METEOR_LAVA }
```

NAMES 加: `BLESSED: "BLESSED"`, `METEOR_LAVA: "METEOR_LAVA"`

## 7. GridRenderer 渲染

BLESSED: 格子加金色发光边框:
```gdscript
if c.has_state(State.BLESSED):
    draw_rect(rect.grow(-3), Color(1, 0.85, 0.3), false, 2)
```

METEOR_LAVA: 暗红脉冲圈 + "▲" 符号:
```gdscript
if c.has_state(State.METEOR_LAVA):
    var cx = rect.position.x + cell_size / 2.0
    var cy = rect.position.y + cell_size / 2.0
    var r = 8.0 + 3.0 * sin(Time.get_ticks_msec() / 200.0)
    draw_circle(Vector2(cx, cy), r, Color(0.5, 0.15, 0.1, 0.5))
    draw_string(_font(), rect.position + Vector2(cell_size / 2.0 - 4, 14), "^", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 0.4, 0.2))
```

## 8. RuleCardView CN 加映射

BLESSED/METEOR_LAVA 是状态不是元素，CN 不用改。但牌的 tooltip 文本要加祝福说明。

## 9. 自检

新增测试:
1. `_test_bless_bonus` — BLESSED 格反应 chain_reward×2
2. `_test_meteor_strike` — 熔≥3 清空所有熔和植
3. `_test_meteor_event` — 陨石事件加 METEOR_LAVA，衰减后熔→岩
4. `_test_disaster_earthquake` — 地震清空2格

## 10. 不在本子项目

- 美术资产集成
- 音效/粒子
- 存盘系统