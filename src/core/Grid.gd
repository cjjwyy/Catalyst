class_name Grid
extends RefCounted

var w: int
var h: int
var cells: Array = []  # cells[y][x] = Cell

func _init(width: int = 6, height: int = 6) -> void:
	w = width
	h = height
	cells.clear()
	for y in range(h):
		var row: Array = []
		for x in range(w):
			var c = Cell.new()
			c.coord = Vector2i(x, y)
			row.append(c)
		cells.append(row)

func get_cell(p: Vector2i) -> Cell:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return null
	return cells[p.y][p.x]

func neighbors(p: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var np = p + d
		var c = get_cell(np)
		if c != null:
			out.append(c)
	return out

func all_cells() -> Array:
	var out: Array = []
	for y in range(h):
		for x in range(w):
			out.append(cells[y][x])
	return out

func cells_in_radius(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if abs(dx) + abs(dy) > radius:
				continue
			var c = get_cell(center + Vector2i(dx, dy))
			if c != null:
				out.append(c)
	return out

func count_element(elem: int) -> int:
	var n = 0
	for c in all_cells():
		if c.element == elem:
			n += 1
	return n

func total_cells() -> int:
	return w * h

func is_in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h