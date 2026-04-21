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
const GRASS_DROP_CHANCE := 0.25
const ERUPTION_INTERVAL := 22.0
const BLIZZARD_INTERVAL := 20.0
const BLIZZARD_DURATION := 4.0
const CREATURE_MOVE_TIME := 1.5
const BOUNCY_DURATION := 15.0
const ICE_WALL_DURATION := 6.0
const INVISIBLE_DURATION := 3.0
const CLONE_LIFETIME := 8.0
const CLONE_MOVE_TIME := 0.8
const CLONE_SLOW_RANGE := 2
const CLONE_SLOW_DUR := 2.0
const COMBO_WINDOW := 2.0
const SCORE_CRATE := 10
const SCORE_IRON := 25
const SCORE_PICKUP := 15
const SCORE_KILL := 200
const SCORE_CREATURE := 30
const SCORE_PHASE := 50
const SCORE_WIN := 300
const FUSE_PENALTY := 0.04
const MIN_FUSE := 1.2
const CHARGE_TIME := 0.8
const SUPER_RANGE_BONUS := 2
const MYSTERY_RATIO := 0.15
const PHASE_OPENING_END := 20.0
const PHASE_TENSION_END := 40.0
const TIMED_WALL_INTERVAL := 6.0
const FLOOD_INTERVAL := 18.0
const AVALANCHE_INTERVAL := 25.0
const SANDSTORM_INTERVAL := 20.0
const SANDSTORM_DURATION := 3.0
const TREASURE_DROP_CHANCE := 0.85

enum Cell { EMPTY, WALL, CRATE, IRON_CRATE, SHRINK_WALL, WATER, ICE_WALL, MYSTERY_CRATE,
	BRIDGE, TIMED_WALL }
enum Floor { NORMAL, ICE, MUD, GRASS, SNOW, SAND, LAVA, CONV_N, CONV_E, CONV_S, CONV_W,
	TALL_GRASS, GATE_N, GATE_E, GATE_S, GATE_W }
enum Phase { PLAYING, P1_WIN, P2_WIN, DRAW }
enum MatchPhase { OPENING, TENSION, CLIMAX }
enum Pickup { BOMB_UP, FIRE_UP, SPEED_UP, KICK, REMOTE, SHIELD, SLOW_CURSE,
	BOUNCY_BOMB, ICE_WALL, SOUL_SWAP, SHADOW_CLONE }


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
	var bouncy_timer: float = 0.0
	var invisible_timer: float = 0.0
	var score: int = 0
	var combo: int = 0
	var combo_timer: float = 0.0
	var max_combo: int = 0
	var pickup_count: int = 0
	var charge_timer: float = 0.0

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
		bouncy_timer = 0.0
		invisible_timer = 0.0
		score = 0
		combo = 0
		combo_timer = 0.0
		max_combo = 0
		pickup_count = 0
		charge_timer = 0.0

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
	var is_bouncy: bool = false
	var bounces_left: int = 0
	var is_super: bool = false

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
	var owner_id: int
	func _init(x: int, y: int, t: float, oid: int = -1) -> void:
		gx = x; gy = y; ttl = t; owner_id = oid


class PickupData:
	var gx: int
	var gy: int
	var kind: int
	func _init(x: int, y: int, k: int) -> void:
		gx = x; gy = y; kind = k


class CreatureData:
	var gx: int
	var gy: int
	var alive: bool = true
	var move_timer: float = 0.0
	func _init(x: int, y: int) -> void:
		gx = x; gy = y; move_timer = randf() * 1.0


class CloneData:
	var gx: int
	var gy: int
	var owner_pid: int
	var alive: bool = true
	var timer: float
	var move_timer: float = 0.0
	func _init(x: int, y: int, pid: int) -> void:
		gx = x; gy = y; owner_pid = pid
		timer = GameLogic.CLONE_LIFETIME; move_timer = randf() * 0.5


# ── 事件队列 ─────────────────────────────

