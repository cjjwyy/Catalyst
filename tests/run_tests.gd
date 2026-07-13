extends RefCounted

class_name CatalystTests

static func run_all() -> bool:
	var ok = true
	ok = ok and _test_transform_basic()
	ok = ok and _test_multiply_basic()
	ok = ok and _test_extinct_basic()
	ok = ok and _test_out_of_radius()
	ok = ok and _test_chain_reaction_runs()
	ok = ok and _test_phantom_multiply_no_chain()
	ok = ok and _test_extinct_terminates()
	print("[CatalystTests] %s" % ("ALL PASS" if ok else "FAIL"))
	return ok

static func _make_card(d: Dictionary) -> Resource:
	var c = RuleCard.new()
	c.from_dict(d)
	return c

static func _put(g: Grid, x: int, y: int, elem: int) -> void:
	var c = g.get_cell(Vector2i(x, y))
	if c != null:
		c.element = elem
		c.placed_at_turn = 0

static func _test_transform_basic() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.LAVA)
	var card = _make_card({
		"id":"steamify","name":"steamify","kind":"TRANSFORM",
		"trigger_element":"WATER","contact_element":"LAVA",
		"result_element":"STEAM","self_replace":"STONE",
		"radius":1,"life":4
	})
	var pillar = RulePillar.new(card, Vector2i(1,1), 0)
	var engine = RuleEngine.new()
	var out = engine.evaluate(g, [pillar])
	assert(out.size() >= 1, "TRANSFORM should yield >=1 Reaction")
	for r in out:
		r.apply(g)
	assert(g.get_cell(Vector2i(1,1)).element == Element.STEAM, "water -> steam")
	assert(g.get_cell(Vector2i(2,1)).element == Element.STONE, "lava -> stone")
	print("test_transform_basic OK")
	return true

static func _test_multiply_basic() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.STEAM)
	var card = _make_card({
		"id":"grow","name":"grow","kind":"MULTIPLY",
		"trigger_element":"PLANT","contact_element":"STEAM",
		"result_element":"PLANT","radius":1,"life":4
	})
	var pillar = RulePillar.new(card, Vector2i(1,1), 0)
	var engine = RuleEngine.new()
	var out = engine.evaluate(g, [pillar])
	assert(out.size() >= 1, "MULTIPLY should yield Reaction")
	for r in out:
		r.apply(g)
	var planted = 0
	for n in g.neighbors(Vector2i(1,1)):
		if n.element == Element.PLANT:
			planted += 1
	assert(planted >= 1, "should spread >=1 plant to neighbor")
	print("test_multiply_basic OK")
	return true

static func _test_extinct_basic() -> bool:
	var g = Grid.new(6, 6)
	# 5 plants within radius-1 of (1,1): the 4-neighborhood plus center
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 1, 2, Element.PLANT)
	_put(g, 0, 1, Element.PLANT)
	_put(g, 1, 0, Element.PLANT)
	var card = _make_card({
		"id":"extinct","name":"extinct","kind":"EXTINCTION",
		"trigger_element":"PLANT","result_element":"NONE",
		"radius":1,"extinct_threshold":5
	})
	var pillar = RulePillar.new(card, Vector2i(1,1), 0)
	var engine = RuleEngine.new()
	var out = engine.evaluate(g, [pillar])
	assert(out.size() >= 1, "EXTINCTION should trigger at >=5")
	for r in out:
		r.apply(g)
	var remaining = g.count_element(Element.PLANT)
	assert(remaining == 0, "EXTINCTION should clear ALL plants in scope, remaining %d" % remaining)
	print("test_extinct_basic OK")
	return true

