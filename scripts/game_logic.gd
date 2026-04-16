class_name GameLogic
extends RefCounted

## 纯游戏状态 + 规则，零 Node / 零 UI 依赖，方便单元测试。

const COLS := 15
const ROWS := 11
const BASE_SPEED := 5.0
const MAX_SPEED := 9.5
const SPEED_PER_SHOE := 1.2
const BOMB_FUSE := 2.4
const EXPLOSION_TTL := 0.45
const DROP_CHANCE := 0.55
const BOMB_SLIDE_INTERVAL := 0.06

enum Cell { EMPTY, WALL, CRATE }
enum Phase { PLAYING, P1_WIN, P2_WIN, DRAW }
enum Pickup { BOMB_UP, FIRE_UP, SPEED_UP, KICK, REMOTE }


class PlayerData:
	var pid: int
	var gx: float
	var gy: float
	var alive: bool = true
	var max_bombs: int = 1
	var range_i: int = 1
	var speed_ups: int = 0
	var has_kick: bool = false
	var has_remote: bool = false
	var last_bomb: Vector2i = Vector2i(999999, 999999)
	var moving: bool = false
	var target_gx: float = 0.0
	var target_gy: float = 0.0

	func _init(p_pid: int, sx: int, sy: int) -> void:
		pid = p_pid
		gx = float(sx)
		gy = float(sy)
		target_gx = gx
		target_gy = gy

	func reset(sx: int, sy: int) -> void:
		gx = float(sx)
		gy = float(sy)
		target_gx = gx
		target_gy = gy
		alive = true
		max_bombs = 1
		range_i = 1
		speed_ups = 0
		has_kick = false
		has_remote = false
		last_bomb = Vector2i(999999, 999999)
		moving = false

	func move_speed() -> float:
		return minf(GameLogic.BASE_SPEED + speed_ups * GameLogic.SPEED_PER_SHOE, GameLogic.MAX_SPEED)

	func aligned() -> bool:
		return (not moving) \
			and absf(gx - roundf(gx)) < 0.02 \
			and absf(gy - roundf(gy)) < 0.02

	func can_stand_on_bomb(bx: int, by: int) -> bool:
		return last_bomb.x == bx and last_bomb.y == by

	func note_placed_bomb(bx: int, by: int) -> void:
		last_bomb = Vector2i(bx, by)


class BombData:
	var gx: int
	var gy: int
	var owner_id: int
	var time: float
	var range_i: int
	var is_remote: bool = false
	var moving: bool = false
	var move_dir: Vector2i = Vector2i.ZERO
	var move_timer: float = 0.0

	func _init(p_gx: int, p_gy: int, oid: int, fuse: float, rng: int) -> void:
		gx = p_gx
		gy = p_gy
		owner_id = oid
		time = fuse
		range_i = rng


class ExplData:
	var gx: int
	var gy: int
	var ttl: float

	func _init(x: int, y: int, t: float) -> void:
		gx = x
		gy = y
		ttl = t


class PickupData:
	var gx: int
	var gy: int
	var kind: int

	func _init(x: int, y: int, k: int) -> void:
		gx = x
		gy = y
		kind = k


# ── 每帧事件队列（view 层读取后清空，避免 signal 依赖）──

enum Event { BOMB_PLACED, EXPLOSION, PICKUP_COLLECTED, PHASE_END, BOMB_KICKED, REMOTE_DETONATE }

class GameEvent:
	var type: int
	var data: Dictionary
	func _init(t: int, d: Dictionary = {}) -> void:
		type = t
		data = d

var events: Array = []


# ── 公开状态 ──────────────────────────────

var rng := RandomNumberGenerator.new()
var grid: Array = []
var p1: PlayerData
var p2: PlayerData
var bombs: Array = []
var explosions: Array = []
var pickups: Array = []
var phase: int = Phase.PLAYING
var _map: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	p1 = PlayerData.new(0, 1, 1)
	p2 = PlayerData.new(1, COLS - 2, ROWS - 2)


func reset(map: Dictionary = {}) -> void:
	_map = map
	phase = Phase.PLAYING
	bombs.clear()
	explosions.clear()
	pickups.clear()
	events.clear()
	_build_grid()
	var spawns: Array = _map.get("spawns", [Vector2i(1, 1), Vector2i(COLS - 2, ROWS - 2)])
	if spawns.size() >= 1:
		p1.reset(spawns[0].x, spawns[0].y)
	else:
		p1.reset(1, 1)
	if spawns.size() >= 2:
		p2.reset(spawns[1].x, spawns[1].y)
	else:
		p2.reset(COLS - 2, ROWS - 2)


