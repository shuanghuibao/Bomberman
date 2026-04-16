extends Node2D

## 本地双人炸弹场：网格 + 道具掉落/拾取 + `_draw` 渲染 + CanvasLayer UI

const COLS := 15
const ROWS := 11
const BASE_SPEED := 5.0
const MAX_SPEED := 9.5
const SPEED_PER_SHOE := 1.2
const BOMB_FUSE := 2.4
const EXPLOSION_TTL := 0.45
const HUD_H := 78.0
const GRID_PADDING := 12.0
const DROP_CHANCE := 0.55

var tile_size := 40.0

enum Cell { EMPTY, WALL, CRATE }
enum Phase { PLAYING, P1_WIN, P2_WIN, DRAW }
enum Pickup { BOMB_UP, FIRE_UP, SPEED_UP }

# ── 颜色常量 ──────────────────────────────
const CLR_PICKUP_BOMB := Color(0.28, 0.62, 1.0)
const CLR_PICKUP_FIRE := Color(1.0, 0.42, 0.22)
const CLR_PICKUP_SPEED := Color(0.25, 0.88, 0.42)


class PlayerData:
	var pid: int
	var gx: float
	var gy: float
	var alive: bool = true
	var max_bombs: int = 1
	var range_i: int = 1
	var speed_ups: int = 0
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
		last_bomb = Vector2i(999999, 999999)
		moving = false

	func move_speed() -> float:
		return minf(BASE_SPEED + speed_ups * SPEED_PER_SHOE, MAX_SPEED)

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
	var kind: int  # Pickup enum value

	func _init(x: int, y: int, k: int) -> void:
		gx = x
		gy = y
		kind = k


var rng := RandomNumberGenerator.new()
var grid: Array = []
var p1 := PlayerData.new(0, 1, 1)
var p2 := PlayerData.new(1, COLS - 2, ROWS - 2)
var bombs: Array = []
var explosions: Array = []
var pickups: Array = []
var phase: Phase = Phase.PLAYING
var origin := Vector2.ZERO
var match_paused: bool = false

@onready var _lbl_hint: Label = %LblHint
@onready var _lbl_phase: Label = %LblPhase
@onready var _pause_layer: Control = %PauseLayer
@onready var _result_layer: Control = %ResultLayer
@onready var _lbl_result: Label = %LblResult


func _ready() -> void:
	rng.randomize()
	%BtnMenu.pressed.connect(_go_main_menu)
	%BtnResume.pressed.connect(_resume)
	%BtnPauseToMenu.pressed.connect(_go_main_menu)
	%BtnRematch.pressed.connect(_on_rematch)
	%BtnResultToMenu.pressed.connect(_go_main_menu)
	get_viewport().size_changed.connect(_recalc_origin)
	_recalc_origin()
	reset_match()
	_refresh_ui()


func _recalc_origin() -> void:
	var vs := get_viewport().get_visible_rect().size
	var avail_w := vs.x - GRID_PADDING * 2.0
	var avail_h := vs.y - HUD_H - GRID_PADDING * 2.0
	tile_size = minf(avail_w / float(COLS), avail_h / float(ROWS))
	tile_size = maxf(tile_size, 16.0)
	var wx := COLS * tile_size
	var wy := ROWS * tile_size
	origin = Vector2(
		(vs.x - wx) * 0.5,
		HUD_H + (vs.y - HUD_H - wy) * 0.5
	)
	queue_redraw()


func reset_match() -> void:
	phase = Phase.PLAYING
	bombs.clear()
	explosions.clear()
	pickups.clear()
	_build_grid()
	p1.reset(1, 1)
	p2.reset(COLS - 2, ROWS - 2)
	match_paused = false
	_pause_layer.hide()
	_result_layer.hide()
	queue_redraw()
	_refresh_ui()


func _build_grid() -> void:
	grid.clear()
	for x in range(COLS):
		var col: Array = []
		col.resize(ROWS)
		grid.append(col)
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
			if rng.randf() < 0.52:
				grid[x][y] = Cell.CRATE
	_carve_reachable_crates()


func _is_spawn_zone(x: int, y: int) -> bool:
	return (x <= 2 and y <= 2) or (x >= COLS - 3 and y >= ROWS - 3)


