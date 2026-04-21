class_name NpcAI
extends RefCounted

## Bomberman NPC — state machine with difficulty tiers
##
## IDLE  → brief pause, prevents re-entering danger
## WANDER → BFS walk toward nearest crate / player / random cell
## FLEE  → follow pre-computed full escape path cell-by-cell
##
## Difficulty: 0=Easy, 1=Medium, 2=Hard

enum State { IDLE, WANDER, FLEE }
enum Difficulty { EASY, MEDIUM, HARD }

const THINK_INTERVALS: Array[float] = [0.25, 0.15, 0.10]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _logic: GameLogic
var _player: GameLogic.PlayerData
var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _difficulty: int = Difficulty.EASY

var _state: int = State.IDLE
var _idle_time: float = 0.5
var _flee_path: Array[Vector2i] = []
var _wander_target: Vector2i = Vector2i(-1, -1)


func _init(logic: GameLogic, player: GameLogic.PlayerData, difficulty: int = Difficulty.EASY) -> void:
	_logic = logic
	_player = player
	_difficulty = difficulty
	_rng.randomize()


# ── 每帧入口 ─────────────────────────────

func tick(dt: float) -> Dictionary:
	if not _player.alive:
		return {"dir": Vector2i.ZERO, "bomb": false}

	_timer -= dt
	if _timer > 0.0:
		return {"dir": Vector2i.ZERO, "bomb": false}
	_timer = THINK_INTERVALS[_difficulty]
	return _think()


func _think() -> Dictionary:
	var gx := int(roundf(_player.gx))
	var gy := int(roundf(_player.gy))
	var pos := Vector2i(gx, gy)
	var danger := _build_danger_map()

	# ── Priority 1: react to danger ──────────
	if danger[gx][gy]:
		if _state != State.FLEE or _flee_path.is_empty():
			_flee_path = _bfs_escape_path(gx, gy, danger)
		_state = State.FLEE

	# ── FLEE ─────────────────────────────────
	if _state == State.FLEE:
		return _do_flee(pos, gx, gy, danger)

	# ── IDLE ─────────────────────────────────
	if _state == State.IDLE:
		_idle_time -= THINK_INTERVALS[_difficulty]
		if _idle_time > 0.0:
			return {"dir": Vector2i.ZERO, "bomb": false}
		_state = State.WANDER
		_wander_target = _pick_wander_target(gx, gy)

	# ── WANDER ───────────────────────────────
	return _do_wander(pos, gx, gy, danger)


# ── FLEE 状态 ────────────────────────────

func _do_flee(pos: Vector2i, gx: int, gy: int, danger: Array) -> Dictionary:
	_pop_reached(pos)

	if _flee_path.is_empty():
		if not danger[gx][gy]:
			_enter_idle()
			return {"dir": Vector2i.ZERO, "bomb": false}
		_flee_path = _bfs_escape_path(gx, gy, danger)
		if _flee_path.is_empty():
			return {"dir": _any_safe_dir(gx, gy, danger), "bomb": false}

	var next: Vector2i = _flee_path[0]
	var d := next - pos
	if d.x < -1 or d.x > 1 or d.y < -1 or d.y > 1 or (d.x != 0 and d.y != 0):
		_flee_path = _bfs_escape_path(gx, gy, danger)
		if _flee_path.is_empty():
			return {"dir": _any_safe_dir(gx, gy, danger), "bomb": false}
		next = _flee_path[0]
		d = next - pos

	if not _logic.walkable_for(next.x, next.y, _player):
		_flee_path = _bfs_escape_path(gx, gy, danger)
		if _flee_path.is_empty():
			return {"dir": _any_safe_dir(gx, gy, danger), "bomb": false}
		next = _flee_path[0]
		d = next - pos

	return {"dir": d, "bomb": false}


# ── WANDER 状态 ──────────────────────────

