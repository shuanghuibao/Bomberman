class_name GameLogic
extends RefCounted

## 纯游戏状态 + 规则，零 Node / 零 UI 依赖，方便单元测试。

const DEFAULT_COLS := 15
const DEFAULT_ROWS := 11
const BASE_SPEED := 5.0
const MAX_SPEED := 9.5
const SPEED_PER_SHOE := 1.2
const BOMB_FUSE := 2.4
const EXPLOSION_TTL := 0.45
const DROP_CHANCE := 0.55
const BOMB_SLIDE_INTERVAL := 0.06
const SLOW_DURATION := 3.0
const SLOW_FACTOR := 0.45
const MUD_FACTOR := 0.5
const SNOW_FACTOR := 0.6
const SAND_FACTOR := 0.7
const LAVA_DAMAGE_TIME := 0.8
const PORTAL_COOLDOWN := 0.5
const SHRINK_START := 30.0
const SHRINK_INTERVAL := 8.0

enum Cell { EMPTY, WALL, CRATE, IRON_CRATE, SHRINK_WALL, WATER }
enum Floor { NORMAL, ICE, MUD, GRASS, SNOW, SAND, LAVA }
enum Phase { PLAYING, P1_WIN, P2_WIN, DRAW }
enum Pickup { BOMB_UP, FIRE_UP, SPEED_UP, KICK, REMOTE, SHIELD, SLOW_CURSE }


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
	var shield: int = 0
	var slow_timer: float = 0.0
	var last_dir: Vector2i = Vector2i.ZERO
	var portal_cd: float = 0.0
	var last_bomb: Vector2i = Vector2i(999999, 999999)
	var moving: bool = false
	var target_gx: float = 0.0
	var target_gy: float = 0.0
	var lava_timer: float = 0.0

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
		shield = 0
		slow_timer = 0.0
		last_dir = Vector2i.ZERO
		portal_cd = 0.0
		last_bomb = Vector2i(999999, 999999)
		moving = false
		lava_timer = 0.0

	func move_speed() -> float:
		var spd := minf(GameLogic.BASE_SPEED + speed_ups * GameLogic.SPEED_PER_SHOE, GameLogic.MAX_SPEED)
		if slow_timer > 0.0:
			spd *= GameLogic.SLOW_FACTOR
		return spd

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
		gx = x; gy = y; ttl = t


class PickupData:
	var gx: int
	var gy: int
	var kind: int
	func _init(x: int, y: int, k: int) -> void:
		gx = x; gy = y; kind = k


# ── 事件队列 ─────────────────────────────

enum Event {
	BOMB_PLACED, EXPLOSION, PICKUP_COLLECTED, PHASE_END,
	BOMB_KICKED, REMOTE_DETONATE, SHIELD_BREAK,
	TELEPORT, SHRINK_ADVANCE, IRON_HIT, IRON_BREAK,
}

class GameEvent:
	var type: int
	var data: Dictionary
	func _init(t: int, d: Dictionary = {}) -> void:
		type = t; data = d

var events: Array = []


# ── 公开状态 ──────────────────────────────

var cols: int = DEFAULT_COLS
var rows: int = DEFAULT_ROWS
var rng := RandomNumberGenerator.new()
var grid: Array = []
var floor_grid: Array = []
var p1: PlayerData
var p2: PlayerData
var bombs: Array = []
var explosions: Array = []
var pickups: Array = []
var portals: Array = []
var iron_hp: Dictionary = {}
var phase: int = Phase.PLAYING
var shrink_enabled: bool = false
var shrink_timer: float = 0.0
var shrink_ring: int = 0
var _map: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	p1 = PlayerData.new(0, 1, 1)
	p2 = PlayerData.new(1, DEFAULT_COLS - 2, DEFAULT_ROWS - 2)