# ── 网格生成 ──────────────────────────────

func _build_grid() -> void:
	grid.clear()
	for x in range(COLS):
		var col: Array = []
		col.resize(ROWS)
		grid.append(col)
	var template: Array = _map.get("template", [])
	var density: float = _map.get("crate_density", 0.52)
	if template.size() == ROWS:
		_build_from_template(template, density)
	else:
		_build_default_grid(density)
	_carve_reachable_crates()


func _build_from_template(template: Array, density: float) -> void:
	for x in range(COLS):
		for y in range(ROWS):
			var row: String = template[y]
			if x < row.length() and row[x] == "#":
				grid[x][y] = Cell.WALL
			else:
				grid[x][y] = Cell.EMPTY
	var spawns: Array = _map.get("spawns", [])
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			if _is_near_any_spawn(x, y, spawns):
				continue
			if rng.randf() < density:
				grid[x][y] = Cell.CRATE


func _build_default_grid(density: float) -> void:
	for x in range(COLS):
		for y in range(ROWS):
			var border := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			if border:
				grid[x][y] = Cell.WALL
			elif (x + y) % 2 == 0 and x > 1 and x < COLS - 2 and y > 1 and y < ROWS - 2:
				grid[x][y] = Cell.WALL
			else:
				grid[x][y] = Cell.EMPTY
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			if _is_spawn_zone(x, y):
				continue
			if rng.randf() < density:
				grid[x][y] = Cell.CRATE


func _is_spawn_zone(x: int, y: int) -> bool:
	return (x <= 2 and y <= 2) or (x >= COLS - 3 and y >= ROWS - 3)


func _is_near_any_spawn(x: int, y: int, spawns: Array) -> bool:
	for s in spawns:
		var sp: Vector2i = s
		if absi(x - sp.x) <= 1 and absi(y - sp.y) <= 1:
			return true
	return false


func _carve_reachable_crates() -> void:
	var reach: Dictionary = {}
	var spawns: Array = _map.get("spawns", [Vector2i(1, 1), Vector2i(COLS - 2, ROWS - 2)])
	for s in spawns:
		var sp: Vector2i = s
		if sp.x > 0 and sp.x < COLS and sp.y > 0 and sp.y < ROWS:
			_bfs_reachable(sp.x, sp.y, reach)
	for x in range(1, COLS - 1):
		for y in range(1, ROWS - 1):
			if grid[x][y] == Cell.CRATE and not reach.has(Vector2i(x, y)):
				grid[x][y] = Cell.EMPTY


func _bfs_reachable(sx: int, sy: int, reach: Dictionary) -> void:
	var q: Array[Vector2i] = [Vector2i(sx, sy)]
	reach[Vector2i(sx, sy)] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in dirs:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS:
				continue
			if grid[n.x][n.y] == Cell.WALL:
				continue
			if reach.has(n):
				continue
			reach[n] = true
			if grid[n.x][n.y] == Cell.EMPTY:
				q.append(n)


# ── 玩家 ─────────────────────────────────

func try_start_move(pl: PlayerData, dx: int, dy: int) -> bool:
	if dx == 0 and dy == 0:
		return false
	if pl.moving or not pl.aligned():
		return false
	var sx := int(roundf(pl.gx))
	var sy := int(roundf(pl.gy))
	var tx := sx + dx
	var ty := sy + dy
	if not walkable_for(tx, ty, pl):
		if pl.has_kick:
			var b: BombData = bomb_at(tx, ty)
			if b != null and not b.moving:
				_kick_bomb(b, Vector2i(dx, dy))
		return false
	pl.gx = float(sx)
	pl.gy = float(sy)
	pl.target_gx = float(tx)
	pl.target_gy = float(ty)
	pl.moving = true
	pl.last_bomb = Vector2i(999999, 999999)
	return true


func player_move_tick(pl: PlayerData, dt: float) -> void:
	if not pl.alive:
		return
	if pl.moving:
		var dx := pl.target_gx - pl.gx
		var dy := pl.target_gy - pl.gy
		var len := sqrt(dx * dx + dy * dy)
		var step := pl.move_speed() * dt
		if len <= 0.0001 or step >= len:
			pl.gx = pl.target_gx
			pl.gy = pl.target_gy
			pl.moving = false
		else:
			pl.gx += dx / len * step
			pl.gy += dy / len * step
	var igx := int(roundf(pl.gx))
	var igy := int(roundf(pl.gy))
	if bomb_at(igx, igy) == null:
		pl.last_bomb = Vector2i(999999, 999999)


