class_name NpcAI
extends RefCounted

## NPC AI：目标持久化 + 玩家追击 + 智能炸弹 + 防抖

const THINK_INTERVAL := 0.18
const DIRS: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

var _logic: GameLogic
var _player: GameLogic.PlayerData
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()

var _goal: Vector2i = Vector2i(-1, -1)
var _goal_ttl: float = 0.0
var _last_pos: Vector2i = Vector2i(-1, -1)
var _stuck_ticks: int = 0


func _init(logic: GameLogic, player: GameLogic.PlayerData) -> void:
	_logic = logic
	_player = player
	_rng.randomize()


func tick(dt: float) -> Dictionary:
	_timer -= dt
	_goal_ttl -= dt
	if _timer > 0.0:
		return {"dir": Vector2i.ZERO, "bomb": false}
	_timer = THINK_INTERVAL + _rng.randf_range(-0.03, 0.03)
	return _think()


func _think() -> Dictionary:
	if not _player.alive:
		return {"dir": Vector2i.ZERO, "bomb": false}

	var gx := int(roundf(_player.gx))
	var gy := int(roundf(_player.gy))
	var pos := Vector2i(gx, gy)

	if pos == _last_pos:
		_stuck_ticks += 1
	else:
		_stuck_ticks = 0
	_last_pos = pos

	var danger := _build_danger_map()
	var on_danger: bool = danger[gx][gy]

	if on_danger:
		_goal = Vector2i(-1, -1)
		var safe_dir := _find_safe_dir(gx, gy, danger)
		if safe_dir != Vector2i.ZERO:
			return {"dir": safe_dir, "bomb": false}
		return {"dir": _find_any_walkable_dir(gx, gy), "bomb": false}

	if _should_place_bomb_smart(gx, gy, danger):
		_goal = Vector2i(-1, -1)
		return {"dir": Vector2i.ZERO, "bomb": true}

	if _goal_ttl <= 0.0 or _goal == pos or _goal == Vector2i(-1, -1) or _stuck_ticks >= 4:
		_pick_goal(gx, gy)
		_stuck_ticks = 0

	if _goal != Vector2i(-1, -1):
		var dir := _bfs_first_step(gx, gy, _goal)
		if dir != Vector2i.ZERO:
			return {"dir": dir, "bomb": false}
		_goal = Vector2i(-1, -1)

	return {"dir": _find_any_walkable_dir(gx, gy), "bomb": false}


# ── 目标选择 ─────────────────────────────

func _pick_goal(gx: int, gy: int) -> void:
	var bomb_spot := _find_bomb_spot(gx, gy)
	if bomb_spot != Vector2i(-1, -1):
		_goal = bomb_spot
		_goal_ttl = 2.5
		return

	var chase := _find_player_approach(gx, gy)
	if chase != Vector2i(-1, -1):
		_goal = chase
		_goal_ttl = 2.0
		return

	_goal = _random_reachable(gx, gy)
	_goal_ttl = 1.2


func _find_bomb_spot(gx: int, gy: int) -> Vector2i:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(gx, gy)]
	visited[Vector2i(gx, gy)] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if _has_bombable_target(cur.x, cur.y):
			return cur
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			visited[nv] = true
			queue.append(nv)
	return Vector2i(-1, -1)


