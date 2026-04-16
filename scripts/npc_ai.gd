class_name NpcAI
extends RefCounted

## 简单 NPC AI：危险格评估 + 寻安全格 + 主动放雷

const THINK_INTERVAL := 0.25
const DIRS: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

var _logic: GameLogic
var _player: GameLogic.PlayerData
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(logic: GameLogic, player: GameLogic.PlayerData) -> void:
	_logic = logic
	_player = player
	_rng.randomize()


func tick(dt: float) -> Dictionary:
	_timer -= dt
	if _timer > 0.0:
		return {"dir": Vector2i.ZERO, "bomb": false}
	_timer = THINK_INTERVAL + _rng.randf_range(-0.06, 0.06)
	return _think()


func _think() -> Dictionary:
	if not _player.alive:
		return {"dir": Vector2i.ZERO, "bomb": false}

	var danger := _build_danger_map()
	var gx := int(roundf(_player.gx))
	var gy := int(roundf(_player.gy))
	var on_danger: bool = danger[gx][gy]

	if on_danger:
		var safe_dir := _find_safe_dir(gx, gy, danger)
		if safe_dir != Vector2i.ZERO:
			return {"dir": safe_dir, "bomb": false}
		return {"dir": _find_any_walkable_dir(gx, gy), "bomb": false}

	if _should_place_bomb(gx, gy, danger):
		return {"dir": Vector2i.ZERO, "bomb": true}

	var crate_dir := _dir_toward_nearest_crate(gx, gy)
	if crate_dir != Vector2i.ZERO:
		return {"dir": crate_dir, "bomb": false}

	return {"dir": _random_walkable_dir(gx, gy), "bomb": false}


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
				if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE:
					break
				map[nx][ny] = true
	return map


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
		for i in range(2, 5):
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


func _should_place_bomb(gx: int, gy: int, danger: Array) -> bool:
	if _logic.bomb_at(gx, gy) != null:
		return false
	var has_target := false
	for d: Vector2i in DIRS:
		var nx: int = gx + d.x
		var ny: int = gy + d.y
		if nx >= 0 and ny >= 0 and nx < GameLogic.COLS and ny < GameLogic.ROWS:
			if _logic.grid[nx][ny] == GameLogic.Cell.CRATE:
				has_target = true
				break
	if not has_target:
		return false
	var would_danger := danger.duplicate(true)
	_mark_bomb_danger(would_danger, gx, gy, _player.range_i)
	for d: Vector2i in DIRS:
		var nx: int = gx + d.x
		var ny: int = gy + d.y
		if not _logic.walkable_for(nx, ny, _player):
			continue
		if not would_danger[nx][ny]:
			return true
		for i in range(2, 5):
			var fx: int = gx + d.x * i
			var fy: int = gy + d.y * i
			if fx < 0 or fy < 0 or fx >= GameLogic.COLS or fy >= GameLogic.ROWS:
				break
			if _logic.grid[fx][fy] != GameLogic.Cell.EMPTY:
				break
			if not would_danger[fx][fy]:
				return true
	return false


func _mark_bomb_danger(danger: Array, bx: int, by: int, rng_i: int) -> void:
	danger[bx][by] = true
	for d: Vector2i in DIRS:
		for i in range(1, rng_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE:
				break
			danger[nx][ny] = true


func _dir_toward_nearest_crate(gx: int, gy: int) -> Vector2i:
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(gx, gy)]
	visited[Vector2i(gx, gy)] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or ny < 0 or nx >= GameLogic.COLS or ny >= GameLogic.ROWS:
				continue
			if _logic.grid[nx][ny] == GameLogic.Cell.CRATE:
				return _trace_first_step(parent, cur, Vector2i(gx, gy))
			var nv := Vector2i(nx, ny)
			if visited.has(nv):
				continue
			if not _logic.walkable_for(nx, ny, _player):
				continue
			visited[nv] = true
			parent[nv] = cur
			queue.append(nv)
	return Vector2i.ZERO


func _trace_first_step(parent: Dictionary, target: Vector2i, start: Vector2i) -> Vector2i:
	var cur := target
	while parent.has(cur) and parent[cur] != start:
		cur = parent[cur]
	if cur == start:
		return Vector2i.ZERO
	return cur - start


func _random_walkable_dir(gx: int, gy: int) -> Vector2i:
	if _rng.randf() < 0.3:
		return Vector2i.ZERO
	return _find_any_walkable_dir(gx, gy)


func _shuffle_dirs(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