func update_player(pl: PlayerData, dir: Vector2i, want_bomb: bool, dt: float) -> void:
	if not pl.alive:
		return
	if dir != Vector2i.ZERO:
		try_start_move(pl, dir.x, dir.y)
	player_move_tick(pl, dt)
	try_collect_pickup(pl)
	if want_bomb:
		try_place_bomb(pl)


func walkable_for(gx: int, gy: int, pl: PlayerData) -> bool:
	if gx < 0 or gy < 0 or gx >= COLS or gy >= ROWS:
		return false
	if grid[gx][gy] != Cell.EMPTY:
		return false
	var b: BombData = bomb_at(gx, gy)
	if b != null:
		return pl.can_stand_on_bomb(gx, gy)
	return true


# ── 炸弹 ─────────────────────────────────

func bomb_at(gx: int, gy: int) -> BombData:
	for b in bombs:
		var bd: BombData = b
		if bd.gx == gx and bd.gy == gy:
			return bd
	return null


func try_place_bomb(pl: PlayerData) -> void:
	if not pl.alive or phase != Phase.PLAYING:
		return
	if not pl.aligned():
		return
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	if bomb_at(gx, gy) != null:
		if pl.has_remote:
			_detonate_remote(pl)
		return
	if _active_bombs_for(pl.pid) >= pl.max_bombs:
		if pl.has_remote:
			_detonate_remote(pl)
		return
	var bd := BombData.new(gx, gy, pl.pid, BOMB_FUSE, pl.range_i)
	if pl.has_remote:
		bd.is_remote = true
		bd.time = 9999.0
	bombs.append(bd)
	pl.note_placed_bomb(gx, gy)
	events.append(GameEvent.new(Event.BOMB_PLACED, {"pid": pl.pid}))


func _detonate_remote(pl: PlayerData) -> void:
	var found := false
	for b_item in bombs:
		var b: BombData = b_item
		if b.owner_id == pl.pid and b.is_remote:
			b.time = 0.0
			b.moving = false
			found = true
	if found:
		events.append(GameEvent.new(Event.REMOTE_DETONATE, {"pid": pl.pid}))


func _active_bombs_for(pid: int) -> int:
	var n := 0
	for b in bombs:
		var bd: BombData = b
		if bd.owner_id == pid:
			n += 1
	return n


func _kick_bomb(b: BombData, dir: Vector2i) -> void:
	b.moving = true
	b.move_dir = dir
	b.move_timer = BOMB_SLIDE_INTERVAL
	events.append(GameEvent.new(Event.BOMB_KICKED, {"gx": b.gx, "gy": b.gy}))


func tick_moving_bombs(dt: float) -> void:
	for b_item in bombs:
		var b: BombData = b_item
		if not b.moving:
			continue
		b.move_timer -= dt
		if b.move_timer > 0.0:
			continue
		b.move_timer += BOMB_SLIDE_INTERVAL
		var nx: int = b.gx + b.move_dir.x
		var ny: int = b.gy + b.move_dir.y
		if _bomb_slide_blocked(nx, ny):
			b.moving = false
			b.move_dir = Vector2i.ZERO
		else:
			b.gx = nx
			b.gy = ny


func _bomb_slide_blocked(gx: int, gy: int) -> bool:
	if gx < 0 or gy < 0 or gx >= COLS or gy >= ROWS:
		return true
	if grid[gx][gy] != Cell.EMPTY:
		return true
	if bomb_at(gx, gy) != null:
		return true
	return false


func tick_bombs(dt: float) -> void:
	if bombs.is_empty():
		return
	for b in bombs:
		var bd: BombData = b
		bd.time -= dt
	while true:
		var next: BombData = null
		for b in bombs:
			var bd: BombData = b
			if bd.time <= 0.0:
				next = bd
				break
		if next == null:
			break
		_explode_bomb_wave(next)


func _explode_bomb_wave(seed_bomb: BombData) -> void:
	var q: Array = [seed_bomb]
	while not q.is_empty():
		var b: BombData = q.pop_front()
		if not bombs.has(b):
			continue
		bombs.erase(b)
		_explode_single(b, q)