static func _test_out_of_radius() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 5, 5, Element.WATER)
	_put(g, 4, 5, Element.LAVA)
	var card = _make_card({
		"id":"steamify","name":"steamify","kind":"TRANSFORM",
		"trigger_element":"WATER","contact_element":"LAVA",
		"result_element":"STEAM","self_replace":"STONE",
		"radius":1,"life":4
	})
	# pillar at (0,0), radius 1, cannot reach (5,5)
	var pillar = RulePillar.new(card, Vector2i(0,0), 0)
	var engine = RuleEngine.new()
	var out = engine.evaluate(g, [pillar])
	for r in out:
		r.apply(g)
	assert(g.get_cell(Vector2i(5,5)).element == Element.WATER, "out-of-radius should not transform")
	print("test_out_of_radius OK")
	return true

static func _test_chain_reaction_runs() -> bool:
	# Chain: WATER+LAVA -> STEAM+STONE at (1,1); then STEAM (at (1,1)) feeds
	# MULTIPLY pillar at (1,2), where (1,2)=PLANT and (1,1) is in its radius-1 scope.
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.LAVA)
	_put(g, 1, 2, Element.PLANT)
	var c1 = _make_card({
		"id":"steamify","name":"steamify","kind":"TRANSFORM",
		"trigger_element":"WATER","contact_element":"LAVA",
		"result_element":"STEAM","self_replace":"STONE","radius":1,"life":4
	})
	var c2 = _make_card({
		"id":"grow","name":"grow","kind":"MULTIPLY",
		"trigger_element":"PLANT","contact_element":"STEAM",
		"result_element":"PLANT","radius":1,"life":4
	})
	var p1 = RulePillar.new(c1, Vector2i(1,1), 0)
	var p2 = RulePillar.new(c2, Vector2i(1,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p1, p2])
	assert(chain >= 2, "chain should trigger >=2 times, got %d" % chain)
	print("test_chain_reaction_runs OK (chain=%d)" % chain)
	return true

static func _test_phantom_multiply_no_chain() -> bool:
	# Plant pillar with STEAM nearby but ALL plant neighbors are non-NONE -> no spread
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.STEAM)
	# surround plant with non-NONE so MULTIPLY has no place to spread
	_put(g, 0, 1, Element.STONE)
	_put(g, 1, 0, Element.STONE)
	_put(g, 1, 2, Element.STONE)
	var card = _make_card({
		"id":"grow","name":"grow","kind":"MULTIPLY",
		"trigger_element":"PLANT","contact_element":"STEAM",
		"result_element":"PLANT","radius":1,"life":4
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	# 没有任何实际 affected -> chain 应为 0,而非 1 (phantom)
	assert(chain == 0, "phantom MULTIPLY should NOT tick chain, got %d" % chain)
	# plant 仍在原地,无任何扩散
	assert(g.get_cell(Vector2i(1,1)).element == Element.PLANT, "plant should remain")
	print("test_phantom_multiply_no_chain OK (chain=%d)" % chain)
	return true

static func _test_extinct_terminates() -> bool:
	# 防回归: 即使 grow + extinct 不重叠、蒸汽源不在 extinct 范围内,
	# 也不应无限刷连锁。cycle 检测会切断 oscillation。
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 1, 2, Element.PLANT)
	_put(g, 2, 2, Element.PLANT)
	_put(g, 5, 5, Element.STEAM)
	# grow pillar 覆盖蒸汽源(5,5)与植物
	var c_grow = _make_card({
		"id":"grow","name":"grow","kind":"MULTIPLY",
		"trigger_element":"PLANT","contact_element":"STEAM",
		"result_element":"PLANT","radius":5,"life":4
	})
	var c_ext = _make_card({
		"id":"extinct","name":"extinct","kind":"EXTINCTION",
		"trigger_element":"PLANT","result_element":"NONE",
		"radius":2,"extinct_threshold":4,"also_clear":"STEAM"
	})
	var p_grow = RulePillar.new(c_grow, Vector2i(2,2), 0)
	var p_ext = RulePillar.new(c_ext, Vector2i(2,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p_grow, p_ext])
	assert(chain < ChainReaction.MAX, "should not hit MAX, got %d" % chain)
	print("test_extinct_terminates OK (chain=%d)" % chain)
	return true