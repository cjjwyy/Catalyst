# 《催化剂》(Catalyst) 第二阶段子阶段-1 设计

> 版本: v1.0 · 日期: 2026-07-13
> 范围: 催化剂尘+风系统+混沌失控判定。新元素/规则牌/多关卡/粒子音效留给后续子阶段。

## 1. 目标

在保持现有 3 张规则牌（蒸汽化/加速生长/丛林灭绝）不变的前提下，加"催化剂尘+风"让连锁自动扩能、实现规划文档中的"连绵雨"雪球效应。不加新元素。

## 2. 风系统（全局属性）

```gdscript
# GameManager 新增
var wind_dir: int = 0     # 0=N 1=E 2=S 3=W
var wind_speed: int = 1   # 1-3
```

- 全图统一一个风向+风速，不是网格元素
- 每回合 `end_turn()` 刷新: `wind_dir = randi() % 4; wind_speed = randi() % 3 + 1`
- UI: GridRenderer 右上角画箭头+数字（如 `↑3` = 北风 3 速）

### 2.1 方向常量
| dir | 向量 | 显示 |
|-----|------|------|
| 0=N | (0, -1) | ↑ |
| 1=E | (+1, 0) | → |
| 2=S | (0, +1) | ↓ |
| 3=W | (-1, 0) | ← |

## 3. 催化剂尘（DUST 状态）

```gdscript
# State.gd 枚举新增
enum { ..., DUST }  # 催化剂尘
```

- DUST 是一个 `State`（不是元素），与现有状态机制完全一致
- 含 DUST 的格子叠加在基础元素之上（一个水格可以同时是 WATER + DUST）
- 生命周期: 3 回合（`states[DUST] = 3`），每个 `tick_states()` 递减，归零时 `states.erase(DUST)`
- 多个 DUST 格子 4 连通形成**团块**

### 3.1 播撒规则

在 `ChainReaction.execute` / `execute_async` 中：
```gdscript
if chain > 0 and chain % 10 == 0:
    var cells = grid.all_cells().filter(func(c):
        return not c.has_state(State.DUST)
    )
    if not cells.is_empty():
        cells.pick_random().add_state(State.DUST, 3)
```

- 每达成 10/20/30... 连锁自动向随机*无尘*格播撒 1 粒尘
- 播撒在反应执行期间（同一帧），不影响本轮其余 Reaction

### 3.2 团块计算

`RuleEngine` 在 `evaluate`/`evaluate_restricted` 前计算：

```gdscript
func _compute_components(grid) -> Array:
    # flood-fill 所有含 DUST 的格子, 按 4 连通聚类
    # 返回数组 of Array[Vector2i], 每个元素是一个团块的所有坐标
```

### 3.3 团块扩展 pillar 作用域

对每个 pillar 判定流程（修改 `evaluate_restricted`）：

1. 正常 scope = `cells_in_radius(pillar.coord, card.radius)`
2. 检查 scope 是否命中任何含 DUST 的格子
3. 若命中，找到该 DUST 所属的团块，把团块中**所有**格子的 Cell 追加到 scope（不重复）
4. 用扩展后的 scope 调用 `_match_in_scope`

效果: 一棵 steamify pillar 的半径内只要有 1 粒尘 → 这粒尘所属的整个 4 连通尘网里的水/熔岩/植物全被 pillar 当作"在作用范围内"。

## 4. 回合行为时序

```
end_turn():
  1. decay_pillars()          # 规则柱 life-1, 过期移除
  2. tick_dust()              # 所有格 DUST 剩余回合 -1, ≤0 则消散
  3. push_dust()              # 按当前 wind_dir/wind_speed 移动所有 DUST
                              #   越界(出网格) → 立即 states.erase(DUST)
  4. chaos_check()            # 单一元素 >50% → 判负或强绝(见 §6)
  5. _reroll_wind()           # 刷新下回合风向+风速
  6. hand.draw(3); energy.refill()
  7. turn += 1; phase = LAYOUT
  state_changed.emit()
```

- 风推尘发生在**回合间**，不在演化阶段内（保证演化结果可确定）
- `tick_states()` 已在 `GameManager.execute()` 的 Post 结算中调用一次，`end_turn()` 中不再调（避免双重衰减）
  - 但是 DUST 状态需要在这个时序衰减！当前 `tick_states()` 在 `GameManager.execute` 末尾对所有 Cell 调了。需要移除此调用，改为只在 `end_turn()` 调统一衰减
  - Ponytail: 直接去掉 execute 中的 `tick_states()`，所有状态衰减统一在 end_turn 处理

### 4.1 push_dust() 伪代码

