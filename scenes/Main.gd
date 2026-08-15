extends Node2D

var GameManager: Node
var grid_renderer: Node2D
var chain_counter: Label
var total_counter: Label
var energy_label: Label
var status_label: Label
var hand_count_label: Label
var hand_container: HBoxContainer
var execute_button: Button
var speed_button: Button
var skip_button: Button
var help_button: Button
var help_panel: TextureRect
var gameover_panel: TextureRect
var gameover_label: Label
var next_button: Button
var retry_button: Button
var menu_button: Button
var save_button: Button
var save_dialog: PanelContainer = null
var save_name_edit: LineEdit = null
var card_views: Array = []
var sound_manager: Node = null
var effect_layer: Node2D = null
var _sound_chain: int = 0
var _effect_level: int = 2  # T3.4: 2=普通全量, 1=4x降级, 0=跳过关闭

func _ready() -> void:
	GameManager = get_node("/root/GameManager")
	sound_manager = preload("res://src/ui/SoundManager.gd").new()
	sound_manager.name = "SoundManager"
	add_child(sound_manager)
	effect_layer = preload("res://src/ui/EffectLayer.gd").new()
	effect_layer.name = "EffectLayer"
	add_child(effect_layer)
	grid_renderer = $GridRenderer
	chain_counter = $ChainCounter
	total_counter = $TotalCounter
	energy_label = $EnergyLabel
	status_label = $StatusLabel
	hand_count_label = $HandCountLabel
	hand_container = $HandContainer
	execute_button = $ExecuteButton
	speed_button = $SpeedButton
	skip_button = $SkipButton
	help_button = $HelpButton
	help_panel = $HelpPanel
	gameover_panel = $GameOverPanel
	gameover_label = $GameOverPanel/GameOverLabel
	next_button = $GameOverPanel/NextButton
	retry_button = $GameOverPanel/RetryButton
	next_button.pressed.connect(_on_next_level)
	retry_button.pressed.connect(_on_retry)
	menu_button = $MenuButton
	menu_button.pressed.connect(_on_menu)
	save_button = $SaveButton
	save_button.pressed.connect(_on_save_clicked)
	next_button.visible = false
	retry_button.visible = false
	execute_button.pressed.connect(_on_execute)
	speed_button.pressed.connect(_on_speed)
	skip_button.pressed.connect(_on_skip)
	help_button.pressed.connect(func(): help_panel.visible = not help_panel.visible)
	GameManager.state_changed.connect(_refresh)
	GameManager.reaction_applied.connect(_on_reaction)
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	GameManager.flash_cell.connect(grid_renderer.on_flash)
	grid_renderer.cell_clicked.connect(_on_cell_clicked)
	grid_renderer.GameManager = GameManager
	GameManager.ensure_game_started()  # T1.4: 新游戏开局 / 读档后不重开
	_refresh()

func _refresh() -> void:
	if GameManager.grid == null:
		return
	grid_renderer.set_grid(GameManager.grid)
	total_counter.text = "总和: %d / %d" % [GameManager.chain_total, GameManager.target]
	energy_label.text = GameManager.energy.text()
	status_label.text = "T%d  %s  死寂%d/%d" % [GameManager.turn, _phase_name(GameManager.phase), GameManager.dead_turns, GameManager.DEAD_TURNS]
	hand_count_label.text = "手牌: %d/%d" % [GameManager.hand.hand_size(), GameManager.hand.hand_capacity()]
	for v in card_views:
		v.queue_free()
	card_views.clear()
	for i in range(GameManager.hand.hand_size()):
		var c = GameManager.hand.hand[i]
		var v = Button.new()
		v.set_script(load("res://src/ui/RuleCardView.gd"))
		v.setup(c, i)
		v.custom_minimum_size = Vector2(130, 80)  # T1.2: 8 张上限 × 130px ≤ 1100px 容器
		v.selected.connect(_on_card_selected)
		hand_container.add_child(v)
		card_views.append(v)
	execute_button.disabled = (GameManager.phase != 1) or GameManager.pillars.is_empty()
	# T1.3: 演化阶段显示加速/跳过按钮
	speed_button.visible = (GameManager.phase == 2)
	skip_button.visible = (GameManager.phase == 2)
	# T1.4: 演化中/结算后禁止存档, 布局阶段可存档
	save_button.disabled = (GameManager.phase == 2) or GameManager.game_ended

func _phase_name(p: int) -> String:
	match p:
		0: return "观察"
		1: return "布局"
		2: return "演化"
		_: return "??"

func _on_card_selected(idx: int) -> void:
	grid_renderer.select_card(idx)

func _on_cell_clicked(coord: Vector2i) -> void:
	if grid_renderer.selected_card_idx < 0:
		return
	if GameManager.play_card(grid_renderer.selected_card_idx, coord):
		grid_renderer.select_card(-1)

func _on_execute() -> void:
	grid_renderer.select_card(-1)  # T2.2: 演化后不得残留选中, 防止误点网格误打旧索引手牌
	_sound_chain = GameManager.chain_total  # T3.3: 本次演化的音高从当前连锁数起算
	_effect_level = 2
	GameManager.execute()

