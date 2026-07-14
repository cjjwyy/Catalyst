# LevelManager + 多关卡系统 实现计划

> **For agentic workers:** Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 加 LevelManager + 关卡选择界面 + 4 个关卡 JSON，让玩家逐级解锁 4 个尺寸/目标/布局各异的关卡。

**Architecture:** LevelManager 是纯 RefCounted 数据类，GameManager 持有它并从它读 size/target/path。新增 LevelSelect 场景作为启动入口。不加新元素/新牌。

**Tech Stack:** Godot 4.x GDScript

## 全局约束
- 不加新元素、新状态、新规则牌
- 不做存盘文件，重启从第 1 关开始
- 所有关卡共用 `data/rules.json` 的 7 张牌
- `project.godot` 的 `run/main_scene` 改为 `LevelSelect.tscn`
- 现有 `data/coast.json` 移到 `data/levels/coast.json`

---

### Task 1: LevelManager.gd — 关卡管理类

**Files:**
- Create: `src/world/LevelManager.gd`
- Test: `tests/run_tests.gd` (加 `_test_level_manager`)

**Interfaces:**
- Produces: `LevelManager.new()`, `.current_level`, `.unlocked`, `.get_current() -> Dictionary`, `.get_level(idx) -> Dictionary`, `.is_unlocked(idx) -> bool`, `.select(idx) -> bool`, `.advance() -> bool`, `.level_count() -> int`

- [ ] **Step 1: 创建 LevelManager.gd**

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
var unlocked: int = 0

func get_current() -> Dictionary:
	return LEVELS[current_level]

func get_level(idx: int) -> Dictionary:
	return LEVELS[idx]

func is_unlocked(idx: int) -> bool:
	return idx <= unlocked

func select(idx: int) -> bool:
	if not is_unlocked(idx):
		return false
	current_level = idx
	return true

func advance() -> bool:
	if current_level + 1 < LEVELS.size():
		unlocked = max(unlocked, current_level + 1)
		current_level += 1
		return true
	return false

func level_count() -> int:
	return LEVELS.size()
```

- [ ] **Step 2: 加测试**

在 `run_all()` 加 `ok = ok and _test_level_manager()`，加函数:

```gdscript
static func _test_level_manager() -> bool:
	var LM = load("res://src/world/LevelManager.gd")
	var lm = LM.new()
	assert(lm.level_count() == 4, "should have 4 levels")
	assert(lm.is_unlocked(0) == true, "level 0 unlocked")
	assert(lm.is_unlocked(1) == false, "level 1 locked")
	assert(lm.select(1) == false, "cannot select locked level")
	assert(lm.select(0) == true, "can select level 0")
	assert(lm.get_current().target == 100, "coast target 100")
	lm.current_level = 0
	assert(lm.advance() == true, "advance to level 1")
	assert(lm.is_unlocked(1) == true, "level 1 now unlocked")
	assert(lm.current_level == 1, "current is now 1")
	assert(lm.get_current().target == 300, "jungle target 300")
	print("test_level_manager OK")
	return true
