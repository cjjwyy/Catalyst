class_name ChainReaction
extends RefCounted

const MAX = 1000

signal reaction_applied(reaction)

# 同步执行连锁,返回累计连锁数。reaction_applied 每次触发一个 Reaction 都会发出。
func execute(grid: Grid, pillars: Array) -> int:
	var engine = RuleEngine.new()
	var chain = 0
	var changed: Array = []
	for p in pillars:
		changed.append(p.coord)

	# ponytail: 状态指纹去重, 发现即将进入 cycle (布局重复) 立即终止,
	# 避免 grow/extinct oscillation 无限刷连锁。
	var seen: Dictionary = {}
	var reactions = engine.evaluate_restricted(grid, pillars, changed)
	while not reactions.is_empty() and chain < MAX:
		var snap := _snapshot(grid)
		if seen.has(snap):
			break
		seen[snap] = true
		var new_changed: Array = []
		var any_effect = false
		for r in reactions:
			r.apply(grid)
			if r.affected.size() > 0 and chain > 0 and chain % 5 == 0:
				var empty_dust_cells: Array = []
				for c2 in grid.all_cells():
					if not c2.has_state(State.DUST):
						empty_dust_cells.append(c2)
				if not empty_dust_cells.is_empty():
					empty_dust_cells.pick_random().add_state(State.DUST, 3)
			if r.affected.size() > 0:
				for c in r.affected:
					new_changed.append(c)
				chain += r.card.chain_reward if r.card != null else 1
				reaction_applied.emit(r)
				any_effect = true
		if not any_effect:
			break
		reactions = engine.evaluate_restricted(grid, pillars, new_changed)
	return chain

func _snapshot(grid: Grid) -> String:
	var s := ""
	for c in grid.all_cells():
		s += str(c.element) + ","
	return s

# 异步执行,每次 Reaction 之间等待 frame_delay,供 UI 演示
func execute_async(grid: Grid, pillars: Array, frame_delay: float = 0.1) -> int:
	var engine = RuleEngine.new()
	var chain = 0
	var changed: Array = []
	for p in pillars:
		changed.append(p.coord)

	var seen: Dictionary = {}
	var reactions = engine.evaluate_restricted(grid, pillars, changed)
	while not reactions.is_empty() and chain < MAX:
		var snap := _snapshot(grid)
		if seen.has(snap):
			break
		seen[snap] = true
		var new_changed: Array = []
		var any_effect = false
		for r in reactions:
			r.apply(grid)
			if r.affected.size() > 0 and chain > 0 and chain % 5 == 0:
				var empty_dust_cells: Array = []
				for c2 in grid.all_cells():
					if not c2.has_state(State.DUST):
						empty_dust_cells.append(c2)
				if not empty_dust_cells.is_empty():
					empty_dust_cells.pick_random().add_state(State.DUST, 3)
			if r.affected.size() > 0:
				for c in r.affected:
					new_changed.append(c)
				chain += r.card.chain_reward if r.card != null else 1
				reaction_applied.emit(r)
				any_effect = true
				await Engine.get_main_loop().process_frame
				if frame_delay > 0.0:
					await Engine.get_main_loop().create_timer(frame_delay).timeout
		if not any_effect:
			break
		reactions = engine.evaluate_restricted(grid, pillars, new_changed)
	return chain