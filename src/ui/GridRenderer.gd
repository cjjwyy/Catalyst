extends Node2D

const MAX_CELL_SIZE = 64
const GRID_OFFSET = Vector2(180, 40)
var cell_size: int = 64
const DIR_CHARS = ["^", ">", "v", "<"]

# 贴图缓存
var tex_elements: Dictionary = {}
var tex_empty: Texture2D = null
var tex_pillar: Texture2D = null
var tex_dust: Texture2D = null
var tex_overlays: Dictionary = {}

const ELEMENT_PATHS = {
	Element.NONE: "res://assets/empty.png",
	Element.WATER: "res://assets/water.png",
	Element.STONE: "res://assets/stone.png",
	Element.EARTH: "res://assets/earth.png",
	Element.STEAM: "res://assets/steam.png",
	Element.LAVA: "res://assets/lava.png",
	Element.PLANT: "res://assets/plant.png",
	Element.ORE: "res://assets/ore.png",
	Element.GRASS: "res://assets/grass.png",
	Element.SPORE: "res://assets/spore.png",
	Element.ICE: "res://assets/ice.png",
}

const LABELS = {
	Element.NONE: "", Element.WATER: "水", Element.STONE: "岩", Element.EARTH: "土",
	Element.STEAM: "汽", Element.LAVA: "熔", Element.PLANT: "植", Element.ORE: "矿",
	Element.GRASS: "草", Element.SPORE: "孢", Element.ICE: "冰",
}

const OVERLAY_PATHS = {
	State.BURNING: "res://assets/overlay_burning.png",
	State.SNOW: "res://assets/overlay_snow.png",
	State.FROZEN: "res://assets/overlay_frozen.png",
	State.BLESSED: "res://assets/overlay_blessed.png",
	State.METEOR_LAVA: "res://assets/overlay_meteor.png",
}

# Fallback colors (when textures fail to load)
var COLORS = {
	Element.NONE: Color(0.08, 0.08, 0.1), Element.WATER: Color(0.2, 0.4, 0.9),
	Element.STONE: Color(0.45, 0.45, 0.5), Element.EARTH: Color(0.4, 0.3, 0.2),
	Element.STEAM: Color(0.85, 0.85, 0.9), Element.LAVA: Color(0.9, 0.25, 0.15),
	Element.PLANT: Color(0.3, 0.75, 0.3), Element.ORE: Color(0.85, 0.7, 0.2),
	Element.GRASS: Color(0.4, 0.9, 0.4), Element.SPORE: Color(0.6, 0.8, 0.5),
	Element.ICE: Color(0.7, 0.85, 0.95),
}

func _ready() -> void:
	_load_textures()

func _load_textures() -> void:
	for elem in ELEMENT_PATHS.keys():
		tex_elements[elem] = _load_resized(ELEMENT_PATHS[elem], 128)
	tex_pillar = _load_resized("res://assets/pillar.png", 128)
	tex_dust = _load_resized("res://assets/dust.png", 64)
	for state in OVERLAY_PATHS.keys():
		tex_overlays[state] = _load_resized(OVERLAY_PATHS[state], 64)

func _load_resized(path: String, sz: int) -> Texture2D:
	var full = ProjectSettings.globalize_path(path)
	var img = Image.new()
	var err = img.load(full)
	if err != OK:
		return null
	img.resize(sz, sz, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func _font() -> Font:
	return ThemeDB.fallback_font

var GameManager: Node = null
var grid: Grid = null
var selected_card_idx: int = -1
var hover_cell: Vector2i = Vector2i(-1, -1)
var flash_cells: Dictionary = {}

signal cell_clicked(coord: Vector2i)
signal cell_right_clicked(coord: Vector2i)

func set_grid(g) -> void:
	grid = g
	var avail_w = 1500 - int(GRID_OFFSET.x) - 260
	var avail_h = 1000 - int(GRID_OFFSET.y) - 120
	cell_size = min(MAX_CELL_SIZE, avail_w / grid.w, avail_h / grid.h)
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
			_draw_cell(c, rect)
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
	# 催化剂尘连线
	for c in grid.all_cells():
		if c.has_state(State.DUST):
			var cp = GRID_OFFSET + Vector2(c.coord.x, c.coord.y) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
			for nb in grid.neighbors(c.coord):
				if nb.has_state(State.DUST) and nb.coord.x >= c.coord.x and nb.coord.y >= c.coord.y:
					var np = GRID_OFFSET + Vector2(nb.coord.x, nb.coord.y) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					draw_line(cp, np, Color(0.9, 0.8, 0.2, 0.4), 2)
	# 生命剩余角标
	for p in (GameManager.pillars if GameManager != null else []):
		var pr = GRID_OFFSET + Vector2(p.coord.x, p.coord.y) * cell_size + Vector2(4, 14)
		draw_string(_font(), pr, str(p.life_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,0.4))
	# 风指示器
	if GameManager != null:
		var wind_text = "风向风速: %s%d" % [DIR_CHARS[GameManager.wind_dir], GameManager.wind_speed]
		draw_string(_font(), GRID_OFFSET + Vector2(0, -18), wind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.7, 0.2))
	_draw_legend()

