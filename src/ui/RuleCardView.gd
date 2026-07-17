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

const CN = {
	Element.NONE: "空", Element.WATER: "水", Element.STONE: "岩",
	Element.EARTH: "土", Element.STEAM: "汽", Element.LAVA: "熔", Element.PLANT: "植",
	Element.ORE: "矿", Element.GRASS: "草",
	Element.SPORE: "孢",
	Element.ICE: "冰"
}

func _label() -> String:
	if card == null: return "-"
	var extra = ""
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			extra = "转化\n%s 接触 %s\n→ %s" % [
				CN.get(card.trigger_element,"?"),
				CN.get(card.contact_element,"?"),
				CN.get(card.result_element,"?")]
			if card.self_replace != Element.NONE:
				extra += " + 清%s" % CN.get(card.self_replace,"?")
		RuleCard.Kind.MULTIPLY:
			extra = "增殖\n%s 相邻 %s\n→ 扩散 %s" % [
				CN.get(card.trigger_element,"?"),
				CN.get(card.contact_element,"?"),
				CN.get(card.result_element,"?")]
		RuleCard.Kind.EXTINCTION:
			extra = "灭绝\n%s ≥%d个\n→ 清空所有%s" % [
				CN.get(card.trigger_element,"?"),
				card.extinct_threshold,
				CN.get(card.trigger_element,"?")]
			if card.also_count != Element.NONE:
				extra += "+%s" % CN.get(card.also_count,"?")
			if card.also_clear != Element.NONE:
				extra += "\n也清%s" % CN.get(card.also_clear,"?")
	var tail = "\n(半径%d格, %d回合" % [card.radius, card.life]
	if card.chain_reward > 1:
		tail += ", +%d连" % card.chain_reward
	tail += ")"
	return extra + tail

func _tooltip() -> String:
	if card == null: return ""
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			return "转化: 半径内 %s 接触到 %s → 全部变 %s\n寿命 %d 回合" % [
				CN.get(card.trigger_element,"?"),
				CN.get(card.contact_element,"?"),
				CN.get(card.result_element,"?"),
				card.life]
		RuleCard.Kind.MULTIPLY:
			return "增殖: 半径内 %s 相邻 %s → 向空格扩散 %s\n寿命 %d 回合" % [
				CN.get(card.trigger_element,"?"),
				CN.get(card.contact_element,"?"),
				CN.get(card.result_element,"?"),
				card.life]
		RuleCard.Kind.EXTINCTION:
			var s = "灭绝: 半径内 %s ≥%d 个 → 清空所有 %s" % [
				CN.get(card.trigger_element,"?"),
				card.extinct_threshold,
				CN.get(card.trigger_element,"?")]
			if card.also_clear != Element.NONE:
				s += "\n同时清除范围内所有 %s" % CN.get(card.also_clear,"?")
			return s + "\n寿命 %d 回合" % card.life
		_: return ""

func _on_pressed() -> void:
	selected.emit(index)