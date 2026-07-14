extends Node2D

var GameManager: Node
var grid_renderer: Node2D
var chain_counter: Label
var total_counter: Label
var energy_label: Label
var status_label: Label
var hand_container: HBoxContainer
var execute_button: Button
var help_button: Button
var help_panel: ColorRect
var gameover_panel: ColorRect
var gameover_label: Label
var next_button: Button
var retry_button: Button
var menu_button: Button
var card_views: Array = []

func _ready() -> void:
	GameManager = get_node("/root/GameManager")
	grid_renderer = $GridRenderer
	chain_counter = $ChainCounter
	total_counter = $TotalCounter
	energy_label = $EnergyLabel
	status_label = $StatusLabel
	hand_container = $HandContainer
	execute_button = $ExecuteButton
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
	next_button.visible = false
	retry_button.visible = false
	execute_button.pressed.connect(_on_execute)
	help_button.pressed.connect(func(): help_panel.visible = not help_panel.visible)
	GameManager.state_changed.connect(_refresh)
	GameManager.reaction_applied.connect(_on_reaction)
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	GameManager.flash_cell.connect(grid_renderer.on_flash)
	grid_renderer.cell_clicked.connect(_on_cell_clicked)
	grid_renderer.GameManager = GameManager
	GameManager.start_game(GameManager.level_manager.current_level)
	_refresh()

func _refresh() -> void:
	if GameManager.grid == null:
		return
	grid_renderer.set_grid(GameManager.grid)
	total_counter.text = "总和: %d / %d" % [GameManager.chain_total, GameManager.target]
	energy_label.text = GameManager.energy.text()
	status_label.text = "T%d  %s  死寂%d/%d" % [GameManager.turn, _phase_name(GameManager.phase), GameManager.dead_turns, GameManager.DEAD_TURNS]
	for v in card_views:
		v.queue_free()
	card_views.clear()
	for i in range(GameManager.hand.hand_size()):
		var c = GameManager.hand.hand[i]
		var v = Button.new()
		v.set_script(load("res://src/ui/RuleCardView.gd"))
		v.setup(c, i)
		v.custom_minimum_size = Vector2(150, 90)
		v.selected.connect(_on_card_selected)
		hand_container.add_child(v)
		card_views.append(v)
	execute_button.disabled = (GameManager.phase != 1) or GameManager.pillars.is_empty()

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
	GameManager.execute()

func _on_reaction(_r) -> void:
	grid_renderer.queue_redraw()
	chain_counter.set_chain(GameManager.chain_total)

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