extends RefCounted

const CSV_PATH := "res://data/i18n/zh.csv"
static var _dict: Dictionary = {}

func t(key: String, args: Array = []) -> String:
	if _dict.is_empty():
		_load()
	var template: String = str(_dict.get(key, key))
	if args.is_empty():
		return template
	return template % args

func _load() -> void:
	_dict.clear()
	var f = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_warning("Texts: 无法打开 " + CSV_PATH)
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("key"):
			continue
		var comma := line.find(",")
		if comma <= 0:
			continue
		_dict[line.substr(0, comma)] = line.substr(comma + 1)
	f.close()

func has(key: String) -> bool:
	if _dict.is_empty():
		_load()
	return _dict.has(key)