enum Event {
	BOMB_PLACED, EXPLOSION, PICKUP_COLLECTED, PHASE_END,
	BOMB_KICKED, REMOTE_DETONATE, SHIELD_BREAK,
	TELEPORT, SHRINK_ADVANCE, IRON_HIT, IRON_BREAK,
	GRASS_BURNED, CRATE_DESTROYED, ERUPTION, CREATURE_KILLED,
	SOUL_SWAPPED, ICE_WALL_PLACED, CLONE_SPAWNED, CLONE_POPPED,
	BOUNCY_ACTIVATED, BOUNCY_BOUNCE,
	COMBO_UP, COMBO_BREAK, MATCH_PHASE_CHANGE,
	MYSTERY_RESOLVED, SUPER_BOMB_PLACED,
	BRIDGE_DESTROYED, TIMED_WALL_TOGGLE,
	FLOOD_ADVANCE, AVALANCHE, SANDSTORM_START, SANDSTORM_END,
	LAVA_SPREAD,
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
var creatures: Array = []
var eruption_timer: float = 0.0
var blizzard_timer: float = 0.0
var blizzard_active: bool = false
var blizzard_remaining: float = 0.0
var clones: Array = []
var ice_wall_timers: Dictionary = {}
var fun_mode: bool = false
var extra_players: Array = []
var match_timer: float = 0.0
var match_phase: int = MatchPhase.OPENING
var _current_blast_owner: int = -1
var _map: Dictionary = {}
var timed_wall_open: Dictionary = {}
var timed_wall_timer: float = 0.0
var flood_timer: float = 0.0
var avalanche_timer: float = 0.0
var avalanche_warn: float = -1.0
var avalanche_edge: int = -1
var avalanche_col: int = -1
var sandstorm_timer: float = 0.0
var sandstorm_active: bool = false
var sandstorm_remaining: float = 0.0
var sandstorm_dir: Vector2i = Vector2i.ZERO
var sandstorm_push_cd: float = 0.0
var treasure_zones: Array = []


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
	creatures.clear()
	clones.clear()
	ice_wall_timers.clear()
	extra_players.clear()
	eruption_timer = 0.0
	blizzard_timer = 0.0
	blizzard_active = false
	blizzard_remaining = 0.0
	match_timer = 0.0
	match_phase = MatchPhase.OPENING
	_current_blast_owner = -1
	timed_wall_open.clear()
	timed_wall_timer = 0.0
	flood_timer = 0.0
	avalanche_timer = 0.0
	avalanche_warn = -1.0
	avalanche_edge = -1
	avalanche_col = -1
	sandstorm_timer = 0.0
	sandstorm_active = false
	sandstorm_remaining = 0.0
	sandstorm_dir = Vector2i.ZERO
	sandstorm_push_cd = 0.0
	treasure_zones = _map.get("treasure_zones", [])
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
		_parse_template(template)
		_randomize_terrain()
		_place_crates(density)
	else:
		_build_default_grid(density)
	_convert_mystery_crates()
	_carve_reachable_crates()


func _parse_template(template: Array) -> void:
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
				">":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.CONV_E
				"<":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.CONV_W
				"^":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.CONV_N
				"v":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.CONV_S
				"C":
					grid[x][y] = Cell.EMPTY
					creatures.append(CreatureData.new(x, y))
				"B":
					grid[x][y] = Cell.BRIDGE
				"X":
					grid[x][y] = Cell.TIMED_WALL
					timed_wall_open[Vector2i(x, y)] = false
				"H":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.TALL_GRASS
				"]":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.GATE_E
				"[":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.GATE_W
				"(":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.GATE_N
				")":
					grid[x][y] = Cell.EMPTY
					floor_grid[x][y] = Floor.GATE_S
				_:
					grid[x][y] = Cell.EMPTY
	for i in range(0, pending_portals.size() - 1, 2):
		portals.append([pending_portals[i], pending_portals[i + 1]])


func _place_crates(density: float) -> void:
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


func _convert_mystery_crates() -> void:
	var crate_positions: Array[Vector2i] = []
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] == Cell.CRATE:
				crate_positions.append(Vector2i(x, y))
	for i in range(crate_positions.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp := crate_positions[i]
		crate_positions[i] = crate_positions[j]
		crate_positions[j] = tmp
	var count := 0
	for p in crate_positions:
		var ratio: float = MYSTERY_RATIO * 2.0 if is_in_treasure_zone(p.x, p.y) else MYSTERY_RATIO
		if rng.randf() < ratio:
			grid[p.x][p.y] = Cell.MYSTERY_CRATE
			count += 1


# ── 主题地形随机化 ────────────────────────

func _randomize_terrain() -> void:
	var theme: String = _map.get("theme", "classic")
	if theme == "classic":
		return
	var spawns: Array = _map.get("spawns", [])
	var portal_pairs: int = portals.size()

	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] == Cell.WATER:
				grid[x][y] = Cell.EMPTY
			floor_grid[x][y] = Floor.NORMAL
	portals.clear()

	match theme:
		"grassland": _deco_grassland(spawns)
		"tundra": _deco_tundra(spawns)
		"desert": _deco_desert(spawns)
		"volcano": _deco_volcano(spawns)

	_place_portals_random(portal_pairs, spawns)


func _deco_grassland(spawns: Array) -> void:
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] == Cell.EMPTY and not _is_near_any_spawn(x, y, spawns):
				if rng.randf() < 0.35:
					floor_grid[x][y] = Floor.GRASS
	_place_river(spawns)


func _deco_tundra(spawns: Array) -> void:
	var cx := cols / 2
	var cy := rows / 2
	var ice_radius: float = minf(float(cols), float(rows)) * 0.28 + rng.randf() * 2.0
	var ice_cx: int = cx + rng.randi() % 5 - 2
	var ice_cy: int = cy + rng.randi() % 3 - 1
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			var dist_border := mini(mini(x, cols - 1 - x), mini(y, rows - 1 - y))
			var dx := float(x - ice_cx)
			var dy := float(y - ice_cy)
			var dist_center := sqrt(dx * dx + dy * dy)
			if dist_center <= ice_radius and rng.randf() < 0.55:
				floor_grid[x][y] = Floor.ICE
			elif dist_border <= 3 and rng.randf() < 0.7:
				floor_grid[x][y] = Floor.SNOW


func _deco_desert(spawns: Array) -> void:
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] == Cell.EMPTY and not _is_near_any_spawn(x, y, spawns):
				if rng.randf() < 0.30:
					floor_grid[x][y] = Floor.SAND
	var oasis_count: int = 1 + rng.randi() % 2
	for oi in range(oasis_count):
		_place_oasis(spawns)


func _deco_volcano(spawns: Array) -> void:
	var cx := cols / 2 + rng.randi() % 5 - 2
	var cy := rows / 2 + rng.randi() % 3 - 1
	var radius: float = minf(float(cols), float(rows)) * 0.22 + rng.randf() * 2.0
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] != Cell.EMPTY:
				continue
			if _is_near_any_spawn(x, y, spawns):
				continue
			var dx := float(x - cx)
			var dy := float(y - cy)
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius and rng.randf() < 0.78:
				floor_grid[x][y] = Floor.LAVA


func _place_river(spawns: Array) -> void:
	var vertical: bool = rng.randf() < 0.5
	for attempt in range(40):
		var positions: Array[Vector2i] = []
		if vertical:
			var cx: int = 3 + rng.randi() % maxi(1, cols - 6)
			for y in range(1, rows - 1):
				if grid[cx][y] == Cell.EMPTY and not _is_near_any_spawn(cx, y, spawns):
					positions.append(Vector2i(cx, y))
		else:
			var cy: int = 3 + rng.randi() % maxi(1, rows - 6)
			for x in range(1, cols - 1):
				if grid[x][cy] == Cell.EMPTY and not _is_near_any_spawn(x, cy, spawns):
					positions.append(Vector2i(x, cy))
		if positions.size() >= 4:
			var gap1: int = rng.randi() % positions.size()
			var gap2: int = (gap1 + positions.size() / 2) % positions.size()
			for i in range(positions.size()):
				if i == gap1 or i == gap2:
					continue
				grid[positions[i].x][positions[i].y] = Cell.WATER
			return


