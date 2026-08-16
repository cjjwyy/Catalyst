extends Control

var GameManager: Node
var buttons: Array = []
var seed_edit: LineEdit
var seed_override: int = -1
var lock_seed_button: Button
var clear_seed_button: Button
var daily_button: Button

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
	# T3.8: 种子输入与每日挑战
	seed_edit = LineEdit.new()
	seed_edit.name = "SeedEdit"
	seed_edit.placeholder_text = "种子(留空=随机)"
	seed_edit.custom_minimum_size = Vector2(360, 34)
	container.add_child(seed_edit)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	container.add_child(seed_row)
	lock_seed_button = Button.new()
	lock_seed_button.name = "LockSeedButton"
	lock_seed_button.text = "锁定种子"
	lock_seed_button.pressed.connect(_on_lock_seed)
	seed_row.add_child(lock_seed_button)
	clear_seed_button = Button.new()
	clear_seed_button.name = "ClearSeedButton"
	clear_seed_button.text = "清除种子"
	clear_seed_button.pressed.connect(func():
		seed_override = -1
		seed_edit.text = "")
	seed_row.add_child(clear_seed_button)
	daily_button = Button.new()
	daily_button.name = "DailyButton"
	daily_button.text = "今日挑战(第1关)"
	daily_button.pressed.connect(func():
		GameManager.start_daily_challenge(0)
		get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	seed_row.add_child(daily_button)

func _on_level_selected(idx: int) -> void:
	if seed_override >= 0:
		GameManager.start_game_with_seed(idx, seed_override)  # T3.8: 回放种子
	else:
		GameManager.level_manager.select(idx)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_lock_seed() -> void:
	var text := seed_edit.text.strip_edges()
	if text == "":
		return
	if text.is_valid_int():
		seed_override = int(text)
	else:
		seed_override = hash(text)