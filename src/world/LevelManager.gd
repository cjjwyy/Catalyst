class_name LevelManager
extends RefCounted

const LEVELS = [
	{"id": "coast", "name": "海岸·启蒙", "path": "res://data/levels/coast.json", "size": [10,10], "target": 100},
	{"id": "jungle", "name": "丛林·生长", "path": "res://data/levels/jungle.json", "size": [12,12], "target": 300},
	{"id": "mountain", "name": "高山·精炼", "path": "res://data/levels/mountain.json", "size": [14,14], "target": 700},
	{"id": "volcano", "name": "火山口·终局", "path": "res://data/levels/volcano.json", "size": [16,16], "target": 1500},
]

var current_level: int = 0
var unlocked: int = 0

func get_current() -> Dictionary:
	return LEVELS[current_level]

func get_level(idx: int) -> Dictionary:
	return LEVELS[idx]

func is_unlocked(idx: int) -> bool:
	return idx <= unlocked

func select(idx: int) -> bool:
	if not is_unlocked(idx):
		return false
	current_level = idx
	return true

func advance() -> bool:
	if current_level + 1 < LEVELS.size():
		unlocked = max(unlocked, current_level + 1)
		current_level += 1
		return true
	return false

func level_count() -> int:
	return LEVELS.size()