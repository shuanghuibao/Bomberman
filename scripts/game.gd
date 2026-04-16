extends Node2D

## 场景控制器：输入 → GameLogic → 渲染 + UI + 音效 + Toast + NPC

const NpcAIScript = preload("res://scripts/npc_ai.gd")

const HUD_H := 78.0
const GRID_PADDING := 12.0
const TOAST_TTL := 1.8

const CLR_PICKUP_BOMB := Color(0.28, 0.62, 1.0)
const CLR_PICKUP_FIRE := Color(1.0, 0.42, 0.22)
const CLR_PICKUP_SPEED := Color(0.25, 0.88, 0.42)

const NPC_COLORS: Array[Color] = [
	Color(1.0, 0.52, 0.38),
	Color(0.62, 0.85, 0.30),
	Color(0.90, 0.55, 0.90),
]

const NPC_SPAWNS: Array[Vector2i] = [
	Vector2i(13, 9),
	Vector2i(1, 9),
	Vector2i(13, 1),
]

var logic: GameLogic
var tile_size := 40.0
var origin := Vector2.ZERO
var match_paused: bool = false
var is_vs_npc: bool = false
var npc_count: int = 1
var npcs: Array = []  # Array[NpcAI]
var npc_players: Array = []  # Array[GameLogic.PlayerData]

class ToastItem:
	var text: String
	var color: Color
	var ttl: float
	func _init(t: String, c: Color, life: float) -> void:
		text = t; color = c; ttl = life

var _toasts: Array = []
var _sfx: SFX

@onready var _lbl_hint: Label = %LblHint
@onready var _lbl_phase: Label = %LblPhase
@onready var _pause_layer: Control = %PauseLayer
@onready var _result_layer: Control = %ResultLayer
@onready var _lbl_result: Label = %LblResult
@onready var _toast_container: VBoxContainer = %ToastContainer


func _ready() -> void:
	_sfx = SFX.new()
	add_child(_sfx)

	logic = GameLogic.new()

	if has_meta("vs_npc"):
		is_vs_npc = get_meta("vs_npc")
	if has_meta("npc_count"):
		npc_count = clampi(get_meta("npc_count"), 1, 3)

	logic.reset()
	_setup_npc_players()

	%BtnMenu.pressed.connect(_go_main_menu)
	%BtnResume.pressed.connect(_resume)
	%BtnPauseToMenu.pressed.connect(_go_main_menu)
	%BtnRematch.pressed.connect(_on_rematch)
	%BtnResultToMenu.pressed.connect(_go_main_menu)
	get_viewport().size_changed.connect(_recalc_origin)
	_recalc_origin()
	_refresh_ui()


func _setup_npc_players() -> void:
	npcs.clear()
	npc_players.clear()
	if not is_vs_npc:
		return
	for i in range(npc_count):
		var spawn: Vector2i = NPC_SPAWNS[i]
		var pl := GameLogic.PlayerData.new(10 + i, spawn.x, spawn.y)
		npc_players.append(pl)
		var ai = NpcAIScript.new(logic, pl)
		npcs.append(ai)
		# clear spawn area
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cx := spawn.x + dx
				var cy := spawn.y + dy
				if cx > 0 and cy > 0 and cx < GameLogic.COLS - 1 and cy < GameLogic.ROWS - 1:
					if logic.grid[cx][cy] == GameLogic.Cell.CRATE:
						logic.grid[cx][cy] = GameLogic.Cell.EMPTY


func _recalc_origin() -> void:
	var vs := get_viewport().get_visible_rect().size
	var avail_w := vs.x - GRID_PADDING * 2.0
	var avail_h := vs.y - HUD_H - GRID_PADDING * 2.0
	tile_size = minf(avail_w / float(GameLogic.COLS), avail_h / float(GameLogic.ROWS))
	tile_size = maxf(tile_size, 16.0)
	var wx := GameLogic.COLS * tile_size
	var wy := GameLogic.ROWS * tile_size
	origin = Vector2(
		(vs.x - wx) * 0.5,
		HUD_H + (vs.y - HUD_H - wy) * 0.5
	)
	queue_redraw()


func _reset_match() -> void:
	logic.reset()
	_setup_npc_players()
	match_paused = false
	_pause_layer.hide()
	_result_layer.hide()
	_toasts.clear()
	queue_redraw()
	_refresh_ui()