func _place_oasis(spawns: Array) -> void:
	for attempt in range(40):
		var cx: int = 3 + rng.randi() % maxi(1, cols - 6)
		var cy: int = 3 + rng.randi() % maxi(1, rows - 6)
		if grid[cx][cy] != Cell.EMPTY or _is_near_any_spawn(cx, cy, spawns):
			continue
		grid[cx][cy] = Cell.WATER
		var oasis_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for od: Vector2i in oasis_dirs:
			var nx: int = cx + od.x
			var ny: int = cy + od.y
			if nx >= 1 and nx < cols - 1 and ny >= 1 and ny < rows - 1:
				if grid[nx][ny] == Cell.EMPTY and not _is_near_any_spawn(nx, ny, spawns):
					if rng.randf() < 0.6:
						grid[nx][ny] = Cell.WATER
					else:
						floor_grid[nx][ny] = Floor.SAND
		return


func _place_portals_random(pair_count: int, spawns: Array) -> void:
	if pair_count <= 0:
		return
	var eligible: Array[Vector2i] = []
	for x in range(2, cols - 2):
		for y in range(2, rows - 2):
			if grid[x][y] != Cell.EMPTY:
				continue
			if _is_near_any_spawn(x, y, spawns):
				continue
			eligible.append(Vector2i(x, y))
	for i in range(eligible.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp := eligible[i]
		eligible[i] = eligible[j]
		eligible[j] = tmp
	var placed := 0
	var used: Dictionary = {}
	var idx := 0
	while placed < pair_count and idx < eligible.size():
		var a := eligible[idx]
		idx += 1
		if used.has(a):
			continue
		for j in range(idx, eligible.size()):
			var b := eligible[j]
			if used.has(b):
				continue
			var dist := absi(a.x - b.x) + absi(a.y - b.y)
			if dist >= 6:
				portals.append([a, b])
				used[a] = true
				used[b] = true
				placed += 1
				break


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
			if (grid[x][y] == Cell.CRATE or grid[x][y] == Cell.MYSTERY_CRATE) and not reach.has(Vector2i(x, y)):
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
			var gc: int = grid[n.x][n.y]
			if gc == Cell.WALL or gc == Cell.WATER:
				continue
			if reach.has(n):
				continue
			reach[n] = true
			if gc == Cell.EMPTY or gc == Cell.BRIDGE or gc == Cell.TIMED_WALL:
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
	if _gate_blocks(tx, ty, dx, dy):
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
	if pl.bouncy_timer > 0.0:
		pl.bouncy_timer = maxf(pl.bouncy_timer - dt, 0.0)
	if pl.invisible_timer > 0.0:
		pl.invisible_timer = maxf(pl.invisible_timer - dt, 0.0)
	if pl.combo > 0:
		pl.combo_timer -= dt
		if pl.combo_timer <= 0.0:
			_break_combo(pl)
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
				if walkable_for(nx, ny, pl) and not _gate_blocks(nx, ny, pl.last_dir.x, pl.last_dir.y):
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
	if not pl.moving and pl.aligned():
		var conv_floor := floor_at(int(roundf(pl.gx)), int(roundf(pl.gy)))
		match conv_floor:
			Floor.CONV_N: try_start_move(pl, 0, -1)
			Floor.CONV_E: try_start_move(pl, 1, 0)
			Floor.CONV_S: try_start_move(pl, 0, 1)
			Floor.CONV_W: try_start_move(pl, -1, 0)


func update_player(pl: PlayerData, dir: Vector2i, want_bomb: bool, dt: float,
		bomb_held: bool = false) -> void:
	if not pl.alive:
		return
	if pl.charge_timer > 0.0:
		pl.charge_timer += dt
		if pl.charge_timer >= CHARGE_TIME:
			_place_super_bomb(pl)
			pl.charge_timer = 0.0
		elif not bomb_held:
			try_place_bomb(pl)
			pl.charge_timer = 0.0
	elif bomb_held and pl.aligned() and bomb_at(int(roundf(pl.gx)), int(roundf(pl.gy))) == null:
		pl.charge_timer = dt
	else:
		if dir != Vector2i.ZERO:
			try_start_move(pl, dir.x, dir.y)
		if want_bomb:
			try_place_bomb(pl)
	player_move_tick(pl, dt)
	try_collect_pickup(pl)


func walkable_for(gx: int, gy: int, pl: PlayerData) -> bool:
	if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
		return false
	var c: int = grid[gx][gy]
	if c == Cell.BRIDGE:
		pass
	elif c == Cell.TIMED_WALL:
		if not timed_wall_open.get(Vector2i(gx, gy), false):
			return false
	elif c != Cell.EMPTY:
		return false
	var b: BombData = bomb_at(gx, gy)
	if b != null:
		return pl.can_stand_on_bomb(gx, gy)
	return true


func _gate_blocks(tx: int, ty: int, dx: int, dy: int) -> bool:
	if tx < 0 or ty < 0 or tx >= cols or ty >= rows:
		return false
	var f: int = floor_grid[tx][ty]
	match f:
		Floor.GATE_E:
			return dx != 1
		Floor.GATE_W:
			return dx != -1
		Floor.GATE_N:
			return dy != -1
		Floor.GATE_S:
			return dy != 1
	return false


func is_concealed(pl: PlayerData) -> bool:
	if not pl.alive:
		return false
	var igx := int(roundf(pl.gx))
	var igy := int(roundf(pl.gy))
	return floor_at(igx, igy) == Floor.TALL_GRASS and not pl.moving


func is_in_treasure_zone(x: int, y: int) -> bool:
	for zone in treasure_zones:
		if x >= zone[0] and y >= zone[1] and x <= zone[2] and y <= zone[3]:
			return true
	return false


func tick_timed_walls(dt: float) -> void:
	if timed_wall_open.is_empty():
		return
	timed_wall_timer += dt
	if timed_wall_timer >= TIMED_WALL_INTERVAL:
		timed_wall_timer -= TIMED_WALL_INTERVAL
		for pos in timed_wall_open:
			timed_wall_open[pos] = not timed_wall_open[pos]
		events.append(GameEvent.new(Event.TIMED_WALL_TOGGLE, {"open": timed_wall_open.values().any(func(v): return v)}))
		for pos in timed_wall_open:
			if not timed_wall_open[pos]:
				_damage_at(pos.x, pos.y)


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
	var bd := BombData.new(gx, gy, pl.pid, _get_fuse_for(pl), pl.range_i)
	if pl.has_remote:
		bd.is_remote = true
		bd.time = 9999.0
	if pl.bouncy_timer > 0.0:
		bd.is_bouncy = true
		bd.bounces_left = 3
		if pl.last_dir != Vector2i.ZERO:
			bd.moving = true
			bd.move_dir = pl.last_dir
			bd.move_timer = BOMB_SLIDE_INTERVAL
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
			if b.is_bouncy and b.bounces_left > 0:
				b.bounces_left -= 1
				b.move_dir = -b.move_dir
				events.append(GameEvent.new(Event.BOUNCY_BOUNCE, {"gx": b.gx, "gy": b.gy}))
				var bnx: int = b.gx + b.move_dir.x
				var bny: int = b.gy + b.move_dir.y
				if not _bomb_slide_blocked(bnx, bny):
					b.gx = bnx
					b.gy = bny
				else:
					b.moving = false
					b.move_dir = Vector2i.ZERO
			else:
				b.moving = false
				b.move_dir = Vector2i.ZERO
		else:
			b.gx = nx
			b.gy = ny


func _bomb_slide_blocked(gx: int, gy: int) -> bool:
	if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
		return true
	var c: int = grid[gx][gy]
	if c == Cell.BRIDGE:
		pass
	elif c == Cell.TIMED_WALL:
		if not timed_wall_open.get(Vector2i(gx, gy), false):
			return true
	elif c != Cell.EMPTY:
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
	_current_blast_owner = -1


func _explode_bomb_wave(seed_bomb: BombData) -> void:
	var q: Array = [seed_bomb]
	while not q.is_empty():
		var b: BombData = q.pop_front()
		if not bombs.has(b):
			continue
		bombs.erase(b)
		_explode_single(b, q)


func _explode_single(b: BombData, q: Array) -> void:
	_current_blast_owner = b.owner_id
	events.append(GameEvent.new(Event.EXPLOSION, {"gx": b.gx, "gy": b.gy, "pid": b.owner_id}))
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
		if c == Cell.WALL or c == Cell.SHRINK_WALL or c == Cell.WATER or c == Cell.ICE_WALL:
			break
		if c == Cell.TIMED_WALL:
			if not timed_wall_open.get(Vector2i(x, y), false):
				break
		if c == Cell.BRIDGE:
			grid[x][y] = Cell.WATER
			_blast_cell(x, y, q)
			events.append(GameEvent.new(Event.BRIDGE_DESTROYED, {"gx": x, "gy": y}))
			break
		var stop := _blast_cell(x, y, q)
		if c == Cell.CRATE:
			grid[x][y] = Cell.EMPTY
			events.append(GameEvent.new(Event.CRATE_DESTROYED, {"gx": x, "gy": y}))
			_award_score_pid(_current_blast_owner, SCORE_CRATE)
			_maybe_drop_pickup(x, y)
			break
		if c == Cell.MYSTERY_CRATE:
			grid[x][y] = Cell.EMPTY
			events.append(GameEvent.new(Event.CRATE_DESTROYED, {"gx": x, "gy": y}))
			_award_score_pid(_current_blast_owner, SCORE_CRATE)
			_resolve_mystery(x, y)
			break
		if c == Cell.IRON_CRATE:
			_damage_iron_crate(x, y)
			break
		var f: int = floor_grid[x][y]
		if c == Cell.EMPTY and (f == Floor.GRASS or f == Floor.TALL_GRASS):
			floor_grid[x][y] = Floor.NORMAL
			events.append(GameEvent.new(Event.GRASS_BURNED, {"gx": x, "gy": y}))
			if rng.randf() < GRASS_DROP_CHANCE:
				_maybe_drop_pickup(x, y)
		if stop:
			break


func _blast_cell(x: int, y: int, q: Array) -> bool:
	explosions.append(ExplData.new(x, y, EXPLOSION_TTL, _current_blast_owner))
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
		_award_score_pid(_current_blast_owner, SCORE_IRON)
		_maybe_drop_pickup(x, y)
		events.append(GameEvent.new(Event.IRON_BREAK, {"gx": x, "gy": y}))
	else:
		events.append(GameEvent.new(Event.IRON_HIT, {"gx": x, "gy": y}))


func _damage_at(x: int, y: int, attacker: int = -1) -> void:
	var atk := attacker if attacker >= 0 else _current_blast_owner
	if p1.alive and int(roundf(p1.gx)) == x and int(roundf(p1.gy)) == y:
		try_kill_player(p1, atk)
	if p2.alive and int(roundf(p2.gx)) == x and int(roundf(p2.gy)) == y:
		try_kill_player(p2, atk)


func try_kill_player(pl: PlayerData, attacker_pid: int = -1) -> void:
	if not pl.alive:
		return
	if pl.shield > 0:
		pl.shield -= 1
		_break_combo(pl)
		events.append(GameEvent.new(Event.SHIELD_BREAK, {"pid": pl.pid}))
		return
	pl.alive = false
	_break_combo(pl)
	if attacker_pid >= 0 and attacker_pid != pl.pid:
		_award_score_pid(attacker_pid, SCORE_KILL)


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
	var interval := SHRINK_INTERVAL * 0.5 if match_phase == MatchPhase.CLIMAX else SHRINK_INTERVAL
	var target := mini(int((shrink_timer - SHRINK_START) / interval) + 1, max_ring)
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
	var chance: float = TREASURE_DROP_CHANCE if is_in_treasure_zone(x, y) else DROP_CHANCE
	if rng.randf() > chance:
		return
	var in_tz: bool = is_in_treasure_zone(x, y)
	var kind: int = _roll_treasure_pickup() if in_tz else _roll_pickup_kind()
	pickups.append(PickupData.new(x, y, kind))


func _roll_treasure_pickup() -> int:
	var roll := rng.randf()
	if roll < 0.25: return Pickup.SHIELD
	elif roll < 0.45: return Pickup.REMOTE
	elif roll < 0.65: return Pickup.KICK
	elif roll < 0.80: return Pickup.FIRE_UP
	elif roll < 0.90: return Pickup.BOMB_UP
	else: return Pickup.SPEED_UP


func _roll_pickup_kind() -> int:
	var roll := rng.randf()
	if fun_mode:
		match match_phase:
			MatchPhase.TENSION:
				if roll < 0.08: return Pickup.BOMB_UP
				elif roll < 0.16: return Pickup.FIRE_UP
				elif roll < 0.22: return Pickup.SPEED_UP
				elif roll < 0.34: return Pickup.KICK
				elif roll < 0.44: return Pickup.REMOTE
				elif roll < 0.56: return Pickup.SHIELD
				elif roll < 0.62: return Pickup.SLOW_CURSE
				elif roll < 0.72: return Pickup.BOUNCY_BOMB
				elif roll < 0.80: return Pickup.ICE_WALL
				elif roll < 0.90: return Pickup.SOUL_SWAP
				else: return Pickup.SHADOW_CLONE
			MatchPhase.CLIMAX:
				if roll < 0.06: return Pickup.BOMB_UP
				elif roll < 0.12: return Pickup.FIRE_UP
				elif roll < 0.16: return Pickup.SPEED_UP
				elif roll < 0.24: return Pickup.KICK
				elif roll < 0.30: return Pickup.REMOTE
				elif roll < 0.40: return Pickup.SHIELD
				elif roll < 0.52: return Pickup.SLOW_CURSE
				elif roll < 0.64: return Pickup.BOUNCY_BOMB
				elif roll < 0.76: return Pickup.ICE_WALL
				elif roll < 0.88: return Pickup.SOUL_SWAP
				else: return Pickup.SHADOW_CLONE
			_:
				if roll < 0.14: return Pickup.BOMB_UP
				elif roll < 0.26: return Pickup.FIRE_UP
				elif roll < 0.36: return Pickup.SPEED_UP
				elif roll < 0.44: return Pickup.KICK
				elif roll < 0.50: return Pickup.REMOTE
				elif roll < 0.58: return Pickup.SHIELD
				elif roll < 0.64: return Pickup.SLOW_CURSE
				elif roll < 0.74: return Pickup.BOUNCY_BOMB
				elif roll < 0.83: return Pickup.ICE_WALL
				elif roll < 0.92: return Pickup.SOUL_SWAP
				else: return Pickup.SHADOW_CLONE
	else:
		match match_phase:
			MatchPhase.TENSION:
				if roll < 0.12: return Pickup.BOMB_UP
				elif roll < 0.24: return Pickup.FIRE_UP
				elif roll < 0.34: return Pickup.SPEED_UP
				elif roll < 0.50: return Pickup.KICK
				elif roll < 0.64: return Pickup.REMOTE
				elif roll < 0.82: return Pickup.SHIELD
				else: return Pickup.SLOW_CURSE
			MatchPhase.CLIMAX:
				if roll < 0.10: return Pickup.BOMB_UP
				elif roll < 0.20: return Pickup.FIRE_UP
				elif roll < 0.28: return Pickup.SPEED_UP
				elif roll < 0.40: return Pickup.KICK
				elif roll < 0.52: return Pickup.REMOTE
				elif roll < 0.68: return Pickup.SHIELD
				else: return Pickup.SLOW_CURSE
			_:
				if roll < 0.22: return Pickup.BOMB_UP
				elif roll < 0.42: return Pickup.FIRE_UP
				elif roll < 0.58: return Pickup.SPEED_UP
				elif roll < 0.70: return Pickup.KICK
				elif roll < 0.80: return Pickup.REMOTE
				elif roll < 0.90: return Pickup.SHIELD
				else: return Pickup.SLOW_CURSE
	return Pickup.BOMB_UP


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
		Pickup.BOUNCY_BOMB:
			pl.bouncy_timer = BOUNCY_DURATION
		Pickup.ICE_WALL:
			pass
		Pickup.SOUL_SWAP:
			pass
		Pickup.SHADOW_CLONE:
			pass
	pl.pickup_count += 1
	_award_score(pl, SCORE_PICKUP)
	events.append(GameEvent.new(Event.PICKUP_COLLECTED, {"pid": pl.pid, "kind": pd.kind}))
	pickups.erase(pd)
	match pd.kind:
		Pickup.ICE_WALL:
			_place_ice_wall(pl)
		Pickup.SOUL_SWAP:
			_soul_swap(pl)
		Pickup.SHADOW_CLONE:
			_spawn_clone(pl)


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
		if phase == Phase.P1_WIN:
			_award_score(p1, SCORE_WIN)
		elif phase == Phase.P2_WIN:
			_award_score(p2, SCORE_WIN)
		events.append(GameEvent.new(Event.PHASE_END, {"phase": phase}))


# ── 地图灾害 ─────────────────────────────

func tick_hazards(dt: float, theme: String) -> void:
	if theme == "volcano":
		eruption_timer += dt
		if eruption_timer >= ERUPTION_INTERVAL:
			eruption_timer = 0.0
			_trigger_eruption()
	if theme == "tundra":
		if blizzard_active:
			blizzard_remaining -= dt
			if blizzard_remaining <= 0.0:
				blizzard_active = false
		else:
			blizzard_timer += dt
			if blizzard_timer >= BLIZZARD_INTERVAL:
				blizzard_timer = 0.0
				blizzard_active = true
				blizzard_remaining = BLIZZARD_DURATION
		_tick_avalanche(dt)
	if theme == "grassland":
		_tick_flood(dt)
	if theme == "desert":
		_tick_sandstorm(dt)


func _trigger_eruption() -> void:
	var lava_cells: Array[Vector2i] = []
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if floor_grid[x][y] == Floor.LAVA and grid[x][y] == Cell.EMPTY:
				lava_cells.append(Vector2i(x, y))
	var count := mini(3 + rng.randi() % 3, lava_cells.size())
	for i in range(count):
		var idx: int = rng.randi() % lava_cells.size()
		var pos := lava_cells[idx]
		lava_cells.remove_at(idx)
		explosions.append(ExplData.new(pos.x, pos.y, EXPLOSION_TTL))
		_damage_at(pos.x, pos.y)
	if count > 0:
		events.append(GameEvent.new(Event.ERUPTION, {}))
	_spread_lava()


func _spread_lava() -> void:
	var edge_cells: Array[Vector2i] = []
	var dirs_arr: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if floor_grid[x][y] != Floor.LAVA:
				continue
			for d in dirs_arr:
				var nx := x + d.x
				var ny := y + d.y
				if nx <= 0 or ny <= 0 or nx >= cols - 1 or ny >= rows - 1:
					continue
				if floor_grid[nx][ny] != Floor.NORMAL and floor_grid[nx][ny] != Floor.GRASS and floor_grid[nx][ny] != Floor.TALL_GRASS:
					continue
				if grid[nx][ny] != Cell.EMPTY:
					continue
				edge_cells.append(Vector2i(nx, ny))
	if edge_cells.is_empty():
		return
	var spread_count := mini(1 + rng.randi() % 2, edge_cells.size())
	for i in range(spread_count):
		var idx := rng.randi() % edge_cells.size()
		var pos := edge_cells[idx]
		edge_cells.remove_at(idx)
		floor_grid[pos.x][pos.y] = Floor.LAVA
		_destroy_pickups_at(pos.x, pos.y)
		_damage_at(pos.x, pos.y)
	events.append(GameEvent.new(Event.LAVA_SPREAD, {}))


func _tick_flood(dt: float) -> void:
	flood_timer += dt
	if flood_timer < FLOOD_INTERVAL:
		return
	flood_timer -= FLOOD_INTERVAL
	var candidates: Array[Vector2i] = []
	var dirs_arr: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in range(1, cols - 1):
		for y in range(1, rows - 1):
			if grid[x][y] != Cell.WATER:
				continue
			for d in dirs_arr:
				var nx := x + d.x
				var ny := y + d.y
				if nx <= 0 or ny <= 0 or nx >= cols - 1 or ny >= rows - 1:
					continue
				var f: int = floor_grid[nx][ny]
				if grid[nx][ny] == Cell.EMPTY and (f == Floor.GRASS or f == Floor.TALL_GRASS or f == Floor.NORMAL):
					candidates.append(Vector2i(nx, ny))
	if candidates.is_empty():
		return
	var flood_count := mini(2 + rng.randi() % 3, candidates.size())
	for i in range(flood_count):
		var idx := rng.randi() % candidates.size()
		var pos := candidates[idx]
		candidates.remove_at(idx)
		grid[pos.x][pos.y] = Cell.WATER
		floor_grid[pos.x][pos.y] = Floor.NORMAL
		_destroy_pickups_at(pos.x, pos.y)
		_damage_at(pos.x, pos.y)
	events.append(GameEvent.new(Event.FLOOD_ADVANCE, {}))


func _tick_avalanche(dt: float) -> void:
	if avalanche_warn >= 0.0:
		avalanche_warn -= dt
		if avalanche_warn <= 0.0:
			_fire_avalanche()
			avalanche_warn = -1.0
		return
	avalanche_timer += dt
	if avalanche_timer < AVALANCHE_INTERVAL:
		return
	avalanche_timer -= AVALANCHE_INTERVAL
	avalanche_edge = rng.randi() % 4
	var is_horizontal := (avalanche_edge == 0 or avalanche_edge == 1)
	var max_val: int = rows if is_horizontal else cols
	avalanche_col = 1 + rng.randi() % maxi(max_val - 2, 1)
	avalanche_warn = 2.0
	events.append(GameEvent.new(Event.AVALANCHE, {"warn": true, "edge": avalanche_edge, "col": avalanche_col}))


func _fire_avalanche() -> void:
	var is_horizontal := (avalanche_edge == 0 or avalanche_edge == 1)
	var length: int = cols if is_horizontal else rows
	var width := 3
	for w in range(-width / 2, width / 2 + 1):
		for i in range(1, length - 1):
			var x: int
			var y: int
			if is_horizontal:
				x = i
				y = avalanche_col + w
			else:
				x = avalanche_col + w
				y = i
			if x < 0 or y < 0 or x >= cols or y >= rows:
				continue
			if grid[x][y] == Cell.WALL or grid[x][y] == Cell.SHRINK_WALL:
				continue
			explosions.append(ExplData.new(x, y, EXPLOSION_TTL))
			_damage_at(x, y)
	events.append(GameEvent.new(Event.AVALANCHE, {"warn": false, "edge": avalanche_edge, "col": avalanche_col}))


func _tick_sandstorm(dt: float) -> void:
	if sandstorm_active:
		sandstorm_remaining -= dt
		sandstorm_push_cd -= dt
		if sandstorm_push_cd <= 0.0:
			sandstorm_push_cd += 1.0
			_sandstorm_push()
		if sandstorm_remaining <= 0.0:
			sandstorm_active = false
			events.append(GameEvent.new(Event.SANDSTORM_END, {}))
	else:
		sandstorm_timer += dt
		if sandstorm_timer >= SANDSTORM_INTERVAL:
			sandstorm_timer -= SANDSTORM_INTERVAL
			sandstorm_active = true
			sandstorm_remaining = SANDSTORM_DURATION
			sandstorm_push_cd = 1.0
			sandstorm_dir = Vector2i(1, 0) if rng.randi() % 2 == 0 else Vector2i(-1, 0)
			events.append(GameEvent.new(Event.SANDSTORM_START, {"dir": sandstorm_dir}))


func _sandstorm_push() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pk: PickupData = pickups[i]
		var nx := pk.gx + sandstorm_dir.x
		var ny := pk.gy + sandstorm_dir.y
		if nx >= 1 and nx < cols - 1 and ny >= 1 and ny < rows - 1:
			if grid[nx][ny] == Cell.EMPTY and bomb_at(nx, ny) == null:
				pk.gx = nx
				pk.gy = ny
	var all_players: Array = [p1, p2] + extra_players
	for pl_item in all_players:
		var pl: PlayerData = pl_item
		if not pl.alive or pl.moving:
			continue
		var igx := int(roundf(pl.gx))
		var igy := int(roundf(pl.gy))
		if floor_at(igx, igy) == Floor.SAND:
			try_start_move(pl, sandstorm_dir.x, sandstorm_dir.y)


# ── 中立生物 ─────────────────────────────

func tick_creatures(dt: float) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c_item in creatures:
		var cr: CreatureData = c_item
		if not cr.alive:
			continue
		for e in explosions:
			var ex: ExplData = e
			if ex.gx == cr.gx and ex.gy == cr.gy:
				cr.alive = false
				_award_score_pid(ex.owner_id, SCORE_CREATURE)
				_maybe_drop_pickup(cr.gx, cr.gy)
				events.append(GameEvent.new(Event.CREATURE_KILLED, {"gx": cr.gx, "gy": cr.gy}))
				break
		if not cr.alive:
			continue
		cr.move_timer -= dt
		if cr.move_timer <= 0.0:
			cr.move_timer = CREATURE_MOVE_TIME + rng.randf() * 1.0
			var valid_dirs: Array[Vector2i] = []
			for d: Vector2i in dirs:
				var nx: int = cr.gx + d.x
				var ny: int = cr.gy + d.y
				if nx >= 1 and nx < cols - 1 and ny >= 1 and ny < rows - 1:
					if grid[nx][ny] == Cell.EMPTY and bomb_at(nx, ny) == null:
						valid_dirs.append(d)
			if not valid_dirs.is_empty():
				var d: Vector2i = valid_dirs[rng.randi() % valid_dirs.size()]
				cr.gx += d.x
				cr.gy += d.y


# ── 趣味道具 ─────────────────────────────

func _place_ice_wall(pl: PlayerData) -> void:
	var dir := pl.last_dir
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var sx := int(roundf(pl.gx)) + dir.x
	var sy := int(roundf(pl.gy)) + dir.y
	var placed := 0
	for i in range(3):
		var wx: int = sx + dir.x * i
		var wy: int = sy + dir.y * i
		if wx < 1 or wx >= cols - 1 or wy < 1 or wy >= rows - 1:
			continue
		if grid[wx][wy] != Cell.EMPTY:
			continue
		if bomb_at(wx, wy) != null:
			continue
		var occupied := false
		for check_pl: PlayerData in _all_players():
			if check_pl.alive and int(roundf(check_pl.gx)) == wx and int(roundf(check_pl.gy)) == wy:
				occupied = true
				break
		if occupied:
			continue
		grid[wx][wy] = Cell.ICE_WALL
		ice_wall_timers[Vector2i(wx, wy)] = ICE_WALL_DURATION
		placed += 1
	if placed > 0:
		events.append(GameEvent.new(Event.ICE_WALL_PLACED, {"pid": pl.pid}))


func _soul_swap(pl: PlayerData) -> void:
	var nearest: PlayerData = null
	var min_dist := INF
	for opp: PlayerData in _all_players():
		if opp.pid == pl.pid or not opp.alive:
			continue
		var dx := pl.gx - opp.gx
		var dy := pl.gy - opp.gy
		var dist := sqrt(dx * dx + dy * dy)
		if dist < min_dist:
			min_dist = dist
			nearest = opp
	if nearest == null:
		return
	var tmp_gx := pl.gx
	var tmp_gy := pl.gy
	pl.gx = nearest.gx
	pl.gy = nearest.gy
	pl.target_gx = pl.gx
	pl.target_gy = pl.gy
	pl.moving = false
	nearest.gx = tmp_gx
	nearest.gy = tmp_gy
	nearest.target_gx = nearest.gx
	nearest.target_gy = nearest.gy
	nearest.moving = false
	events.append(GameEvent.new(Event.SOUL_SWAPPED, {"pid": pl.pid, "other_pid": nearest.pid}))


func _spawn_clone(pl: PlayerData) -> void:
	clones.append(CloneData.new(int(roundf(pl.gx)), int(roundf(pl.gy)), pl.pid))
	pl.invisible_timer = INVISIBLE_DURATION
	events.append(GameEvent.new(Event.CLONE_SPAWNED, {"pid": pl.pid}))


func tick_ice_walls(dt: float) -> void:
	var to_remove: Array[Vector2i] = []
	for pos: Vector2i in ice_wall_timers:
		ice_wall_timers[pos] -= dt
		if ice_wall_timers[pos] <= 0.0:
			to_remove.append(pos)
	for p: Vector2i in to_remove:
		ice_wall_timers.erase(p)
		if p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows:
			if grid[p.x][p.y] == Cell.ICE_WALL:
				grid[p.x][p.y] = Cell.EMPTY


func tick_clones(dt: float) -> void:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cl_item in clones:
		var cl: CloneData = cl_item
		if not cl.alive:
			continue
		for e in explosions:
			var ex: ExplData = e
			if ex.gx == cl.gx and ex.gy == cl.gy:
				cl.alive = false
				_clone_pop_slow(cl)
				events.append(GameEvent.new(Event.CLONE_POPPED, {"gx": cl.gx, "gy": cl.gy, "pid": cl.owner_pid}))
				break
		if not cl.alive:
			continue
		cl.timer -= dt
		if cl.timer <= 0.0:
			cl.alive = false
			continue
		cl.move_timer -= dt
		if cl.move_timer <= 0.0:
			cl.move_timer = CLONE_MOVE_TIME + rng.randf() * 0.5
			var valid: Array[Vector2i] = []
			for d: Vector2i in dirs:
				var nx: int = cl.gx + d.x
				var ny: int = cl.gy + d.y
				if nx >= 1 and nx < cols - 1 and ny >= 1 and ny < rows - 1:
					if grid[nx][ny] == Cell.EMPTY and bomb_at(nx, ny) == null:
						valid.append(d)
			if not valid.is_empty():
				var d: Vector2i = valid[rng.randi() % valid.size()]
				cl.gx += d.x
				cl.gy += d.y


func _clone_pop_slow(cl: CloneData) -> void:
	for t: PlayerData in _all_players():
		if not t.alive or t.pid == cl.owner_pid:
			continue
		var dx := absi(int(roundf(t.gx)) - cl.gx)
		var dy := absi(int(roundf(t.gy)) - cl.gy)
		if dx <= CLONE_SLOW_RANGE and dy <= CLONE_SLOW_RANGE:
			t.slow_timer = maxf(t.slow_timer, CLONE_SLOW_DUR)


# ── 得分 / 连击 ───────────────────────────

func _player_by_pid(pid: int) -> PlayerData:
	if p1.pid == pid:
		return p1
	if p2.pid == pid:
		return p2
	for ep in extra_players:
		var epl: PlayerData = ep
		if epl.pid == pid:
			return epl
	return null


func _award_score(pl: PlayerData, base: int) -> void:
	var mult := 1.0 + pl.combo * 0.3
	if match_phase == MatchPhase.CLIMAX:
		mult *= 2.0
	pl.score += int(base * mult)
	pl.combo += 1
	pl.combo_timer = COMBO_WINDOW
	if pl.combo > pl.max_combo:
		pl.max_combo = pl.combo
	if pl.combo >= 2:
		events.append(GameEvent.new(Event.COMBO_UP, {"pid": pl.pid, "combo": pl.combo}))


func _award_score_pid(pid: int, base: int) -> void:
	if pid < 0:
		return
	var pl := _player_by_pid(pid)
	if pl != null and pl.alive:
		_award_score(pl, base)


func _break_combo(pl: PlayerData) -> void:
	if pl.combo > 0:
		events.append(GameEvent.new(Event.COMBO_BREAK, {"pid": pl.pid, "combo": pl.combo}))
		pl.combo = 0
		pl.combo_timer = 0.0


func _get_fuse_for(pl: PlayerData) -> float:
	return maxf(BOMB_FUSE - pl.pickup_count * FUSE_PENALTY, MIN_FUSE)


func _place_super_bomb(pl: PlayerData) -> void:
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	if bomb_at(gx, gy) != null:
		return
	if _active_bombs_for(pl.pid) >= pl.max_bombs:
		return
	var bd := BombData.new(gx, gy, pl.pid, _get_fuse_for(pl), pl.range_i + SUPER_RANGE_BONUS)
	bd.is_super = true
	if pl.has_remote:
		bd.is_remote = true
		bd.time = 9999.0
	bombs.append(bd)
	pl.note_placed_bomb(gx, gy)
	_award_score(pl, 5)
	events.append(GameEvent.new(Event.SUPER_BOMB_PLACED, {"pid": pl.pid}))


func _resolve_mystery(x: int, y: int) -> void:
	var roll := rng.randf()
	var result: String
	if roll < 0.50:
		result = "rare"
		var kind: int = Pickup.BOMB_UP if rng.randf() < 0.5 else Pickup.FIRE_UP
		pickups.append(PickupData.new(x, y, kind))
		pickups.append(PickupData.new(x, y, kind))
	elif roll < 0.80:
		result = "trap"
		explosions.append(ExplData.new(x, y, EXPLOSION_TTL))
		_damage_at(x, y)
	else:
		result = "curse"
		pickups.append(PickupData.new(x, y, Pickup.SLOW_CURSE))
	events.append(GameEvent.new(Event.MYSTERY_RESOLVED, {"gx": x, "gy": y, "result": result}))


# ── 比赛阶段 ──────────────────────────────

func tick_match_phase(dt: float) -> void:
	if phase != Phase.PLAYING:
		return
	match_timer += dt
	var new_phase: int = match_phase
	if match_timer >= PHASE_TENSION_END:
		new_phase = MatchPhase.CLIMAX
	elif match_timer >= PHASE_OPENING_END:
		new_phase = MatchPhase.TENSION
	if new_phase != match_phase:
		var old_phase := match_phase
		match_phase = new_phase
		events.append(GameEvent.new(Event.MATCH_PHASE_CHANGE, {"phase": match_phase}))
		for pl: PlayerData in _all_players():
			if pl.alive:
				_award_score(pl, SCORE_PHASE)
		if match_phase == MatchPhase.TENSION and not shrink_enabled:
			shrink_enabled = true
			shrink_timer = SHRINK_START - 5.0


func _all_players() -> Array:
	var result: Array = [p1, p2]
	result.append_array(extra_players)
	return result