```

- [ ] **Step 3: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 16/16 ALL PASS

- [ ] **Step 4: Commit**

```bash
git add src/world/LevelManager.gd tests/run_tests.gd
git commit -m "feat: add LevelManager class with 4 levels + test"
```

---

### Task 2: 4 个关卡 JSON 文件

**Files:**
- Create: `data/levels/coast.json` (从 data/coast.json 移动)
- Create: `data/levels/jungle.json`
- Create: `data/levels/mountain.json`
- Create: `data/levels/volcano.json`

- [ ] **Step 1: 移动 coast.json 到 data/levels/**

把 `data/coast.json` 的内容复制到 `data/levels/coast.json`，保持不变。

- [ ] **Step 2: 创建 jungle.json (12×12, target 300)**

丛林：植物覆盖 ~40%，少量水+熔岩，矿石稀少。

```json
{
  "name": "丛林·生长",
  "size": [12, 12],
  "target": 300,
  "elements": [
    {"coord": [1, 1], "element": "WATER"},
    {"coord": [2, 1], "element": "WATER"},
    {"coord": [3, 1], "element": "LAVA"},
    {"coord": [8, 2], "element": "WATER"},
    {"coord": [9, 2], "element": "WATER"},
    {"coord": [9, 3], "element": "LAVA"},
    {"coord": [2, 8], "element": "WATER"},
    {"coord": [2, 9], "element": "LAVA"},

    {"coord": [0, 3], "element": "PLANT"},
    {"coord": [1, 3], "element": "PLANT"},
    {"coord": [2, 3], "element": "PLANT"},
    {"coord": [0, 4], "element": "PLANT"},
    {"coord": [1, 4], "element": "PLANT"},
    {"coord": [2, 4], "element": "PLANT"},
    {"coord": [0, 5], "element": "PLANT"},
    {"coord": [1, 5], "element": "PLANT"},

    {"coord": [4, 6], "element": "PLANT"},
    {"coord": [5, 6], "element": "PLANT"},
    {"coord": [6, 6], "element": "PLANT"},
    {"coord": [7, 6], "element": "PLANT"},
    {"coord": [4, 7], "element": "PLANT"},
    {"coord": [5, 7], "element": "PLANT"},
    {"coord": [6, 7], "element": "PLANT"},
    {"coord": [7, 7], "element": "PLANT"},
    {"coord": [5, 8], "element": "PLANT"},
    {"coord": [6, 8], "element": "PLANT"},

    {"coord": [9, 8], "element": "PLANT"},
    {"coord": [10, 8], "element": "PLANT"},
    {"coord": [9, 9], "element": "PLANT"},
    {"coord": [10, 9], "element": "PLANT"},
    {"coord": [11, 9], "element": "PLANT"},

    {"coord": [4, 0], "element": "PLANT"},
    {"coord": [5, 0], "element": "PLANT"},
    {"coord": [6, 0], "element": "PLANT"},

    {"coord": [8, 10], "element": "PLANT"},
    {"coord": [9, 10], "element": "PLANT"},
    {"coord": [10, 10], "element": "PLANT"},

    {"coord": [0, 0], "element": "ORE"},
    {"coord": [11, 11], "element": "ORE"},
    {"coord": [3, 10], "element": "STONE"},
    {"coord": [8, 0], "element": "STONE"}
  ]
}
```

- [ ] **Step 3: 创建 mountain.json (14×14, target 700)**

高山：多岩石+矿石脉，水/熔岩在裂缝中，植物稀少。

```json
{
  "name": "高山·精炼",
  "size": [14, 14],
  "target": 700,
  "elements": [
    {"coord": [1, 1], "element": "STONE"},
    {"coord": [2, 1], "element": "STONE"},
    {"coord": [3, 1], "element": "STONE"},
    {"coord": [10, 1], "element": "STONE"},
    {"coord": [11, 1], "element": "STONE"},
    {"coord": [12, 1], "element": "STONE"},
    {"coord": [1, 12], "element": "STONE"},
    {"coord": [2, 12], "element": "STONE"},
    {"coord": [10, 12], "element": "STONE"},
    {"coord": [11, 12], "element": "STONE"},
    {"coord": [12, 12], "element": "STONE"},
    {"coord": [6, 6], "element": "STONE"},
    {"coord": [7, 6], "element": "STONE"},
    {"coord": [6, 7], "element": "STONE"},
    {"coord": [7, 7], "element": "STONE"},

    {"coord": [0, 1], "element": "ORE"},
    {"coord": [13, 1], "element": "ORE"},
    {"coord": [0, 12], "element": "ORE"},
    {"coord": [13, 12], "element": "ORE"},
    {"coord": [5, 5], "element": "ORE"},
    {"coord": [8, 5], "element": "ORE"},
    {"coord": [5, 8], "element": "ORE"},
    {"coord": [8, 8], "element": "ORE"},

    {"coord": [4, 3], "element": "WATER"},
    {"coord": [4, 4], "element": "WATER"},
    {"coord": [4, 5], "element": "LAVA"},
    {"coord": [9, 3], "element": "WATER"},
    {"coord": [9, 4], "element": "WATER"},
    {"coord": [9, 5], "element": "LAVA"},
    {"coord": [6, 10], "element": "WATER"},
    {"coord": [7, 10], "element": "WATER"},
    {"coord": [7, 11], "element": "LAVA"},

    {"coord": [3, 7], "element": "PLANT"},
    {"coord": [10, 7], "element": "PLANT"},
    {"coord": [6, 3], "element": "PLANT"},
    {"coord": [7, 3], "element": "PLANT"}
  ]
}
```

- [ ] **Step 4: 创建 volcano.json (16×16, target 1500)**

火山口：大量熔岩+岩石，少量水陷阱，几乎无植物。

```json
{
  "name": "火山口·终局",
  "size": [16, 16],
  "target": 1500,
  "elements": [
    {"coord": [2, 2], "element": "LAVA"},
    {"coord": [3, 2], "element": "LAVA"},
    {"coord": [2, 3], "element": "LAVA"},
    {"coord": [3, 3], "element": "LAVA"},

    {"coord": [12, 2], "element": "LAVA"},
    {"coord": [13, 2], "element": "LAVA"},
    {"coord": [12, 3], "element": "LAVA"},
    {"coord": [13, 3], "element": "LAVA"},

    {"coord": [2, 12], "element": "LAVA"},
    {"coord": [3, 12], "element": "LAVA"},
    {"coord": [2, 13], "element": "LAVA"},
    {"coord": [3, 13], "element": "LAVA"},

    {"coord": [12, 12], "element": "LAVA"},
    {"coord": [13, 12], "element": "LAVA"},
    {"coord": [12, 13], "element": "LAVA"},
    {"coord": [13, 13], "element": "LAVA"},

    {"coord": [7, 7], "element": "LAVA"},
    {"coord": [8, 7], "element": "LAVA"},
    {"coord": [7, 8], "element": "LAVA"},
    {"coord": [8, 8], "element": "LAVA"},

    {"coord": [0, 0], "element": "STONE"},
    {"coord": [1, 0], "element": "STONE"},
    {"coord": [0, 1], "element": "STONE"},
    {"coord": [15, 15], "element": "STONE"},
    {"coord": [14, 15], "element": "STONE"},
    {"coord": [15, 14], "element": "STONE"},
    {"coord": [0, 15], "element": "STONE"},
    {"coord": [15, 0], "element": "STONE"},
    {"coord": [5, 5], "element": "STONE"},
    {"coord": [10, 5], "element": "STONE"},
    {"coord": [5, 10], "element": "STONE"},
    {"coord": [10, 10], "element": "STONE"},

    {"coord": [6, 3], "element": "WATER"},
    {"coord": [9, 3], "element": "WATER"},
    {"coord": [6, 12], "element": "WATER"},
    {"coord": [9, 12], "element": "WATER"},

    {"coord": [5, 8], "element": "PLANT"},
    {"coord": [10, 8], "element": "PLANT"},

    {"coord": [7, 5], "element": "ORE"},
    {"coord": [8, 10], "element": "ORE"}
  ]
}
```

- [ ] **Step 5: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 16/16 ALL PASS

- [ ] **Step 6: Commit**

```bash
git add data/levels/
git commit -m "feat: add 4 level JSONs (coast/jungle/mountain/volcano)"
```

---

### Task 3: GameManager 集成 LevelManager

**Files:**
- Modify: `src/main/GameManager.gd`

**Interfaces:**
- Consumes: `LevelManager` (Task 1)
- Produces: `GameManager.level_manager`, `GameManager.start_game(level_idx)`, `GameManager.target` (动态), `GameManager.level_complete` 信号

- [ ] **Step 1: 加 level_manager 属性和 level_complete 信号**

在 `var game_ended: bool = false` 后加:
```gdscript
var level_manager: LevelManager = LevelManager.new()
var target: int = 100
```

在信号区加:
```gdscript
signal level_complete(level_idx: int)
```

- [ ] **Step 2: 改 start_game 接受 level_idx**

把 `const TARGET = 100` 删除，改为动态 `target`。

`start_game()` 改为:
```gdscript
func start_game(level_idx: int = -1) -> void:
	if level_idx >= 0:
		level_manager.current_level = level_idx
	var lvl = level_manager.get_current()
	target = int(lvl.target)
	all_card_defs = _load_rules()
	grid = _load_level(lvl.path)
	hand = HandManager.new()
	hand.fill_draw_pile(all_card_defs)
	hand.refill_to(5)
	energy = EnergySystem.new(3)
	chain_total = 0
	dead_turns = 0
	game_ended = false
	phase = Phase.LAYOUT
	_reroll_wind()
	state_changed.emit()