func _on_speed() -> void:
	grid_renderer.select_card(-1)  # T2.2: 同执行按钮
	_sound_chain = GameManager.chain_total
	_effect_level = 1
	GameManager.execute(4.0)  # T1.3: 4x 加速

func _on_skip() -> void:
	grid_renderer.select_card(-1)  # T2.2: 同执行按钮
	_sound_chain = GameManager.chain_total
	_effect_level = 0
	GameManager.execute(0.0)  # T1.3: 跳过动画, 同步结算

func _on_reaction(_r) -> void:
	_sound_chain += 1
	if sound_manager != null:
		sound_manager.play_chain(_sound_chain)
	if effect_layer != null and _effect_level > 0:
		# 4x 降级为每 3 次反应一个爆点; 跳过档完全关闭
		if _effect_level == 2 or _sound_chain % 3 == 0:
			for c in _r.affected:
				effect_layer.reaction_burst(grid_renderer.cell_center(c))
		if _sound_chain in [10, 50, 100, 500, 1000]:
			effect_layer.milestone(_sound_chain)
	grid_renderer.queue_redraw()
	chain_counter.set_chain(_sound_chain)

func _on_game_over(won: bool, msg: String) -> void:
	if won:
		return  # 胜利由 _on_level_complete 处理
	gameover_label.text = msg
	gameover_label.add_theme_color_override("font_color", Color.RED)
	gameover_panel.visible = true
	retry_button.visible = true
	retry_button.disabled = false
	execute_button.disabled = true

func _on_level_complete(_idx: int) -> void:
	gameover_label.text = "胜利! 达成 %d 连锁" % GameManager.chain_total
	gameover_label.add_theme_color_override("font_color", Color.GREEN)
	gameover_panel.visible = true
	if GameManager.level_manager.advance():
		GameManager.persist_unlock()  # T1.4: 通关解锁立即持久化(meta 区, 删档不丢)
		next_button.visible = true
		next_button.disabled = false
	retry_button.visible = true
	retry_button.disabled = false
	execute_button.disabled = true

func _on_next_level() -> void:
	GameManager.start_game(GameManager.level_manager.current_level)
	gameover_panel.visible = false
	next_button.visible = false
	retry_button.visible = false
	_refresh()

func _on_retry() -> void:
	GameManager.start_game(GameManager.level_manager.current_level)
	gameover_panel.visible = false
	next_button.visible = false
	retry_button.visible = false
	_refresh()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

# ---------- T1.4 存档弹窗 ----------
func _on_save_clicked() -> void:
	if save_dialog != null and is_instance_valid(save_dialog):
		save_dialog.queue_free()
	save_dialog = PanelContainer.new()
	save_dialog.offset_left = 950
	save_dialog.offset_top = 250
	save_dialog.offset_right = 1450
	save_dialog.offset_bottom = 660
	add_child(save_dialog)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	save_dialog.add_child(vbox)
	var title = Label.new()
	title.text = "存档: 命名 + 选槽"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	save_name_edit = LineEdit.new()
	save_name_edit.custom_minimum_size = Vector2(0, 34)
	save_name_edit.placeholder_text = "存档名(留空则用默认名)"
	save_name_edit.text = "关卡%d-T%d" % [GameManager.level_manager.current_level + 1, GameManager.turn]
	vbox.add_child(save_name_edit)
	var sm = GameManager.save_manager
	for i in range(SaveManager.SLOT_COUNT):
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 14)
		if sm.has_slot(i):
			b.text = "槽%d: %s — %s" % [i + 1, sm.slot_name(i), sm.slot_time_text(i)]
		else:
			b.text = "槽%d: (空槽位)" % (i + 1)
		b.pressed.connect(func(): _do_save_to(i))
		vbox.add_child(b)
	var cancel = Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(func():
		if save_dialog != null and is_instance_valid(save_dialog):
			save_dialog.queue_free()
		save_dialog = null)
	vbox.add_child(cancel)

func _do_save_to(i: int) -> void:
	var nm = save_name_edit.text.strip_edges() if save_name_edit != null else ""
	if nm == "":
		nm = "关卡%d-T%d" % [GameManager.level_manager.current_level + 1, GameManager.turn]
	var sm = GameManager.save_manager
	if sm.should_confirm_overwrite(i):
		# T1.4: 覆盖非来源槽 → 确认框(显示槽名与最后存档时间, 精确到秒)
		var dlg = AcceptDialog.new()
		dlg.dialog_text = "将覆盖 槽%d「%s」\n最后存档: %s\n确定?" % [i + 1, sm.slot_name(i), sm.slot_time_text(i)]
		dlg.confirmed.connect(func():
			GameManager.save_game(i, nm)
			if save_dialog != null and is_instance_valid(save_dialog):
				save_dialog.queue_free()
			save_dialog = null)
		add_child(dlg)
		dlg.popup_centered()
	else:
		GameManager.save_game(i, nm)
		if save_dialog != null and is_instance_valid(save_dialog):
			save_dialog.queue_free()
		save_dialog = null