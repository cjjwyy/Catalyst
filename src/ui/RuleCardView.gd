extends Button

var card: Resource = null  # RuleCard
var index: int = -1

signal selected(idx: int)

@onready var title_label: Label = get_node_or_null("TitleLabel")
@onready var effect_label: Label = get_node_or_null("EffectLabel")
@onready var trigger_icon: TextureRect = get_node_or_null("TriggerIcon")
@onready var result_icon: TextureRect = get_node_or_null("ResultIcon")
@onready var type_band: ColorRect = get_node_or_null("TypeBand")

func setup(c, idx: int) -> void:
	card = c
	index = idx
	text = ""
	tooltip_text = _tooltip()
	var t: Label = get_node_or_null("TitleLabel")
	if t != null:
		t.text = c.display_name if c != null else "-"
	var e: Label = get_node_or_null("EffectLabel")
	if e != null:
		var dv = card.get("desc") if card != null else null
		var desc: String = str(dv) if dv != null else ""
		e.text = desc if desc != "" else _effect_text()
	var band: ColorRect = get_node_or_null("TypeBand")
	if band != null:
		band.color = _kind_color()
	var ti: TextureRect = get_node_or_null("TriggerIcon")
	if ti != null and card != null:
		ti.texture = _element_texture(card.trigger_element)
	var ri: TextureRect = get_node_or_null("ResultIcon")
	if ri != null and card != null:
		ri.texture = _element_texture(card.result_element)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func refresh() -> void:
	tooltip_text = _tooltip()
	var t: Label = get_node_or_null("TitleLabel")
	if t != null and card != null:
		t.text = card.display_name
	var e: Label = get_node_or_null("EffectLabel")
	if e != null:
		var dv = card.get("desc") if card != null else null
		var desc: String = str(dv) if dv != null else ""
		e.text = desc if desc != "" else _effect_text()

const CN = {
	Element.NONE: "空", Element.WATER: "水", Element.STONE: "岩",
	Element.EARTH: "土", Element.STEAM: "汽", Element.LAVA: "熔", Element.PLANT: "植",
	Element.ORE: "矿", Element.GRASS: "草",
	Element.SPORE: "孢",
	Element.ICE: "冰"
}

func _element_texture(elem: int) -> Texture2D:
	if elem == Element.NONE:
		return load("res://assets/empty.png")
	var key: String = Element.NAMES.get(elem, "empty").to_lower()
	return load("res://assets/%s.png" % key)

func _kind_color() -> Color:
	if card == null:
		return Color(0.2, 0.2, 0.25)
	match card.kind:
		RuleCard.Kind.MULTIPLY:
			return Color(0.15, 0.45, 0.2, 0.9)
		RuleCard.Kind.EXTINCTION:
			return Color(0.55, 0.16, 0.16, 0.9)
		_:
			return Color(0.2, 0.35, 0.7, 0.9)

func _effect_text() -> String:
	if card == null:
		return "-"
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			var s := "%s+%s → %s" % [CN.get(card.trigger_element, "?"), CN.get(card.contact_element, "?"), CN.get(card.result_element, "?")]
			if card.self_replace != Element.NONE:
				s += " 清%s" % CN.get(card.self_replace, "?")
			return s
		RuleCard.Kind.MULTIPLY:
			return "%s+%s → 扩散%s" % [CN.get(card.trigger_element, "?"), CN.get(card.contact_element, "?"), CN.get(card.result_element, "?")]
		RuleCard.Kind.EXTINCTION:
			return "%s≥%d 清空" % [CN.get(card.trigger_element, "?"), card.extinct_threshold]
		_:
			return ""

func _tooltip() -> String:
	if card == null:
		return ""
	var desc_v = card.get("desc")
	var desc: String = str(desc_v) if desc_v != null else ""
	var tip_v = card.get("tip")
	var tip: String = str(tip_v) if tip_v != null else ""
	var base := _tooltip_rule()
	if desc != "":
		base += "\n说明: %s" % desc
	if tip != "":
		base += "\n示例: %s" % tip
	base += "\n半径%d格 · 寿命%d回合 · 连锁+%d" % [card.radius, card.life, card.chain_reward]
	return base

func _tooltip_rule() -> String:
	match card.kind:
		RuleCard.Kind.TRANSFORM:
			return "转化: 柱扫描半径内,每格%s 若范围内有 %s → 变 %s" % [
				CN.get(card.trigger_element, "?"), CN.get(card.contact_element, "?"), CN.get(card.result_element, "?")]
		RuleCard.Kind.MULTIPLY:
			return "增殖: 柱扫描半径内,每格%s 若范围内有 %s → 空格生 %s" % [
				CN.get(card.trigger_element, "?"), CN.get(card.contact_element, "?"), CN.get(card.result_element, "?")]
		RuleCard.Kind.EXTINCTION:
			return "灭绝: 柱扫描半径内 %s≥%d → 全部清空" % [CN.get(card.trigger_element, "?"), card.extinct_threshold]
		_:
			return ""

func _on_pressed() -> void:
	selected.emit(index)
