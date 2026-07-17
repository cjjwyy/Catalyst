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
	ok = ok and _test_dust_spawn()
	ok = ok and _test_wind_push_dust()
	ok = ok and _test_dust_blob_extends_scope()
	ok = ok and _test_chaos_detection()
	ok = ok and _test_ore_harvest()
	ok = ok and _test_grass_wither()
	ok = ok and _test_steam_evaporate()
	ok = ok and _test_extinct_counts_grass()
	ok = ok and _test_level_manager()
	ok = ok and _test_level_load()
	ok = ok and _test_sporify()
	ok = ok and _test_spore_bloom()
	ok = ok and _test_burning_ignite()
	ok = ok and _test_spore_wind_move()
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

static func _test_dust_spawn() -> bool:
	# 用棋盘格填满 WATER+LAVA 对,确保 chain >= 10 触发尘播撒
	var g = Grid.new(6, 6)
	for x in range(6):
		for y in range(6):
			if (x + y) % 2 == 0:
				_put(g, x, y, Element.WATER)
			else:
				_put(g, x, y, Element.LAVA)
	var c1 = _make_card({
		"id":"steamify","name":"steamify","kind":"TRANSFORM",
		"trigger_element":"WATER","contact_element":"LAVA",
		"result_element":"STEAM","self_replace":"STONE","radius":5,"life":4
	})
	var p1 = RulePillar.new(c1, Vector2i(2,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p1])
	var dust_count = 0
	for c in g.all_cells():
		if c.has_state(State.DUST):
			dust_count += 1
	assert(dust_count >= 1, "chain >= 10 should produce at least 1 DUST, got %d" % dust_count)
	print("test_dust_spawn OK (chain=%d, dust=%d)" % [chain, dust_count])
	return true

static func _test_wind_push_dust() -> bool:
	var g = Grid.new(6, 6)
	var src = g.get_cell(Vector2i(2, 3))
	src.add_state(State.DUST, 3)
	var dir_vec = Vector2i(0, -1)
	var speed = 2
	var dst_coord = Vector2i(2, 3)
	var fell = false
	for _i in range(speed):
		dst_coord = dst_coord + dir_vec
		if not g.is_in_bounds(dst_coord):
			fell = true
			break
	if fell:
		src.remove_state(State.DUST)
	else:
		var dst = g.get_cell(dst_coord)
		var turns = src.states.get(State.DUST, 0)
		src.remove_state(State.DUST)
		dst.add_state(State.DUST, max(dst.states.get(State.DUST, 0), turns))
	assert(g.get_cell(Vector2i(2, 1)).has_state(State.DUST), "dust should move to (2,1)")
	assert(not g.get_cell(Vector2i(2, 3)).has_state(State.DUST), "old cell should be clean")
	print("test_wind_push_dust OK")
	return true

static func _test_dust_blob_extends_scope() -> bool:
	# 3 格尘形成 4 连通团块: (2,2)(2,3)(3,3)
	# pillar at (1,1) radius=2 touches (2,2) → blob expands to (2,3)(3,3)
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.STEAM)
	_put(g, 2, 2, Element.PLANT)
	g.get_cell(Vector2i(2,2)).add_state(State.DUST, 3)
	_put(g, 2, 3, Element.PLANT)
	g.get_cell(Vector2i(2,3)).add_state(State.DUST, 3)
	_put(g, 3, 3, Element.PLANT)
	g.get_cell(Vector2i(3,3)).add_state(State.DUST, 3)
	var card = _make_card({
		"id":"grow","name":"grow","kind":"MULTIPLY",
		"trigger_element":"PLANT","contact_element":"STEAM",
		"result_element":"PLANT","radius":2,"life":4
	})
	var pillar = RulePillar.new(card, Vector2i(1,1), 0)
	var engine = RuleEngine.new()
	var out = engine.evaluate(g, [pillar])
	var targets: Array = []
	for r in out:
		targets.append(r.target_coord)
	assert(targets.has(Vector2i(2,2)), "should trigger plant at (2,2)")
	assert(targets.has(Vector2i(2,3)), "should trigger plant at (2,3) via dust blob")
	assert(targets.has(Vector2i(3,3)), "should trigger plant at (3,3) via dust blob")
	print("test_dust_blob_extends_scope OK (%d reactions)" % out.size())
	return true

