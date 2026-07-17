# Catalyst — AI 代理指南

## 项目概述
《催化剂》(Catalyst): Godot 4 + GDScript 实现的回合制网格策略游戏。
玩家在网格上放置"规则柱"激活元素连锁反应。详见 `docs/Catalyst-规划.md` (原始策划) 与 `docs/superpowers/specs/` 下各阶段规格。

## 当前阶段
**第四阶段**: 多关卡系统 + 燃烧/孢子(第2关) + 冰晶/覆雪/冻结(第3关)。第4关(祝福+天灾)未实现。
1-4 关: 10×10 → 12×12 → 14×14 → 16×16, 目标 100/300/700/1500。

## 技术栈
- 引擎: Godot 4.x · 语言: GDScript
- 入口场景: `scenes/LevelSelect.tscn`
- Autoload: `GameManager` (`src/main/GameManager.gd`, `/root/GameManager`)
- 数据: `data/rules.json` (规则定义, 含 `level` 字段控制关卡出现), `data/levels/*.json` (关卡配置)

## 目录约定
```
src/core/    元素/状态/格子/网格 (Element/State/Cell/Grid)
src/rules/   规则引擎 (RuleCard/RulePillar/RuleEngine/Reaction/ChainReaction)
src/player/  手牌/能量 (HandManager/EnergySystem)
src/ui/      渲染与输入 (GridRenderer/LevelSelect/RuleCardView)
src/main/    GameManager (Autoload 总控) + LevelManager
src/world/   LevelManager (关卡管理)
data/        JSON 配置 (rules.json + levels/*.json)
scenes/      .tscn 场景
tests/       GDScript assert 自检 (25 个用例)
```

## 核心判定机制

### 匹配规则 (_match_cell)
柱子扫描其曼哈顿半径内每格。对于每个触发格(element==trigger_element), 取其**邻1格范围**(scope1=曼哈顿≤1), 若 scope1 内有 catalyst dust → flood-fill 扩展 dust 团块 → scope1 延展。在延展后的 scope1 中查找 contact_element, 命中→触发。

### 三种 kind
- **TRANSFORM**: 触发格 element→result, 同时清空 scope1 内首个 contact_element→self_replace
- **MULTIPLY**: 触发格保留, 其4邻空格→result
- **EXTINCTION**: 直接统计柱子半径内 trigger+also_count 总数, ≥threshold→全部清空+also_clear也清

### 连锁循环
evaluate → 执行所有 Reaction → 记录 affected → evaluate_restricted(只看 affected 的 pillar) → 直到无新 reaction

## 架构原则
1. **引擎代码不动**: 新元素/牌/关卡只加 JSON+枚举值, RuleEngine/Reaction 不改逻辑
2. **卡牌关卡隔离**: `level=0` 全关通用, `level=N` 仅第N关出现
3. **世界规则每回合**: `_world_rules()` 执行自然衰减/生成/蔓延/飘散
4. **催化剂尘团块**: `RuleEngine._expand_scope_for_dust()` 用 flood-fill 扩展邻1格范围
5. **风系统**: 全局属性 wind_dir(0-3), wind_speed(1-3), 推动尘/孢子, 越界消失

## 关键参数
| 参数 | 值 |
|------|----|
| 关卡数 | 4 (10/12/14/16) |
| 手牌池 | 7 通用 + 2 孢子(第2关) + 2 冰(第3关) = 11 张 |
| 初始手牌 | 5 |
| 每回合抽牌 | 3 |
| 能量上限 | 3 (所有牌 cost=1) |
| 规则柱生命 | 4 回合 |
| 催化剂尘:播撒 | 每 5 连锁 3 粒, 持续 5 回合 |
| 连锁上限 | 1000 |
| 死寂阈值 | 10 回合 |
| EXTINCTION 阈值 | 半径内 5 个 |
| 尘/孢子边界 | 越界消失 |

## 元素与状态

| Element | 字标 | State | 说明 |
|---------|------|-------|------|
| WATER | 水 | BURNING | 植物+熔岩→燃烧,蔓延,烧完变空 |
| STONE | 岩 | STEAMED | 未使用 |
| EARTH | 土 | FROZEN | 阻断反应,暂未实装加冻 |
| STEAM | 汽 | ASH | 未使用 |
| LAVA | 熔 | DUST | 催化剂尘,每5连播3粒 |
| PLANT | 植 | SNOW | 覆雪,水+雪→冰,邻热消散 |
| ORE | 矿 | | |
| GRASS | 草 | | |
| SPORE | 孢 | | |
| ICE | 冰 | | |

## 验证约定
- `tests/run_tests.gd` 25 个 assert 用例, GameManager 启动时跑
- 修规则/引擎 → 同处补 test
- 渲染/UI 不测

## 开发与运行
- Godot 4.x 打开 `project.godot` → F5
- 启动: 关卡选择 → 点关卡 → 点手牌→落柱 → 执行演化 → 下一关/重试/主菜单