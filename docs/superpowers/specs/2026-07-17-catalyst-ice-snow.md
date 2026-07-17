# 《催化剂》第四阶段子项目-3: 第3关新元素(冰晶+覆雪+冻结)

> 版本: v1.0 · 日期: 2026-07-17
> 范围: ICE 元素 + SNOW/FROZEN 状态 + 2 张新牌 + 4 条世界规则
> 引擎改动: 轻度 (Element +1, State +2, Cell +1, GameManager._world_rules +4 逻辑)

## 1. 新元素

| 枚举 | 中文 | 颜色 | 字标 |
|------|------|------|------|
| ICE | 冰晶 | 浅蓝白 | 冰 |

## 2. 新状态

| 枚举 | 中文 | 视觉 | 说明 |
|------|------|------|------|
| SNOW | 覆雪 | 白色半透叠层 | 2回合自然消散，遇热提前消 |
| FROZEN | 冻结 | 蓝白色边框 | 已有占位，激活使用，锁定格子的元素不被改变 |

## 3. 新规则牌（2 张，data/rules.json 追加）

| id | 牌名 | kind | trigger | contact | result | 半径 | 寿命 | 说明 |
|----|------|------|---------|---------|--------|------|------|------|
| freeze | 结冰 | MULTIPLY | 冰 | 冰 | 冰 | 2 | 4 | 冰向空格扩散 |
| melt | 融冰 | TRANSFORM | 冰 | 汽 | 水 | 2 | 4 | 冰遇蒸汽融化 |

### 卡牌中文介绍

**结冰**: `增殖\n冰 相邻 冰\n→ 扩散 冰\n(半径2格, 4回合)`
**融冰**: `转化\n冰 接触 汽\n→ 水\n(半径2格, 4回合)`

## 4. 世界规则（GameManager._world_rules 追加，高山关专属）

### 4.1 降雪
```
随机 1~2 个 NONE 格 add_state(SNOW, 2)
```
### 4.2 雪化冰
```
SNOW 覆盖的 WATER → 变 ICE, 清除 SNOW
```
### 4.3 雪融
```
SNOW 格相邻有熔岩/蒸汽 → 清除 SNOW
```
### 4.4 冻结
```
FROZEN 的格子不被任何规则改变(Reaction.apply 跳过), tick 到0→解冻恢复原元素
```

**FROZEN 实现**：Cell 加 `var frozen_original: int = Element.NONE`。FROZEN 添加时记录原元素；tick_states 衰减 FROZEN→0 时恢复 elements = frozen_original。Reaction.apply 中检查 `c.has_state(State.FROZEN)` 则跳过该格。

## 5. Cell 新增字段

```gdscript
var frozen_original: int = Element.NONE   # FROZEN 前的原元素
```

## 6. 自检

新增测试:
1. `_test_freeze_multiply` — 冰向空格扩散
2. `_test_melt` — 冰遇汽变水
3. `_test_snow_to_ice` — SNOW+水→冰
4. `_test_frozen_blocks` — FROZEN 格不被反应改变

## 7. 不在本子项目

- 祝福/天灾(第4关)
- 美术资产集成