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
const CLR_PICKUP_BOUNCY := Color(1.0, 0.60, 0.10)
const CLR_PICKUP_ICE := Color(0.55, 0.78, 1.0)
const CLR_PICKUP_SWAP := Color(0.65, 0.30, 0.95)
const CLR_PICKUP_CLONE := Color(0.30, 0.30, 0.40)

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
var _theme: String = "classic"
var _fun_mode: bool = false
var _npc_difficulty: int = 0
var _map_index: int = 0
var _win_streak: int = 0
var _anim_time: float = 0.0
var _shake_offset := Vector2.ZERO
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0
var _combo_popups: Array = []
var _p1_bomb_held: bool = false

class ComboPopup:
	var text: String
	var px: float
	var py: float
	var timer: float
	var color: Color
	func _init(t: String, x: float, y: float, c: Color) -> void:
		text = t; px = x; py = y; timer = 1.2; color = c

class Particle:
	var x: float
	var y: float
	var vx: float
	var vy: float
	var life: float
	var max_life: float
	var color: Color
	var size: float
	func _init(px: float, py: float, pvx: float, pvy: float, pl: float, pc: Color, ps: float) -> void:
		x = px; y = py; vx = pvx; vy = pvy; life = pl; max_life = pl; color = pc; size = ps

var _weather_particles: Array = []
var _debris_particles: Array = []
const WEATHER_COUNT := 60

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
	GameLogic.Pickup.BOUNCY_BOMB: "item_bouncy",
	GameLogic.Pickup.ICE_WALL: "item_ice_wall",
	GameLogic.Pickup.SOUL_SWAP: "item_soul_swap",
	GameLogic.Pickup.SHADOW_CLONE: "item_clone",
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
	if has_meta("fun_mode"):
		_fun_mode = get_meta("fun_mode")
	if has_meta("npc_difficulty"):
		_npc_difficulty = clampi(int(get_meta("npc_difficulty")), 0, 2)

	var all_maps := MapDefs.get_all_maps()
	if has_meta("map_index"):
		_map_index = clampi(int(get_meta("map_index")), 0, maxi(all_maps.size() - 1, 0))
	_current_map = all_maps[_map_index] if _map_index < all_maps.size() else {}
	_win_streak = _load_streak()

	logic.reset(_current_map)
	logic.fun_mode = _fun_mode
	_theme = str(_current_map.get("theme", "classic"))
	_setup_npc_players()
	logic.extra_players = npc_players.duplicate()
	_sfx.start_ambient(_theme)

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
	var def_spawns := MapDefs._spawns_for(logic.cols, logic.rows)
	var spawns: Array = _current_map.get("spawns", def_spawns)
	for i in range(npc_count):
		var spawn_idx := 2 + i
		var spawn: Vector2i = spawns[spawn_idx] if spawn_idx < spawns.size() else Vector2i(logic.cols - 2, logic.rows - 2)
		if spawn.x <= 0 or spawn.y <= 0 or spawn.x >= logic.cols - 1 or spawn.y >= logic.rows - 1:
			spawn = Vector2i(logic.cols - 2, 1)
		if logic.grid[spawn.x][spawn.y] != GameLogic.Cell.EMPTY:
			logic.grid[spawn.x][spawn.y] = GameLogic.Cell.EMPTY
			logic.iron_hp.erase(spawn)
		var pl := GameLogic.PlayerData.new(10 + i, spawn.x, spawn.y)
		npc_players.append(pl)
		var ai = NpcAIScript.new(logic, pl, _npc_difficulty)
		npcs.append(ai)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cx := spawn.x + dx
				var cy := spawn.y + dy
				if cx > 0 and cy > 0 and cx < logic.cols - 1 and cy < logic.rows - 1:
					var cell: int = logic.grid[cx][cy]
					if cell == GameLogic.Cell.CRATE or cell == GameLogic.Cell.IRON_CRATE or cell == GameLogic.Cell.MYSTERY_CRATE:
						logic.grid[cx][cy] = GameLogic.Cell.EMPTY
						logic.iron_hp.erase(Vector2i(cx, cy))


func _recalc_origin() -> void:
	var vs := get_viewport().get_visible_rect().size
	var avail_w := vs.x - GRID_PADDING * 2.0
	var avail_h := vs.y - HUD_H - GRID_PADDING * 2.0
	tile_size = minf(avail_w / float(logic.cols), avail_h / float(logic.rows))
	tile_size = maxf(tile_size, 16.0)
	var wx := logic.cols * tile_size
	var wy := logic.rows * tile_size
	origin = Vector2(
		(vs.x - wx) * 0.5,
		HUD_H + (vs.y - HUD_H - wy) * 0.5
	)
	queue_redraw()


func _reset_match() -> void:
	logic.reset(_current_map)
	logic.fun_mode = _fun_mode
	_theme = str(_current_map.get("theme", "classic"))
	_setup_npc_players()
	logic.extra_players = npc_players.duplicate()
	_sfx.start_ambient(_theme)
	_weather_particles.clear()
	_debris_particles.clear()
	match_paused = false
	_pause_layer.hide()
	_result_layer.hide()
	_toasts.clear()
	queue_redraw()
	_refresh_ui()


func _process(delta: float) -> void:
	_anim_time += delta
	_tick_toasts(delta)
	_tick_shake(delta)
	_tick_particles(delta)

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
	logic.tick_match_phase(delta)

	_p1_bomb_held = Input.is_action_pressed("p1_bomb")
	var p1_dir := _read_dir_p1() if logic.p1.charge_timer <= 0.0 else Vector2i.ZERO
	logic.update_player(logic.p1, p1_dir, Input.is_action_just_pressed("p1_bomb"), delta, _p1_bomb_held)

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
		var p2_held := Input.is_action_pressed("p2_bomb")
		var p2_dir := _read_dir_p2() if logic.p2.charge_timer <= 0.0 else Vector2i.ZERO
		logic.update_player(logic.p2, p2_dir, Input.is_action_just_pressed("p2_bomb"), delta, p2_held)

	logic.tick_moving_bombs(delta)
	logic.tick_bombs(delta)
	logic.tick_shrink(delta)
	logic.tick_timed_walls(delta)
	logic.tick_hazards(delta, _theme)
	logic.tick_creatures(delta)
	logic.tick_ice_walls(delta)
	logic.tick_clones(delta)
	_resolve_phase_extended()

	_handle_events()
	_refresh_ui()
	queue_redraw()


