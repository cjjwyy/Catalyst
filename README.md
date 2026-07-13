# 《催化剂》Catalyst

> Godot 4 回合制网格策略游戏 — 放置"规则柱"编织元素连锁反应，看积分雪球式增长。

## 快速开始

用 Godot 4.3+ 打开 `project.godot` → F5 运行。

## 玩法

1. **点手牌** 选中规则柱
2. **点网格空格** 放置规则柱（消耗 1 能量/张，上限 3 张/回合）
3. **点「执行演化」** 观看连锁反应
4. 达成 100 连锁 → 胜利；连续 10 回合无连锁 → 失败

## 当前规则牌

| 牌名 | 类型 | 半径 | 触発条件 |
|------|------|------|----------|
| 蒸汽化 | 转化 | 2 | 水体相邻熔岩 → 蒸汽，熔岩冷却为岩石 |
| 加速生长 | 增殖 | 2 | 植物相邻蒸汽 → 向空格扩散植物 |
| 丛林灭绝 | 灭绝 | 2 | 半径内 ≥5 植物时清空区域内全部植物 + 蒸汽 |

## 催化剂尘（第二阶段新加）

- 每 5 连锁自动播撒 3 粒催化剂尘
- 尘形成 4 连通团块，团块触到规则柱则整个团块享受规则效果
- 全局风向每回合随机刷新，推动陈尘移动
- 单一元素超过 50% 格子 → 混沌失控判负

## 目录结构

```
src/core/      纯数据模型 (Element/State/Cell/Grid)
src/rules/     规则引擎 (RuleCard/RulePillar/RuleEngine/Reaction/ChainReaction)
src/player/    玩家系统 (HandManager/EnergySystem)
src/ui/        渲染与输入 (GridRenderer/ChainCounter/RuleCardView)
src/main/      GameManager (Autoload 总控)
data/          JSON 配置 (关卡/规则)
scenes/        场景文件
tests/         GDScript 自检 (启动时自动跑)
docs/          规划与设计文档
```

## 测试

```bash
# headless 运行测试
& "path/to/godot.exe" --headless --path "." --quit
```

GameManager 启动时自动跑所有自检，失败 `push_error`。

## 设计文档

- `docs/Catalyst-规划.md` — 原始策划
- `docs/superpowers/specs/2026-07-13-catalyst-prototype-design.md` — 第一阶段规格
- `docs/superpowers/specs/2026-07-13-catalyst-phase2-design.md` — 催化剂尘+风规格
- `AGENTS.md` — 项目开发约定

## 许可

MIT