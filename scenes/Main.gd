extends Node2D

const CARD_VIEW_SCENE = preload("res://scenes/RuleCardView.tscn")

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
var help_label: Label
var help_title_label: Label
var help_prev_button: Button
var help_next_button: Button
var _help_pages: Array = []
var _help_page: int = 0
var gameover_panel: TextureRect
var gameover_label: Label
var next_button: Button
var retry_button: Button
var menu_button: Button
var save_button: Button
var undo_button: Button
var preview_button: Button
var seed_button: Button
var onboarding_panel: PanelContainer = null
var onboarding_label: Label
var onboarding_next_button: Button
var onboarding_skip_button: Button
var _onboarding_step: int = 0
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
	help_label = $HelpPanel/HelpLabel
	help_label.position = Vector2(16, 40)
	help_label.size = Vector2(943, 560)
	help_title_label = Label.new()
	help_title_label.name = "HelpTitleLabel"
	help_title_label.position = Vector2(16, 8)
	help_title_label.size = Vector2(943, 28)
	help_title_label.add_theme_font_size_override("font_size", 18)
	help_panel.add_child(help_title_label)
	help_prev_button = Button.new()
	help_prev_button.name = "HelpPrevButton"
	help_prev_button.text = "上一页"
	help_prev_button.position = Vector2(16, 606)
	help_prev_button.size = Vector2(110, 30)
	help_prev_button.pressed.connect(_on_help_prev)
	help_panel.add_child(help_prev_button)
	help_next_button = Button.new()
	help_next_button.name = "HelpNextButton"
	help_next_button.text = "下一页"
	help_next_button.position = Vector2(830, 606)
	help_next_button.size = Vector2(110, 30)
	help_next_button.pressed.connect(_on_help_next)
	help_panel.add_child(help_next_button)
	_help_pages = _load_help_pages()
	_refresh_help_page()
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
	undo_button = Button.new()
	undo_button.name = "UndoButton"
	undo_button.text = "撤销上回合"
	undo_button.position = Vector2(1300, 813)
	undo_button.size = Vector2(160, 26)
	undo_button.focus_mode = Control.FOCUS_ALL
	undo_button.pressed.connect(_on_undo)
	add_child(undo_button)
	preview_button = Button.new()
	preview_button.name = "PreviewButton"
	preview_button.text = "预演(1能量)"
	preview_button.position = Vector2(1300, 781)
	preview_button.size = Vector2(160, 26)
	preview_button.focus_mode = Control.FOCUS_ALL
	preview_button.pressed.connect(_on_preview)
	add_child(preview_button)
	seed_button = Button.new()
	seed_button.name = "SeedButton"
	seed_button.position = Vector2(1300, 753)
	seed_button.size = Vector2(160, 26)
	seed_button.focus_mode = Control.FOCUS_ALL
	seed_button.pressed.connect(_on_copy_seed)
	add_child(seed_button)
	next_button.visible = false
	retry_button.visible = false
	execute_button.pressed.connect(_on_execute)
	speed_button.pressed.connect(_on_speed)
	skip_button.pressed.connect(_on_skip)
	help_button.pressed.connect(_on_help_toggle)
	GameManager.state_changed.connect(_refresh)
	GameManager.reaction_applied.connect(_on_reaction)
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	GameManager.flash_cell.connect(grid_renderer.on_flash)
	grid_renderer.cell_clicked.connect(_on_cell_clicked)
	grid_renderer.GameManager = GameManager
	GameManager.auto_retention = false  # T3.5: 真实游戏走手动保留; 测试可在执行前改回 true
	GameManager.ensure_game_started()  # T1.4: 新游戏开局 / 读档后不重开
	_refresh()
	_maybe_show_onboarding()  # T3.9: 首次进入引导