func reset(map: Dictionary = {}) -> void:
	_map = map
	cols = int(_map.get("cols", DEFAULT_COLS))
	rows = int(_map.get("rows", DEFAULT_ROWS))
	phase = Phase.PLAYING
	bombs.clear()
	explosions.clear()
	pickups.clear()
	events.clear()
	portals.clear()
	iron_hp.clear()
	shrink_timer = 0.0
	shrink_ring = 0
	shrink_enabled = _map.get("shrink", false)
	_build_grid()
	var spawns: Array = _map.get("spawns", [Vector2i(1, 1), Vector2i(cols - 2, rows - 2)])
	if spawns.size() >= 1:
		p1.reset(spawns[0].x, spawns[0].y)
	else:
		p1.reset(1, 1)
	if spawns.size() >= 2:
		p2.reset(spawns[1].x, spawns[1].y)
	else:
		p2.reset(cols - 2, rows - 2)


# ── 网格生成 ──────────────────────────────

func _build_grid() -> void:
	grid.clear()
	floor_grid.clear()
	for x in range(cols):
		var col: Array = []
		col.resize(rows)
		grid.append(col)
		var fcol: Array = []
		fcol.resize(rows)
		fcol.fill(Floor.NORMAL)
		floor_grid.append(fcol)
	var template: Array = _map.get("template", [])
	var density: float = _map.get("crate_density", 0.52)
	if template.size() == rows:
		_build_from_template(template, density)
	else:
		_build_default_grid(density)
	_carve_reachable_crates()


func _build_from_template(template: Array, density: float) -> void:
	var pending_portals: Array[Vector2i] = []
	for x in range(cols):
		for y in range(rows):
			var row: String = template[y]
			var ch := row[x] if x < row.length() else "."
			match ch:
				"#":
					grid[x][y] = Cell.WALL
				"I":
					grid[x][y] = Cell.IRON_CRATE
					iron_hp[Vector2i(x, y)] = 2
				"~":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.ICE
				"%":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.MUD
				"T":
					grid[x][y] = Cell.EMPTY
					pending_portals.append(Vector2i(x, y))
				"W":
					grid[x][y] = Cell.WATER
				"G":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.GRASS
				"S":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.SNOW
				"A":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.SAND
				"L":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.LAVA
				_:
					grid[x][y] = Cell.EMPTY
	for i in range(0, pending_portals.size() - 1, 2):
		portals.append([pending_portals[i], pending_portals[i + 1]])
	var spawns: Array = _map.get("spawns", [])
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			if floor_grid[x][y] != Floor.NORMAL:
				continue
			if _is_portal_cell(x, y):
				continue
			if _is_near_any_spawn(x, y, spawns):
				continue
			if rng.randf() < density:
				grid[x][y] = Cell.CRATE


func _build_default_grid(density: float) -> void:
	for x in range(cols):
		for y in range(rows):
			var border := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			if border:
				grid[x][y] = Cell.WALL
			elif (x + y) % 2 == 0 and x > 1 and x < cols - 2 and y > 1 and y < rows - 2:
				grid[x][y] = Cell.WALL
			else:
				grid[x][y] = Cell.EMPTY
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			if _is_spawn_zone(x, y):
				continue
			if rng.randf() < density:
				grid[x][y] = Cell.CRATE


func _is_spawn_zone(x: int, y: int) -> bool:
	return (x <= 2 and y <= 2) or (x >= cols - 3 and y >= rows - 3) \
		or (x >= cols - 3 and y <= 2) or (x <= 2 and y >= rows - 3)


func _is_near_any_spawn(x: int, y: int, spawns: Array) -> bool:
	for s in spawns:
		var sp: Vector2i = s
		if absi(x - sp.x) <= 1 and absi(y - sp.y) <= 1:
			return true
	return false


func _is_portal_cell(x: int, y: int) -> bool:
	for pair in portals:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if (a.x == x and a.y == y) or (b.x == x and b.y == y):
			return true
	return false


func _carve_reachable_crates() -> void:
	var reach: Dictionary = {}
	var spawns: Array = _map.get("spawns", [Vector2i(1, 1), Vector2i(cols - 2, rows - 2)])
	for s in spawns:
		var sp: Vector2i = s
		if sp.x > 0 and sp.x < cols and sp.y > 0 and sp.y < rows:
			_bfs_reachable(sp.x, sp.y, reach)
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
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
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if grid[n.x][n.y] == Cell.WALL or grid[n.x][n.y] == Cell.WATER:
				continue
			if reach.has(n):
				continue
			reach[n] = true
			if grid[n.x][n.y] == Cell.EMPTY:
				q.append(n)


