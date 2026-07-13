extends Button

var card: Resource = null  # RuleCard
var index: int = -1

signal selected(idx: int)

func setup(c, idx: int) -> void:
	card = c
	index = idx
	text = _label()
	pressed.connect(_on_pressed)

func refresh() -> void:
	text = _label()

func _label() -> String:
	if card == null:
		return "-"
	var k = ""
	match card.kind:
		RuleCard.Kind.TRANSFORM: k = "转化"
		RuleCard.Kind.MULTIPLY: k = "增殖"
		RuleCard.Kind.EXTINCTION: k = "灭绝"
	return "%s\n[%s] r%d L%d" % [card.display_name, k, card.radius, card.life]

func _on_pressed() -> void:
	selected.emit(index)