func _process(delta: float) -> void:
	_tick_toasts(delta)

	if Input.is_action_just_pressed("ui_cancel"):
		if logic.phase == GameLogic.Phase.PLAYING:
			match_paused = not match_paused
			_pause_layer.visible = match_paused
			_refresh_ui()

	logic.tick_explosions(delta)

	if logic.phase != GameLogic.Phase.PLAYING:
		if Input.is_action_just_pressed("reset_match"):
			_reset_match()
		queue_redraw()
		return

	if match_paused:
		queue_redraw()
		return

	if Input.is_action_just_pressed("reset_match"):
		_reset_match()
		return

	logic.events.clear()

	logic.update_player(logic.p1, _read_dir_p1(), Input.is_action_just_pressed("p1_bomb"), delta)

	if is_vs_npc:
		for i in range(npcs.size()):
			var ai = npcs[i]
			var pl: GameLogic.PlayerData = npc_players[i]
			if not pl.alive:
				continue
			var decision: Dictionary = ai.tick(delta)
			var dir: Vector2i = decision["dir"]
			var want_bomb: bool = decision["bomb"]
			_update_npc_player(pl, dir, want_bomb, delta)
	else:
		logic.update_player(logic.p2, _read_dir_p2(), Input.is_action_just_pressed("p2_bomb"), delta)

	logic.tick_bombs(delta)
	_resolve_phase_extended()

	_handle_events()
	_refresh_ui()
	queue_redraw()


func _update_npc_player(pl: GameLogic.PlayerData, dir: Vector2i, want_bomb: bool, dt: float) -> void:
	if not pl.alive:
		return
	if dir != Vector2i.ZERO:
		logic.try_start_move(pl, dir.x, dir.y)
	logic.player_move_tick(pl, dt)
	logic.try_collect_pickup(pl)
	if want_bomb:
		_try_place_bomb_for(pl)


func _try_place_bomb_for(pl: GameLogic.PlayerData) -> void:
	if not pl.alive or logic.phase != GameLogic.Phase.PLAYING:
		return
	if not pl.aligned():
		return
	var gx := int(roundf(pl.gx))
	var gy := int(roundf(pl.gy))
	if logic.bomb_at(gx, gy) != null:
		return
	var count := 0
	for b in logic.bombs:
		var bd: GameLogic.BombData = b
		if bd.owner_id == pl.pid:
			count += 1
	if count >= pl.max_bombs:
		return
	logic.bombs.append(GameLogic.BombData.new(gx, gy, pl.pid, GameLogic.BOMB_FUSE, pl.range_i))
	pl.note_placed_bomb(gx, gy)
	logic.events.append(GameLogic.GameEvent.new(GameLogic.Event.BOMB_PLACED, {"pid": pl.pid}))


func _resolve_phase_extended() -> void:
	if logic.phase != GameLogic.Phase.PLAYING:
		return
	if is_vs_npc:
		var any_npc_alive := false
		for pl in npc_players:
			var p: GameLogic.PlayerData = pl
			if p.alive:
				any_npc_alive = true
				break
		# also damage NPC players from explosions
		_damage_npc_players()
		any_npc_alive = false
		for pl in npc_players:
			var p: GameLogic.PlayerData = pl
			if p.alive:
				any_npc_alive = true
				break
		if logic.p1.alive and not any_npc_alive:
			logic.phase = GameLogic.Phase.P1_WIN
			logic.events.append(GameLogic.GameEvent.new(GameLogic.Event.PHASE_END, {"phase": logic.phase}))
		elif not logic.p1.alive:
			logic.phase = GameLogic.Phase.P2_WIN
			logic.events.append(GameLogic.GameEvent.new(GameLogic.Event.PHASE_END, {"phase": logic.phase}))
	else:
		logic.resolve_phase()


func _damage_npc_players() -> void:
	for pl in npc_players:
		var p: GameLogic.PlayerData = pl
		if not p.alive:
			continue
		var gx := int(roundf(p.gx))
		var gy := int(roundf(p.gy))
		for e in logic.explosions:
			var ex: GameLogic.ExplData = e
			if ex.gx == gx and ex.gy == gy:
				p.alive = false
				break


