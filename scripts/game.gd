extends Node2D

## 场景控制器：输入 → GameLogic → 渲染 + UI + 音效 + Toast + NPC

const NpcAIScript = preload("res://scripts/npc_ai.gd")

const HUD_H := 78.0
const GRID_PADDING := 12.0
const TOAST_TTL := 1.8

const CLR_PICKUP_BOMB := Color(0.28, 0.62, 1.0)
const CLR_PICKUP_FIRE := Color(1.0, 0.42, 0.22)
const CLR_PICKUP_SPEED := Color(0.25, 0.88, 0.42)
const CLR_PICKUP_KICK := Color(0.95, 0.82, 0.18)
const CLR_PICKUP_REMOTE := Color(0.72, 0.38, 0.95)
const CLR_PICKUP_SHIELD := Color(0.20, 0.85, 0.85)
const CLR_PICKUP_CURSE := Color(0.75, 0.18, 0.22)

const NPC_COLORS: Array[Color] = [
	Color(1.0, 0.52, 0.38),
	Color(0.62, 0.85, 0.30),
	Color(0.90, 0.55, 0.90),
]

var logic: GameLogic
var tile_size := 40.0
var origin := Vector2.ZERO
var match_paused: bool = false
var is_vs_npc: bool = false
var npc_count: int = 1
var npcs: Array = []
var npc_players: Array = []
var _current_map: Dictionary = {}
var _sprites: SpriteFactory

const PLAYER_SPRITE_KEYS: Array[String] = ["p1", "p2"]
const NPC_SPRITE_KEYS: Array[String] = ["npc0", "npc1", "npc2"]

const PICKUP_SPRITE_MAP: Dictionary = {
	GameLogic.Pickup.BOMB_UP: "item_bomb_up",
	GameLogic.Pickup.FIRE_UP: "item_fire_up",
	GameLogic.Pickup.SPEED_UP: "item_speed",
	GameLogic.Pickup.KICK: "item_kick",
	GameLogic.Pickup.REMOTE: "item_remote",
	GameLogic.Pickup.SHIELD: "item_shield",
	GameLogic.Pickup.SLOW_CURSE: "item_curse",
}

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
	_sprites = SpriteFactory.get_instance()

	logic = GameLogic.new()

	if has_meta("vs_npc"):
		is_vs_npc = get_meta("vs_npc")
	if has_meta("npc_count"):
		npc_count = clampi(get_meta("npc_count"), 1, 3)

	var all_maps := MapDefs.get_all_maps()
	var map_index := 0
	if has_meta("map_index"):
		map_index = clampi(int(get_meta("map_index")), 0, maxi(all_maps.size() - 1, 0))
	_current_map = all_maps[map_index] if map_index < all_maps.size() else {}

	logic.reset(_current_map)
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
	var spawns: Array = _current_map.get("spawns", MapDefs.DEFAULT_SPAWNS)
	for i in range(npc_count):
		var spawn_idx := 2 + i
		var spawn: Vector2i = spawns[spawn_idx] if spawn_idx < spawns.size() else Vector2i(13, 9)
		if logic.grid[spawn.x][spawn.y] != GameLogic.Cell.EMPTY:
			logic.grid[spawn.x][spawn.y] = GameLogic.Cell.EMPTY
			logic.iron_hp.erase(spawn)
		var pl := GameLogic.PlayerData.new(10 + i, spawn.x, spawn.y)
		npc_players.append(pl)
		var ai = NpcAIScript.new(logic, pl)
		npcs.append(ai)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cx := spawn.x + dx
				var cy := spawn.y + dy
				if cx > 0 and cy > 0 and cx < GameLogic.COLS - 1 and cy < GameLogic.ROWS - 1:
					var cell: int = logic.grid[cx][cy]
					if cell == GameLogic.Cell.CRATE or cell == GameLogic.Cell.IRON_CRATE:
						logic.grid[cx][cy] = GameLogic.Cell.EMPTY
						logic.iron_hp.erase(Vector2i(cx, cy))


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
	logic.reset(_current_map)
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

	logic.tick_moving_bombs(delta)
	logic.tick_bombs(delta)
	logic.tick_shrink(delta)
	_resolve_phase_extended()

	_handle_events()
	_refresh_ui()
	queue_redraw()