func _carve_reachable_crates() -> void:
	var reach: Dictionary = {}
	_bfs_reachable(1, 1, reach)
	_bfs_reachable(COLS - 2, ROWS - 2, reach)
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


# ── 道具 ──────────────────────────────────

func _maybe_drop_pickup(x: int, y: int) -> void:
	if rng.randf() > DROP_CHANCE:
		return
	var roll := rng.randf()
	var kind: int
	if roll < 0.38:
		kind = Pickup.BOMB_UP
	elif roll < 0.72:
		kind = Pickup.FIRE_UP
	else:
		kind = Pickup.SPEED_UP
	pickups.append(PickupData.new(x, y, kind))


func _pickup_at(gx: int, gy: int) -> PickupData:
	for p in pickups:
		var pd: PickupData = p
		if pd.gx == gx and pd.gy == gy:
			return pd
	return null


func _try_collect_pickup(pl: PlayerData) -> void:
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	var pd: PickupData = _pickup_at(gx, gy)
	if pd == null:
		return
	match pd.kind:
		Pickup.BOMB_UP:
			pl.max_bombs = mini(pl.max_bombs + 1, 8)
		Pickup.FIRE_UP:
			pl.range_i = mini(pl.range_i + 1, 8)
		Pickup.SPEED_UP:
			pl.speed_ups = mini(pl.speed_ups + 1, 5)
	pickups.erase(pd)


func _destroy_pickups_at(x: int, y: int) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pd: PickupData = pickups[i]
		if pd.gx == x and pd.gy == y:
			pickups.remove_at(i)


# ── 主循环 ────────────────────────────────

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if phase == Phase.PLAYING:
			match_paused = not match_paused
			_pause_layer.visible = match_paused
			_refresh_ui()

	_tick_explosions(delta)

	if phase != Phase.PLAYING:
		if Input.is_action_just_pressed("reset_match"):
			reset_match()
		queue_redraw()
		return

	if match_paused:
		queue_redraw()
		return

	if Input.is_action_just_pressed("reset_match"):
		reset_match()
		_refresh_ui()
		queue_redraw()
		return

	_update_player(p1, _read_dir_p1(), Input.is_action_just_pressed("p1_bomb"), delta)
	_update_player(p2, _read_dir_p2(), Input.is_action_just_pressed("p2_bomb"), delta)
	_tick_bombs(delta)
	_resolve_phase()
	_refresh_ui()
	queue_redraw()


func _read_dir_p1() -> Vector2i:
	var x := 0
	var y := 0
	if Input.is_physical_key_pressed(KEY_A):
		x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		x += 1
	if Input.is_physical_key_pressed(KEY_W):
		y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		y += 1
	return _norm_dir(x, y)


func _read_dir_p2() -> Vector2i:
	var x := 0
	var y := 0
	if Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1
	if Input.is_physical_key_pressed(KEY_UP):
		y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN):
		y += 1
	return _norm_dir(x, y)


func _norm_dir(x: int, y: int) -> Vector2i:
	if x != 0 and y != 0:
		if absi(x) >= absi(y):
			y = 0
		else:
			x = 0
	return Vector2i(x, y)


func _update_player(pl: PlayerData, dir: Vector2i, want_bomb: bool, delta: float) -> void:
	if not pl.alive:
		return
	if dir != Vector2i.ZERO:
		_try_start_move(pl, dir.x, dir.y)
	_player_move_tick(pl, delta)
	_try_collect_pickup(pl)
	if want_bomb:
		_try_place_bomb(pl)


func _try_start_move(pl: PlayerData, dx: int, dy: int) -> bool:
	if dx == 0 and dy == 0:
		return false
	if pl.moving or not pl.aligned():
		return false
	var sx := int(roundf(pl.gx))
	var sy := int(roundf(pl.gy))
	var tx := sx + dx
	var ty := sy + dy
	if not _walkable_for(tx, ty, pl):
		return false
	pl.gx = float(sx)
	pl.gy = float(sy)
	pl.target_gx = float(tx)
	pl.target_gy = float(ty)
	pl.moving = true
	pl.last_bomb = Vector2i(999999, 999999)
	return true


