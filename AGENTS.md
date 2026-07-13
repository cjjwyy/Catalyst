# Catalyst — AI 代理指南

## 项目概述
《催化剂》(Catalyst): Godot 4 + GDScript 实现的回合制网格策略游戏。
玩家在网格上放置"规则柱"激活元素连锁反应。详见 `docs/Catalyst-规划.md` (原始策划) 与 `docs/superpowers/specs/2026-07-13-catalyst-prototype-design.md` (第一阶段设计规格,实现依据)。

## 当前阶段
**第一阶段核心机制原型**: 6×6 单关卡, 3 张规则牌(蒸汽化/加速生长/丛林灭绝), 局部生效规则柱, 连锁计数。催化剂尘、多关卡、粒子音效留给第二步。

## 技术栈
- 引擎: Godot 4.x · 语言: GDScript
- 入口场景: `scenes/Main.tscn`
- Autoload: `GameManager` (`src/main/GameManager.gd`, 全局单例 `/root/GameManager`)
- 数据: `data/*.json` (关卡配置: `coast.json`; 规则定义: `rules.json`)

## 目录约定
```
src/core/    纯数据模型 (Element/State/Cell/Grid) - 不依赖 Godot 节点,可单测
src/rules/   规则引擎 (RuleCard/RulePillar/RuleEngine/Reaction/ChainReaction)
src/player/  玩家系统 (HandManager/EnergySystem)
src/ui/      渲染与输入 (GridRenderer/ChainCounter/RuleCardView) - 仅依赖 GameManager 信号
src/main/    GameManager (Autoload 总控,持有 grid/pillars/hand/energy)
data/        JSON 配置 (规则与关卡)
scenes/      .tscn/.gd
tests/       GDScript assert 自检 (run_tests.gd,GameManager 启动时跑)
```

## 架构原则( ponytail: 复用优先、最小新增 )
1. **核心逻辑层 vs 渲染层严格分离**: `src/core/`、`src/rules/`、`src/player/` 是纯 `RefCounted`/`Resource`,无 Node 依赖,可被 `tests/` 直接 `assert` 测试。UI 仅订阅 GameManager 信号再 `queue_redraw`。
2. **规则柱局部生效**: 规则按曼哈顿半径扫描 `grid.cells_in_radius(pillar.coord, card.radius)`。评估分两路: `evaluate` (全量) 与 `evaluate_restricted` (仅扫变更格子) — 后者由 `ChainReaction` 用于迭代,避免每轮遍历整个网格。
3. **数据驱动扩展**: 新增规则只需在 `data/rules.json` 增配置,`RuleEngine` 按 `kind`/字段通用匹配,无需改引擎代码。
4. **执行流程分阶段**: `LAYOUT` (玩家布局) → `EVOLVE` (`ChainReaction.execute_async` 异步跑连锁,100ms/Reaction 演示) → 结算 → `end_turn` (衰减 pillar、抽牌、回能)。
5. **限制与上限**: `MAX_CHAIN=1000`,无新 Reaction 即终止 (`evaluate_restricted` 返回空)。终局: `chain_total >= TARGET`(100) 胜, `dead_turns >= DEAD_TURNS`(10) 败。
6. **EXTINCTION 走统一局部路径**: pillar 半径内 `trigger_element` 数 ≥ `extinct_threshold` 即产 1 个 Reaction,消除范围内最旧 (placed_at_turn 最小) 一个。无全局"50%"判定。

## 关键参数(实现时按需调)
| 参数 | 值 |
|------|----|
| 网格尺寸 (原型) | 6×6 |
| 初始手牌 | 5 |
| 每回合抽牌 | 3 |
| 能量上限 | 3 (所有牌 cost=1) |
| 规则柱生命 | 4 回合 |
| 规则柱半径 | 1 (曼哈顿) |
| 连锁单帧间隔 | 0.1s |
| 连锁上限 | 1000 |
| 胜利目标 | 100 |
| 死寂阈值 | 10 回合 |
| EXTINCTION 阈值 | 半径内 5 个 |

## 验证约定
- 非平凡逻辑必须有可跑的自检: `tests/run_tests.gd::CatalystTests.run_all()`,GameManager 启动时调用,失败立即 `push_error`。
- 修规则/数据/匹配逻辑 → 在同处补 `assert` 测试用例。
- 一次性渲染/输出函数不测,YAGNI 测试也适用。

## 开发与运行
- 用 Godot 4.x 打开 `project.godot` 即可运行。无外部依赖。
- 启动场景 `scenes/Main.tscn`: 屏幕显示网格、手牌区、能量、连锁计数、总和、状态、执行按钮。
- 交互: 点手牌高亮 → 点网格空格落柱(消耗1能量,可叠 3 个) → 点"执行演化"看连锁 → 计数刷新到下回合。

## 第二阶段扩展点(留口, 现不实现)
- `Element`/`State` 枚举加值 → 引擎代码不动
- `RuleCard` 加字段 → `from_dict` 增字段读取
- 催化剂尘: `ChainReaction.execute` 在 `chain % 10 == 0` 时向随机格 `add_state`
- 多关卡: `LevelManager` 接管 `coast.json` 之外的 biome
- 失败加"单一元素超 50%"全局触发强制灭绝
- 预演系统: 复制 grid → 同步 `execute` → 返回预测 chain