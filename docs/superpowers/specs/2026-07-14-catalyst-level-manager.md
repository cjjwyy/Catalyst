# 《催化剂》第四阶段子项目-1: LevelManager + 多关卡系统

> 版本: v1.0 · 日期: 2026-07-14
> 范围: LevelManager + 关卡选择界面 + 4 个关卡 JSON。不加新元素/新牌。

## 1. 目标

让玩家在 4 个尺寸/目标/布局各异的关卡间选择并逐级解锁。

## 2. LevelManager (`src/world/LevelManager.gd`)

```gdscript
class_name LevelManager
extends RefCounted

const LEVELS = [
    {"id": "coast", "name": "海岸·启蒙", "path": "res://data/levels/coast.json", "size": [10,10], "target": 100},
    {"id": "jungle", "name": "丛林·生长", "path": "res://data/levels/jungle.json", "size": [12,12], "target": 300},
    {"id": "mountain", "name": "高山·精炼", "path": "res://data/levels/mountain.json", "size": [14,14], "target": 700},
    {"id": "volcano", "name": "火山口·终局", "path": "res://data/levels/volcano.json", "size": [16,16], "target": 1500},
]

var current_level: int = 0
var unlocked: int = 0   # 最高解锁到第几关 (0=只解锁第1关)

func get_current() -> Dictionary
func get_level(idx: int) -> Dictionary
func is_unlocked(idx: int) -> bool
func select(idx: int) -> bool   # 仅在 is_unlocked 时允许
func advance() -> bool          # 胜利后调用, 解锁下一关, 返回是否还有下一关
func level_count() -> int
```

- 不做存盘文件 (YAGNI), 重启从第 1 关开始
- GameManager 持有 `level_manager: LevelManager`

## 3. GameManager 改动

- 新增 `var level_manager: LevelManager = LevelManager.new()`
- `start_game(level_idx: int = 0)` 改为从 `level_manager.get_level(level_idx)` 读 size/target/path
- `TARGET` 常量改为从当前关卡读取: `var target: int = 100`
- 胜利时: `level_manager.advance()`, 发 `level_complete` 信号 (非 `game_over`)
- `game_over` 仅用于失败

新增信号:
```gdscript
signal level_complete(level_idx: int)
```

## 4. 关卡选择界面 (`scenes/LevelSelect.tscn` + `src/ui/LevelSelect.gd`)

启动场景改为 `LevelSelect.tscn`。

布局:
```
┌───────────────────────────────────┐
│          催化剂 Catalyst           │
│                                   │
│  [海岸·启蒙  10×10  目标100]      │ ← 已解锁
│  [丛林·生长  12×12  目标300]      │ ← 锁定(灰)
│  [高山·精炼  14×14  目标700]      │ ← 锁定(灰)
│  [火山口·终局 16×16 目标1500]     │ ← 锁定(灰)
│                                   │
│  点击已解锁关卡开始游戏           │
└───────────────────────────────────┘
```

- 4 个 Button, 已解锁亮色可点, 锁定暗灰不可点
- 点击已解锁关卡 → `get_tree().change_scene_to_file("res://scenes/Main.tscn")`, GameManager 用 selected level 启动
- `project.godot` 的 `run/main_scene` 改为 `LevelSelect.tscn`

## 5. Main.tscn / Main.gd 改动

- `Main.gd._ready()` 调用 `GameManager.start_game(GameManager.level_manager.current_level)`
- 胜利弹窗加"下一关"按钮 (如果 `level_manager.advance()` 成功)
- "下一关" → 切换回 `LevelSelect.tscn` 或直接 `start_game(next_idx)`
- 失败弹窗加"重试"按钮 → `start_game(current_level)` 重置当前关

## 6. 关卡 JSON 布局

`data/levels/coast.json` — 移动现有 coast.json
`data/levels/jungle.json` — 12×12, 植物覆盖 ~40%, 少量水+熔岩, 矿石稀少
`data/levels/mountain.json` — 14×14, 多岩石+矿石脉, 水/熔岩在裂缝中, 植物稀少
`data/levels/volcano.json` — 16×16, 大量熔岩+岩石, 少量水, 几乎无植物

每关 JSON 格式:
```json
{
    "name": "海岸·启蒙",
    "size": [10, 10],
    "target": 100,
    "elements": [
        {"coord": [1, 2], "element": "WATER"},
        ...
    ]
}
```

## 7. 自检

新增测试:
1. `_test_level_manager` — LevelManager 初始 unlocked=0, advance() 后 unlocked=1, is_unlocked 正确
2. `_test_level_load` — 加载不同关卡 JSON, grid 尺寸和 target 正确

## 8. 不在本子项目

- 新元素 (孢子/冰晶/黑曜)
- 新状态 (燃烧/带电/雪/祝福)
- 新规则牌
- 存盘文件
- 天灾事件