func _player_move_tick(pl: PlayerData, dt: float) -> void:
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


func _walkable_for(gx: int, gy: int, pl: PlayerData) -> bool:
	if gx < 0 or gy < 0 or gx >= COLS or gy >= ROWS:
		return false
	if grid[gx][gy] != Cell.EMPTY:
		return false
	var b: BombData = bomb_at(gx, gy)
	if b != null:
		return pl.can_stand_on_bomb(gx, gy)
	return true


func bomb_at(gx: int, gy: int) -> BombData:
	for b in bombs:
		var bd: BombData = b
		if bd.gx == gx and bd.gy == gy:
			return bd
	return null


func _try_place_bomb(pl: PlayerData) -> void:
	if not pl.alive or phase != Phase.PLAYING:
		return
	if not pl.aligned():
		return
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	if bomb_at(gx, gy) != null:
		return
	if _active_bombs_for(pl.pid) >= pl.max_bombs:
		return
	bombs.append(BombData.new(gx, gy, pl.pid, BOMB_FUSE, pl.range_i))
	pl.note_placed_bomb(gx, gy)


func _active_bombs_for(pid: int) -> int:
	var n := 0
	for b in bombs:
		var bd: BombData = b
		if bd.owner_id == pid:
			n += 1
	return n


func _tick_bombs(dt: float) -> void:
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


func _explode_bomb_wave(seed: BombData) -> void:
	var q: Array = [seed]
	while not q.is_empty():
		var b: BombData = q.pop_front()
		if not bombs.has(b):
			continue
		bombs.erase(b)
		_explode_single(b, q)


func _explode_single(b: BombData, q: Array) -> void:
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
		var c: Cell = grid[x][y]
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
			q.append(other)
		return true
	var c: Cell = grid[x][y]
	return c == Cell.WALL or c == Cell.CRATE


func _damage_at(x: int, y: int) -> void:
	if p1.alive and int(roundf(p1.gx)) == x and int(roundf(p1.gy)) == y:
		p1.alive = false
	if p2.alive and int(roundf(p2.gx)) == x and int(roundf(p2.gy)) == y:
		p2.alive = false


func _tick_explosions(dt: float) -> void:
	for i in range(explosions.size() - 1, -1, -1):
		var e: ExplData = explosions[i]
		e.ttl -= dt
		if e.ttl <= 0.0:
			explosions.remove_at(i)


func _resolve_phase() -> void:
	if phase != Phase.PLAYING:
		return
	if p1.alive and not p2.alive:
		phase = Phase.P1_WIN
	elif p2.alive and not p1.alive:
		phase = Phase.P2_WIN
	elif not p1.alive and not p2.alive:
		phase = Phase.DRAW
	else:
		return
	match_paused = false
	_pause_layer.hide()
	_result_layer.show()
	match phase:
		Phase.P1_WIN:
			_lbl_result.text = "玩家 1（蓝）获胜！"
		Phase.P2_WIN:
			_lbl_result.text = "玩家 2（橙）获胜！"
		Phase.DRAW:
			_lbl_result.text = "平局（同归于尽）"
	_refresh_ui()


func _refresh_ui() -> void:
	var p1s := "P1 炸弹%d 火力%d 速度%d" % [p1.max_bombs, p1.range_i, p1.speed_ups]
	var p2s := "P2 炸弹%d 火力%d 速度%d" % [p2.max_bombs, p2.range_i, p2.speed_ups]
	_lbl_hint.text = "%s  |  %s  |  WASD/空格  方向键/回车  R重开  Esc暂停" % [p1s, p2s]
	if phase == Phase.PLAYING:
		_lbl_phase.text = "对局进行中" if not match_paused else "已暂停"
	else:
		_lbl_phase.text = "本局结束"


func _go_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _resume() -> void:
	match_paused = false
	_pause_layer.hide()
	_refresh_ui()


func _on_rematch() -> void:
	reset_match()


# ── 绘制 ──────────────────────────────────