```

- [ ] **Step 3: 改 execute() 胜利逻辑**

找到 `if chain_total >= TARGET:`，改为:
```gdscript
if chain_total >= target:
	game_ended = true
	level_complete.emit(level_manager.current_level)
	return
```

把所有其他 `TARGET` 引用改为 `target` (在 `_refresh` 等 UI 引用处也要改，但 Main.gd 引用 `GameManager.TARGET` 的地方在 Task 5 里改)。

- [ ] **Step 4: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 16/16 ALL PASS

- [ ] **Step 5: Commit**

```bash
git add src/main/GameManager.gd
git commit -m "feat: integrate LevelManager into GameManager"
```

---

### Task 4: 关卡选择界面

**Files:**
- Create: `scenes/LevelSelect.tscn`
- Create: `src/ui/LevelSelect.gd`

**Interfaces:**
- Consumes: `GameManager.level_manager`
- Produces: 切换到 `Main.tscn` 场景

- [ ] **Step 1: 创建 LevelSelect.gd**

```gdscript
extends Control

var GameManager: Node
var buttons: Array = []

func _ready() -> void:
	GameManager = get_node("/root/GameManager")
	var lm = GameManager.level_manager
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.add_theme_constant_override("separation", 12)
	add_child(container)
	
	var title = Label.new()
	title.text = "催化剂 Catalyst"
	title.add_theme_font_size_override("font", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)
	
	for i in range(lm.level_count()):
		var lvl = lm.get_level(i)
		var btn = Button.new()
		btn.text = "%s  %dx%d  目标%d" % [lvl.name, lvl.size[0], lvl.size[1], lvl.target]
		btn.custom_minimum_size = Vector2(360, 50)
		btn.add_theme_font_size_override("font", 16)
		if not lm.is_unlocked(i):
			btn.text += "  [锁定]"
			btn.disabled = true
		btn.pressed.connect(func(): _on_level_selected(i))
		container.add_child(btn)
		buttons.append(btn)

