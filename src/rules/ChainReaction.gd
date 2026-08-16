class_name ChainReaction
extends RefCounted

const MAX = 1000

signal reaction_applied(reaction)

var cancelled: bool = false  # T2.5: 由 GameManager 在 start_game 时置位, 中止旧演化协程

# 同步执行连锁,返回累计连锁数。reaction_applied 每次触发一个 Reaction 都会发出。
# rng: 可选随机源; GameManager 传入可播种的 GameManager.rng, 使催化剂尘播撒确定化(测试基准可复现)。
func execute(grid: Grid, pillars: Array, turn: int = 0, rng: RandomNumberGenerator = null) -> int:
	var engine = RuleEngine.new()
	var chain = 0
	var changed: Array = []
	for p in pillars:
		changed.append(p.coord)

	# ponytail: 状态指纹去重, 发现即将进入 cycle (布局重复) 立即终止,
	# 避免 grow/extinct oscillation 无限刷连锁。
	var seen: Dictionary = {}
	var reactions = engine.evaluate_restricted(grid, pillars, changed)
	while not reactions.is_empty() and chain < MAX and not cancelled:
		var snap := _snapshot_hash(grid)
		if seen.has(snap):
			break
		seen[snap] = true
		var new_changed: Array = []
		var any_effect = false
		var blessed_before: Dictionary = {}
		for cc in grid.all_cells():
			if cc.has_state(State.BLESSED):
				blessed_before[cc.coord] = true
		for r in reactions:
			if cancelled:
				return chain
			r.apply(grid, turn)
			if r.card != null and r.card.add_state == State.BLESSED:
				for bc in r.affected:
					if grid.get_cell(bc) != null and grid.get_cell(bc).has_state(State.BLESSED):
						blessed_before[bc] = true
			if r.affected.size() > 0 and chain > 0 and chain % 5 == 0:
				_spawn_dust(grid, rng)
			if r.affected.size() > 0:
				for c in r.affected:
					new_changed.append(c)
				var reward = r.card.chain_reward if r.card != null else 1
				for coord in r.affected:
					if blessed_before.has(coord):
						reward *= 2
						break
				chain += reward
				reaction_applied.emit(r)
				any_effect = true
		if not any_effect:
			break
		reactions = engine.evaluate_restricted(grid, pillars, new_changed)
	return chain

func _snapshot_hash(grid: Grid) -> int:
	var s := ""
	for c in grid.all_cells():
		s += str(c.element) + ","
	return hash(s)

func _spawn_dust(grid: Grid, rng: RandomNumberGenerator) -> void:
	var empty_dust_cells: Array = []
	for c in grid.all_cells():
		if not c.has_state(State.DUST):
			empty_dust_cells.append(c)
	# 每次播撒 3 粒尘,形成簇状
	if rng != null:
		for _i in range(min(3, empty_dust_cells.size())):
			empty_dust_cells[rng.randi_range(0, empty_dust_cells.size() - 1)].add_state(State.DUST, 5)
	else:
		for _i in range(min(3, empty_dust_cells.size())):
			empty_dust_cells.pick_random().add_state(State.DUST, 5)
			empty_dust_cells.shuffle()

# 异步执行,每次 Reaction 之间等待 frame_delay,供 UI 演示
# speed: 动画倍速(>0), <=0 表示跳过动画, 同步结算(仍逐条发 reaction_applied)
func execute_async(grid: Grid, pillars: Array, frame_delay: float = 0.1, speed: float = 1.0, turn: int = 0, rng: RandomNumberGenerator = null) -> int:
	if speed <= 0.0:
		return execute(grid, pillars, turn, rng)
	var engine = RuleEngine.new()
	var chain = 0
	var changed: Array = []
	for p in pillars:
		changed.append(p.coord)

	var seen: Dictionary = {}
	var reactions = engine.evaluate_restricted(grid, pillars, changed)
	while not reactions.is_empty() and chain < MAX and not cancelled:
		var snap := _snapshot_hash(grid)
		if seen.has(snap):
			break
		seen[snap] = true
		var new_changed: Array = []
		var any_effect = false
		var blessed_before: Dictionary = {}
		for cc in grid.all_cells():
			if cc.has_state(State.BLESSED):
				blessed_before[cc.coord] = true
		for r in reactions:
			if cancelled:
				return chain
			r.apply(grid, turn)
			if r.card != null and r.card.add_state == State.BLESSED:
				for bc in r.affected:
					if grid.get_cell(bc) != null and grid.get_cell(bc).has_state(State.BLESSED):
						blessed_before[bc] = true
			if r.affected.size() > 0 and chain > 0 and chain % 5 == 0:
				_spawn_dust(grid, rng)
			if r.affected.size() > 0:
				for c in r.affected:
					new_changed.append(c)
				var reward = r.card.chain_reward if r.card != null else 1
				for coord in r.affected:
					if blessed_before.has(coord):
						reward *= 2
						break
				chain += reward
				reaction_applied.emit(r)
				any_effect = true
				await Engine.get_main_loop().process_frame
				if frame_delay > 0.0:
					await Engine.get_main_loop().create_timer(frame_delay / speed).timeout
				if cancelled:
					return chain
		if not any_effect:
			break
		reactions = engine.evaluate_restricted(grid, pillars, new_changed)
	return chain
