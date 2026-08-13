class_name SaveManager
extends RefCounted

const SLOT_COUNT: int = 3
const SAVE_PATH: String = "user://save.cfg"

var slots: Array = []           # [{name, timestamp, data}], 空字典 = 空槽
var loaded_from_slot: int = -1  # T1.4: 本局加载来源槽; -1 = 新游戏
var meta_unlocked: int = 0      # 全局通关进度(删档不丢)
var save_path: String = SAVE_PATH

func _init() -> void:
	slots.clear()
	for i in range(SLOT_COUNT):
		slots.append({})
	load_from_disk()

# 测试隔离用: 切换到指定路径并重载
func use_path(p: String) -> void:
	save_path = p
	slots.clear()
	for i in range(SLOT_COUNT):
		slots.append({})
	loaded_from_slot = -1
	meta_unlocked = 0
	load_from_disk()

func load_from_disk() -> void:
	var f = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	meta_unlocked = int(data.get("unlocked", 0))
	var arr = data.get("slots", [])
	if typeof(arr) == TYPE_ARRAY:
		for i in range(min(SLOT_COUNT, arr.size())):
			if typeof(arr[i]) == TYPE_DICTIONARY and not arr[i].is_empty():
				slots[i] = arr[i]

func save_to_disk() -> void:
	var data = {"unlocked": meta_unlocked, "slots": slots}
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: 无法写入 %s" % save_path)
		return
	f.store_string(JSON.stringify(data))
	f.close()

func has_slot(i: int) -> bool:
	return i >= 0 and i < SLOT_COUNT and not slots[i].is_empty()

func slot_name(i: int) -> String:
	if has_slot(i):
		return str(slots[i].get("name", ""))
	return ""

func slot_timestamp(i: int) -> int:
	if has_slot(i):
		return int(slots[i].get("timestamp", 0))
	return 0

# T1.4: 最后存档时间精确到秒, 格式 YYYY-MM-DD HH:MM:SS
func slot_time_text(i: int) -> String:
	var t = slot_timestamp(i)
	if t <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(t, true)

# T1.4: 目标槽非空 且 不是本局加载来源槽 → 覆盖需确认
func should_confirm_overwrite(i: int) -> bool:
	return has_slot(i) and i != loaded_from_slot

func save_slot(i: int, slot_name: String, snapshot: Dictionary) -> bool:
	if i < 0 or i >= SLOT_COUNT:
		return false
	slots[i] = {
		"name": slot_name,
		"timestamp": int(Time.get_unix_time_from_system()),
		"data": snapshot,
	}
	# T1.4: 普通存档不改来源标记 —— 只有"从该档加载"才豁免覆盖确认
	save_to_disk()
	return true

func load_slot(i: int) -> Dictionary:
	if not has_slot(i):
		return {}
	loaded_from_slot = i
	return slots[i].get("data", {})

func delete_slot(i: int) -> void:
	if i >= 0 and i < SLOT_COUNT:
		slots[i] = {}
	if loaded_from_slot == i:
		loaded_from_slot = -1  # T1.4: 删除来源槽后标记复位
	save_to_disk()

func rename_slot(i: int, new_name: String) -> void:
	if has_slot(i):
		slots[i]["name"] = new_name
		save_to_disk()

func set_unlocked(v: int) -> void:
	meta_unlocked = max(meta_unlocked, v)
	save_to_disk()

func get_unlocked() -> int:
	return meta_unlocked