func _do_wander(pos: Vector2i, gx: int, gy: int, danger: Array) -> Dictionary:
	if _wander_target == Vector2i(-1, -1) or _wander_target == pos:
		var bomb_result := _try_bomb_at(gx, gy, danger)
		if bomb_result.size() > 0:
			return bomb_result
		if _difficulty >= Difficulty.MEDIUM and _is_near_opponent(gx, gy, _player.range_i + 1):
			var bomb_r := _try_bomb_at(gx, gy, danger)
			if bomb_r.size() > 0:
				return bomb_r
		_wander_target = _pick_wander_target(gx, gy)
		if _wander_target == Vector2i(-1, -1):
			return {"dir": Vector2i.ZERO, "bomb": false}

	var step := _bfs_first_step(gx, gy, _wander_target)
	if step == Vector2i.ZERO:
		_wander_target = _random_reachable(gx, gy)
		step = _bfs_first_step(gx, gy, _wander_target) if _wander_target != Vector2i(-1, -1) else Vector2i.ZERO

	if _difficulty >= Difficulty.HARD and _player.has_remote:
		_try_remote_detonate(gx, gy, danger)

	return {"dir": step, "bomb": false}


# ── 放炸弹决策 ───────────────────────────

func _try_bomb_at(gx: int, gy: int, danger: Array) -> Dictionary:
	if _logic.bomb_at(gx, gy) != null:
		return {}
	var bomb_count := 0
	for b in _logic.bombs:
		var bd: GameLogic.BombData = b
		if bd.owner_id == _player.pid:
			bomb_count += 1
	if bomb_count >= _player.max_bombs:
		return {}
	if not _has_bombable_neighbor(gx, gy):
		return {}

	var would := danger.duplicate(true)
	_mark_bomb_danger(would, gx, gy, _player.range_i)
	var path := _bfs_escape_path(gx, gy, would)
	if path.is_empty():
		return {}

	_state = State.FLEE
	_flee_path = path
	var first_step := path[0] - Vector2i(gx, gy)
	return {"dir": first_step, "bomb": true}