func _refresh() -> void:
	if GameManager.grid == null:
		return
	grid_renderer.set_grid(GameManager.grid)
	total_counter.text = "总和: %d / %d" % [GameManager.chain_total, GameManager.target]
	energy_label.text = GameManager.energy.text()
	var phase_hint := ""
	match GameManager.phase:
		1: phase_hint = "选牌落柱"
		2: phase_hint = "演化中"
		3: phase_hint = "点牌弃到3"
		_: phase_hint = "观察"
	status_label.text = "T%d %s %s" % [GameManager.turn, _phase_name(GameManager.phase), phase_hint]
	if GameManager.phase == GameManager.Phase.RETAIN:
		hand_count_label.text = "保留: 点击弃牌, 留%d张 (%d/%d)" % [GameManager.RETAIN_LIMIT, GameManager.hand.hand_size(), GameManager.hand.hand_capacity()]
	else:
		hand_count_label.text = "手牌: %d/%d" % [GameManager.hand.hand_size(), GameManager.hand.hand_capacity()]
	for v in card_views:
		v.queue_free()
	card_views.clear()
	for i in range(GameManager.hand.hand_size()):
		var c = GameManager.hand.hand[i]
		var v = CARD_VIEW_SCENE.instantiate()
		v.setup(c, i)
		v.custom_minimum_size = Vector2(130, 80)  # T1.2: 8 张上限 × 130px ≤ 1100px 容器
		v.selected.connect(_on_card_selected)
		hand_container.add_child(v)
		card_views.append(v)
	execute_button.disabled = (GameManager.phase != 1) or GameManager.pillars.is_empty()
	execute_button.tooltip_text = "先落柱才能执行" if GameManager.pillars.is_empty() else "执行本回合所有规则柱"
	# T1.3: 演化阶段显示加速/跳过按钮
	speed_button.visible = (GameManager.phase == 2)
	skip_button.visible = (GameManager.phase == 2)
	# T1.4: 演化中/结算后禁止存档, 布局阶段可存档
	save_button.disabled = (GameManager.phase == 2) or GameManager.game_ended
	undo_button.disabled = not GameManager.can_undo()
	preview_button.disabled = (GameManager.phase != 1) or GameManager.pillars.is_empty() or GameManager.energy.current < 1 or GameManager.game_ended
	seed_button.text = "复制种子 %s" % GameManager.rng.seed_hex()

func _onboarding_steps() -> Array:
	return [
		"① 看手牌: 每张卡左上角是名字, 彩色条代表类型(蓝=转化/绿=增殖/红=灭绝)。",
		"② 选牌落柱: 点击一张手牌, 再点击网格空格; 黄圈是柱子扫描范围, 右键可撤回。",
		"③ 执行演化: 放好柱子后点击「执行演化」, 元素会按规则连锁反应。",
		"④ 看懂结算: 每回合结束会抽3张牌、回满能量; 回合结束需点击弃牌保留3张。",
		"⑤ 随时求助: 右上角「?」打开6页帮助手册; 主菜单可返回; 存档在布局阶段进行。",
	]

func _maybe_show_onboarding() -> void:
	var force: bool = OS.get_environment("FORCE_ONBOARDING") == "1"
	if force or not GameManager.save_manager.is_onboarding_seen():
		_show_onboarding()