```gdscript
func push_dust():
    var moves = []  # [(from_coord, to_coord)]
    for cell in grid.all_cells():
        if cell.has_state(State.DUST):
            var dir_vec = DIR_VECTORS[wind_dir]
            var dst = cell.coord
            for i in range(wind_speed):
                var next = dst + dir_vec
                if not grid.is_in_bounds(next):
                    # 越界 → 放入除尘队列(消失)
                    moves.append((cell.coord, null))
                    break
                dst = next
            moves.append((cell.coord, dst))
    for m in moves:
        grid.get_cell(m[0]).remove_state(State.DUST)
        if m[1] != null:
            var dst_cell = grid.get_cell(m[1])
            var t = max(dst_cell.states.get(State.DUST, 0), 3)
            dst_cell.add_state(State.DUST, t)
```

- 多重尘叠达到同一格: 保持最大剩余回合数
- wind 推 dust 后，同格可以叠多份尘，但叠加后 turn 取较长者

## 5. ChainReaction 修改汇总

`execute` / `execute_async` 改动:

| 改动 | 位置 | 说明 |
|------|------|------|
| 播撒钩子 | for loop 内 | chain%10==0 → 随机空格 add_state(DUST, 3) |
| 团块计算 | evaluate_restricted 调前 | RuleEngine._compute_components(grid) 返回团块列表 |
| 扩展 scope | evaluate_restricted 内部 | 命中 DUST → 加整团块到 scope |

## 6. 混沌失控判定

```gdscript
func chaos_check():
    var total = grid.w * grid.h
    for elem in [Element.WATER, Element.STONE, Element.EARTH,
                 Element.STEAM, Element.LAVA, Element.PLANT]:
        var n = grid.count_element(elem)
        if n > total * 0.5:
            # 全场任何 EXTINCTION pillar 它的 trigger 等于泛滥元素?
            var ext_pillar = pillars.filter(func(p):
                return p.card.kind == RuleCard.Kind.EXTINCTION and \
                       p.card.trigger_element == elem
            )
            if not ext_pillar.is_empty():
                # 强制执行: 清空前 1 个 EXTINCTION pillar 范围内的全部 elem
                var p = ext_pillar[0]
                for c in grid.cells_in_radius(p.coord, p.card.radius):
                    if c.element == elem:
                        c.element = Element.NONE
                        c.clear_states()
                return
            else:
                game_over.emit(false, "混沌失控 — %s 覆盖超过 50%%" % elem)
                return
```

- 仅检查基础元素（不含 NONE 和 DUST 状态）
- 若存在匹配的 EXTINCTION 在场 → 不判负，强制执行一次灭绝；若无 → 游戏直接失败

## 7. UI 改动

| 改动 | 文件 | 说明 |
|------|------|------|
| 风指示器 | GridRenderer._draw | 网格上方画 `↑3` 风向+数字 |
| 尘可视化 | GridRenderer._draw | 含 DUST 的格子叠加金黄色半透明点粒子（draw_circle） |
| 图例更新 | GridRenderer._draw_legend | 加一行"催化剂尘 Dust"金色点说明 |

## 8. State 枚举改动

```gdscript
enum { NONE, BURNING, STEAMED, FROZEN, ASH, DUST }
```

DUST 是唯一实际使用的状态（原型阶段），其余四个（BURNING/STEAMED/FROZEN/ASH）继续占位，留待以后。

## 9. Grid 新增方法

```gdscript
func is_in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h
```

## 10. 自检

新增测试（补充到 `tests/run_tests.gd`）:

1. **风推尘跨格**: 设 wind_dir=N, speed=2, 尘在 (2,3) → 应移到 (2,1)；在 (0,0) → 越界消失
2. **尘团块扩展 scope**: grid 上 3 格 DUST 形成 4 连通团块，pillar 半径 1 刚好触到 1 格 → scope 应扩展到全部 3 格
3. **混沌失控检测**: 31 个 PLANT（>50% of 36），无 EXTINCTION pillar → game_over 信号 emit
4. **播撒时机**: 构造场景让 chain 达到 10 → 确认有格获 DUST 状态

## 11. 不在本阶段实现的项

- 新元素（矿石 Ore / 冰晶 Ice / 风 Wind 作为网格元素）
- 新规则牌（光尘覆盖 / 带电分裂 / 祝福等）
- 多关卡 / LevelManager（8×8 丛林、10×10 高山、12×12 火山口）
- 预演系统
- 粒子特效 / 音效 / 屏幕泛光
- 手牌保留上限
- 扰动事件
- 能量成本差异化

本阶段完成后：第一阶段 3 牌 + 催化剂尘雪球 + 风动态 + 混沌失控 → 可评测"连绵雨"核心体验，决定下一步加什么。

---

**附**: 现有引擎改动仅在 `RuleEngine._evaluate_restricted`（加团块扩展）和 `ChainReaction`（播撒钩子 + cycle 检测已在第一阶段完成）。`RuleCard`/`Reaction`/`RulePillar` 不改。