func _has_bombable_neighbor(bx: int, by: int) -> bool:
	for d: Vector2i in DIRS:
		for i in range(1, _player.range_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= _logic.cols or ny >= _logic.rows:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.SHRINK_WALL or c == GameLogic.Cell.WATER:
				break
			if c == GameLogic.Cell.TIMED_WALL:
				if not _logic.timed_wall_open.get(Vector2i(nx, ny), false):
					break
			if c == GameLogic.Cell.CRATE or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.MYSTERY_CRATE:
				return true
	return false


# ── BFS 完整逃生路径 ─────────────────────

func _bfs_escape_path(sx: int, sy: int, danger: Array) -> Array[Vector2i]:
	var start := Vector2i(sx, sy)
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			if not _walkable_ignore_own_bomb(nv.x, nv.y):
				continue
			if _logic._gate_blocks(nv.x, nv.y, d.x, d.y):
				continue
			parent[nv] = cur
			if not danger[nv.x][nv.y]:
				return _build_path(parent, nv, start)
			visited[nv] = true
			queue.append(nv)
	return []


func _walkable_ignore_own_bomb(gx: int, gy: int) -> bool:
	if gx < 0 or gy < 0 or gx >= _logic.cols or gy >= _logic.rows:
		return false
	var c: int = _logic.grid[gx][gy]
	if c == GameLogic.Cell.BRIDGE:
		pass
	elif c == GameLogic.Cell.TIMED_WALL:
		if not _logic.timed_wall_open.get(Vector2i(gx, gy), false):
			return false
	elif c != GameLogic.Cell.EMPTY:
		return false
	var b: GameLogic.BombData = _logic.bomb_at(gx, gy)
	if b != null:
		if b.owner_id == _player.pid:
			return true
		return _player.can_stand_on_bomb(gx, gy)
	return true


func _build_path(parent: Dictionary, target: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := target
	while cur != start:
		path.append(cur)
		cur = parent[cur]
	path.reverse()
	return path


# ── BFS 导航（单步） ─────────────────────

func _bfs_first_step(sx: int, sy: int, target: Vector2i) -> Vector2i:
	if sx == target.x and sy == target.y:
		return Vector2i.ZERO
	var start := Vector2i(sx, sy)
	var visited: Dictionary = {start: true}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			parent[nv] = cur
			if nv == target:
				var p := _build_path(parent, nv, start)
				return p[0] - start if p.size() > 0 else Vector2i.ZERO
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			if _logic._gate_blocks(nv.x, nv.y, d.x, d.y):
				continue
			visited[nv] = true
			queue.append(nv)
	return Vector2i.ZERO


# ── 目标选择 ─────────────────────────────

func _pick_wander_target(gx: int, gy: int) -> Vector2i:
	if _difficulty >= Difficulty.MEDIUM:
		var pursue_chance := 0.35 if _difficulty == Difficulty.MEDIUM else 0.60
		if _rng.randf() < pursue_chance:
			var target := _find_nearest_opponent(gx, gy)
			if target != Vector2i(-1, -1):
				return target

	var start := Vector2i(gx, gy)
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var candidates: Array[Vector2i] = []
	var cluster_best: Vector2i = Vector2i(-1, -1)
	var cluster_best_count: int = 0

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if _has_bombable_neighbor(cur.x, cur.y):
			candidates.append(cur)
			if _difficulty >= Difficulty.HARD:
				var count := _count_bombable_neighbors(cur.x, cur.y)
				if count > cluster_best_count:
					cluster_best_count = count
					cluster_best = cur
			if candidates.size() >= 5:
				break
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if visited.has(nv):
				continue
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			visited[nv] = true
			queue.append(nv)

	if _difficulty >= Difficulty.HARD and cluster_best != Vector2i(-1, -1):
		return cluster_best
	if not candidates.is_empty():
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return _random_reachable(gx, gy)


func _random_reachable(gx: int, gy: int) -> Vector2i:
	var cells: Array[Vector2i] = []
	var queue: Array[Vector2i] = [Vector2i(gx, gy)]
	var seen: Dictionary = {Vector2i(gx, gy): true}
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		cells.append(cur)
		for d: Vector2i in DIRS:
			var nv := Vector2i(cur.x + d.x, cur.y + d.y)
			if seen.has(nv):
				continue
			if not _logic.walkable_for(nv.x, nv.y, _player):
				continue
			seen[nv] = true
			queue.append(nv)
	if cells.size() <= 1:
		return Vector2i(-1, -1)
	return cells[_rng.randi_range(1, cells.size() - 1)]


# ── 中/高难度行为 ────────────────────────

func _find_nearest_opponent(gx: int, gy: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	for pl: GameLogic.PlayerData in _logic._all_players():
		if pl.pid == _player.pid or not pl.alive:
			continue
		var dx := absi(int(roundf(pl.gx)) - gx)
		var dy := absi(int(roundf(pl.gy)) - gy)
		var dist := float(dx + dy)
		if dist < best_dist:
			best_dist = dist
			best = Vector2i(int(roundf(pl.gx)), int(roundf(pl.gy)))
	if best_dist > 1.0:
		var approach := _bfs_first_step(gx, gy, best)
		if approach != Vector2i.ZERO:
			return Vector2i(gx + approach.x, gy + approach.y)
	return best


func _is_near_opponent(gx: int, gy: int, radius: int) -> bool:
	for pl: GameLogic.PlayerData in _logic._all_players():
		if pl.pid == _player.pid or not pl.alive:
			continue
		var dx := absi(int(roundf(pl.gx)) - gx)
		var dy := absi(int(roundf(pl.gy)) - gy)
		if dx + dy <= radius:
			return true
	return false


func _count_bombable_neighbors(bx: int, by: int) -> int:
	var count := 0
	for d: Vector2i in DIRS:
		for i in range(1, _player.range_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= _logic.cols or ny >= _logic.rows:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.SHRINK_WALL or c == GameLogic.Cell.WATER:
				break
			if c == GameLogic.Cell.TIMED_WALL:
				if not _logic.timed_wall_open.get(Vector2i(nx, ny), false):
					break
			if c == GameLogic.Cell.CRATE or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.MYSTERY_CRATE:
				count += 1
				break
	return count


func _try_remote_detonate(gx: int, gy: int, danger: Array) -> void:
	if not _player.has_remote:
		return
	for b in _logic.bombs:
		var bd: GameLogic.BombData = b
		if bd.owner_id != _player.pid or not bd.is_remote:
			continue
		for pl: GameLogic.PlayerData in _logic._all_players():
			if pl.pid == _player.pid or not pl.alive:
				continue
			var px := int(roundf(pl.gx))
			var py := int(roundf(pl.gy))
			if _in_blast_range(bd.gx, bd.gy, bd.range_i, px, py):
				if not _in_blast_range(bd.gx, bd.gy, bd.range_i, gx, gy):
					_logic._detonate_remote(_player)
					return


func _in_blast_range(bx: int, by: int, rng_i: int, tx: int, ty: int) -> bool:
	if bx == tx and by == ty:
		return true
	for d: Vector2i in DIRS:
		for i in range(1, rng_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= _logic.cols or ny >= _logic.rows:
				break
			var c: int = _logic.grid[nx][ny]
			if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE \
				or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.SHRINK_WALL \
				or c == GameLogic.Cell.WATER:
				break
			if c == GameLogic.Cell.TIMED_WALL:
				if not _logic.timed_wall_open.get(Vector2i(nx, ny), false):
					break
			if nx == tx and ny == ty:
				return true
	return false


# ── 危险地图 ─────────────────────────────

func _build_danger_map() -> Array:
	var L := _logic
	var map: Array = []
	for x in range(_logic.cols):
		var col: Array = []
		col.resize(_logic.rows)
		col.fill(false)
		map.append(col)
	for b in L.bombs:
		var bd: GameLogic.BombData = b
		_mark_bomb_danger(map, bd.gx, bd.gy, bd.range_i)
	for e in L.explosions:
		var ex: GameLogic.ExplData = e
		if ex.gx >= 0 and ex.gx < _logic.cols and ex.gy >= 0 and ex.gy < _logic.rows:
			map[ex.gx][ex.gy] = true
	if L.avalanche_warn > 0.0 and L.avalanche_edge >= 0:
		_mark_avalanche_danger(map)
	return map


func _blast_blocks(c: int, pos: Vector2i) -> bool:
	if c == GameLogic.Cell.WALL or c == GameLogic.Cell.CRATE \
		or c == GameLogic.Cell.IRON_CRATE or c == GameLogic.Cell.SHRINK_WALL \
		or c == GameLogic.Cell.WATER or c == GameLogic.Cell.ICE_WALL \
		or c == GameLogic.Cell.MYSTERY_CRATE:
		return true
	if c == GameLogic.Cell.TIMED_WALL:
		if not _logic.timed_wall_open.get(pos, false):
			return true
	return false


func _mark_bomb_danger(danger: Array, bx: int, by: int, rng_i: int) -> void:
	danger[bx][by] = true
	for d: Vector2i in DIRS:
		for i in range(1, rng_i + 1):
			var nx: int = bx + d.x * i
			var ny: int = by + d.y * i
			if nx < 0 or ny < 0 or nx >= _logic.cols or ny >= _logic.rows:
				break
			var c: int = _logic.grid[nx][ny]
			if _blast_blocks(c, Vector2i(nx, ny)):
				break
			danger[nx][ny] = true


func _mark_avalanche_danger(danger: Array) -> void:
	var edge: int = _logic.avalanche_edge
	var col_idx: int = _logic.avalanche_col
	var is_horizontal := (edge == 0 or edge == 1)
	for w in range(-1, 2):
		if is_horizontal:
			var y := col_idx + w
			if y >= 0 and y < _logic.rows:
				for x in range(_logic.cols):
					danger[x][y] = true
		else:
			var x := col_idx + w
			if x >= 0 and x < _logic.cols:
				for y in range(_logic.rows):
					danger[x][y] = true


# ── 辅助 ─────────────────────────────────

func _enter_idle() -> void:
	_state = State.IDLE
	_idle_time = _rng.randf_range(0.3, 0.8)
	_flee_path.clear()


func _pop_reached(pos: Vector2i) -> void:
	while not _flee_path.is_empty() and _flee_path[0] == pos:
		_flee_path.remove_at(0)


func _any_safe_dir(gx: int, gy: int, danger: Array) -> Vector2i:
	var shuffled := DIRS.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Vector2i = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for d: Vector2i in shuffled:
		var nx := gx + d.x
		var ny := gy + d.y
		if _logic.walkable_for(nx, ny, _player):
			if not danger[nx][ny]:
				return d
	for d: Vector2i in shuffled:
		if _logic.walkable_for(gx + d.x, gy + d.y, _player):
			return d
	return Vector2i.ZERO