func _has_bombable_target(bx: int, by: int) -> bool:
	for d: Vector2i in DIRS:
		for i in range(1, _player.range_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.SHRINK_WALL:
				break
			if c == GameLogic.Cell.CRATE or c == GameLogic.Cell.IRON_CRATE:
				return true
	return false


func _find_player_approach(gx: int, gy: int) -> Vector2i:
	var enemies: Array[Vector2i] = _get_enemy_positions()
	if enemies.is_empty():
		return Vector2i(-1, -1)
	var best := enemies[0]
	var best_d := absi(gx - best.x) + absi(gy - best.y)
	for i in range(1, enemies.size()):
		var d := absi(gx - enemies[i].x) + absi(gy - enemies[i].y)
		if d < best_d:
			best_d = d
			best = enemies[i]
	var candidates: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		for r in range(1, _player.range_i + 1):
			var cx: int = best.x + d.x * r
			var cy: int = best.y + d.y * r
			if cx < 0 or cy < 0 or cx >= GameLogic.COLS or cy >= GameLogic.ROWS:
				break
			if _logic.grid[cx][cy] != GameLogic.Cell.EMPTY:
				break
			candidates.append(Vector2i(cx, cy))
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var pick := candidates[0]
	var pick_d := absi(gx - pick.x) + absi(gy - pick.y)
	for i in range(1, candidates.size()):
		var cd := absi(gx - candidates[i].x) + absi(gy - candidates[i].y)
		if cd < pick_d:
			pick_d = cd
			pick = candidates[i]
	return pick


func _get_enemy_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _logic.p1.alive and _logic.p1.pid != _player.pid:
		out.append(Vector2i(int(roundf(_logic.p1.gx)), int(roundf(_logic.p1.gy))))
	if _logic.p2.alive and _logic.p2.pid != _player.pid:
		out.append(Vector2i(int(roundf(_logic.p2.gx)), int(roundf(_logic.p2.gy))))
	return out


func _random_reachable(gx: int, gy: int) -> Vector2i:
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [Vector2i(gx, gy)]
	var seen: Dictionary = {Vector2i(gx, gy): true}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		visited.append(cur)
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if seen.has(nv):
				continue
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			seen[nv] = true
			queue.append(nv)
	if visited.size() <= 1:
		return Vector2i(-1, -1)
	var idx := _rng.randi_range(maxi(1, visited.size() / 3), visited.size() - 1)
	return visited[idx]


# ── BFS 导航 ─────────────────────────────

func _bfs_first_step(sx: int, sy: int, target: Vector2i) -> Vector2i:
	if sx == target.x and sy == target.y:
		return Vector2i.ZERO
	var start := Vector2i(sx, sy)
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == target:
			return _trace_back(parent, cur, start)
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			if nv == target:
				parent[nv] = cur
				return _trace_back(parent, nv, start)
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			visited[nv] = true
			parent[nv] = cur
			queue.append(nv)
	return Vector2i.ZERO


func _trace_back(parent: Dictionary, target: Vector2i, start: Vector2i) -> Vector2i:
	var cur := target
	while parent.has(cur) and parent[cur] != start:
		cur = parent[cur]
	if cur == start:
		return Vector2i.ZERO
	return cur - start


# ── 炸弹决策 ─────────────────────────────

func _should_place_bomb_smart(gx: int, gy: int, danger: Array) -> bool:
	if _logic.bomb_at(gx, gy) != null:
		return false
	var has_target := _has_bombable_target(gx, gy) or _player_in_blast(gx, gy)
	if not has_target:
		return false
	return _can_escape(gx, gy, danger)


func _player_in_blast(bx: int, by: int) -> bool:
	var enemies := _get_enemy_positions()
	for d: Vector2i in DIRS:
		for i in range(1, _player.range_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
				break
			var c: int = _logic.grid[nx][ny]
			if c != GameLogic.Cell.EMPTY:
				break
			var p := Vector2i(nx, ny)
			for e: Vector2i in enemies:
				if e == p:
					return true
	return false


func _can_escape(gx: int, gy: int, danger: Array) -> bool:
	var would := danger.duplicate(true)
	_mark_bomb_danger(would, gx, gy, _player.range_i)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var nv := Vector2i(gx + d.x, gy + d.y)
		if _logic.walkable_for(nv.x, nv.y, _player):
			if not would[nv.x][nv.y]:
				return true
			visited[nv] = true
			queue.append(nv)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			if not would[nv.x][nv.y]:
				return true
			visited[nv] = true
			if visited.size() < 12:
				queue.append(nv)
	return false


# ── 危险地图 ─────────────────────────────

func _build_danger_map() -> Array:
	var L := _logic
	var map: Array = []
	for x in range(GameLogic.COLS):
		var col: Array = []
		col.resize(GameLogic.ROWS)
		col.fill(false)
		map.append(col)
	for b in L.bombs:
		var bd: GameLogic.BombData = b
		map[bd.gx][bd.gy] = true
		for d: Vector2i in DIRS:
			for i in range(1, bd.range_i + 1):
				var nx: int = bd.gx + d.x * i
				var ny: int = bd.gy + d.y * i
				if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
					break
				var c: int = L.grid[nx][ny]
				if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.SHRINK_WALL:
					break
				map[nx][ny] = true
	return map


func _mark_bomb_danger(danger: Array, bx: int, by: int, rng_i: int) -> void:
	danger[bx][by] = true
	for d: Vector2i in DIRS:
		for i in range(1, rng_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.SHRINK_WALL:
				break
			danger[nx][ny] = true


func _find_safe_dir(gx: int, gy: int, danger: Array) -> Vector2i:
	var best_dir := Vector2i.ZERO
	var best_dist := 999
	var shuffled := DIRS.duplicate()
	_shuffle_dirs(shuffled)
	for d: Vector2i in shuffled:
		var nx: int = gx + d.x
		var ny: int = gy + d.y
		if not _logic.walkable_for(nx, ny, _player):
			continue
		if not danger[nx][ny]:
			return d
		for i in range(2, 6):
			var fx: int = gx + d.x * i
			var fy: int = gy + d.y * i
			if fx < 0 or fy < 0 or fx >= GameLogic.COLS or fy >= GameLogic.ROWS:
				break
			if _logic.grid[fx][fy] != GameLogic.Cell.EMPTY:
				break
			if not danger[fx][fy]:
				if i < best_dist:
					best_dist = i
					best_dir = d
				break
	return best_dir


func _find_any_walkable_dir(gx: int, gy: int) -> Vector2i:
	var shuffled := DIRS.duplicate()
	_shuffle_dirs(shuffled)
	for d: Vector2i in shuffled:
		if _logic.walkable_for(gx + d.x, gy + d.y, _player):
			return d
	return Vector2i.ZERO


func _shuffle_dirs(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
