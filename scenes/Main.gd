extends Node2D

var GameManager: Node
var grid_renderer: Node2D
var chain_counter: Label
var total_counter: Label
var energy_label: Label
var status_label: Label
var hand_container: HBoxContainer
var execute_button: Button
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
	execute_button.pressed.connect(_on_execute)
	GameManager.state_changed.connect(_refresh)
	GameManager.reaction_applied.connect(_on_reaction)
	GameManager.game_over.connect(_on_game_over)
	grid_renderer.cell_clicked.connect(_on_cell_clicked)
	grid_renderer.GameManager = GameManager
	_refresh()

func _refresh() -> void:
	if GameManager.grid == null:
		return
	grid_renderer.set_grid(GameManager.grid)
	total_counter.text = "总和: %d / %d" % [GameManager.chain_total, GameManager.TARGET]
	energy_label.text = GameManager.energy.text()
	status_label.text = "回合 %d · 阶段 %s · 死寂 %d/%d" % [GameManager.turn, _phase_name(GameManager.phase), GameManager.dead_turns, GameManager.DEAD_TURNS]
	# 重建手牌视图
	for v in card_views:
		v.queue_free()
	card_views.clear()
	for i in range(GameManager.hand.hand_size()):
		var c = GameManager.hand.hand[i]
		var v = Button.new()
		v.set_script(load("res://src/ui/RuleCardView.gd"))
		v.setup(c, i)
		v.selected.connect(_on_card_selected)
		hand_container.add_child(v)
		card_views.append(v)
	# phase 1 = LAYOUT
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
	var ok = GameManager.play_card(grid_renderer.selected_card_idx, coord)
	if ok:
		grid_renderer.select_card(-1)

func _on_execute() -> void:
	GameManager.execute()

func _on_reaction(_r) -> void:
	grid_renderer.queue_redraw()
	chain_counter.set_chain(GameManager.chain_total)

func _on_game_over(won: bool, msg: String) -> void:
	status_label.text = msg
	execute_button.disabled = true