func _on_level_selected(idx: int) -> void:
	GameManager.level_manager.select(idx)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
```

- [ ] **Step 2: 创建 LevelSelect.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/LevelSelect.gd" id="1_ls"]

[node name="LevelSelect" type="Control"]
offset_right = 1280.0
offset_bottom = 850.0
script = ExtResource("1_ls")
```

- [ ] **Step 3: 改 project.godot 主场景**

把 `run/main_scene` 改为:
```
run/main_scene="res://scenes/LevelSelect.tscn"
```

- [ ] **Step 4: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 16/16 ALL PASS

- [ ] **Step 5: Commit**

```bash
git add src/ui/LevelSelect.gd scenes/LevelSelect.tscn project.godot
git commit -m "feat: add level selection screen"
```

---

### Task 5: Main.gd/Main.tscn — 关卡完成/重试按钮

**Files:**
- Modify: `scenes/Main.gd`
- Modify: `scenes/Main.tscn`

- [ ] **Step 1: Main.gd — 连接 level_complete 信号 + 加按钮回调**

在 `_ready()` 中加:
```gdscript
GameManager.level_complete.connect(_on_level_complete)
```

改 `_refresh()` 中 `GameManager.TARGET` 为 `GameManager.target`。

加方法:
```gdscript
var next_button: Button
var retry_button: Button

func _on_level_complete(_idx: int) -> void:
	gameover_label.text = "胜利! 达成 %d 连锁" % GameManager.chain_total
	gameover_label.add_theme_color_override("font_color", Color.GREEN)
	gameover_panel.visible = true
	if GameManager.level_manager.advance():
		next_button.visible = true
		next_button.disabled = false
	retry_button.visible = true
	retry_button.disabled = false
	execute_button.disabled = true

func _on_next_level() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_retry() -> void:
	GameManager.start_game(GameManager.level_manager.current_level)
	gameover_panel.visible = false
	get_node("/root/GameManager").state_changed.emit()
```