func _explode_single(b: BombData, q: Array) -> void:
	events.append(GameEvent.new(Event.EXPLOSION, {"gx": b.gx, "gy": b.gy}))
	_blast_cell(b.gx, b.gy, q)
	_spread_blast(b.gx, b.gy, 1, 0, b.range_i, q)
	_spread_blast(b.gx, b.gy, -1, 0, b.range_i, q)
	_spread_blast(b.gx, b.gy, 0, 1, b.range_i, q)
	_spread_blast(b.gx, b.gy, 0, -1, b.range_i, q)


func _spread_blast(ox: int, oy: int, dx: int, dy: int, range_i: int, q: Array) -> void:
	for i in range(1, range_i + 1):
		var x := ox + dx * i
		var y := oy + dy * i
		if x < 0 or y < 0 or x >= COLS or y >= ROWS:
			break
		var c: int = grid[x][y]
		if c == Cell.WALL:
			break
		var stop := _blast_cell(x, y, q)
		if c == Cell.CRATE:
			grid[x][y] = Cell.EMPTY
			_maybe_drop_pickup(x, y)
			break
		if stop:
			break


func _blast_cell(x: int, y: int, q: Array) -> bool:
	explosions.append(ExplData.new(x, y, EXPLOSION_TTL))
	_damage_at(x, y)
	_destroy_pickups_at(x, y)
	var other: BombData = bomb_at(x, y)
	if other != null:
		if other.time > 0.0:
			other.time = 0.0
			other.moving = false
			q.append(other)
		return true
	var c: int = grid[x][y]
	return c == Cell.WALL or c == Cell.CRATE


func _damage_at(x: int, y: int) -> void:
	if p1.alive and int(roundf(p1.gx)) == x and int(roundf(p1.gy)) == y:
		p1.alive = false
	if p2.alive and int(roundf(p2.gx)) == x and int(roundf(p2.gy)) == y:
		p2.alive = false


# ── 爆炸 ─────────────────────────────────

func tick_explosions(dt: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var e: ExplData = explosions[i]
		e.ttl -= dt
		if e.ttl <= 0.0:
			explosions.remove_at(i)


# ── 道具 ─────────────────────────────────

func _maybe_drop_pickup(x: int, y: int) -> void:
	if rng.randf() > DROP_CHANCE:
		return
	var roll := rng.randf()
	var kind: int
	if roll < 0.28:
		kind = Pickup.BOMB_UP
	elif roll < 0.52:
		kind = Pickup.FIRE_UP
	elif roll < 0.72:
		kind = Pickup.SPEED_UP
	elif roll < 0.86:
		kind = Pickup.KICK
	else:
		kind = Pickup.REMOTE
	pickups.append(PickupData.new(x, y, kind))


func pickup_at(gx: int, gy: int) -> PickupData:
	for p in pickups:
		var pd: PickupData = p
		if pd.gx == gx and pd.gy == gy:
			return pd
	return null


func try_collect_pickup(pl: PlayerData) -> void:
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	var pd: PickupData = pickup_at(gx, gy)
	if pd == null:
		return
	match pd.kind:
		Pickup.BOMB_UP:
			pl.max_bombs = mini(pl.max_bombs + 1, 8)
		Pickup.FIRE_UP:
			pl.range_i = mini(pl.range_i + 1, 8)
		Pickup.SPEED_UP:
			pl.speed_ups = mini(pl.speed_ups + 1, 5)
		Pickup.KICK:
			pl.has_kick = true
		Pickup.REMOTE:
			pl.has_remote = true
	events.append(GameEvent.new(Event.PICKUP_COLLECTED, {"pid": pl.pid, "kind": pd.kind}))
	pickups.erase(pd)


func _destroy_pickups_at(x: int, y: int) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pd: PickupData = pickups[i]
		if pd.gx == x and pd.gy == y:
			pickups.remove_at(i)


# ── 胜负 ─────────────────────────────────

func resolve_phase() -> void:
	if phase != Phase.PLAYING:
		return
	if p1.alive and not p2.alive:
		phase = Phase.P1_WIN
	elif p2.alive and not p1.alive:
		phase = Phase.P2_WIN
	elif not p1.alive and not p2.alive:
		phase = Phase.DRAW
	if phase != Phase.PLAYING:
		events.append(GameEvent.new(Event.PHASE_END, {"phase": phase}))
