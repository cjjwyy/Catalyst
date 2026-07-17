# 《催化剂》第四阶段子项目-2: 第2关新元素(燃烧+孢子)

> 版本: v1.0 · 日期: 2026-07-14
> 范围: SPORE 元素 + BURNING 状态激活 + 2 张新牌 + 2 条世界规则
> 引擎改动: 轻度（Element +1, State 激活已有占位, GameManager._world_rules +2 逻辑, push_dust 边界改回消失, RuleCardView 中文映射 +2）

## 1. 新元素

| 枚举 | 中文 | 颜色 | 字标 |
|------|------|------|------|
| SPORE | 孢子 | 浅紫绿 | 孢 |

## 2. 新状态（已有占位，激活使用）

| 状态 | 中文 | 视觉 |
|------|------|------|
| BURNING | 燃烧 | 格子叠加橙红半透明 +火焰效果 |

## 3. 新规则牌（2 张，data/rules.json 追加）

| id | 牌名 | kind | trigger | contact | result | chain_reward | 半径 | 寿命 | 说明 |
|----|------|------|---------|---------|--------|--------------|------|------|------|
| sporify | 结孢子 | MULTIPLY | 汽 | 植 | 孢 | 1 | 2 | 4 | 汽相邻有植物→向汽的空相邻格扩散孢子，植物和汽都保留 |
| spore_bloom | 孢子萌发 | MULTIPLY | 水 | 孢 | 植 | 1 | 2 | 4 | 孢子相邻有水→向水的空相邻格扩散植物，水和孢子都保留 |

### 卡牌中文介绍（RuleCardView._label / _tooltip）

**结孢子**：
- label: `增殖\n汽 相邻 植\n→ 扩散 孢\n(半径2格, 4回合)`
- tooltip: `增殖: 半径内 汽 相邻 植 → 向空格扩散 孢\n寿命 4 回合`

**孢子萌发**：
- label: `增殖\n水 相邻 孢\n→ 扩散 植\n(半径2格, 4回合)`
- tooltip: `增殖: 半径内 水 相邻 孢 → 向空格扩散 植\n寿命 4 回合`

## 4. 世界规则追加（GameManager._world_rules()）

在现有世界规则之后追加：

### 4.1 点燃蔓延

```
for c in grid.all_cells():
    if c.element == Element.PLANT and not c.has_state(State.BURNING):
        # 植物相邻有熔岩 → 点燃
        for n in grid.neighbors(c.coord):
            if n.element == Element.LAVA:
                c.add_state(State.BURNING, 2)  # 2回合后烧完
                break
    if c.has_state(State.BURNING):
        # 燃烧格让相邻植物也点燃
        for n in grid.neighbors(c.coord):
            if n.element == Element.PLANT and not n.has_state(State.BURNING):
                n.add_state(State.BURNING, 2)
        # 燃烧植物 tick 后变空(由 tick_states 衰减到0时触发)
```

BURNING 状态衰减到 0 时(tick_states 消除后), 需要额外检查: 如果该格元素是 PLANT → 变 NONE。

在 `tick_states()` 调用后, `_world_rules()` 中加:
```
for c in grid.all_cells():
    if c.element == Element.PLANT and not c.has_state(State.BURNING) and c was_burning:
        c.element = Element.NONE  # 烧完了
```

**实现方式**: 在 Cell 加 `var was_burning: bool = false`。tick_states 衰减消除 BURNING 时设 was_burning=true。_world_rules 检查 was_burning → 植物变空 → 清 was_burning。

### 4.2 孢子飘散

```
# 孢子随风向移动 1 格, 碰边界继续向外→消失
var dir_vec = DIR_VECTORS[wind_dir]
var moves: Array = []
for c in grid.all_cells():
    if c.element == Element.SPORE:
        var nx = c.coord + dir_vec
        if not grid.is_in_bounds(nx):
            moves.append([c.coord, null])  # 越界消失
        else:
            moves.append([c.coord, nx])
for m in moves:
    var src = grid.get_cell(m[0])
    src.element = Element.NONE  # 孢子不像尘是叠加态, 是元素, 直接移动
    if m[1] != null:
        var dst_cell = grid.get_cell(m[1])
        if dst_cell.element == Element.NONE:
            dst_cell.element = Element.SPORE
        # 如果目标格非空, 孢子消失(被挡住)
```

## 5. 尘边界行为改回消失

`push_dust()` 中删除"反弹停在边界"逻辑, 恢复"越界→移除":

```
# 原: if not grid.is_in_bounds(nx): break  (反弹)
# 改: if not grid.is_in_bounds(nx): fell_off = true; break  (消失)
if fell_off:
    moves.append([c.coord, null])
```

## 6. RuleCardView CN 字典加映射

```gdscript
const CN = {
    ...,
    Element.SPORE: "孢"
}
```

State.NAMES 已有 BURNING, 但 CN 用的是 Element 映射。BURNING 作为状态不在 CN 中。GridRenderer 已有 BURNING 半透明渲染, 只需加 SPORE 颜色和字标。

## 7. GridRenderer 加 SPORE 颜色和字标

COLORS 加: `Element.SPORE: Color(0.6, 0.8, 0.5)` (浅黄绿)
LABELS 加: `Element.SPORE: "孢"`

## 8. 自检

新增测试:
1. `_test_sporify` — 汽相邻植→空格生孢, 汽和植保留
2. `_test_spore_bloom` — 孢相邻水→空格生植, 孢和水保留
3. `_test_burning_ignite` — 植物相邻熔岩→加 BURNING 状态
4. `_test_spore_wind_move` — 孢子随风向移动 1 格, 越界消失

## 9. 不在本子项目

- 冰晶/带电/雪 (第3关)
- 祝福/天灾 (第4关)
- 美术资产集成
- 音效/粒子