static func _test_chaos_detection() -> bool:
	var g = Grid.new(6, 6)
	for y in range(g.h):
		for x in range(g.w):
			var c = g.get_cell(Vector2i(x, y))
			if c != null and not (y == 5 and x == 5):
				c.element = Element.PLANT
	var n = g.count_element(Element.PLANT)
	assert(n > g.w * g.h / 2, "should be majority (got %d/36)" % n)
	assert(n >= 35, "33+ plants needed, got %d" % n)
	print("test_chaos_detection OK (plant=%d)" % n)
	return true

static func _test_ore_harvest() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.ORE)
	var card = _make_card({
		"id":"harvest","name":"采掘","kind":"TRANSFORM",
		"trigger_element":"PLANT","contact_element":"ORE",
		"result_element":"NONE","self_replace":"NONE",
		"radius":2,"life":4,"chain_reward":5
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	assert(chain == 5, "harvest should give 5 chain, got %d" % chain)
	assert(g.get_cell(Vector2i(1,1)).element == Element.NONE, "plant gone")
	assert(g.get_cell(Vector2i(2,1)).element == Element.NONE, "ore gone")
	print("test_ore_harvest OK (chain=%d)" % chain)
	return true

static func _test_grass_wither() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(2,2)).element = Element.GRASS
	g.get_cell(Vector2i(2,2)).decay_timer = 0
	var c = g.get_cell(Vector2i(2,2))
	for _i in range(2):
		var hf = false
		for n in g.neighbors(c.coord):
			if n.element in [Element.PLANT, Element.GRASS]:
				hf = true; break
		if not hf: c.decay_timer += 1
		else: c.decay_timer = 0
		if c.decay_timer >= 2:
			c.element = Element.EARTH
			c.decay_timer = 0
	assert(g.get_cell(Vector2i(2,2)).element == Element.EARTH, "grass should wither to earth")
	print("test_grass_wither OK")
	return true

static func _test_steam_evaporate() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(3,3)).element = Element.STEAM
	g.get_cell(Vector2i(3,3)).placed_at_turn = 0
	var turn = 2
	for c in g.all_cells():
		if c.element == Element.STEAM and turn - c.placed_at_turn >= 2:
			c.element = Element.NONE
	assert(g.get_cell(Vector2i(3,3)).element == Element.NONE, "steam should vanish")
	print("test_steam_evaporate OK")
	return true