func _draw() -> void:
	var o := origin
	var ts := tile_size

	# 地图底色（整片暗色背景）
	draw_rect(Rect2(o.x, o.y, COLS * ts, ROWS * ts), Color(0.09, 0.10, 0.13))

	for x in range(COLS):
		for y in range(ROWS):
			var c: Cell = grid[x][y]
			var col: Color
			match c:
				Cell.WALL:
					col = Color(0.22, 0.24, 0.30)
				Cell.CRATE:
					col = Color(0.78, 0.52, 0.28)
				_:
					col = Color(0.12, 0.13, 0.16)
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, ts), col)
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, 1.2), Color(0, 0, 0, 0.18))
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, 1.2, ts), Color(0, 0, 0, 0.18))

	# 道具
	for p in pickups:
		var pd: PickupData = p
		_draw_pickup(pd, o, ts)

	# 炸弹
	for b in bombs:
		var bd: BombData = b
		var pulse := 0.5 + 0.5 * sin(bd.time * 14.0)
		var inset := ts * 0.15 + pulse * ts * 0.05
		var rx := o.x + bd.gx * ts + inset
		var ry := o.y + bd.gy * ts + inset
		var sz := ts - inset * 2.0
		draw_rect(Rect2(rx, ry, sz, sz), Color(0.05, 0.05, 0.06))
		var inner := ts * 0.08
		draw_rect(Rect2(rx + inner, ry + inner, sz - inner * 2.0, sz - inner * 2.0), Color(0.95, 0.35, 0.12))

	# 爆炸
	for e in explosions:
		var ex: ExplData = e
		var t := ex.ttl / EXPLOSION_TTL
		var ins := ts * 0.25 * (1.0 - t)
		draw_rect(
			Rect2(o.x + ex.gx * ts + ins, o.y + ex.gy * ts + ins, ts - ins * 2.0, ts - ins * 2.0),
			Color(1.0, 0.85 * t, 0.15 * t, 0.85)
		)

	# 玩家
	_draw_player(p1, Color(0.35, 0.75, 1.0))
	_draw_player(p2, Color(1.0, 0.52, 0.38))


func _draw_pickup(pd: PickupData, o: Vector2, ts: float) -> void:
	var m := ts * 0.28
	var col: Color
	match pd.kind:
		Pickup.BOMB_UP:
			col = CLR_PICKUP_BOMB
		Pickup.FIRE_UP:
			col = CLR_PICKUP_FIRE
		Pickup.SPEED_UP:
			col = CLR_PICKUP_SPEED
		_:
			col = Color.WHITE
	# 底色圆角感（用两层方块模拟）
	var bg := col.darkened(0.55)
	draw_rect(Rect2(o.x + pd.gx * ts + m - 2.0, o.y + pd.gy * ts + m - 2.0, ts - (m - 2.0) * 2.0, ts - (m - 2.0) * 2.0), bg)
	draw_rect(Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m, ts - m * 2.0, ts - m * 2.0), col)
	# 内部小标记区分类型
	var cx := o.x + pd.gx * ts + ts * 0.5
	var cy := o.y + pd.gy * ts + ts * 0.5
	var dot := ts * 0.08
	match pd.kind:
		Pickup.BOMB_UP:
			draw_rect(Rect2(cx - dot, cy - dot * 2.5, dot * 2.0, dot * 5.0), Color.WHITE)
		Pickup.FIRE_UP:
			draw_rect(Rect2(cx - dot * 2.5, cy - dot, dot * 5.0, dot * 2.0), Color.WHITE)
			draw_rect(Rect2(cx - dot, cy - dot * 2.5, dot * 2.0, dot * 5.0), Color.WHITE)
		Pickup.SPEED_UP:
			draw_rect(Rect2(cx - dot * 1.5, cy - dot * 1.5, dot * 3.0, dot * 3.0), Color.WHITE)


func _draw_player(pl: PlayerData, col: Color) -> void:
	if not pl.alive:
		return
	var o := origin
	var ts := tile_size
	var m := ts * 0.2
	draw_rect(
		Rect2(o.x + pl.gx * ts + m, o.y + pl.gy * ts + m, ts - m * 2.0, ts - m * 2.0),
		col
	)
	draw_rect(
		Rect2(o.x + pl.gx * ts + m, o.y + pl.gy * ts + ts - m - 4.0, ts - m * 2.0, 4.0),
		Color(0, 0, 0, 0.25)
	)