func floor_at(gx: int, gy: int) -> int:
	if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
		return Floor.NORMAL
	return floor_grid[gx][gy]


func portal_dest(gx: int, gy: int) -> Vector2i:
	for pair in portals:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if a.x == gx and a.y == gy:
			return b
		if b.x == gx and b.y == gy:
			return a
	return Vector2i(-1, -1)


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
	pl.last_dir = Vector2i(dx, dy)
	pl.last_bomb = Vector2i(999999, 999999)
	return true


func player_move_tick(pl: PlayerData, dt: float) -> void:
	if not pl.alive:
		return
	if pl.slow_timer > 0.0:
		pl.slow_timer = maxf(pl.slow_timer - dt, 0.0)
	if pl.portal_cd > 0.0:
		pl.portal_cd = maxf(pl.portal_cd - dt, 0.0)
	if pl.moving:
		var dx := pl.target_gx - pl.gx
		var dy := pl.target_gy - pl.gy
		var len := sqrt(dx * dx + dy * dy)
		var spd := pl.move_speed()
		var cur_gx := int(roundf(pl.gx))
		var cur_gy := int(roundf(pl.gy))
		var cur_floor := floor_at(cur_gx, cur_gy)
		if cur_floor == Floor.MUD:
			spd *= MUD_FACTOR
		elif cur_floor == Floor.SNOW:
			spd *= SNOW_FACTOR
		elif cur_floor == Floor.SAND:
			spd *= SAND_FACTOR
		var step := spd * dt
		if len <= 0.0001 or step >= len:
			pl.gx = pl.target_gx
			pl.gy = pl.target_gy
			pl.moving = false
			var igx := int(roundf(pl.gx))
			var igy := int(roundf(pl.gy))
			if floor_at(igx, igy) == Floor.ICE and pl.last_dir != Vector2i.ZERO:
				var nx := igx + pl.last_dir.x
				var ny := igy + pl.last_dir.y
				if walkable_for(nx, ny, pl):
					pl.target_gx = float(nx)
					pl.target_gy = float(ny)
					pl.moving = true
		else:
			pl.gx += dx / len * step
			pl.gy += dy / len * step
	if not pl.moving and pl.aligned() and pl.portal_cd <= 0.0:
		var igx := int(roundf(pl.gx))
		var igy := int(roundf(pl.gy))
		var dest := portal_dest(igx, igy)
		if dest.x >= 0:
			pl.gx = float(dest.x)
			pl.gy = float(dest.y)
			pl.target_gx = pl.gx
			pl.target_gy = pl.gy
			pl.portal_cd = PORTAL_COOLDOWN
			events.append(GameEvent.new(Event.TELEPORT, {"pid": pl.pid}))
	var igx := int(roundf(pl.gx))
	var igy := int(roundf(pl.gy))
	if bomb_at(igx, igy) == null:
		pl.last_bomb = Vector2i(999999, 999999)
	if pl.alive and floor_at(igx, igy) == Floor.LAVA:
		pl.lava_timer += dt
		if pl.lava_timer >= LAVA_DAMAGE_TIME:
			try_kill_player(pl)
	else:
		pl.lava_timer = 0.0


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
	if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
		return false
	var c: int = grid[gx][gy]
	if c != Cell.EMPTY:
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
	if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
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
		if x < 0 or y < 0 or x >= cols or y >= rows:
			break
		var c: int = grid[x][y]
		if c == Cell.WALL or c == Cell.SHRINK_WALL or c == Cell.WATER:
			break
		var stop := _blast_cell(x, y, q)
		if c == Cell.CRATE:
			grid[x][y] = Cell.EMPTY
			_maybe_drop_pickup(x, y)
			break
		if c == Cell.IRON_CRATE:
			_damage_iron_crate(x, y)
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
	return c != Cell.EMPTY


