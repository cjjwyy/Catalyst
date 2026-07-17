class_name RuleCard
extends Resource

enum Kind { TRANSFORM, MULTIPLY, EXTINCTION }

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

func from_dict(d: Dictionary) -> void:
	id = d.get("id", "")
	display_name = d.get("name", "")
	kind = Kind.get(d.get("kind", "TRANSFORM"))
	trigger_element = Element.from_string(d.get("trigger_element", "NONE"))
	trigger_state = State.from_string(d.get("trigger_state", "NONE"))
	contact_element = Element.from_string(d.get("contact_element", "NONE"))
	result_element = Element.from_string(d.get("result_element", "NONE"))
	self_replace = Element.from_string(d.get("self_replace", "NONE"))
	radius = int(d.get("radius", 1))
	life = int(d.get("life", 4))
	chain_reward = int(d.get("chain_reward", 1))
	extinct_threshold = int(d.get("extinct_threshold", 5))
	add_state = State.from_string(d.get("add_state", "NONE"))
	add_state_turns = int(d.get("add_state_turns", 0))
	also_clear = Element.from_string(d.get("also_clear", "NONE"))
	also_count = Element.from_string(d.get("also_count", "NONE"))
	level = int(d.get("level", 0))