func _handle_events() -> void:
	for ev in logic.events:
		var e: GameLogic.GameEvent = ev
		match e.type:
			GameLogic.Event.BOMB_PLACED:
				_sfx.play_place_bomb()
			GameLogic.Event.EXPLOSION:
				_sfx.play_explosion()
			GameLogic.Event.PICKUP_COLLECTED:
				_sfx.play_pickup()
				_spawn_pickup_toast(e.data)
			GameLogic.Event.PHASE_END:
				_show_result()
				var p: int = e.data.get("phase", 0)
				if p == GameLogic.Phase.P1_WIN:
					_sfx.play_win()
				else:
					_sfx.play_lose()


func _spawn_pickup_toast(data: Dictionary) -> void:
	var kind: int = data.get("kind", 0)
	var pid: int = data.get("pid", 0)
	var who := "P1" if pid == 0 else ("NPC" if pid >= 10 else "P2")
	var desc := ""
	var col := Color.WHITE
	match kind:
		GameLogic.Pickup.BOMB_UP:
			desc = "%s 获得 炸弹+1（同时可放更多雷）" % who
			col = CLR_PICKUP_BOMB
		GameLogic.Pickup.FIRE_UP:
			desc = "%s 获得 火力+1（爆炸范围更远）" % who
			col = CLR_PICKUP_FIRE
		GameLogic.Pickup.SPEED_UP:
			desc = "%s 获得 加速鞋（移动更快）" % who
			col = CLR_PICKUP_SPEED
	_toasts.append(ToastItem.new(desc, col, TOAST_TTL))
	_sync_toast_ui()


func _tick_toasts(dt: float) -> void:
	var changed := false
	for i in range(_toasts.size() - 1, -1, -1):
		var t: ToastItem = _toasts[i]
		t.ttl -= dt
		if t.ttl <= 0.0:
			_toasts.remove_at(i)
			changed = true
	if changed:
		_sync_toast_ui()


func _sync_toast_ui() -> void:
	for c in _toast_container.get_children():
		c.queue_free()
	for t in _toasts:
		var ti: ToastItem = t
		var lbl := Label.new()
		lbl.text = ti.text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ti.color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_container.add_child(lbl)


func _show_result() -> void:
	match_paused = false
	_pause_layer.hide()
	_result_layer.show()
	match logic.phase:
		GameLogic.Phase.P1_WIN:
			if is_vs_npc:
				_lbl_result.text = "你赢了！"
			else:
				_lbl_result.text = "玩家 1（蓝）获胜！"
		GameLogic.Phase.P2_WIN:
			if is_vs_npc:
				_lbl_result.text = "NPC 获胜，你输了"
			else:
				_lbl_result.text = "玩家 2（橙）获胜！"
		GameLogic.Phase.DRAW:
			_lbl_result.text = "平局（同归于尽）"


func _read_dir_p1() -> Vector2i:
	var x := 0; var y := 0
	if Input.is_physical_key_pressed(KEY_A): x -= 1
	if Input.is_physical_key_pressed(KEY_D): x += 1
	if Input.is_physical_key_pressed(KEY_W): y -= 1
	if Input.is_physical_key_pressed(KEY_S): y += 1
	return _norm_dir(x, y)


func _read_dir_p2() -> Vector2i:
	var x := 0; var y := 0
	if Input.is_physical_key_pressed(KEY_LEFT): x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT): x += 1
	if Input.is_physical_key_pressed(KEY_UP): y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN): y += 1
	return _norm_dir(x, y)


func _norm_dir(x: int, y: int) -> Vector2i:
	if x != 0 and y != 0:
		if absi(x) >= absi(y): y = 0
		else: x = 0
	return Vector2i(x, y)


func _refresh_ui() -> void:
	if is_vs_npc:
		var p1s := "你 炸弹%d 火力%d 速度%d" % [logic.p1.max_bombs, logic.p1.range_i, logic.p1.speed_ups]
		_lbl_hint.text = "%s  |  WASD/空格  R重开  Esc暂停" % p1s
	else:
		var p1s := "P1 炸弹%d 火力%d 速度%d" % [logic.p1.max_bombs, logic.p1.range_i, logic.p1.speed_ups]
		var p2s := "P2 炸弹%d 火力%d 速度%d" % [logic.p2.max_bombs, logic.p2.range_i, logic.p2.speed_ups]
		_lbl_hint.text = "%s  |  %s  |  WASD/空格  方向键/回车  R重开  Esc暂停" % [p1s, p2s]
	if logic.phase == GameLogic.Phase.PLAYING:
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
	_reset_match()