func _damage_iron_crate(x: int, y: int) -> void:
	var pos := Vector2i(x, y)
	if not iron_hp.has(pos):
		return
	iron_hp[pos] -= 1
	if iron_hp[pos] <= 0:
		iron_hp.erase(pos)
		grid[x][y] = Cell.EMPTY
		_maybe_drop_pickup(x, y)
		events.append(GameEvent.new(Event.IRON_BREAK, {"gx": x, "gy": y}))
	else:
		events.append(GameEvent.new(Event.IRON_HIT, {"gx": x, "gy": y}))


func _damage_at(x: int, y: int) -> void:
	if p1.alive and int(roundf(p1.gx)) == x and int(roundf(p1.gy)) == y:
		try_kill_player(p1)
	if p2.alive and int(roundf(p2.gx)) == x and int(roundf(p2.gy)) == y:
		try_kill_player(p2)


func try_kill_player(pl: PlayerData) -> void:
	if not pl.alive:
		return
	if pl.shield > 0:
		pl.shield -= 1
		events.append(GameEvent.new(Event.SHIELD_BREAK, {"pid": pl.pid}))
		return
	pl.alive = false


# ── 爆炸 ─────────────────────────────────

func tick_explosions(dt: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var e: ExplData = explosions[i]
		e.ttl -= dt
		if e.ttl <= 0.0:
			explosions.remove_at(i)


# ── 缩圈 ─────────────────────────────────

func tick_shrink(dt: float) -> void:
	if not shrink_enabled or phase != Phase.PLAYING:
		return
	shrink_timer += dt
	if shrink_timer < SHRINK_START:
		return
	var max_ring := mini(cols, rows) / 2 - 1
	var target := mini(int((shrink_timer - SHRINK_START) / SHRINK_INTERVAL) + 1, max_ring)
	while shrink_ring < target:
		shrink_ring += 1
		_apply_shrink_ring(shrink_ring)


func _apply_shrink_ring(ring: int) -> void:
	for x in range(cols):
		for y in range(rows):
			if x != ring and x != cols - 1 - ring and y != ring and y != rows - 1 - ring:
				continue
			if grid[x][y] == Cell.WALL or grid[x][y] == Cell.SHRINK_WALL:
				continue
			grid[x][y] = Cell.SHRINK_WALL
			floor_grid[x][y] = Floor.NORMAL
			iron_hp.erase(Vector2i(x, y))
			_destroy_pickups_at(x, y)
			_destroy_bombs_at(x, y)
			_damage_at(x, y)
	_remove_dead_portals()
	events.append(GameEvent.new(Event.SHRINK_ADVANCE, {"ring": ring}))


func _destroy_bombs_at(x: int, y: int) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var bd: BombData = bombs[i]
		if bd.gx == x and bd.gy == y:
			bombs.remove_at(i)


func _remove_dead_portals() -> void:
	for i in range(portals.size() - 1, -1, -1):
		var pair: Array = portals[i]
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if grid[a.x][a.y] != Cell.EMPTY or grid[b.x][b.y] != Cell.EMPTY:
			portals.remove_at(i)


# ── 道具 ─────────────────────────────────

func _maybe_drop_pickup(x: int, y: int) -> void:
	if rng.randf() > DROP_CHANCE:
		return
	var roll := rng.randf()
	var kind: int
	if roll < 0.22:
		kind = Pickup.BOMB_UP
	elif roll < 0.42:
		kind = Pickup.FIRE_UP
	elif roll < 0.58:
		kind = Pickup.SPEED_UP
	elif roll < 0.70:
		kind = Pickup.KICK
	elif roll < 0.80:
		kind = Pickup.REMOTE
	elif roll < 0.90:
		kind = Pickup.SHIELD
	else:
		kind = Pickup.SLOW_CURSE
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
		Pickup.SHIELD:
			pl.shield = mini(pl.shield + 1, 2)
		Pickup.SLOW_CURSE:
			pl.slow_timer = SLOW_DURATION
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
