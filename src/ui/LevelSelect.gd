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