在 `_ready()` 中找 GameOverPanel 的子节点:
```gdscript
next_button = $GameOverPanel/NextButton
retry_button = $GameOverPanel/RetryButton
next_button.pressed.connect(_on_next_level)
retry_button.pressed.connect(_on_retry)
next_button.visible = false
retry_button.visible = false
```

同时改 `_on_game_over` 不再处理胜利（只处理失败）:
```gdscript
func _on_game_over(won: bool, msg: String) -> void:
	if won:
		return  # 胜利由 _on_level_complete 处理
	gameover_label.text = msg
	gameover_label.add_theme_color_override("font_color", Color.RED)
	gameover_panel.visible = true
	retry_button.visible = true
	retry_button.disabled = false
	execute_button.disabled = true
```

改 `_ready()` 中:
```gdscript
GameManager.start_game(GameManager.level_manager.current_level)
```

- [ ] **Step 2: Main.tscn — 在 GameOverPanel 加 NextButton + RetryButton**

在 GameOverPanel 节点下加两个子节点:
```
[node name="NextButton" type="Button" parent="GameOverPanel"]
visible = false
offset_left = 60.0
offset_top = 90.0
offset_right = 220.0
offset_bottom = 120.0
text = "下一关"

[node name="RetryButton" type="Button" parent="GameOverPanel"]
visible = false
offset_left = 360.0
offset_top = 90.0
offset_right = 520.0
offset_bottom = 120.0
text = "重试"
```

- [ ] **Step 3: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 16/16 ALL PASS

- [ ] **Step 4: Commit**

```bash
git add scenes/Main.gd scenes/Main.tscn
git commit -m "feat: level complete/retry buttons, wire LevelSelect as start"
```

---

### Task 6: 加 _test_level_load 测试

**Files:**
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 加测试调用**

在 `run_all()` 加 `ok = ok and _test_level_load()`，加函数:

```gdscript
static func _test_level_load() -> bool:
	var LM = load("res://src/world/LevelManager.gd")
	var lm = LM.new()
	# 测试每关 JSON 能加载且 size/target 正确
	for i in range(lm.level_count()):
		var lvl = lm.get_level(i)
		var f = FileAccess.open(lvl.path, FileAccess.READ)
		assert(f != null, "level %d JSON not found at %s" % [i, lvl.path])
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		assert(int(data.size[0]) == lvl.size[0], "level %d size mismatch" % i)
		assert(int(data.target) == lvl.target, "level %d target mismatch" % i)
	print("test_level_load OK (4 levels verified)")
	return true
```

- [ ] **Step 2: 运行自检**

Run: `& "D:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\code\Catalyst" --quit`
Expected: 17/17 ALL PASS

- [ ] **Step 3: Commit**

```bash
git add tests/run_tests.gd
git commit -m "test: add _test_level_load verifying 4 level JSONs"
```

---

### Task 7: 端到端手动验证

用 Godot F5:
1. 启动 → 显示关卡选择界面
2. 点击"海岸·启蒙" → 进入 10×10 游戏
3. 正常游玩到 100 连锁 → 弹"胜利" + "下一关" + "重试"按钮
4. 点"下一关" → 回到关卡选择，第 2 关解锁
5. 点"丛林·生长" → 进入 12×12 游戏
6. 点"重试" → 重置当前关