func _draw_cell(c: Cell, rect: Rect2) -> void:
	# 底层: 元素贴图(或有 fallback 色块)
	var tex = tex_elements.get(c.element)
	if tex != null:
		draw_texture_rect(tex, rect, false)
	else:
		draw_rect(rect, COLORS.get(c.element, Color.BLACK), true)
	draw_rect(rect, Color(0.2, 0.2, 0.22), false, 1.0)
	# 元素字标
	var lbl = LABELS.get(c.element, "")
	if lbl != "":
		draw_string(_font(), rect.position + Vector2(6, 26), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0,0,0,0.5))
		draw_string(_font(), rect.position + Vector2(4, 24), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1,1,1,0.9))
	# 状态叠层: STEAMED(用代码), BURNING/SNOW/FROZEN/BLESSED/METEOR_LAVA(用贴图)
	if c.has_state(State.STEAMED):
		draw_rect(rect.grow(-6), Color(0.9, 0.9, 1, 0.32), true)
	for state in [State.BURNING, State.SNOW, State.FROZEN, State.BLESSED, State.METEOR_LAVA]:
		if c.has_state(state):
			var ot = tex_overlays.get(state)
			if ot != null:
				draw_texture_rect(ot, rect, false)
			elif state == State.BLESSED:
				draw_rect(rect.grow(-3), Color(1, 0.85, 0.3), false, 2)
			elif state == State.METEOR_LAVA:
				var cx = rect.position.x + cell_size / 2.0
				var cy = rect.position.y + cell_size / 2.0
				var mr = 8.0 + 3.0 * sin(Time.get_ticks_msec() / 200.0)
				draw_circle(Vector2(cx, cy), mr, Color(0.5, 0.15, 0.1, 0.5))
	# 催化剂尘: 贴图或代码脉冲
	if c.has_state(State.DUST):
		var cx = rect.position.x + cell_size / 2.0
		var cy = rect.position.y + cell_size / 2.0
		if tex_dust != null:
			var dr = Rect2(rect.position.x + cell_size/2.0 - 16, rect.position.y + cell_size/2.0 - 16, 32, 32)
			draw_texture_rect(tex_dust, dr, false)
		else:
			var r = 4.0 + 4.0 * sin(Time.get_ticks_msec() / 190.0)
			draw_circle(Vector2(cx, cy), r, Color(0.9, 0.8, 0.2, 0.7))
	# 规则柱: 贴图或代码边框
	if c.pillar != null:
		if tex_pillar != null:
			draw_texture_rect(tex_pillar, rect, false)
		else:
			draw_rect(rect.grow(-4), Color(1, 0.92, 0.2), false, 3)

func _draw_legend() -> void:
	var origin = GRID_OFFSET + Vector2(grid.w * cell_size + 20, 0)
	var items = [
		[Element.WATER, "水"], [Element.STONE, "岩"], [Element.EARTH, "土"],
		[Element.STEAM, "汽"], [Element.LAVA, "熔"], [Element.PLANT, "植"],
		[Element.ORE, "矿"], [Element.GRASS, "草"], [Element.SPORE, "孢"],
		[Element.ICE, "冰"], [Element.NONE, "空"],
	]
	var sz = 28
	var i = 0
	for item in items:
		var elem = item[0]
		var box = Rect2(origin + Vector2(0, i * (sz + 6)), Vector2(sz, sz))
		var t = tex_elements.get(elem)
		if t != null:
			draw_texture_rect(t, box, false)
		else:
			draw_rect(box, COLORS.get(elem, Color.BLACK), true)
		draw_rect(box, Color(0.2, 0.2, 0.22), false, 1.0)
		draw_string(_font(), origin + Vector2(sz + 6, i * (sz + 6) + 20), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
		i += 1
	# 规则柱 + 尘
	if tex_pillar != null:
		draw_texture_rect(tex_pillar, Rect2(origin + Vector2(0, i * (sz + 6)), Vector2(sz, sz)), false)
	else:
		draw_rect(Rect2(origin + Vector2(0, i * (sz + 6)), Vector2(sz, sz)), Color(0.1, 0.1, 0.12), true)
		draw_rect(Rect2(origin + Vector2(0, i * (sz + 6)), Vector2(sz, sz)).grow(-3), Color(1, 0.92, 0.2), false, 3)
	draw_string(_font(), origin + Vector2(sz + 6, i * (sz + 6) + 20), "规则柱", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
	i += 1
	if tex_dust != null:
		draw_texture_rect(tex_dust, Rect2(origin + Vector2(4, i * (sz + 6) + 4), Vector2(20, 20)), false)
	else:
		draw_circle(origin + Vector2(sz/2, i * (sz + 6) + sz/2), 6, Color(0.9, 0.8, 0.2, 0.8))
	draw_string(_font(), origin + Vector2(sz + 6, i * (sz + 6) + 20), "催化剂尘", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))

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
		if coord.x >= 0 and GameManager != null:
			if GameManager.remove_pillar(coord):
				select_card(-1)