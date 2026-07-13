extends Button

var card: Resource = null  # RuleCard
var index: int = -1

signal selected(idx: int)

func setup(c, idx: int) -> void:
	card = c
	index = idx
	text = _label()
	tooltip_text = _tooltip()
	pressed.connect(_on_pressed)

func refresh() -> void:
	text = _label()
	tooltip_text = _tooltip()

func _label() -> String:
	if card == null:
		return "-"
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			return "转化\n%s 接触 %s\n→ %s\n(r%d, %d回合)" % [
				Element.NAMES.get(card.trigger_element,"?"),
				Element.NAMES.get(card.contact_element,"?"),
				Element.NAMES.get(card.result_element,"?"),
				card.radius, card.life]
		RuleCard.Kind.MULTIPLY:
			return "增殖\n%s 相邻 %s\n→ 扩散 %s\n(r%d, %d回合)" % [
				Element.NAMES.get(card.trigger_element,"?"),
				Element.NAMES.get(card.contact_element,"?"),
				Element.NAMES.get(card.result_element,"?"),
				card.radius, card.life]
		RuleCard.Kind.EXTINCTION:
			var s = "灭绝\n%s ≥%d个\n→ 清空所有%s" % [
				Element.NAMES.get(card.trigger_element,"?"),
				card.extinct_threshold,
				Element.NAMES.get(card.trigger_element,"?")]
			if card.also_clear != Element.NONE:
				s += "\n也清%s" % Element.NAMES.get(card.also_clear,"?")
			return s + "\n(r%d, %d回合)" % [card.radius, card.life]
		_: return ""

func _tooltip() -> String:
	if card == null: return ""
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			return "转化: 半径内 %s 接触到 %s → 全部变 %s\n寿命 %d 回合" % [
				Element.NAMES.get(card.trigger_element,"?"),
				Element.NAMES.get(card.contact_element,"?"),
				Element.NAMES.get(card.result_element,"?"),
				card.life]
		RuleCard.Kind.MULTIPLY:
			return "增殖: 半径内 %s 相邻 %s → 向空格扩散 %s\n寿命 %d 回合" % [
				Element.NAMES.get(card.trigger_element,"?"),
				Element.NAMES.get(card.contact_element,"?"),
				Element.NAMES.get(card.result_element,"?"),
				card.life]
		RuleCard.Kind.EXTINCTION:
			var s = "灭绝: 半径内 %s ≥%d 个 → 清空所有 %s" % [
				Element.NAMES.get(card.trigger_element,"?"),
				card.extinct_threshold,
				Element.NAMES.get(card.trigger_element,"?")]
			if card.also_clear != Element.NONE:
				s += "\n同时清除范围内所有 %s" % Element.NAMES.get(card.also_clear,"?")
			return s + "\n寿命 %d 回合" % card.life
		_: return ""

func _on_pressed() -> void:
	selected.emit(index)