func _show_onboarding() -> void:
	if onboarding_panel != null and is_instance_valid(onboarding_panel):
		onboarding_panel.queue_free()
	onboarding_panel = PanelContainer.new()
	onboarding_panel.name = "OnboardingPanel"
	onboarding_panel.z_index = 100
	onboarding_panel.position = Vector2(360, 220)
	onboarding_panel.size = Vector2(780, 300)
	add_child(onboarding_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	onboarding_panel.add_child(box)
	var title := Label.new()
	title.name = "OnboardingTitle"
	title.text = "新手引导 (%d/5)" % (_onboarding_step + 1)
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	onboarding_label = Label.new()
	onboarding_label.name = "OnboardingLabel"
	onboarding_label.text = _onboarding_steps()[_onboarding_step]
	onboarding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	onboarding_label.custom_minimum_size = Vector2(720, 140)
	onboarding_label.add_theme_font_size_override("font_size", 16)
	box.add_child(onboarding_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	onboarding_next_button = Button.new()
	onboarding_next_button.name = "OnboardingNextButton"
	onboarding_next_button.text = "下一步"
	onboarding_next_button.custom_minimum_size = Vector2(180, 40)
	onboarding_next_button.pressed.connect(_on_onboarding_next)
	row.add_child(onboarding_next_button)
	onboarding_skip_button = Button.new()
	onboarding_skip_button.name = "OnboardingSkipButton"
	onboarding_skip_button.text = "跳过引导"
	onboarding_skip_button.custom_minimum_size = Vector2(180, 40)
	onboarding_skip_button.pressed.connect(_on_onboarding_skip)
	row.add_child(onboarding_skip_button)

func _on_onboarding_next() -> void:
	if _onboarding_step >= 4:
		_onboarding_finish()
		return
	_onboarding_step += 1
	_show_onboarding()

func _on_onboarding_skip() -> void:
	_onboarding_finish()

func _onboarding_finish() -> void:
	GameManager.save_manager.set_onboarding_seen(true)
	if onboarding_panel != null and is_instance_valid(onboarding_panel):
		onboarding_panel.queue_free()
	onboarding_panel = null

func _phase_name(p: int) -> String:
	match p:
		0: return "观察"
		1: return "布局"
		2: return "演化"
		3: return "保留"
		_: return "??"

func _on_help_toggle() -> void:
	help_panel.visible = not help_panel.visible
	if help_panel.visible:
		_help_page = 0
		_refresh_help_page()

func _on_help_prev() -> void:
	_help_page = max(_help_page - 1, 0)
	_refresh_help_page()

func _on_help_next() -> void:
	_help_page = min(_help_page + 1, _help_pages.size() - 1)
	_refresh_help_page()

func _load_help_pages() -> Array:
	var fallback := [
		{"title": "目标与回合流程", "summary": "累计连锁达标过关", "body": "· 目标: 累计连锁达到关卡目标。
· 回合: 布局→执行演化→世界结算→抽牌。
· 右键规则柱可以撤回;执行按钮无柱时不可用。", "example": "第1关目标100,先蒸汽化再扩散植物。"}
	]
	var f = FileAccess.open("res://data/help.json", FileAccess.READ)
	if f == null:
		return fallback
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_ARRAY or data.is_empty():
		return fallback
	return data

func _refresh_help_page() -> void:
	if _help_pages.is_empty():
		return
	var page: Dictionary = _help_pages[_help_page]
	help_title_label.text = "%d/%d  %s — %s" % [_help_page + 1, _help_pages.size(), page.get("title", ""), page.get("summary", "")]
	help_label.text = "%s

示例: %s" % [page.get("body", ""), page.get("example", "")]
	help_prev_button.disabled = _help_page <= 0
	help_next_button.disabled = _help_page >= _help_pages.size() - 1

func _on_card_selected(idx: int) -> void:
	if GameManager.phase == GameManager.Phase.RETAIN:
		GameManager.discard_for_retention(idx)  # T3.5: 保留阶段点击手牌即弃牌
		return
	grid_renderer.select_card(idx)

func _on_cell_clicked(coord: Vector2i) -> void:
	if grid_renderer.selected_card_idx < 0:
		return
	if GameManager.play_card(grid_renderer.selected_card_idx, coord):
		grid_renderer.clear_preview()
		grid_renderer.select_card(-1)

func _on_execute() -> void:
	grid_renderer.clear_preview()
	grid_renderer.select_card(-1)  # T2.2: 演化后不得残留选中, 防止误点网格误打旧索引手牌
	_sound_chain = GameManager.chain_total  # T3.3: 本次演化的音高从当前连锁数起算
	_effect_level = 2
	GameManager.execute()

func _on_speed() -> void:
	grid_renderer.clear_preview()
	grid_renderer.select_card(-1)  # T2.2: 同执行按钮
	_sound_chain = GameManager.chain_total
	_effect_level = 1
	GameManager.execute(4.0)  # T1.3: 4x 加速

func _on_undo() -> void:
	grid_renderer.clear_preview()
	if GameManager.undo_turn():
		grid_renderer.select_card(-1)

func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(GameManager.get_seed()))
	seed_button.text = "种子已复制"
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(seed_button):
		seed_button.text = "复制种子 %s" % GameManager.rng.seed_hex()

func _on_preview() -> void:
	var result: Dictionary = GameManager.preview_evolution()
	if result.is_empty():
		return
	grid_renderer.set_preview_cells(result.get("affected", []))
	status_label.text = "预演: 预计 +%d 连锁, %d 格受影响" % [result.get("chain_delta", 0), result.get("affected", []).size()]

func _on_skip() -> void:
	grid_renderer.clear_preview()
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
	var stars_text := ""
	for _i in range(GameManager.last_stars):
		stars_text += "★"
	for _i in range(GameManager.last_stars, 3):
		stars_text += "☆"
	gameover_label.text = "胜利! 达成 %d 连锁  %s" % [GameManager.chain_total, stars_text]
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
	GameManager.auto_retention = false
	gameover_panel.visible = false
	next_button.visible = false
	retry_button.visible = false
	_refresh()

func _on_retry() -> void:
	GameManager.start_game(GameManager.level_manager.current_level)
	GameManager.auto_retention = false
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