func _update_npc_player(pl: GameLogic.PlayerData, dir: Vector2i, want_bomb: bool, dt: float) -> void:
	if not pl.alive:
		return
	if want_bomb:
		_try_place_bomb_for(pl)
	if dir != Vector2i.ZERO:
		logic.try_start_move(pl, dir.x, dir.y)
	logic.player_move_tick(pl, dt)
	logic.try_collect_pickup(pl)


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
		_damage_npc_players()
		var any_npc_alive := false
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
		if logic.grid[gx][gy] == GameLogic.Cell.SHRINK_WALL:
			logic.try_kill_player(p)
			continue
		for e in logic.explosions:
			var ex: GameLogic.ExplData = e
			if ex.gx == gx and ex.gy == gy:
				logic.try_kill_player(p)
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
				var pk: int = e.data.get("kind", 0)
				if pk == GameLogic.Pickup.SLOW_CURSE:
					_sfx.play_curse()
				else:
					_sfx.play_pickup()
				_spawn_pickup_toast(e.data)
			GameLogic.Event.BOMB_KICKED:
				_sfx.play_kick()
			GameLogic.Event.REMOTE_DETONATE:
				_sfx.play_detonate()
			GameLogic.Event.SHIELD_BREAK:
				_sfx.play_shield_break()
				var sw := "P1" if e.data.get("pid", 0) == 0 else ("NPC" if e.data.get("pid", 0) >= 10 else "P2")
				_toasts.append(ToastItem.new("%s 的护盾抵挡了一次爆炸！" % sw, CLR_PICKUP_SHIELD, TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.TELEPORT:
				_sfx.play_teleport()
				var tw := "P1" if e.data.get("pid", 0) == 0 else ("NPC" if e.data.get("pid", 0) >= 10 else "P2")
				_toasts.append(ToastItem.new("%s 传送！" % tw, Color(0.6, 0.4, 1.0), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.SHRINK_ADVANCE:
				_sfx.play_shrink()
				_toasts.append(ToastItem.new("毒圈缩进第 %d 圈！" % e.data.get("ring", 0), Color(0.9, 0.2, 0.2), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.IRON_HIT:
				_sfx.play_iron_hit()
			GameLogic.Event.IRON_BREAK:
				_sfx.play_explosion()
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
		GameLogic.Pickup.KICK:
			desc = "%s 获得 踢雷（走向炸弹可踢飞）" % who
			col = CLR_PICKUP_KICK
		GameLogic.Pickup.REMOTE:
			desc = "%s 获得 遥控引爆（满雷后再按引爆）" % who
			col = CLR_PICKUP_REMOTE
		GameLogic.Pickup.SHIELD:
			desc = "%s 获得 护盾（抵挡一次爆炸）" % who
			col = CLR_PICKUP_SHIELD
		GameLogic.Pickup.SLOW_CURSE:
			desc = "%s 触发 减速诅咒！（3秒内变慢）" % who
			col = CLR_PICKUP_CURSE
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
		var p1s := "你 %s" % _player_stat_str(logic.p1)
		_lbl_hint.text = "%s  |  WASD/空格  R重开  Esc暂停" % p1s
	else:
		var p1s := "P1 %s" % _player_stat_str(logic.p1)
		var p2s := "P2 %s" % _player_stat_str(logic.p2)
		_lbl_hint.text = "%s  |  %s  |  WASD/空格  方向键/回车  R重开  Esc暂停" % [p1s, p2s]
	if logic.phase == GameLogic.Phase.PLAYING:
		if match_paused:
			_lbl_phase.text = "已暂停"
		elif logic.shrink_enabled:
			var remaining := maxf(GameLogic.SHRINK_START - logic.shrink_timer, 0.0)
			if remaining > 0.0:
				_lbl_phase.text = "毒圈倒计时 %.0fs" % remaining
			else:
				_lbl_phase.text = "毒圈 第%d圈" % logic.shrink_ring
		else:
			_lbl_phase.text = "对局进行中"
	else:
		_lbl_phase.text = "本局结束"


func _player_stat_str(pl: GameLogic.PlayerData) -> String:
	var s := "炸弹%d 火力%d 速度%d" % [pl.max_bombs, pl.range_i, pl.speed_ups]
	if pl.has_kick: s += " 踢"
	if pl.has_remote: s += " 遥控"
	if pl.shield > 0: s += " 盾x%d" % pl.shield
	if pl.slow_timer > 0.0: s += " 慢%.1fs" % pl.slow_timer
	return s


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
			elif c == GameLogic.Cell.IRON_CRATE:
				var hp: int = L.iron_hp.get(Vector2i(x, y), 2)
				col = Color(0.50, 0.52, 0.58) if hp >= 2 else Color(0.62, 0.40, 0.35)
			elif c == GameLogic.Cell.SHRINK_WALL:
				col = Color(0.65, 0.12, 0.15)
			else:
				var fl: int = L.floor_grid[x][y]
				if fl == GameLogic.Floor.ICE:
					col = Color(0.18, 0.32, 0.50)
				elif fl == GameLogic.Floor.MUD:
					col = Color(0.22, 0.17, 0.10)
				else:
					col = Color(0.12, 0.13, 0.16)
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, ts), col)
			if c == GameLogic.Cell.IRON_CRATE:
				var cx := o.x + x * ts + ts * 0.5
				var cy := o.y + y * ts + ts * 0.5
				var bar := ts * 0.06
				draw_rect(Rect2(cx - ts * 0.25, cy - bar, ts * 0.5, bar * 2.0), Color(0.3, 0.3, 0.35))
				draw_rect(Rect2(cx - bar, cy - ts * 0.25, bar * 2.0, ts * 0.5), Color(0.3, 0.3, 0.35))
			elif c == GameLogic.Cell.EMPTY:
				var fl: int = L.floor_grid[x][y]
				if fl == GameLogic.Floor.ICE:
					var d := ts * 0.08
					var bx := o.x + x * ts
					var by := o.y + y * ts
					draw_rect(Rect2(bx + ts * 0.3, by + ts * 0.3, d, d), Color(0.35, 0.55, 0.75, 0.4))
					draw_rect(Rect2(bx + ts * 0.6, by + ts * 0.6, d, d), Color(0.35, 0.55, 0.75, 0.4))
				elif fl == GameLogic.Floor.MUD:
					var d := ts * 0.07
					var bx := o.x + x * ts
					var by := o.y + y * ts
					draw_rect(Rect2(bx + ts * 0.25, by + ts * 0.4, d, d), Color(0.14, 0.11, 0.06, 0.5))
					draw_rect(Rect2(bx + ts * 0.55, by + ts * 0.25, d, d), Color(0.14, 0.11, 0.06, 0.5))
					draw_rect(Rect2(bx + ts * 0.45, by + ts * 0.65, d, d), Color(0.14, 0.11, 0.06, 0.5))
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, 1.2), Color(0, 0, 0, 0.18))
			draw_rect(Rect2(o.x + x * ts, o.y + y * ts, 1.2, ts), Color(0, 0, 0, 0.18))

	for pair in L.portals:
		_draw_portal(pair, o, ts)

	for p in L.pickups:
		var pd: GameLogic.PickupData = p
		_draw_pickup(pd, o, ts)

	for b in L.bombs:
		var bd: GameLogic.BombData = b
		_draw_bomb(bd, o, ts)

	var expl_tex: ImageTexture = _sprites.get_tex("explosion")
	for e in L.explosions:
		var ex: GameLogic.ExplData = e
		var t := ex.ttl / GameLogic.EXPLOSION_TTL
		var ins := ts * 0.12 * (1.0 - t)
		var r := Rect2(o.x + ex.gx * ts + ins, o.y + ex.gy * ts + ins, ts - ins * 2.0, ts - ins * 2.0)
		if expl_tex:
			draw_texture_rect(expl_tex, r, false, Color(1.0, 1.0, 1.0, 0.7 + 0.3 * t))
		else:
			draw_rect(r, Color(1.0, 0.85 * t, 0.15 * t, 0.85))

	_draw_player_sprite(L.p1, "p1")
	if is_vs_npc:
		for i in range(npc_players.size()):
			_draw_player_sprite(npc_players[i], NPC_SPRITE_KEYS[i % NPC_SPRITE_KEYS.size()])
	else:
		_draw_player_sprite(L.p2, "p2")


func _draw_portal(pair: Array, o: Vector2, ts: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
	var portal_col := Color(0.55, 0.30, 0.95).lerp(Color(0.80, 0.55, 1.0), pulse)
	for pos in pair:
		var p: Vector2i = pos
		var m := ts * 0.30
		draw_rect(
			Rect2(o.x + p.x * ts + m, o.y + p.y * ts + m, ts - m * 2.0, ts - m * 2.0),
			portal_col
		)
		var m2 := ts * 0.40
		draw_rect(
			Rect2(o.x + p.x * ts + m2, o.y + p.y * ts + m2, ts - m2 * 2.0, ts - m2 * 2.0),
			Color(0.95, 0.85, 1.0, 0.6)
		)


func _draw_bomb(bd: GameLogic.BombData, o: Vector2, ts: float) -> void:
	var pulse := 0.5 + 0.5 * sin(bd.time * 14.0)
	var inset := ts * 0.08 + pulse * ts * 0.04
	var rx := o.x + bd.gx * ts + inset
	var ry := o.y + bd.gy * ts + inset
	var sz := ts - inset * 2.0
	var tex: ImageTexture = _sprites.get_tex("bomb")
	if tex:
		var tint := Color(0.85, 0.65, 1.0) if bd.is_remote else Color.WHITE
		draw_texture_rect(tex, Rect2(rx, ry, sz, sz), false, tint)
	else:
		draw_rect(Rect2(rx, ry, sz, sz), Color(0.05, 0.05, 0.06))


func _draw_pickup(pd: GameLogic.PickupData, o: Vector2, ts: float) -> void:
	var m := ts * 0.18
	var bg_m := m - 3.0
	var bg_col := Color(0.15, 0.15, 0.20, 0.75)
	draw_rect(Rect2(o.x + pd.gx * ts + bg_m, o.y + pd.gy * ts + bg_m,
		ts - bg_m * 2.0, ts - bg_m * 2.0), bg_col)
	var key: String = PICKUP_SPRITE_MAP.get(pd.kind, "")
	var tex: ImageTexture = _sprites.get_tex(key) if key != "" else null
	if tex:
		var bob := sin(Time.get_ticks_msec() * 0.005 + pd.gx * 1.3 + pd.gy * 2.1) * ts * 0.04
		draw_texture_rect(tex, Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m + bob,
			ts - m * 2.0, ts - m * 2.0), false)
	else:
		var col: Color
		match pd.kind:
			GameLogic.Pickup.BOMB_UP: col = CLR_PICKUP_BOMB
			GameLogic.Pickup.FIRE_UP: col = CLR_PICKUP_FIRE
			GameLogic.Pickup.SPEED_UP: col = CLR_PICKUP_SPEED
			GameLogic.Pickup.KICK: col = CLR_PICKUP_KICK
			GameLogic.Pickup.REMOTE: col = CLR_PICKUP_REMOTE
			GameLogic.Pickup.SHIELD: col = CLR_PICKUP_SHIELD
			GameLogic.Pickup.SLOW_CURSE: col = CLR_PICKUP_CURSE
			_: col = Color.WHITE
		draw_rect(Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m,
			ts - m * 2.0, ts - m * 2.0), col)


func _draw_player_sprite(pl: GameLogic.PlayerData, sprite_key: String) -> void:
	if not pl.alive:
		return
	var o := origin
	var ts := tile_size
	var m := ts * 0.08
	var px := o.x + pl.gx * ts + m
	var py := o.y + pl.gy * ts + m
	var sz := ts - m * 2.0

	if pl.shield > 0:
		var aura: ImageTexture = _sprites.get_tex("shield_aura")
		if aura:
			var s := ts * 0.12
			draw_texture_rect(aura, Rect2(px - s, py - s, sz + s * 2.0, sz + s * 2.0), false)

	var tex: ImageTexture = _sprites.get_tex(sprite_key)
	if tex:
		var tint := Color(0.5, 0.5, 0.6) if pl.slow_timer > 0.0 else Color.WHITE
		draw_texture_rect(tex, Rect2(px, py, sz, sz), false, tint)
	else:
		var col := Color(0.35, 0.75, 1.0) if sprite_key == "p1" else Color(1.0, 0.52, 0.38)
		draw_rect(Rect2(px, py, sz, sz), col)

	draw_rect(Rect2(px, py + sz - 3.0, sz, 3.0), Color(0, 0, 0, 0.2))
