extends Control

const TextsScript = preload("res://src/ui/Texts.gd")
var texts = TextsScript.new()

# T1.4 存档入口: 选档 / 新游戏 / 调整存档

var GameManager: Node
var manage_panel: PanelContainer = null

func _ready() -> void:
	GameManager = get_node("/root/GameManager")
	_build_ui()

func _build_ui() -> void:
	var vbox: VBoxContainer = get_node_or_null("Layout")
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.add_theme_constant_override("separation", 12)
		add_child(vbox)

	var title = Label.new()
	title.text = texts.t("app_title")
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = texts.t("choose_slot_hint")
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	for i in range(SaveManager.SLOT_COUNT):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(560, 56)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(func(): _on_slot(i))
		vbox.add_child(btn)
		_update_slot_button(btn, i)

	var new_btn = Button.new()
	new_btn.text = texts.t("new_game")
	new_btn.custom_minimum_size = Vector2(560, 48)
	new_btn.add_theme_font_size_override("font_size", 16)
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var manage_btn = Button.new()
	manage_btn.text = texts.t("manage_slots")
	manage_btn.custom_minimum_size = Vector2(560, 48)
	manage_btn.add_theme_font_size_override("font_size", 16)
	manage_btn.pressed.connect(_on_manage)
	vbox.add_child(manage_btn)

func _update_slot_button(btn: Button, i: int) -> void:
	var sm = GameManager.save_manager
	if sm.has_slot(i):
		# T1.4: 显示名称 + 最后存档时间(精确到秒)
		btn.text = texts.t("slot_filled", [i + 1, sm.slot_name(i), sm.slot_time_text(i)])
		btn.disabled = false
	else:
		btn.text = texts.t("slot_empty", [i + 1])
		btn.disabled = false

func _on_slot(i: int) -> void:
	if not GameManager.save_manager.has_slot(i):
		return
	if GameManager.load_game(i):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

# ---------- 调整存档: 重命名 / 删除 ----------
func _on_manage() -> void:
	if manage_panel != null and is_instance_valid(manage_panel):
		manage_panel.queue_free()
	manage_panel = PanelContainer.new()
	manage_panel.offset_left = 720
	manage_panel.offset_top = 120
	manage_panel.offset_right = 1380
	manage_panel.offset_bottom = 880
	add_child(manage_panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	manage_panel.add_child(vbox)
	var title = Label.new()
	title.text = texts.t("manage_title")
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	for i in range(SaveManager.SLOT_COUNT):
		_build_manage_row(vbox, i)
	var close = Button.new()
	close.text = texts.t("close")
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func():
		if manage_panel != null and is_instance_valid(manage_panel):
			manage_panel.queue_free()
		manage_panel = null)
	vbox.add_child(close)

func _build_manage_row(vbox: VBoxContainer, i: int) -> void:
	var sm = GameManager.save_manager
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lab = Label.new()
	lab.custom_minimum_size = Vector2(48, 32)
	lab.text = texts.t("slot_label", [i + 1])
	row.add_child(lab)
	var edit = LineEdit.new()
	edit.custom_minimum_size = Vector2(300, 32)
	edit.placeholder_text = texts.t("empty_placeholder")
	if sm.has_slot(i):
		edit.text = sm.slot_name(i)
	row.add_child(edit)
	var ren = Button.new()
	ren.text = texts.t("rename")
	ren.disabled = not sm.has_slot(i)
	ren.pressed.connect(func():
		GameManager.save_manager.rename_slot(i, edit.text.strip_edges())
		_rebuild_manage())
	row.add_child(ren)
	var del = Button.new()
	del.text = texts.t("delete")
	del.disabled = not sm.has_slot(i)
	del.pressed.connect(func(): _confirm_delete(i))
	row.add_child(del)
	var tlab = Label.new()
	tlab.text = sm.slot_time_text(i)
	tlab.add_theme_font_size_override("font_size", 11)
	row.add_child(tlab)
	vbox.add_child(row)

func _confirm_delete(i: int) -> void:
	var dlg = AcceptDialog.new()
	dlg.dialog_text = texts.t("confirm_delete", [i + 1, GameManager.save_manager.slot_name(i)])
	dlg.confirmed.connect(func():
		GameManager.save_manager.delete_slot(i)
		_rebuild_manage())
	add_child(dlg)
	dlg.popup_centered()

func _rebuild_manage() -> void:
	if manage_panel != null and is_instance_valid(manage_panel):
		manage_panel.queue_free()
	manage_panel = null
	_on_manage()
