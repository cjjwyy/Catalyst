extends Node2D

const CELL_SIZE = 64
const GRID_OFFSET = Vector2(160, 120)
const DIR_CHARS = ["^", ">", "v", "<"]

var COLORS = {
	Element.NONE: Color(0.08, 0.08, 0.1),
	Element.WATER: Color(0.2, 0.4, 0.9),
	Element.STONE: Color(0.45, 0.45, 0.5),
	Element.EARTH: Color(0.4, 0.3, 0.2),
	Element.STEAM: Color(0.85, 0.85, 0.9),
	Element.LAVA: Color(0.9, 0.25, 0.15),
	Element.PLANT: Color(0.3, 0.75, 0.3),
}

const LABELS = {
	Element.NONE: "",
	Element.WATER: "水",
	Element.STONE: "岩",
	Element.EARTH: "土",
	Element.STEAM: "汽",
	Element.LAVA: "熔",
	Element.PLANT: "植",
}

func _font() -> Font:
	return ThemeDB.fallback_font

var GameManager: Node = null
var grid: Grid = null
var selected_card_idx: int = -1
var hover_cell: Vector2i = Vector2i(-1, -1)

signal cell_clicked(coord: Vector2i)

func set_grid(g) -> void:
	grid = g
	queue_redraw()

func select_card(idx: int) -> void:
	selected_card_idx = idx
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	for y in range(grid.h):
		for x in range(grid.w):
			var c = grid.get_cell(Vector2i(x, y))
			var rect = Rect2(GRID_OFFSET + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			var col = COLORS.get(c.element, Color.BLACK)
			draw_rect(rect, col, true)
			draw_rect(rect, Color(0.2, 0.2, 0.22), false, 1.5)
			var lbl = LABELS.get(c.element, "")
			if lbl != "":
				draw_string(_font(), rect.position + Vector2(6, 26), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0,0,0,0.55))
				draw_string(_font(), rect.position + Vector2(4, 24), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1,1,1))
			if c.has_state(State.DUST):
				var cx = rect.position.x + CELL_SIZE / 2.0
				var cy = rect.position.y + CELL_SIZE / 2.0
				draw_circle(Vector2(cx, cy), 6, Color(0.9, 0.8, 0.2, 0.7))
			if c.pillar != null:
				draw_rect(rect.grow(-4), Color(1, 0.92, 0.2), false, 3)
			if c.has_state(State.STEAMED):
				draw_rect(rect.grow(-6), Color(0.9, 0.9, 1, 0.32), true)
			if c.has_state(State.BURNING):
				draw_rect(rect.grow(-6), Color(1, 0.3, 0, 0.32), true)
	if selected_card_idx >= 0 and hover_cell.x >= 0:
		var rect = Rect2(GRID_OFFSET + Vector2(hover_cell.x, hover_cell.y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, Color(1, 1, 0.4), false, 3)
	# 生命剩余角标
	for p in (GameManager.pillars if GameManager != null else []):
		var rect = Rect2(GRID_OFFSET + Vector2(p.coord.x, p.coord.y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		draw_string(_font(), rect.position + Vector2(4, 14), str(p.life_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,0.4))
	if GameManager != null:
		var wind_text = DIR_CHARS[GameManager.wind_dir] + str(GameManager.wind_speed)
		draw_string(_font(), GRID_OFFSET + Vector2(0, -20), wind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.8, 0.3))
	_draw_legend()

func _draw_legend() -> void:
	# 右侧网格旁画一行:色块 + 元素名,列出所有元素及"规则柱"
	var origin = GRID_OFFSET + Vector2(grid.w * CELL_SIZE + 20, 0)
	var items = [
		[Element.WATER, "水体 Water"],
		[Element.STONE, "岩石 Stone"],
		[Element.EARTH, "土壤 Earth"],
		[Element.STEAM, "蒸汽 Steam"],
		[Element.LAVA, "熔岩 Lava"],
		[Element.PLANT, "植物 Plant"],
		[Element.NONE, "空 Empty"],
	]
	var i = 0
	for item in items:
		var elem = item[0]
		var name_text = item[1]
		var box = Rect2(origin + Vector2(0, i * 38), Vector2(26, 26))
		draw_rect(box, COLORS.get(elem, Color.BLACK), true)
		draw_rect(box, Color(0.2, 0.2, 0.22), false, 1.5)
		draw_string(_font(), origin + Vector2(34, i * 38 + 20), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
		i += 1
	# 规则柱说明
	var box = Rect2(origin + Vector2(0, i * 38), Vector2(26, 26))
	draw_rect(box, Color(0.1, 0.1, 0.12), true)
	draw_rect(box.grow(-3), Color(1, 0.92, 0.2), false, 3)
	draw_string(_font(), origin + Vector2(34, i * 38 + 20), "规则柱 Pillar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	i += 1
	draw_circle(origin + Vector2(13, i * 38 + 13), 5, Color(0.9, 0.8, 0.2, 0.8))
	draw_string(_font(), origin + Vector2(34, i * 38 + 20), "催化剂尘 Dust", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))

func world_to_coord(wp: Vector2) -> Vector2i:
	var local = wp - GRID_OFFSET
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x = int(local.x / CELL_SIZE)
	var y = int(local.y / CELL_SIZE)
	if x >= grid.w or y >= grid.h:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _input(event: InputEvent) -> void:
	if grid == null:
		return
	var coord = world_to_coord(get_global_mouse_position())
	if event is InputEventMouseMotion:
		if coord != hover_cell:
			hover_cell = coord
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if coord.x >= 0:
			cell_clicked.emit(coord)
			get_viewport().set_input_as_handled()