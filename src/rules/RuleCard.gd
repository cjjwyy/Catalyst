class_name RuleCard
extends Resource

enum Kind { TRANSFORM, MULTIPLY, EXTINCTION }

const MIN_RADIUS := 1
const MAX_RADIUS := 16
const MIN_LIFE := 1
const MAX_LIFE := 99
const MIN_EXTINCT_THRESHOLD := 1
const MAX_EXTINCT_THRESHOLD := 1000

@export var id: String = ""
@export var display_name: String = ""
@export var kind: int = Kind.TRANSFORM
@export var trigger_element: int = Element.NONE
@export var trigger_state: int = State.NONE
@export var contact_element: int = Element.NONE
@export var result_element: int = Element.NONE
@export var self_replace: int = Element.NONE
@export var radius: int = 1
@export var life: int = 4
@export var chain_reward: int = 1
@export var extinct_threshold: int = 5
@export var add_state: int = State.NONE
@export var add_state_turns: int = 0
@export var also_clear: int = Element.NONE   # EXTINCTION 触发时,同范围内清掉此元素(断燃料)
@export var also_count: int = Element.NONE  # EXTINCTION: 计数时也包含此元素
@export var level: int = 0  # 0=全关通用, 1-4=仅该关出现

# 从 JSON 字典填充字段。非法 kind 时整条不写入并返回 false(调用方应跳过该条目)。
func from_dict(d: Dictionary) -> bool:
	var kind_key: String = str(d.get("kind", "TRANSFORM"))
	if not Kind.has(kind_key):
		kind_key = kind_key.to_upper()
	if not Kind.has(kind_key):
		push_warning("RuleCard.from_dict: 非法 kind '%s', 已跳过整条规则" % str(d.get("kind", "")))
		return false
	id = str(d.get("id", ""))
	display_name = str(d.get("name", ""))
	kind = Kind[kind_key]
	trigger_element = Element.from_string(str(d.get("trigger_element", "NONE")))
	trigger_state = State.from_string(str(d.get("trigger_state", "NONE")))
	contact_element = Element.from_string(str(d.get("contact_element", "NONE")))
	result_element = Element.from_string(str(d.get("result_element", "NONE")))
	self_replace = Element.from_string(str(d.get("self_replace", "NONE")))
	radius = clampi(int(d.get("radius", MIN_RADIUS)), MIN_RADIUS, MAX_RADIUS)
	life = clampi(int(d.get("life", 4)), MIN_LIFE, MAX_LIFE)
	chain_reward = clampi(int(d.get("chain_reward", 1)), 0, 1000)
	extinct_threshold = clampi(int(d.get("extinct_threshold", 5)), MIN_EXTINCT_THRESHOLD, MAX_EXTINCT_THRESHOLD)
	add_state = State.from_string(str(d.get("add_state", "NONE")))
	add_state_turns = clampi(int(d.get("add_state_turns", 0)), 0, 99)
	also_clear = Element.from_string(str(d.get("also_clear", "NONE")))
	also_count = Element.from_string(str(d.get("also_count", "NONE")))
	level = clampi(int(d.get("level", 0)), 0, 4)
	return true
