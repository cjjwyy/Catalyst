extends Node2D

const MAX_CELL_SIZE = 64
const GRID_OFFSET = Vector2(180, 40)
var cell_size: int = 64
const DIR_CHARS = ["^", ">", "v", "<"]

var COLORS = {
	Element.NONE: Color(0.08, 0.08, 0.1),
	Element.WATER: Color(0.2, 0.4, 0.9),
	Element.STONE: Color(0.45, 0.45, 0.5),
	Element.EARTH: Color(0.4, 0.3, 0.2),
	Element.STEAM: Color(0.85, 0.85, 0.9),
	Element.LAVA: Color(0.9, 0.25, 0.15),
	Element.PLANT: Color(0.3, 0.75, 0.3),
	Element.ORE: Color(0.85, 0.7, 0.2),
	Element.GRASS: Color(0.4, 0.9, 0.4),
	Element.SPORE: Color(0.6, 0.8, 0.5),
}

const LABELS = {
	Element.NONE: "",
	Element.WATER: "水",
	Element.STONE: "岩",
	Element.EARTH: "土",
	Element.STEAM: "汽",
	Element.LAVA: "熔",
	Element.PLANT: "植",
	Element.ORE: "矿",
	Element.GRASS: "草",
	Element.SPORE: "孢",
}

func _font() -> Font:
	return ThemeDB.fallback_font

var GameManager: Node = null
var grid: Grid = null
var selected_card_idx: int = -1
var hover_cell: Vector2i = Vector2i(-1, -1)
var flash_cells: Dictionary = {}  # coord -> flash_start_ms

signal cell_clicked(coord: Vector2i)
signal cell_right_clicked(coord: Vector2i)

func set_grid(g) -> void:
	grid = g
	# 动态计算 cell_size: 适配窗口, 最大 64px
	var avail_w = 1500 - int(GRID_OFFSET.x) - 220   # 右侧留 220 给图例
	var avail_h = 1000 - int(GRID_OFFSET.y) - 120   # 下方留 120 给手牌
	cell_size = min(MAX_cell_size, avail_w / grid.w, avail_h / grid.h)
	queue_redraw()

func select_card(idx: int) -> void:
	selected_card_idx = idx
	queue_redraw()

func on_flash(coord: Vector2i) -> void:
	flash_cells[coord] = Time.get_ticks_msec()
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	for y in range(grid.h):
		for x in range(grid.w):
			var c = grid.get_cell(Vector2i(x, y))
			var rect = Rect2(GRID_OFFSET + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size))
			var col = COLORS.get(c.element, Color.BLACK)
			draw_rect(rect, col, true)
			draw_rect(rect, Color(0.2, 0.2, 0.22), false, 1.5)
			var lbl = LABELS.get(c.element, "")
			if lbl != "":
				draw_string(_font(), rect.position + Vector2(6, 26), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0,0,0,0.55))
				draw_string(_font(), rect.position + Vector2(4, 24), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1,1,1))
			if c.has_state(State.DUST):
				var cx = rect.position.x + cell_size / 2.0
				var cy = rect.position.y + cell_size / 2.0
				# 心跳脉冲: sin 周期约 1.2 秒, 半径 4-8 之间呼吸
				var r = 4.0 + 4.0 * sin(Time.get_ticks_msec() / 190.0)
				draw_circle(Vector2(cx, cy), r, Color(0.9, 0.8, 0.2, 0.7))
			if c.pillar != null:
				draw_rect(rect.grow(-4), Color(1, 0.92, 0.2), false, 3)
			if c.has_state(State.STEAMED):
				draw_rect(rect.grow(-6), Color(0.9, 0.9, 1, 0.32), true)
			if c.has_state(State.BURNING):
				draw_rect(rect.grow(-6), Color(1, 0.3, 0, 0.32), true)
	if selected_card_idx >= 0 and hover_cell.x >= 0:
		var rect = Rect2(GRID_OFFSET + Vector2(hover_cell.x, hover_cell.y) * cell_size, Vector2(cell_size, cell_size))
		draw_rect(rect, Color(1, 1, 0.4), false, 3)
	# 链式反馈: 闪烁白块
	var now = Time.get_ticks_msec()
	var expired: Array = []
	for coord in flash_cells.keys():
		var age = now - flash_cells[coord]
		if age > 300:
			expired.append(coord)
			continue
		var a = 1.0 - age / 300.0
		var fr = Rect2(GRID_OFFSET + Vector2(coord.x, coord.y) * cell_size, Vector2(cell_size, cell_size))
		draw_rect(fr, Color(1, 1, 1, a * 0.6), true)
	for c in expired:
		flash_cells.erase(c)
	# 催化剂尘连线: 相邻尘格画金线
	for c in grid.all_cells():
		if c.has_state(State.DUST):
			var cp = GRID_OFFSET + Vector2(c.coord.x, c.coord.y) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
			for nb in grid.neighbors(c.coord):
				if nb.has_state(State.DUST) and nb.coord.x >= c.coord.x and nb.coord.y >= c.coord.y:
					var np = GRID_OFFSET + Vector2(nb.coord.x, nb.coord.y) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					draw_line(cp, np, Color(0.9, 0.8, 0.2, 0.4), 2)
	# 生命剩余角标
	for p in (GameManager.pillars if GameManager != null else []):
		var pr = Rect2(GRID_OFFSET + Vector2(p.coord.x, p.coord.y) * cell_size, Vector2(cell_size, cell_size))
		draw_string(_font(), pr.position + Vector2(4, 14), str(p.life_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,0.4))
	# 风指示器(网格左上角上方)
	if GameManager != null:
		var wind_text = "风向风速: %s%d" % [DIR_CHARS[GameManager.wind_dir], GameManager.wind_speed]
		draw_string(_font(), GRID_OFFSET + Vector2(0, -18), wind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.7, 0.2))
	_draw_legend()

func _draw_legend() -> void:
	# 右侧网格旁画一行:色块 + 元素名,列出所有元素及"规则柱"
	var origin = GRID_OFFSET + Vector2(grid.w * cell_size + 20, 0)
	var items = [
		[Element.WATER, "水"],
		[Element.STONE, "岩"],
		[Element.EARTH, "土"],
		[Element.STEAM, "汽"],
		[Element.LAVA, "熔"],
		[Element.PLANT, "植"],
		[Element.ORE, "矿"],
		[Element.GRASS, "草"],
		[Element.NONE, "空"],
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
	draw_string(_font(), origin + Vector2(34, i * 38 + 20), "规则柱", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	i += 1
	draw_circle(origin + Vector2(13, i * 38 + 13), 5, Color(0.9, 0.8, 0.2, 0.8))
	draw_string(_font(), origin + Vector2(34, i * 38 + 20), "催化剂尘", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))

func world_to_coord(wp: Vector2) -> Vector2i:
	var local = wp - GRID_OFFSET
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x = int(local.x / cell_size)
	var y = int(local.y / cell_size)
	if x >= grid.w or y >= grid.h:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _unhandled_input(event: InputEvent) -> void:
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# 右键撤回规则柱
		if coord.x >= 0 and GameManager != null:
			if GameManager.remove_pillar(coord):
				select_card(-1)