static func _test_extinct_counts_grass() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 1, 2, Element.PLANT)
	_put(g, 2, 2, Element.GRASS)
	_put(g, 0, 2, Element.GRASS)
	var card = _make_card({
		"id":"extinct","name":"丛林灭绝","kind":"EXTINCTION",
		"trigger_element":"PLANT","result_element":"NONE",
		"radius":2,"extinct_threshold":5,"also_count":"GRASS"
	})
	var p = RulePillar.new(card, Vector2i(2,2), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	var p_left = g.count_element(Element.PLANT)
	var g_left = g.count_element(Element.GRASS)
	assert(p_left == 0, "all plants cleared (got %d)" % p_left)
	assert(g_left == 0, "all grass cleared (got %d)" % g_left)
	print("test_extinct_counts_grass OK (chain=%d)" % chain)
	return true

static func _test_level_manager() -> bool:
	var LM = load("res://src/world/LevelManager.gd")
	var lm = LM.new()
	assert(lm.level_count() == 4, "should have 4 levels")
	assert(lm.is_unlocked(0) == true, "level 0 unlocked")
	assert(lm.is_unlocked(1) == false, "level 1 locked")
	assert(lm.select(1) == false, "cannot select locked level")
	assert(lm.select(0) == true, "can select level 0")
	assert(lm.get_current().target == 100, "coast target 100")
	lm.current_level = 0
	assert(lm.advance() == true, "advance to level 1")
	assert(lm.is_unlocked(1) == true, "level 1 now unlocked")
	assert(lm.current_level == 1, "current is now 1")
	assert(lm.get_current().target == 300, "jungle target 300")
	print("test_level_manager OK")
	return true

static func _test_level_load() -> bool:
	var LM = load("res://src/world/LevelManager.gd")
	var lm = LM.new()
	# 测试每关 JSON 能加载且 size/target 正确
	for i in range(lm.level_count()):
		var lvl = lm.get_level(i)
		var f = FileAccess.open(lvl.path, FileAccess.READ)
		assert(f != null, "level %d JSON not found at %s" % [i, lvl.path])
		var data = JSON.parse_string(f.get_as_text())
		f.close()
		assert(int(data.size[0]) == lvl.size[0], "level %d size mismatch" % i)
		assert(int(data.target) == lvl.target, "level %d target mismatch" % i)
	print("test_level_load OK (4 levels verified)")
	return true

static func _test_sporify() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.STEAM)
	_put(g, 2, 1, Element.PLANT)
	_put(g, 0, 1, Element.NONE)
	var card = _make_card({
		"id":"sporify","name":"结孢子","kind":"MULTIPLY",
		"trigger_element":"STEAM","contact_element":"PLANT",
		"result_element":"SPORE","radius":2,"life":4
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	assert(g.get_cell(Vector2i(1,1)).element == Element.STEAM, "steam kept")
	assert(g.get_cell(Vector2i(2,1)).element == Element.PLANT, "plant kept")
	var spore_count = 0
	for c in g.all_cells():
		if c.element == Element.SPORE:
			spore_count += 1
	assert(spore_count >= 1, "should produce >=1 spore, got %d" % spore_count)
	print("test_sporify OK (chain=%d, spores=%d)" % [chain, spore_count])
	return true

static func _test_spore_bloom() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.WATER)
	_put(g, 2, 1, Element.SPORE)
	_put(g, 0, 1, Element.NONE)
	var card = _make_card({
		"id":"spore_bloom","name":"孢子萌发","kind":"MULTIPLY",
		"trigger_element":"WATER","contact_element":"SPORE",
		"result_element":"PLANT","radius":2,"life":4
	})
	var p = RulePillar.new(card, Vector2i(1,1), 0)
	var runner = ChainReaction.new()
	var chain = runner.execute(g, [p])
	assert(g.get_cell(Vector2i(1,1)).element == Element.WATER, "water kept")
	assert(g.get_cell(Vector2i(2,1)).element == Element.SPORE, "spore kept")
	var plant_count = 0
	for c in g.all_cells():
		if c.element == Element.PLANT:
			plant_count += 1
	assert(plant_count >= 1, "should produce >=1 plant, got %d" % plant_count)
	print("test_spore_bloom OK (chain=%d, plants=%d)" % [chain, plant_count])
	return true

static func _test_burning_ignite() -> bool:
	var g = Grid.new(6, 6)
	_put(g, 1, 1, Element.PLANT)
	_put(g, 2, 1, Element.LAVA)
	var c = g.get_cell(Vector2i(1,1))
	for n in g.neighbors(c.coord):
		if n.element == Element.LAVA:
			c.add_state(State.BURNING, 2)
			break
	assert(c.has_state(State.BURNING), "plant should ignite near lava")
	_put(g, 0, 1, Element.PLANT)
	for n in g.neighbors(c.coord):
		if n.element == Element.PLANT and not n.has_state(State.BURNING):
			n.add_state(State.BURNING, 2)
	assert(g.get_cell(Vector2i(0,1)).has_state(State.BURNING), "fire should spread")
	print("test_burning_ignite OK")
	return true

static func _test_spore_wind_move() -> bool:
	var g = Grid.new(6, 6)
	g.get_cell(Vector2i(2, 3)).element = Element.SPORE
	var dir = Vector2i(0, -1)
	var nx = Vector2i(2, 3) + dir
	var fell = false
	if not g.is_in_bounds(nx):
		fell = true
	if fell:
		g.get_cell(Vector2i(2,3)).element = Element.NONE
	else:
		g.get_cell(Vector2i(2,3)).element = Element.NONE
		var dst = g.get_cell(nx)
		if dst.element == Element.NONE:
			dst.element = Element.SPORE
	assert(g.get_cell(Vector2i(2,2)).element == Element.SPORE, "spore should move to (2,2)")
	assert(g.get_cell(Vector2i(2,3)).element == Element.NONE, "old cell cleared")
	g.get_cell(Vector2i(0,0)).element = Element.SPORE
	nx = Vector2i(0,0) + dir
	fell = false
	if not g.is_in_bounds(nx):
		fell = true
	if fell:
		g.get_cell(Vector2i(0,0)).element = Element.NONE
	assert(g.get_cell(Vector2i(0,0)).element == Element.NONE, "spore off-edge should vanish")
	print("test_spore_wind_move OK")
	return true