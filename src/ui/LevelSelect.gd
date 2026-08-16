extends Control

const TextsScript = preload("res://src/ui/Texts.gd")
var texts = TextsScript.new()

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
	var container: VBoxContainer = get_node_or_null("Layout")
	if container == null:
		container = VBoxContainer.new()
		container.set_anchors_preset(Control.PRESET_CENTER)
		container.add_theme_constant_override("separation", 12)
		add_child(container)

	var title = Label.new()
	title.text = texts.t("app_title")
	title.add_theme_font_size_override("font", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(title)

	for i in range(lm.level_count()):
		var lvl = lm.get_level(i)
		var btn = Button.new()
		btn.text = texts.t("level_format", [lvl.name, lvl.size[0], lvl.size[1], lvl.target])
		btn.custom_minimum_size = Vector2(360, 50)
		btn.add_theme_font_size_override("font", 16)
		if not lm.is_unlocked(i):
			btn.text += texts.t("locked_suffix")
			btn.disabled = true
		btn.pressed.connect(func(): _on_level_selected(i))
		container.add_child(btn)
		buttons.append(btn)
		var rule_hint := Label.new()
		match i:
			1: rule_hint.text = texts.t("rule_level_2")
			2: rule_hint.text = texts.t("rule_level_3")
			3: rule_hint.text = texts.t("rule_level_4")
			4: rule_hint.text = texts.t("rule_level_5")
			_: rule_hint.text = texts.t("rule_level_1")
		rule_hint.add_theme_font_size_override("font_size", 12)
		rule_hint.modulate = Color(0.85, 0.9, 0.85)
		container.add_child(rule_hint)
	# T3.8: 种子输入与每日挑战
	seed_edit = LineEdit.new()
	seed_edit.name = "SeedEdit"
	seed_edit.placeholder_text = texts.t("seed_placeholder")
	seed_edit.custom_minimum_size = Vector2(360, 34)
	container.add_child(seed_edit)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	container.add_child(seed_row)
	lock_seed_button = Button.new()
	lock_seed_button.name = "LockSeedButton"
	lock_seed_button.text = texts.t("lock_seed")
	lock_seed_button.pressed.connect(_on_lock_seed)
	seed_row.add_child(lock_seed_button)
	clear_seed_button = Button.new()
	clear_seed_button.name = "ClearSeedButton"
	clear_seed_button.text = texts.t("clear_seed")
	clear_seed_button.pressed.connect(func():
		seed_override = -1
		seed_edit.text = "")
	seed_row.add_child(clear_seed_button)
	daily_button = Button.new()
	daily_button.name = "DailyButton"
	daily_button.text = texts.t("daily_challenge")
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