func _tick_shake(dt: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= dt
		var t := _shake_timer / 0.3
		_shake_offset = Vector2(
			sin(_anim_time * 80.0) * _shake_intensity * t,
			cos(_anim_time * 90.0) * _shake_intensity * t * 0.7
		)
		if _shake_timer <= 0.0:
			_shake_offset = Vector2.ZERO


func _trigger_shake(intensity: float) -> void:
	_shake_intensity = intensity
	_shake_timer = 0.3


func _tick_particles(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var gw := logic.cols * tile_size
	var gh := logic.rows * tile_size

	# Weather particles
	while _weather_particles.size() < WEATHER_COUNT:
		_weather_particles.append(_spawn_weather_particle(vs, gw, gh))
	var i := 0
	while i < _weather_particles.size():
		var p: Particle = _weather_particles[i]
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.life -= dt
		if p.life <= 0.0 or p.y > origin.y + gh + 20.0 or p.x > origin.x + gw + 20.0:
			_weather_particles[i] = _spawn_weather_particle(vs, gw, gh)
		i += 1

	# Debris particles
	i = _debris_particles.size() - 1
	while i >= 0:
		var p: Particle = _debris_particles[i]
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vy += 200.0 * dt
		p.life -= dt
		if p.life <= 0.0:
			_debris_particles.remove_at(i)
		i -= 1


func _spawn_weather_particle(vs: Vector2, gw: float, gh: float) -> Particle:
	var px := origin.x + randf() * gw
	var py := origin.y - randf() * 40.0
	match _theme:
		"grassland":
			return Particle.new(px, py, randf() * 15.0 - 7.0, 20.0 + randf() * 15.0,
				3.0 + randf() * 2.0, Color(0.35, 0.65, 0.20, 0.5), 3.0)
		"tundra":
			return Particle.new(px, py, randf() * 20.0 - 10.0, 12.0 + randf() * 10.0,
				4.0 + randf() * 3.0, Color(1.0, 1.0, 1.0, 0.7), 2.5)
		"desert":
			return Particle.new(px, py, 25.0 + randf() * 15.0, randf() * 5.0 - 2.0,
				2.0 + randf() * 2.0, Color(0.85, 0.72, 0.45, 0.4), 2.0)
		"volcano":
			return Particle.new(px, py, randf() * 10.0 - 5.0, 8.0 + randf() * 8.0,
				2.5 + randf() * 2.0, Color(0.6, 0.4, 0.3, 0.45), 2.0)
		_:
			return Particle.new(px, py, randf() * 5.0, 10.0 + randf() * 5.0,
				3.0 + randf() * 2.0, Color(0.5, 0.5, 0.5, 0.2), 1.5)


func _spawn_debris(gx: int, gy: int, col: Color) -> void:
	var cx := origin.x + (float(gx) + 0.5) * tile_size
	var cy := origin.y + (float(gy) + 0.5) * tile_size
	for k in range(8):
		var angle := randf() * TAU
		var spd := 60.0 + randf() * 100.0
		_debris_particles.append(Particle.new(
			cx, cy, cos(angle) * spd, sin(angle) * spd - 50.0,
			0.4 + randf() * 0.3, col, 2.0 + randf() * 2.0
		))


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
	logic.bombs.append(GameLogic.BombData.new(gx, gy, pl.pid, logic._get_fuse_for(pl), pl.range_i))
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
			logic._award_score(logic.p1, GameLogic.SCORE_WIN)
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
				logic.try_kill_player(p, ex.owner_id)
				break


func _handle_events() -> void:
	for ev in logic.events:
		var e: GameLogic.GameEvent = ev
		match e.type:
			GameLogic.Event.BOMB_PLACED:
				_sfx.play_place_bomb()
			GameLogic.Event.EXPLOSION:
				_sfx.play_explosion()
				_trigger_shake(tile_size * 0.12)
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
			GameLogic.Event.CRATE_DESTROYED:
				_spawn_debris(e.data.get("gx", 0), e.data.get("gy", 0), Color(0.72, 0.50, 0.28))
			GameLogic.Event.GRASS_BURNED:
				_spawn_debris(e.data.get("gx", 0), e.data.get("gy", 0), Color(0.35, 0.60, 0.20))
			GameLogic.Event.ERUPTION:
				_trigger_shake(tile_size * 0.18)
				_sfx.play_explosion()
			GameLogic.Event.CREATURE_KILLED:
				_spawn_debris(e.data.get("gx", 0), e.data.get("gy", 0), Color(0.85, 0.70, 0.40))
				_sfx.play_pickup()
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
			GameLogic.Event.SOUL_SWAPPED:
				_sfx.play_teleport()
				var sw1 := _pid_label(e.data.get("pid", 0))
				var sw2 := _pid_label(e.data.get("other_pid", 1))
				_toasts.append(ToastItem.new("灵魂互换！%s ↔ %s" % [sw1, sw2], CLR_PICKUP_SWAP, TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.ICE_WALL_PLACED:
				_sfx.play_place_bomb()
				var iw := _pid_label(e.data.get("pid", 0))
				_toasts.append(ToastItem.new("%s 召唤了冰墙！" % iw, CLR_PICKUP_ICE, TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.CLONE_SPAWNED:
				_sfx.play_teleport()
				var cs := _pid_label(e.data.get("pid", 0))
				_toasts.append(ToastItem.new("%s 释放了影分身！" % cs, CLR_PICKUP_CLONE, TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.CLONE_POPPED:
				_sfx.play_explosion()
				_spawn_debris(e.data.get("gx", 0), e.data.get("gy", 0), Color(0.3, 0.3, 0.45))
				_toasts.append(ToastItem.new("分身被炸毁！附近敌人减速！", CLR_PICKUP_CLONE, TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.BOUNCY_BOUNCE:
				_sfx.play_kick()
			GameLogic.Event.COMBO_UP:
				var cpid: int = e.data.get("pid", 0)
				var ccombo: int = e.data.get("combo", 0)
				var cpl := logic._player_by_pid(cpid)
				if cpl:
					var cpx := origin.x + cpl.gx * tile_size + tile_size * 0.5
					var cpy := origin.y + cpl.gy * tile_size
					var ccol := Color(1.0, 0.9, 0.2) if ccombo < 5 else Color(1.0, 0.5, 0.1)
					_combo_popups.append(ComboPopup.new("x%d COMBO!" % ccombo, cpx, cpy, ccol))
				_sfx.play_pickup()
			GameLogic.Event.COMBO_BREAK:
				_sfx.play_curse()
				var bpid: int = e.data.get("pid", 0)
				var bcombo: int = e.data.get("combo", 0)
				if bcombo >= 3:
					var bl := _pid_label(bpid)
					_toasts.append(ToastItem.new("%s 连击断裂！x%d" % [bl, bcombo], Color(1.0, 0.3, 0.2), TOAST_TTL))
					_sync_toast_ui()
			GameLogic.Event.MATCH_PHASE_CHANGE:
				var mp: int = e.data.get("phase", 0)
				var phase_name := "探索阶段"
				var phase_col := Color(0.3, 0.8, 0.3)
				if mp == GameLogic.MatchPhase.TENSION:
					phase_name = "-- 紧张阶段 --"
					phase_col = Color(1.0, 0.7, 0.2)
				elif mp == GameLogic.MatchPhase.CLIMAX:
					phase_name = "-- 决战阶段 x2 --"
					phase_col = Color(1.0, 0.3, 0.2)
				_toasts.append(ToastItem.new(phase_name, phase_col, 2.5))
				_sync_toast_ui()
				_sfx.play_shrink()
			GameLogic.Event.MYSTERY_RESOLVED:
				var mresult: String = e.data.get("result", "")
				var mcol := Color.WHITE
				var mdesc := ""
				match mresult:
					"rare":
						mdesc = "神秘箱子：稀有双倍道具！"
						mcol = Color(1.0, 0.85, 0.2)
					"trap":
						mdesc = "神秘箱子：陷阱爆炸！"
						mcol = Color(1.0, 0.3, 0.2)
						_trigger_shake(tile_size * 0.10)
					"curse":
						mdesc = "神秘箱子：减速诅咒！"
						mcol = CLR_PICKUP_CURSE
				_toasts.append(ToastItem.new(mdesc, mcol, TOAST_TTL))
				_sync_toast_ui()
				_sfx.play_explosion()
			GameLogic.Event.SUPER_BOMB_PLACED:
				_sfx.play_place_bomb()
				var spid := _pid_label(e.data.get("pid", 0))
				_toasts.append(ToastItem.new("%s 放置了超级炸弹！" % spid, Color(1.0, 0.6, 0.1), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.BRIDGE_DESTROYED:
				_sfx.play_explosion()
				_spawn_debris(e.data.get("gx", 0), e.data.get("gy", 0), Color(0.65, 0.48, 0.25))
				_toasts.append(ToastItem.new("桥梁被炸毁！", Color(0.70, 0.52, 0.28), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.TIMED_WALL_TOGGLE:
				_sfx.play_shrink()
			GameLogic.Event.FLOOD_ADVANCE:
				_sfx.play_shrink()
				_toasts.append(ToastItem.new("洪水蔓延！", Color(0.15, 0.55, 0.95), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.AVALANCHE:
				var is_warn: bool = e.data.get("warn", false)
				if is_warn:
					_toasts.append(ToastItem.new("雪崩警告！", Color(0.9, 0.2, 0.2), 2.0))
					_sync_toast_ui()
				else:
					_trigger_shake(tile_size * 0.22)
					_sfx.play_explosion()
			GameLogic.Event.SANDSTORM_START:
				_sfx.play_shrink()
				var sd: Vector2i = e.data.get("dir", Vector2i.ZERO)
				var dir_name := "东" if sd.x > 0 else "西"
				_toasts.append(ToastItem.new("沙尘暴来袭！方向：%s" % dir_name, Color(0.92, 0.78, 0.42), 2.0))
				_sync_toast_ui()
			GameLogic.Event.SANDSTORM_END:
				_toasts.append(ToastItem.new("沙尘暴结束", Color(0.85, 0.72, 0.40), TOAST_TTL))
				_sync_toast_ui()
			GameLogic.Event.LAVA_SPREAD:
				_trigger_shake(tile_size * 0.08)
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
		GameLogic.Pickup.BOUNCY_BOMB:
			desc = "%s 获得 橡皮弹弹（炸弹碰墙反弹！）" % who
			col = CLR_PICKUP_BOUNCY
		GameLogic.Pickup.ICE_WALL:
			desc = "%s 召唤了 瞬间冰墙！" % who
			col = CLR_PICKUP_ICE
		GameLogic.Pickup.SOUL_SWAP:
			desc = "%s 触发 灵魂互换！位置对调！" % who
			col = CLR_PICKUP_SWAP
		GameLogic.Pickup.SHADOW_CLONE:
			desc = "%s 释放 影分身！（3秒隐身）" % who
			col = CLR_PICKUP_CLONE
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
	_save_match_result()
	var winner_text := ""
	match logic.phase:
		GameLogic.Phase.P1_WIN:
			winner_text = "你赢了！" if is_vs_npc else "玩家 1（蓝）获胜！"
		GameLogic.Phase.P2_WIN:
			winner_text = "NPC 获胜，你输了" if is_vs_npc else "玩家 2（橙）获胜！"
		GameLogic.Phase.DRAW:
			winner_text = "平局（同归于尽）"
	var stats := "\n\n"
	var time_str := "%.0f秒" % logic.match_timer
	if is_vs_npc:
		stats += "得分: %d  |  最高连击: x%d  |  用时: %s" % [
			logic.p1.score, logic.p1.max_combo, time_str]
	else:
		stats += "P1 得分: %d (连击x%d)  |  P2 得分: %d (连击x%d)  |  用时: %s" % [
			logic.p1.score, logic.p1.max_combo,
			logic.p2.score, logic.p2.max_combo, time_str]
	if _win_streak >= 2:
		stats += "\n连胜: %d" % _win_streak
	_lbl_result.text = winner_text + stats


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


func _tile_hash(x: int, y: int) -> float:
	return absf(fmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0))


func _refresh_ui() -> void:
	var mode_tag := " [趣味]" if _fun_mode else ""
	var p1_score := "  得分:%d" % logic.p1.score
	if logic.p1.combo >= 2:
		p1_score += " x%d连击" % logic.p1.combo
	if is_vs_npc:
		var p1s := "你 %s%s" % [_player_stat_str(logic.p1), p1_score]
		_lbl_hint.text = "%s%s  |  WASD/空格(长按蓄力)  R重开  Esc暂停" % [p1s, mode_tag]
	else:
		var p2_score := "  得分:%d" % logic.p2.score
		if logic.p2.combo >= 2:
			p2_score += " x%d连击" % logic.p2.combo
		var p1s := "P1 %s%s" % [_player_stat_str(logic.p1), p1_score]
		var p2s := "P2 %s%s" % [_player_stat_str(logic.p2), p2_score]
		_lbl_hint.text = "%s  |  %s%s  |  WASD/空格(长按蓄力)  方向键/回车  R重开  Esc暂停" % [p1s, p2s, mode_tag]
	if logic.phase == GameLogic.Phase.PLAYING:
		if match_paused:
			_lbl_phase.text = "已暂停"
		else:
			var phase_str := ""
			match logic.match_phase:
				GameLogic.MatchPhase.OPENING:
					phase_str = "探索"
				GameLogic.MatchPhase.TENSION:
					phase_str = "紧张"
				GameLogic.MatchPhase.CLIMAX:
					phase_str = "决战x2"
			var time_str := "%.0fs" % logic.match_timer
			if logic.shrink_enabled:
				var remaining := maxf(GameLogic.SHRINK_START - logic.shrink_timer, 0.0)
				if remaining > 0.0:
					_lbl_phase.text = "%s | 毒圈倒计时 %.0fs | %s" % [phase_str, remaining, time_str]
				else:
					_lbl_phase.text = "%s | 毒圈第%d圈 | %s" % [phase_str, logic.shrink_ring, time_str]
			else:
				_lbl_phase.text = "%s | %s" % [phase_str, time_str]
	else:
		_lbl_phase.text = "本局结束"


func _player_stat_str(pl: GameLogic.PlayerData) -> String:
	var s := "炸弹%d 火力%d 速度%d" % [pl.max_bombs, pl.range_i, pl.speed_ups]
	if pl.has_kick: s += " 踢"
	if pl.has_remote: s += " 遥控"
	if pl.shield > 0: s += " 盾x%d" % pl.shield
	if pl.slow_timer > 0.0: s += " 慢%.1fs" % pl.slow_timer
	if pl.bouncy_timer > 0.0: s += " 弹%.0fs" % pl.bouncy_timer
	if pl.invisible_timer > 0.0: s += " 隐%.1fs" % pl.invisible_timer
	return s


func _pid_label(pid: int) -> String:
	if pid == 0:
		return "P1" if not is_vs_npc else "你"
	if pid == 1:
		return "P2"
	return "NPC"


func _pid_to_sprite_key(pid: int) -> String:
	if pid == 0:
		return "p1"
	if pid == 1:
		return "p2"
	if pid >= 10:
		var idx := pid - 10
		return NPC_SPRITE_KEYS[idx % NPC_SPRITE_KEYS.size()]
	return "p1"


func _go_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── 进度保存 ─────────────────────────────

const PROGRESS_PATH := "user://progress.cfg"

func _load_progress() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PROGRESS_PATH)
	return cfg


func _save_match_result() -> void:
	var cfg := _load_progress()
	var map_key := "map_%d" % _map_index
	var p1_won := logic.phase == GameLogic.Phase.P1_WIN

	if p1_won:
		_win_streak += 1
	else:
		if _win_streak > 0:
			_toasts.append(ToastItem.new("连胜记录中断！曾连胜 %d 局" % _win_streak, Color(1.0, 0.3, 0.2), 3.0))
			_sync_toast_ui()
		_win_streak = 0
	cfg.set_value("global", "win_streak", _win_streak)

	var best_score: int = cfg.get_value(map_key, "best_score", 0)
	if logic.p1.score > best_score:
		cfg.set_value(map_key, "best_score", logic.p1.score)

	var star1: bool = cfg.get_value(map_key, "star_win", false)
	var star2: bool = cfg.get_value(map_key, "star_score", false)
	var star3: bool = cfg.get_value(map_key, "star_hard", false)
	if p1_won:
		star1 = true
	if p1_won and logic.p1.score >= 500:
		star2 = true
	if p1_won and (_npc_difficulty >= 2 or logic.p1.max_combo >= 5):
		star3 = true
	cfg.set_value(map_key, "star_win", star1)
	cfg.set_value(map_key, "star_score", star2)
	cfg.set_value(map_key, "star_hard", star3)
	cfg.save(PROGRESS_PATH)


func _load_streak() -> int:
	var cfg := _load_progress()
	return cfg.get_value("global", "win_streak", 0)

func _resume() -> void:
	match_paused = false
	_pause_layer.hide()
	_refresh_ui()

func _on_rematch() -> void:
	_reset_match()


# ── 绘制 ──────────────────────────────────

func _draw() -> void:
	var o := origin + _shake_offset
	var ts := tile_size
	var L := logic
	var th := _theme

	var ground_tex: ImageTexture = _sprites.get_tex("ground_" + th)
	var wall_tex: ImageTexture = _sprites.get_tex("wall_" + th)
	var crate_tex: ImageTexture = _sprites.get_tex("crate_" + th)
	var iron_tex: ImageTexture = _sprites.get_tex("iron_" + th)
	var shrink_tex: ImageTexture = _sprites.get_tex("shrink_" + th)
	var water_tex: ImageTexture = _sprites.get_tex("tile_water")
	var grass_tex: ImageTexture = _sprites.get_tex("tile_grass")
	var snow_tex: ImageTexture = _sprites.get_tex("tile_snow")
	var sand_tex: ImageTexture = _sprites.get_tex("tile_sand")
	var lava_tex: ImageTexture = _sprites.get_tex("tile_lava")
	var ice_tex: ImageTexture = _sprites.get_tex("tile_ice")
	var mud_tex: ImageTexture = _sprites.get_tex("tile_mud")
	var bridge_tex: ImageTexture = _sprites.get_tex("tile_bridge")
	var twall_tex: ImageTexture = _sprites.get_tex("tile_timed_wall")
	var tgrass_tex: ImageTexture = _sprites.get_tex("tile_tall_grass")
	var gate_texes: Dictionary = {
		GameLogic.Floor.GATE_N: _sprites.get_tex("tile_gate_n"),
		GameLogic.Floor.GATE_E: _sprites.get_tex("tile_gate_e"),
		GameLogic.Floor.GATE_S: _sprites.get_tex("tile_gate_s"),
		GameLogic.Floor.GATE_W: _sprites.get_tex("tile_gate_w"),
	}

	draw_rect(Rect2(o.x, o.y, logic.cols * ts, logic.rows * ts), Color(0.09, 0.10, 0.13))

	for x in range(logic.cols):
		for y in range(logic.rows):
			var r := Rect2(o.x + x * ts, o.y + y * ts, ts, ts)
			var c: int = L.grid[x][y]
			var h := _tile_hash(x, y)
			var bright := 0.93 + h * 0.14

			if c == GameLogic.Cell.EMPTY:
				var fl: int = L.floor_grid[x][y]
				var has_shadow: bool = y > 0 and (L.grid[x][y - 1] == GameLogic.Cell.WALL \
					or L.grid[x][y - 1] == GameLogic.Cell.IRON_CRATE)
				var bt := Color(bright, bright, bright)

				if fl == GameLogic.Floor.GRASS and grass_tex:
					var sway := sin(_anim_time * 1.5 + float(x) * 1.1 + float(y) * 0.7) * ts * 0.015
					draw_texture_rect(grass_tex, Rect2(r.position.x + sway, r.position.y, r.size.x, r.size.y), false, bt)
				elif fl == GameLogic.Floor.LAVA and lava_tex:
					var lp := 0.85 + 0.15 * sin(_anim_time * 3.5 + float(x) * 0.5 + float(y) * 0.8)
					draw_texture_rect(lava_tex, r, false, Color(bright, lp * bright, lp * 0.7 * bright))
				elif fl == GameLogic.Floor.ICE and ice_tex:
					var shimmer := 0.95 + 0.05 * sin(_anim_time * 2.0 + float(x) * 0.9 + float(y) * 0.6)
					draw_texture_rect(ice_tex, r, false, Color(shimmer * bright, shimmer * bright, bright))
				elif fl == GameLogic.Floor.SNOW and snow_tex:
					draw_texture_rect(snow_tex, r, false, bt)
				elif fl == GameLogic.Floor.SAND and sand_tex:
					draw_texture_rect(sand_tex, r, false, bt)
				elif fl == GameLogic.Floor.MUD and mud_tex:
					draw_texture_rect(mud_tex, r, false, bt)
				elif fl == GameLogic.Floor.TALL_GRASS and tgrass_tex:
					var sway := sin(_anim_time * 1.8 + float(x) * 0.9 + float(y) * 0.5) * ts * 0.02
					draw_texture_rect(tgrass_tex, Rect2(r.position.x + sway, r.position.y, r.size.x, r.size.y), false, bt)
				elif fl >= GameLogic.Floor.GATE_N and fl <= GameLogic.Floor.GATE_W:
					var gtex: ImageTexture = gate_texes.get(fl, null)
					if gtex:
						draw_texture_rect(gtex, r, false, bt)
					else:
						draw_rect(r, Color(0.35, 0.35, 0.42))
				elif ground_tex:
					draw_texture_rect(ground_tex, r, false, bt)
				else:
					draw_rect(r, Color(0.22 * bright, 0.24 * bright, 0.30 * bright))

				if has_shadow:
					draw_rect(Rect2(r.position.x, r.position.y, ts, ts * 0.18), Color(0, 0, 0, 0.14))
				_draw_tile_deco(x, y, fl, h, o, ts)

			elif c == GameLogic.Cell.WALL:
				if wall_tex:
					draw_texture_rect(wall_tex, r, false, Color(bright, bright, bright))
				else:
					draw_rect(r, Color(0.22 * bright, 0.24 * bright, 0.30 * bright))
				if y + 1 < logic.rows and L.grid[x][y + 1] == GameLogic.Cell.EMPTY:
					var hl := Color(1.0, 1.0, 1.0, 0.08)
					draw_rect(Rect2(r.position.x, r.position.y + ts - 1.0, ts, 1.0), hl)
			elif c == GameLogic.Cell.CRATE:
				if crate_tex:
					draw_texture_rect(crate_tex, r, false, Color(bright, bright, bright))
				else:
					draw_rect(r, Color(0.78 * bright, 0.52 * bright, 0.28 * bright))
			elif c == GameLogic.Cell.IRON_CRATE:
				var hp: int = L.iron_hp.get(Vector2i(x, y), 2)
				if iron_tex:
					var tint := Color(bright, bright, bright) if hp >= 2 else Color(bright, 0.75 * bright, 0.65 * bright)
					draw_texture_rect(iron_tex, r, false, tint)
				else:
					draw_rect(r, Color(0.50, 0.52, 0.58) if hp >= 2 else Color(0.62, 0.40, 0.35))
			elif c == GameLogic.Cell.SHRINK_WALL:
				var sp := 0.9 + 0.1 * sin(_anim_time * 2.0 + float(x + y) * 0.5)
				if shrink_tex:
					draw_texture_rect(shrink_tex, r, false, Color(sp, 0.85, 0.85))
				else:
					draw_rect(r, Color(0.65 * sp, 0.12, 0.15))
			elif c == GameLogic.Cell.WATER:
				if water_tex:
					var wp := 0.92 + 0.08 * sin(_anim_time * 2.5 + float(x) * 0.8 + float(y) * 0.6)
					draw_texture_rect(water_tex, r, false, Color(wp, 0.95 + 0.05 * sin(_anim_time * 3.0 + float(x)), 1.0))
				else:
					draw_rect(r, Color(0.15, 0.45, 0.82))
			elif c == GameLogic.Cell.MYSTERY_CRATE:
				if crate_tex:
					draw_texture_rect(crate_tex, r, false, Color(bright, bright, bright))
				else:
					draw_rect(r, Color(0.78 * bright, 0.52 * bright, 0.28 * bright))
				var qm := ts * 0.22
				var qpulse := 0.7 + 0.3 * sin(_anim_time * 3.5 + float(x + y) * 0.5)
				draw_rect(Rect2(r.position.x + qm, r.position.y + qm, ts - qm * 2.0, ts - qm * 2.0),
					Color(1.0, 0.85, 0.2, 0.35 * qpulse))
				var font := ThemeDB.fallback_font
				if font:
					var fs := int(ts * 0.5)
					draw_string(font, Vector2(r.position.x + ts * 0.32, r.position.y + ts * 0.7),
						"?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.3, qpulse))
			elif c == GameLogic.Cell.ICE_WALL:
				var shimmer := 0.85 + 0.15 * sin(_anim_time * 3.0 + float(x) * 1.2 + float(y) * 0.8)
				draw_rect(r, Color(0.55 * shimmer, 0.75 * shimmer, 1.0, 0.90))
				var iw_m := ts * 0.12
				draw_rect(Rect2(r.position.x + iw_m, r.position.y + iw_m,
					ts - iw_m * 2.0, ts - iw_m * 2.0), Color(0.85, 0.92, 1.0, 0.35 * shimmer))
				draw_rect(Rect2(r.position.x + ts * 0.3, r.position.y + ts * 0.45,
					ts * 0.4, ts * 0.10), Color(1.0, 1.0, 1.0, 0.3))
				draw_rect(Rect2(r.position.x + ts * 0.45, r.position.y + ts * 0.3,
					ts * 0.10, ts * 0.4), Color(1.0, 1.0, 1.0, 0.3))
			elif c == GameLogic.Cell.BRIDGE:
				if bridge_tex:
					var wobble := sin(_anim_time * 2.0 + float(x) * 1.5) * ts * 0.01
					draw_texture_rect(bridge_tex, Rect2(r.position.x, r.position.y + wobble, ts, ts), false)
				else:
					draw_rect(r, Color(0.65, 0.48, 0.25))
			elif c == GameLogic.Cell.TIMED_WALL:
				var tw_open: bool = L.timed_wall_open.get(Vector2i(x, y), false)
				if tw_open:
					if ground_tex:
						draw_texture_rect(ground_tex, r, false, Color(bright, bright, bright))
					else:
						draw_rect(r, Color(0.22, 0.24, 0.30))
					var remaining := L.timed_wall_timer
					var is_closing := remaining > GameLogic.TIMED_WALL_INTERVAL - 1.5
					if is_closing:
						var a := 0.25 + 0.25 * sin(_anim_time * 8.0)
						draw_rect(r, Color(0.85, 0.72, 0.20, a))
					else:
						draw_rect(Rect2(r.position.x + 1, r.position.y + 1, ts - 2, ts - 2),
							Color(0.60, 0.55, 0.40, 0.15))
				else:
					if twall_tex:
						draw_texture_rect(twall_tex, r, false, Color(bright, bright, bright))
					else:
						draw_rect(r, Color(0.50, 0.50, 0.58))
					var is_opening := L.timed_wall_timer > GameLogic.TIMED_WALL_INTERVAL - 1.5
					if is_opening:
						var a := 0.2 + 0.2 * sin(_anim_time * 6.0)
						draw_rect(r, Color(0.30, 0.85, 0.30, a))

	# Treasure zone glow borders
	for tz in L.treasure_zones:
		var zx1: int = tz[0]
		var zy1: int = tz[1]
		var zx2: int = tz[2]
		var zy2: int = tz[3]
		var tz_shimmer := 0.4 + 0.3 * sin(_anim_time * 2.0)
		var tz_col := Color(1.0, 0.85, 0.15, tz_shimmer * 0.5)
		var tz_r := Rect2(o.x + zx1 * ts, o.y + zy1 * ts, (zx2 - zx1 + 1) * ts, (zy2 - zy1 + 1) * ts)
		draw_rect(tz_r, tz_col, false, 2.0)

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

	# Conveyor arrows
	for x in range(L.cols):
		for y in range(L.rows):
			var ft: int = L.floor_grid[x][y]
			if ft >= GameLogic.Floor.CONV_N and ft <= GameLogic.Floor.CONV_W:
				_draw_conveyor(x, y, ft, o, ts)

	# Water edge foam
	for x in range(L.cols):
		for y in range(L.rows):
			if L.grid[x][y] == GameLogic.Cell.WATER:
				_draw_water_edges(x, y, o, ts)

	# Creatures
	for cr_item in L.creatures:
		var cr: GameLogic.CreatureData = cr_item
		if cr.alive:
			_draw_creature(cr, o, ts)

	# Clones (drawn before players so real players render on top)
	for cl_item in L.clones:
		var cl: GameLogic.CloneData = cl_item
		if cl.alive:
			_draw_clone(cl, o, ts)

	# Torch glow on volcano
	if th == "volcano":
		_draw_torch_glow(o, ts)

	_draw_player_sprite(L.p1, "p1")
	if is_vs_npc:
		for i in range(npc_players.size()):
			_draw_player_sprite(npc_players[i], NPC_SPRITE_KEYS[i % NPC_SPRITE_KEYS.size()])
	else:
		_draw_player_sprite(L.p2, "p2")

	# Charge indicator
	for pl_item in [L.p1, L.p2] + npc_players:
		var cpl: GameLogic.PlayerData = pl_item
		if cpl.charge_timer > 0.0 and cpl.alive:
			var cpx := o.x + cpl.gx * ts + ts * 0.1
			var cpy := o.y + cpl.gy * ts - ts * 0.15
			var cw := ts * 0.8
			var fill := clampf(cpl.charge_timer / GameLogic.CHARGE_TIME, 0.0, 1.0)
			draw_rect(Rect2(cpx, cpy, cw, ts * 0.08), Color(0.2, 0.2, 0.2, 0.7))
			draw_rect(Rect2(cpx, cpy, cw * fill, ts * 0.08), Color(1.0, 0.6, 0.1, 0.9))

	# Combo popups
	_draw_combo_popups(o, ts)

	# Weather & debris particles
	_draw_particles(o, ts)

	# Blizzard fog overlay
	if L.blizzard_active:
		_draw_blizzard_fog(o, ts)

	# Sandstorm overlay
	if L.sandstorm_active:
		_draw_sandstorm_overlay(o, ts)

	# Avalanche warning flash
	if L.avalanche_warn > 0.0:
		_draw_avalanche_warning(o, ts)


func _draw_portal(pair: Array, o: Vector2, ts: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_time * 3.0)
	var portal_col := Color(0.60, 0.35, 1.0).lerp(Color(0.85, 0.60, 1.0), pulse)
	var scale_pulse := 0.28 + 0.04 * sin(_anim_time * 2.5)
	for pos in pair:
		var p: Vector2i = pos
		var m := ts * scale_pulse
		draw_rect(
			Rect2(o.x + p.x * ts + m, o.y + p.y * ts + m, ts - m * 2.0, ts - m * 2.0),
			portal_col
		)
		var m2 := ts * (scale_pulse + 0.10)
		draw_rect(
			Rect2(o.x + p.x * ts + m2, o.y + p.y * ts + m2, ts - m2 * 2.0, ts - m2 * 2.0),
			Color(0.98, 0.90, 1.0, 0.65)
		)
		var m3 := ts * (scale_pulse + 0.18)
		draw_rect(
			Rect2(o.x + p.x * ts + m3, o.y + p.y * ts + m3, ts - m3 * 2.0, ts - m3 * 2.0),
			Color(1.0, 1.0, 1.0, 0.4 * pulse)
		)


func _draw_bomb(bd: GameLogic.BombData, o: Vector2, ts: float) -> void:
	var pulse := 0.5 + 0.5 * sin(bd.time * 14.0)
	var inset := ts * 0.08 + pulse * ts * 0.04
	var rx := o.x + bd.gx * ts + inset
	var ry := o.y + bd.gy * ts + inset
	var sz := ts - inset * 2.0
	if bd.is_super:
		var glow_r := ts * 0.15
		var glow_a := 0.15 + 0.1 * pulse
		draw_circle(Vector2(rx + sz * 0.5, ry + sz * 0.5), sz * 0.7 + glow_r, Color(1.0, 0.6, 0.1, glow_a))
	var tex: ImageTexture = _sprites.get_tex("bomb")
	if tex:
		var tint: Color
		if bd.is_super:
			tint = Color(1.0, 0.7, 0.2)
		elif bd.is_remote:
			tint = Color(0.85, 0.65, 1.0)
		else:
			var fuse_ratio := clampf(bd.time / GameLogic.BOMB_FUSE, 0.0, 1.0)
			if fuse_ratio < 0.5:
				tint = Color(1.0, 0.5 + fuse_ratio, fuse_ratio)
			else:
				tint = Color.WHITE
		draw_texture_rect(tex, Rect2(rx, ry, sz, sz), false, tint)
	else:
		draw_rect(Rect2(rx, ry, sz, sz), Color(0.05, 0.05, 0.06))


func _draw_pickup(pd: GameLogic.PickupData, o: Vector2, ts: float) -> void:
	var on_tall_grass := logic.floor_at(pd.gx, pd.gy) == GameLogic.Floor.TALL_GRASS
	var m := ts * 0.18
	var bg_m := m - 3.0
	var bg_alpha := 0.35 if on_tall_grass else 0.75
	var bg_col := Color(0.15, 0.15, 0.20, bg_alpha)
	draw_rect(Rect2(o.x + pd.gx * ts + bg_m, o.y + pd.gy * ts + bg_m,
		ts - bg_m * 2.0, ts - bg_m * 2.0), bg_col)
	var key: String = PICKUP_SPRITE_MAP.get(pd.kind, "")
	var tex: ImageTexture = _sprites.get_tex(key) if key != "" else null
	var dim_tint := Color(1.0, 1.0, 1.0, 0.5) if on_tall_grass else Color.WHITE
	if tex:
		var bob := sin(Time.get_ticks_msec() * 0.005 + pd.gx * 1.3 + pd.gy * 2.1) * ts * 0.04
		draw_texture_rect(tex, Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m + bob,
			ts - m * 2.0, ts - m * 2.0), false, dim_tint)
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
			GameLogic.Pickup.BOUNCY_BOMB: col = CLR_PICKUP_BOUNCY
			GameLogic.Pickup.ICE_WALL: col = CLR_PICKUP_ICE
			GameLogic.Pickup.SOUL_SWAP: col = CLR_PICKUP_SWAP
			GameLogic.Pickup.SHADOW_CLONE: col = CLR_PICKUP_CLONE
			_: col = Color.WHITE
		draw_rect(Rect2(o.x + pd.gx * ts + m, o.y + pd.gy * ts + m,
			ts - m * 2.0, ts - m * 2.0), col)


func _draw_player_sprite(pl: GameLogic.PlayerData, sprite_key: String) -> void:
	if not pl.alive:
		return
	var o := origin
	var ts := tile_size
	var m := ts * 0.08
	var bob := sin(_anim_time * 4.0 + float(pl.pid) * 1.7) * ts * 0.04
	var px := o.x + pl.gx * ts + m
	var py := o.y + pl.gy * ts + m + bob
	var sz := ts - m * 2.0
	var is_invisible := pl.invisible_timer > 0.0

	if pl.shield > 0 and not is_invisible:
		var aura: ImageTexture = _sprites.get_tex("shield_aura")
		if aura:
			var s := ts * 0.12
			draw_texture_rect(aura, Rect2(px - s, py - s, sz + s * 2.0, sz + s * 2.0), false)

	var is_concealed := logic.is_concealed(pl)

	var tex: ImageTexture = _sprites.get_tex(sprite_key)
	if tex:
		var tint: Color
		if is_invisible:
			tint = Color(1.0, 1.0, 1.0, 0.15)
		elif is_concealed:
			tint = Color(1.0, 1.0, 1.0, 0.35)
		elif pl.slow_timer > 0.0:
			tint = Color(0.5, 0.5, 0.6)
		elif pl.bouncy_timer > 0.0:
			var bp := 0.8 + 0.2 * sin(_anim_time * 6.0)
			tint = Color(1.0, bp, 0.5)
		else:
			tint = Color.WHITE
		draw_texture_rect(tex, Rect2(px, py, sz, sz), false, tint)
	else:
		var col := Color(0.35, 0.75, 1.0) if sprite_key == "p1" else Color(1.0, 0.52, 0.38)
		if is_invisible:
			col.a = 0.15
		elif is_concealed:
			col.a = 0.35
		draw_rect(Rect2(px, py, sz, sz), col)

	if not is_invisible and not is_concealed:
		draw_rect(Rect2(px, py + sz - 3.0, sz, 3.0), Color(0, 0, 0, 0.2))


func _draw_clone(cl: GameLogic.CloneData, o: Vector2, ts: float) -> void:
	var m := ts * 0.08
	var bob := sin(_anim_time * 4.0 + float(cl.owner_pid) * 1.7 + 2.0) * ts * 0.04
	var px := o.x + float(cl.gx) * ts + m
	var py := o.y + float(cl.gy) * ts + m + bob
	var sz := ts - m * 2.0
	var key := _pid_to_sprite_key(cl.owner_pid)
	var tex: ImageTexture = _sprites.get_tex(key)
	var flicker := 0.92 + 0.08 * sin(_anim_time * 8.0 + float(cl.gx))
	if tex:
		draw_texture_rect(tex, Rect2(px, py, sz, sz), false, Color(flicker, flicker, flicker))
	else:
		draw_rect(Rect2(px, py, sz, sz), Color(0.5, 0.5, 0.5))
	draw_rect(Rect2(px, py + sz - 3.0, sz, 3.0), Color(0, 0, 0, 0.2))


func _draw_tile_deco(x: int, y: int, fl: int, h: float, o: Vector2, ts: float) -> void:
	if h < 0.70:
		return
	var dh := _tile_hash(x + 97, y + 53)
	var dx := o.x + float(x) * ts + ts * (0.25 + dh * 0.5)
	var dy := o.y + float(y) * ts + ts * (0.30 + fmod(dh * 7.0, 0.4))
	var sz := ts * 0.08
	var di := int(dh * 1000.0) % 5

	if h > 0.88:
		var dx2 := o.x + float(x) * ts + ts * (0.15 + fmod(dh * 3.0, 0.4))
		var dy2 := o.y + float(y) * ts + ts * (0.55 + fmod(dh * 5.0, 0.3))
		_draw_single_deco(dx2, dy2, sz, (di + 2) % 5)

	_draw_single_deco(dx, dy, sz, di)


func _draw_single_deco(dx: float, dy: float, sz: float, di: int) -> void:
	match _theme:
		"grassland":
			match di:
				0: draw_circle(Vector2(dx, dy), sz, Color(1.0, 0.92, 0.20, 0.85))
				1: draw_circle(Vector2(dx, dy), sz * 0.9, Color(1.0, 0.55, 0.65, 0.8))
				2: draw_circle(Vector2(dx, dy), sz * 0.6, Color(0.60, 0.50, 0.38, 0.5))
				3:
					draw_circle(Vector2(dx, dy), sz * 1.3, Color(0.30, 0.62, 0.18, 0.45))
					draw_circle(Vector2(dx + sz, dy - sz * 0.5), sz, Color(0.35, 0.68, 0.22, 0.4))
				_: draw_circle(Vector2(dx, dy), sz * 0.8, Color(0.98, 0.98, 1.0, 0.75))
		"tundra":
			match di:
				0: draw_circle(Vector2(dx, dy), sz * 0.5, Color(1.0, 1.0, 1.0, 0.6))
				1:
					draw_circle(Vector2(dx, dy), sz * 1.2, Color(0.85, 0.90, 0.98, 0.3))
					draw_circle(Vector2(dx, dy), sz * 0.5, Color(1.0, 1.0, 1.0, 0.5))
				_: draw_circle(Vector2(dx, dy), sz * 0.4, Color(0.75, 0.85, 1.0, 0.4))
		"desert":
			match di:
				0: draw_circle(Vector2(dx, dy), sz * 0.6, Color(0.70, 0.58, 0.38, 0.5))
				1:
					draw_rect(Rect2(dx - sz * 0.3, dy - sz * 2.0, sz * 0.6, sz * 2.5), Color(0.40, 0.65, 0.25, 0.6))
					draw_circle(Vector2(dx, dy - sz * 2.2), sz * 0.8, Color(0.35, 0.58, 0.20, 0.5))
				2: draw_circle(Vector2(dx, dy), sz * 0.5, Color(0.82, 0.72, 0.50, 0.4))
				_: draw_rect(Rect2(dx - sz, dy - sz * 0.3, sz * 2.2, sz * 0.5), Color(0.62, 0.50, 0.35, 0.35))
		"volcano":
			var ep := 0.5 + 0.5 * sin(_anim_time * 5.0 + dx * 0.1)
			match di:
				0: draw_circle(Vector2(dx, dy), sz * 0.7, Color(1.0, 0.50, 0.12, 0.5 * ep + 0.2))
				1: draw_circle(Vector2(dx, dy), sz * 0.5, Color(1.0, 0.85, 0.20, 0.4 * ep + 0.1))
				_: draw_circle(Vector2(dx, dy), sz * 0.4, Color(0.55, 0.45, 0.40, 0.35))
		_:
			if di < 2:
				draw_circle(Vector2(dx, dy), sz * 0.5, Color(0.50, 0.50, 0.50, 0.25))


func _draw_water_edges(x: int, y: int, o: Vector2, ts: float) -> void:
	var foam := Color(0.80, 0.92, 1.0, 0.45)
	var w := ts * 0.08
	if y > 0 and logic.grid[x][y - 1] != GameLogic.Cell.WATER:
		draw_rect(Rect2(o.x + x * ts, o.y + y * ts, ts, w), foam)
	if y < logic.rows - 1 and logic.grid[x][y + 1] != GameLogic.Cell.WATER:
		draw_rect(Rect2(o.x + x * ts, o.y + (y + 1) * ts - w, ts, w), foam)
	if x > 0 and logic.grid[x - 1][y] != GameLogic.Cell.WATER:
		draw_rect(Rect2(o.x + x * ts, o.y + y * ts, w, ts), foam)
	if x < logic.cols - 1 and logic.grid[x + 1][y] != GameLogic.Cell.WATER:
		draw_rect(Rect2(o.x + (x + 1) * ts - w, o.y + y * ts, w, ts), foam)


func _draw_conveyor(x: int, y: int, ft: int, o: Vector2, ts: float) -> void:
	var cx := o.x + (float(x) + 0.5) * ts
	var cy := o.y + (float(y) + 0.5) * ts
	var arrow_col := Color(0.9, 0.9, 0.3, 0.55)
	var sz := ts * 0.15
	var scroll := fmod(_anim_time * 2.0, 1.0)
	for k in range(3):
		var off := (float(k) / 3.0 + scroll) * ts * 0.6 - ts * 0.3
		var px := cx
		var py := cy
		match ft:
			GameLogic.Floor.CONV_N: py = cy - off
			GameLogic.Floor.CONV_S: py = cy + off
			GameLogic.Floor.CONV_E: px = cx + off
			GameLogic.Floor.CONV_W: px = cx - off
		if px > o.x + x * ts and px < o.x + (x + 1) * ts and py > o.y + y * ts and py < o.y + (y + 1) * ts:
			draw_circle(Vector2(px, py), sz, arrow_col)


func _draw_creature(cr: GameLogic.CreatureData, o: Vector2, ts: float) -> void:
	var bob := sin(_anim_time * 3.5 + float(cr.gx) * 2.0) * ts * 0.05
	var m := ts * 0.2
	var px := o.x + float(cr.gx) * ts + m
	var py := o.y + float(cr.gy) * ts + m + bob
	var sz := ts - m * 2.0
	var tex: ImageTexture = _sprites.get_tex("creature")
	if tex:
		draw_texture_rect(tex, Rect2(px, py, sz, sz), false)
	else:
		draw_rect(Rect2(px, py, sz, sz), Color(0.85, 0.65, 0.30))
		draw_circle(Vector2(px + sz * 0.3, py + sz * 0.3), sz * 0.1, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(px + sz * 0.7, py + sz * 0.3), sz * 0.1, Color(0.1, 0.1, 0.1))


func _draw_torch_glow(o: Vector2, ts: float) -> void:
	for pair in logic.portals:
		for pos in pair:
			var p: Vector2i = pos
			var cx := o.x + (float(p.x) + 0.5) * ts
			var cy := o.y + (float(p.y) + 0.5) * ts
			var pulse := 0.7 + 0.3 * sin(_anim_time * 4.0 + float(p.x) * 1.5)
			var r := ts * 2.5 * pulse
			draw_circle(Vector2(cx, cy), r, Color(1.0, 0.6, 0.2, 0.06 * pulse))
			draw_circle(Vector2(cx, cy), r * 0.5, Color(1.0, 0.5, 0.15, 0.08 * pulse))


func _draw_particles(o: Vector2, ts: float) -> void:
	for p_item in _weather_particles:
		var p: Particle = p_item
		var alpha := clampf(p.life / p.max_life, 0.0, 1.0)
		var col := Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		draw_circle(Vector2(p.x, p.y), p.size, col)

	for p_item in _debris_particles:
		var p: Particle = p_item
		var alpha := clampf(p.life / p.max_life, 0.0, 1.0)
		var col := Color(p.color.r, p.color.g, p.color.b, alpha)
		draw_rect(Rect2(p.x - p.size * 0.5, p.y - p.size * 0.5, p.size, p.size), col)


func _draw_combo_popups(o: Vector2, ts: float) -> void:
	var font := ThemeDB.fallback_font
	if not font:
		return
	var i := _combo_popups.size() - 1
	while i >= 0:
		var cp: ComboPopup = _combo_popups[i]
		cp.timer -= get_process_delta_time()
		cp.py -= 40.0 * get_process_delta_time()
		if cp.timer <= 0.0:
			_combo_popups.remove_at(i)
		else:
			var alpha := clampf(cp.timer / 1.2, 0.0, 1.0)
			var scale := 1.0 + (1.0 - alpha) * 0.3
			var fs := int(16.0 * scale)
			var col := Color(cp.color.r, cp.color.g, cp.color.b, alpha)
			draw_string(font, Vector2(cp.px - 30.0, cp.py), cp.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		i -= 1


func _draw_blizzard_fog(o: Vector2, ts: float) -> void:
	var gw := logic.cols * ts
	var gh := logic.rows * ts
	var fog_alpha := 0.6 + 0.15 * sin(_anim_time * 2.0)
	draw_rect(Rect2(o.x, o.y, gw, gh), Color(0.75, 0.82, 0.92, fog_alpha * 0.5))

	var players: Array = [logic.p1]
	if is_vs_npc:
		for np in npc_players:
			players.append(np)
	else:
		players.append(logic.p2)
	for pl_item in players:
		var pl: GameLogic.PlayerData = pl_item
		if not pl.alive:
			continue
		var px := o.x + pl.gx * ts + ts * 0.5
		var py := o.y + pl.gy * ts + ts * 0.5
		var view_r := ts * 3.0
		for ring in range(6):
			var r := view_r + float(ring) * ts * 0.4
			var alpha := float(ring) / 6.0 * 0.3
			draw_arc(Vector2(px, py), r, 0.0, TAU, 32, Color(0.85, 0.90, 0.98, alpha), ts * 0.5)


func _draw_sandstorm_overlay(o: Vector2, ts: float) -> void:
	var gw := logic.cols * ts
	var gh := logic.rows * ts
	var sand_alpha := 0.3 + 0.1 * sin(_anim_time * 3.0)
	draw_rect(Rect2(o.x, o.y, gw, gh), Color(0.85, 0.72, 0.40, sand_alpha * 0.4))
	var stripe_offset := fmod(_anim_time * 200.0 * float(logic.sandstorm_dir.x), gw)
	for i in range(8):
		var sy := float(i) * gh / 8.0 + sin(_anim_time * 2.0 + float(i)) * ts * 0.5
		var sx := o.x + stripe_offset + sin(float(i) * 1.3) * ts * 2.0
		var sw := ts * (3.0 + sin(_anim_time + float(i)) * 1.0)
		draw_rect(Rect2(sx, o.y + sy, sw, ts * 0.15), Color(0.90, 0.78, 0.48, 0.25))


func _draw_avalanche_warning(o: Vector2, ts: float) -> void:
	var flash := 0.5 + 0.5 * sin(_anim_time * 10.0)
	var warn_col := Color(1.0, 0.3, 0.2, flash * 0.4)
	var L := logic
	var edge: int = L.avalanche_edge
	var col_idx: int = L.avalanche_col
	var is_horizontal := (edge == 0 or edge == 1)
	for w in range(-1, 2):
		if is_horizontal:
			var y := col_idx + w
			if y >= 0 and y < L.rows:
				draw_rect(Rect2(o.x, o.y + y * ts, L.cols * ts, ts), warn_col)
		else:
			var x := col_idx + w
			if x >= 0 and x < L.cols:
				draw_rect(Rect2(o.x + x * ts, o.y, ts, L.rows * ts), warn_col)