# ── 绘制 ──────────────────────────────────

func _draw() -> void:
	var o := origin
	var ts := tile_size
	var L := logic

	draw_rect(Rect2(o.x, o.y, GameLogic.COLS * ts, GameLogic.ROWS * ts), Color(0.09, 0.10, 0.13))

	for x in range(GameLogic.COLS):
		for y in range(GameLogic.ROWS):
			var c: int = L.grid[x][y]
			var col: Color
			if c == GameLogic.Cell.WALL:
				col = Color(0.22, 0.24, 0.30)
			elif c == GameLogic.Cell.CRATE:
				col = Color(0.78, 0.52, 0.28)
			else:
				col = Color(0.12, 0.13, 0.16)
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, ts), col)
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, 1.2), Color(0, 0, 0, 0.18))
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, 1.2, ts), Color(0, 0, 0, 0.18))

	for p in L.pickups:
		var pd: GameLogic.PickupData = p
		_draw_pickup(pd, o, ts)

	for b in L.bombs:
		var bd: GameLogic.BombData = b
		var pulse := 0.5 + 0.5 * sin(bd.time * 14.0)
		var inset := ts * 0.15 + pulse * ts * 0.05
		var rx := o.x + bd.gx * ts + inset
		var ry := o.y + bd.gy * ts + inset
		var sz := ts - inset * 2.0
		draw_rect(Rect2(rx, ry, sz, sz), Color(0.05, 0.05, 0.06))
		var inner := ts * 0.08
		draw_rect(Rect2(rx + inner, ry + inner, sz - inner * 2.0, sz - inner * 2.0), Color(0.95, 0.35, 0.12))

	for e in L.explosions:
		var ex: GameLogic.ExplData = e
		var t := ex.ttl / GameLogic.EXPLOSION_TTL
		var ins := ts * 0.25 * (1.0 - t)
		draw_rect(
			Rect2(o.x + ex.gx * ts + ins, o.y + ex.gy * ts + ins, ts - ins * 2.0, ts - ins * 2.0),
			Color(1.0, 0.85 * t, 0.15 * t, 0.85)
		)

	_draw_player(L.p1, Color(0.35, 0.75, 1.0))
	if is_vs_npc:
		for i in range(npc_players.size()):
			_draw_player(npc_players[i], NPC_COLORS[i % NPC_COLORS.size()])
	else:
		_draw_player(L.p2, Color(1.0, 0.52, 0.38))


func _draw_pickup(pd: GameLogic.PickupData, o: Vector2, ts: float) -> void:
	var m := ts * 0.28
	var col: Color
	if pd.kind == GameLogic.Pickup.BOMB_UP:
		col = CLR_PICKUP_BOMB
	elif pd.kind == GameLogic.Pickup.FIRE_UP:
		col = CLR_PICKUP_FIRE
	elif pd.kind == GameLogic.Pickup.SPEED_UP:
		col = CLR_PICKUP_SPEED
	else:
		col = Color.WHITE
	var bg := col.darkened(0.55)
	draw_rect(Rect2(o.x + pd.gx * ts + m - 2.0, o.y + pd.gy * ts + m - 2.0, ts - (m - 2.0) * 2.0, ts - (m - 2.0) * 2.0), bg)
	draw_rect(Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m, ts - m * 2.0, ts - m * 2.0), col)
	var cx := o.x + pd.gx * ts + ts * 0.5
	var cy := o.y + pd.gy * ts + ts * 0.5
	var dot := ts * 0.08
	if pd.kind == GameLogic.Pickup.BOMB_UP:
		draw_rect(Rect2(cx - dot, cy - dot * 2.5, dot * 2.0, dot * 5.0), Color.WHITE)
	elif pd.kind == GameLogic.Pickup.FIRE_UP:
		draw_rect(Rect2(cx - dot * 2.5, cy - dot, dot * 5.0, dot * 2.0), Color.WHITE)
		draw_rect(Rect2(cx - dot, cy - dot * 2.5, dot * 2.0, dot * 5.0), Color.WHITE)
	elif pd.kind == GameLogic.Pickup.SPEED_UP:
		draw_rect(Rect2(cx - dot * 1.5, cy - dot * 1.5, dot * 3.0, dot * 3.0), Color.WHITE)


func _draw_player(pl: GameLogic.PlayerData, col: Color) -> void:
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
