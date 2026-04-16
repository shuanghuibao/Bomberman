extends RefCounted

## GameLogic 单元测试

var T  # test_runner (SceneTree)


func _init(runner) -> void:
	T = runner


func run() -> void:
	print("── test_game_logic ──")
	test_grid_dimensions()
	test_grid_borders_are_walls()
	test_spawn_zones_clear()
	test_deterministic_seed()
	test_player_initial_state()
	test_player_move_right()
	test_player_cannot_walk_into_wall()
	test_place_bomb()
	test_bomb_limit()
	test_bomb_explodes_after_fuse()
	test_explosion_destroys_crate()
	test_explosion_kills_player()
	test_phase_p1_wins()
	test_phase_draw()
	test_pickup_bomb_up()
	test_pickup_fire_up()
	test_pickup_speed_up()
	test_pickup_caps()
	test_explosion_destroys_pickup()
	test_speed_increases_with_shoes()
	test_chain_explosion()
	test_kick_bomb()
	test_no_kick_without_ability()
	test_bomb_slide_stops_at_wall()
	test_remote_bomb()
	test_remote_detonate()
	test_pickup_kick()
	test_pickup_remote()
	test_pickup_shield()
	test_pickup_slow_curse()
	test_shield_absorbs_explosion()
	test_slow_curse_wears_off()
	test_map_template()
	test_iron_crate_two_hits()
	test_ice_slide()
	test_mud_slows_movement()
	test_portal_teleport()
	test_shrink_zone()
	test_floor_grid_dimensions()
	test_dynamic_grid_size()
	test_water_impassable()
	test_grass_floor()
	test_snow_speed()
	test_sand_speed()
	test_lava_damage()
	print("  done.\n")


# ── helpers ───────────────────────────────

func _make(seed_v: int = 42) -> GameLogic:
	var gl := GameLogic.new(seed_v)
	gl.reset()
	return gl


func _clear_around(gl: GameLogic, cx: int, cy: int, radius: int = 3) -> void:
	for x in range(maxi(1, cx - radius), mini(gl.cols - 1, cx + radius + 1)):
		for y in range(maxi(1, cy - radius), mini(gl.rows - 1, cy + radius + 1)):
			if gl.grid[x][y] == GameLogic.Cell.CRATE:
				gl.grid[x][y] = GameLogic.Cell.EMPTY


func _finish_move(gl: GameLogic, pl: GameLogic.PlayerData) -> void:
	for i in range(120):
		gl.player_move_tick(pl, 1.0 / 60.0)
		if pl.aligned():
			break


# ── 网格生成 ──────────────────────────────

func test_grid_dimensions() -> void:
	T.begin("grid_dimensions")
	var gl := _make()
	T.assert_eq(gl.grid.size(), gl.cols, "cols")
	T.assert_eq(gl.grid[0].size(), gl.rows, "rows")


func test_grid_borders_are_walls() -> void:
	T.begin("grid_borders_are_walls")
	var gl := _make()
	for x in range(gl.cols):
		T.assert_eq(gl.grid[x][0], GameLogic.Cell.WALL, "bottom border x=%d" % x)
		T.assert_eq(gl.grid[x][gl.rows - 1], GameLogic.Cell.WALL, "top border x=%d" % x)
	for y in range(gl.rows):
		T.assert_eq(gl.grid[0][y], GameLogic.Cell.WALL, "left border y=%d" % y)
		T.assert_eq(gl.grid[gl.cols - 1][y], GameLogic.Cell.WALL, "right border y=%d" % y)


func test_spawn_zones_clear() -> void:
	T.begin("spawn_zones_clear")
	var gl := _make()
	T.assert_eq(gl.grid[1][1], GameLogic.Cell.EMPTY, "p1 spawn")
	T.assert_eq(gl.grid[gl.cols - 2][gl.rows - 2], GameLogic.Cell.EMPTY, "p2 spawn")


func test_deterministic_seed() -> void:
	T.begin("deterministic_seed")
	var a := _make(123)
	var b := _make(123)
	var same := true
	for x in range(a.cols):
		for y in range(a.rows):
			if a.grid[x][y] != b.grid[x][y]:
				same = false
	T.assert_true(same, "same seed → same grid")


# ── 玩家 ─────────────────────────────────

func test_player_initial_state() -> void:
	T.begin("player_initial_state")
	var gl := _make()
	T.assert_eq(gl.p1.gx, 1.0)
	T.assert_eq(gl.p1.gy, 1.0)
	T.assert_true(gl.p1.alive)
	T.assert_eq(gl.p1.max_bombs, 1)
	T.assert_eq(gl.p1.range_i, 1)


func test_player_move_right() -> void:
	T.begin("player_move_right")
	var gl := _make()
	_clear_around(gl, 1, 1)
	var ok := gl.try_start_move(gl.p1, 1, 0)
	T.assert_true(ok, "move accepted")
	T.assert_true(gl.p1.moving, "player is moving")
	_finish_move(gl, gl.p1)
	T.assert_eq(gl.p1.gx, 2.0, "arrived x")
	T.assert_eq(gl.p1.gy, 1.0, "same y")


func test_player_cannot_walk_into_wall() -> void:
	T.begin("player_cannot_walk_into_wall")
	var gl := _make()
	var ok := gl.try_start_move(gl.p1, -1, 0)
	T.assert_false(ok, "blocked by left wall")
	T.assert_eq(gl.p1.gx, 1.0)


# ── 炸弹 ─────────────────────────────────

func test_place_bomb() -> void:
	T.begin("place_bomb")
	var gl := _make()
	gl.try_place_bomb(gl.p1)
	T.assert_eq(gl.bombs.size(), 1)
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_eq(bd.gx, 1)
	T.assert_eq(bd.gy, 1)


func test_bomb_limit() -> void:
	T.begin("bomb_limit")
	var gl := _make()
	gl.try_place_bomb(gl.p1)
	_clear_around(gl, 1, 1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.try_place_bomb(gl.p1)
	T.assert_eq(gl.bombs.size(), 1, "max_bombs=1 → only one bomb")


func test_bomb_explodes_after_fuse() -> void:
	T.begin("bomb_explodes_after_fuse")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.try_place_bomb(gl.p1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.bombs.size(), 0, "bomb removed")
	T.assert_true(gl.explosions.size() > 0, "explosion created")


func test_explosion_destroys_crate() -> void:
	T.begin("explosion_destroys_crate")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.grid[2][1] = GameLogic.Cell.CRATE
	gl.try_place_bomb(gl.p1)
	gl.try_start_move(gl.p1, 0, 1)
	_finish_move(gl, gl.p1)
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.grid[2][1], GameLogic.Cell.EMPTY, "crate destroyed")


func test_explosion_kills_player() -> void:
	T.begin("explosion_kills_player")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.try_place_bomb(gl.p1)
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_false(gl.p1.alive, "p1 killed by own bomb")


func test_chain_explosion() -> void:
	T.begin("chain_explosion")
	var gl := _make()
	_clear_around(gl, 1, 1, 6)
	gl.try_place_bomb(gl.p1)
	gl.bombs.append(GameLogic.BombData.new(2, 1, 1, 999.0, 1))
	gl.p1.gx = 1.0; gl.p1.gy = 3.0; gl.p1.moving = false
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.bombs.size(), 0, "chain: both bombs detonated")


# ── 胜负 ─────────────────────────────────

func test_phase_p1_wins() -> void:
	T.begin("phase_p1_wins")
	var gl := _make()
	gl.p2.alive = false
	gl.resolve_phase()
	T.assert_eq(gl.phase, GameLogic.Phase.P1_WIN)


func test_phase_draw() -> void:
	T.begin("phase_draw")
	var gl := _make()
	gl.p1.alive = false
	gl.p2.alive = false
	gl.resolve_phase()
	T.assert_eq(gl.phase, GameLogic.Phase.DRAW)


# ── 道具 ─────────────────────────────────

func test_pickup_bomb_up() -> void:
	T.begin("pickup_bomb_up")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.BOMB_UP))
	gl.try_collect_pickup(gl.p1)
	T.assert_eq(gl.p1.max_bombs, 2, "bomb_up applied")
	T.assert_eq(gl.pickups.size(), 0, "pickup consumed")


func test_pickup_fire_up() -> void:
	T.begin("pickup_fire_up")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.FIRE_UP))
	gl.try_collect_pickup(gl.p1)
	T.assert_eq(gl.p1.range_i, 2, "fire_up applied")


func test_pickup_speed_up() -> void:
	T.begin("pickup_speed_up")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.SPEED_UP))
	gl.try_collect_pickup(gl.p1)
	T.assert_eq(gl.p1.speed_ups, 1, "speed_up applied")


func test_pickup_caps() -> void:
	T.begin("pickup_caps")
	var gl := _make()
	gl.p1.max_bombs = 8
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.BOMB_UP))
	gl.try_collect_pickup(gl.p1)
	T.assert_eq(gl.p1.max_bombs, 8, "capped at 8")


func test_explosion_destroys_pickup() -> void:
	T.begin("explosion_destroys_pickup")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.pickups.append(GameLogic.PickupData.new(2, 1, GameLogic.Pickup.FIRE_UP))
	gl.try_place_bomb(gl.p1)
	gl.p1.gx = 1.0; gl.p1.gy = 3.0; gl.p1.moving = false
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.pickups.size(), 0, "pickup destroyed by blast")


func test_speed_increases_with_shoes() -> void:
	T.begin("speed_increases_with_shoes")
	var gl := _make()
	var base_spd := gl.p1.move_speed()
	gl.p1.speed_ups = 2
	T.assert_gt(gl.p1.move_speed(), base_spd, "faster with shoes")
	gl.p1.speed_ups = 99
	T.assert_lte(gl.p1.move_speed(), GameLogic.MAX_SPEED, "capped at MAX_SPEED")


# ── 踢雷 ─────────────────────────────────

func test_kick_bomb() -> void:
	T.begin("kick_bomb")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.p1.has_kick = true
	gl.bombs.append(GameLogic.BombData.new(2, 1, 1, 999.0, 1))
	var moved := gl.try_start_move(gl.p1, 1, 0)
	T.assert_false(moved, "player stays put")
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_true(bd.moving, "bomb kicked into motion")
	T.assert_eq(bd.move_dir, Vector2i(1, 0), "moves right")


func test_no_kick_without_ability() -> void:
	T.begin("no_kick_without_ability")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.bombs.append(GameLogic.BombData.new(2, 1, 1, 999.0, 1))
	gl.try_start_move(gl.p1, 1, 0)
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_false(bd.moving, "bomb not kicked")


func test_bomb_slide_stops_at_wall() -> void:
	T.begin("bomb_slide_stops_at_wall")
	var gl := _make()
	_clear_around(gl, 1, 1, 8)
	gl.p1.has_kick = true
	gl.bombs.append(GameLogic.BombData.new(2, 1, 0, 999.0, 1))
	gl.try_start_move(gl.p1, 1, 0)
	for i in range(200):
		gl.tick_moving_bombs(0.02)
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_false(bd.moving, "stopped sliding")
	T.assert_true(bd.gx < gl.cols, "within bounds")


# ── 遥控引爆 ─────────────────────────────

func test_remote_bomb() -> void:
	T.begin("remote_bomb")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.p1.has_remote = true
	gl.try_place_bomb(gl.p1)
	T.assert_eq(gl.bombs.size(), 1, "placed")
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_true(bd.is_remote, "remote flag set")
	T.assert_true(bd.time > 100.0, "very long fuse")


func test_remote_detonate() -> void:
	T.begin("remote_detonate")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.p1.has_remote = true
	gl.try_place_bomb(gl.p1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.try_place_bomb(gl.p1)
	var bd: GameLogic.BombData = gl.bombs[0]
	T.assert_true(bd.time <= 0.0, "remote detonated")


# ── 新道具 ───────────────────────────────

func test_pickup_kick() -> void:
	T.begin("pickup_kick")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.KICK))
	gl.try_collect_pickup(gl.p1)
	T.assert_true(gl.p1.has_kick, "kick acquired")
	T.assert_eq(gl.pickups.size(), 0, "consumed")


func test_pickup_remote() -> void:
	T.begin("pickup_remote")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.REMOTE))
	gl.try_collect_pickup(gl.p1)
	T.assert_true(gl.p1.has_remote, "remote acquired")
	T.assert_eq(gl.pickups.size(), 0, "consumed")


func test_pickup_shield() -> void:
	T.begin("pickup_shield")
	var gl := _make()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.SHIELD))
	gl.try_collect_pickup(gl.p1)
	T.assert_eq(gl.p1.shield, 1, "shield acquired")
	T.assert_eq(gl.pickups.size(), 0, "consumed")


func test_pickup_slow_curse() -> void:
	T.begin("pickup_slow_curse")
	var gl := _make()
	var base_spd := gl.p1.move_speed()
	gl.pickups.append(GameLogic.PickupData.new(1, 1, GameLogic.Pickup.SLOW_CURSE))
	gl.try_collect_pickup(gl.p1)
	T.assert_true(gl.p1.slow_timer > 0.0, "slow applied")
	T.assert_true(gl.p1.move_speed() < base_spd, "speed reduced")


func test_shield_absorbs_explosion() -> void:
	T.begin("shield_absorbs_explosion")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.p1.shield = 1
	gl.try_place_bomb(gl.p1)
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_true(gl.p1.alive, "survived thanks to shield")
	T.assert_eq(gl.p1.shield, 0, "shield consumed")


func test_slow_curse_wears_off() -> void:
	T.begin("slow_curse_wears_off")
	var gl := _make()
	gl.p1.slow_timer = 1.0
	var slow_spd := gl.p1.move_speed()
	for i in range(70):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
	T.assert_true(gl.p1.slow_timer <= 0.0, "slow expired")
	T.assert_true(gl.p1.move_speed() > slow_spd, "speed restored")


# ── 地图模板 ─────────────────────────────

func test_map_template() -> void:
	T.begin("map_template")
	var gl := GameLogic.new(42)
	var arena: Dictionary = MapDefs.get_presets()[1]
	gl.reset(arena)
	T.assert_eq(gl.grid.size(), gl.cols, "cols")
	T.assert_eq(gl.grid[0].size(), gl.rows, "rows")
	T.assert_eq(gl.grid[3][2], GameLogic.Cell.WALL, "arena wall (3,2)")
	T.assert_eq(gl.grid[3][3], GameLogic.Cell.WALL, "arena wall (3,3)")
	T.assert_eq(gl.grid[7][5], GameLogic.Cell.EMPTY, "arena center empty")


# ── 铁箱 ─────────────────────────────────

func test_iron_crate_two_hits() -> void:
	T.begin("iron_crate_two_hits")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.grid[2][1] = GameLogic.Cell.IRON_CRATE
	gl.iron_hp[Vector2i(2, 1)] = 2
	gl.try_place_bomb(gl.p1)
	gl.p1.gx = 1.0; gl.p1.gy = 3.0; gl.p1.moving = false
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.grid[2][1], GameLogic.Cell.IRON_CRATE, "still iron after first hit")
	T.assert_eq(gl.iron_hp.get(Vector2i(2, 1), 0), 1, "hp reduced to 1")
	gl.p1.gx = 1.0; gl.p1.gy = 1.0; gl.p1.moving = false
	gl.try_place_bomb(gl.p1)
	gl.p1.gx = 1.0; gl.p1.gy = 3.0; gl.p1.moving = false
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_eq(gl.grid[2][1], GameLogic.Cell.EMPTY, "destroyed after second hit")
	T.assert_false(gl.iron_hp.has(Vector2i(2, 1)), "hp entry removed")


# ── 冰面 ─────────────────────────────────

func test_ice_slide() -> void:
	T.begin("ice_slide")
	var gl := _make()
	_clear_around(gl, 1, 1, 6)
	gl.floor_grid[2][1] = GameLogic.Floor.ICE
	gl.floor_grid[3][1] = GameLogic.Floor.ICE
	gl.try_start_move(gl.p1, 1, 0)
	for i in range(300):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		if gl.p1.aligned() and not gl.p1.moving:
			break
	T.assert_eq(gl.p1.gx, 4.0, "slid through ice to non-ice cell")
	T.assert_eq(gl.p1.gy, 1.0, "y unchanged")


# ── 泥地 ─────────────────────────────────

func test_mud_slows_movement() -> void:
	T.begin("mud_slows_movement")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.try_start_move(gl.p1, 1, 0)
	var normal_frames := 0
	for i in range(200):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		normal_frames += 1
		if gl.p1.aligned():
			break
	gl.p1.gx = 1.0; gl.p1.gy = 1.0; gl.p1.target_gx = 1.0; gl.p1.target_gy = 1.0; gl.p1.moving = false
	gl.floor_grid[1][1] = GameLogic.Floor.MUD
	gl.floor_grid[2][1] = GameLogic.Floor.MUD
	gl.try_start_move(gl.p1, 1, 0)
	var mud_frames := 0
	for i in range(400):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		mud_frames += 1
		if gl.p1.aligned():
			break
	T.assert_true(mud_frames > normal_frames, "mud slowed movement")


# ── 传送门 ───────────────────────────────

func test_portal_teleport() -> void:
	T.begin("portal_teleport")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	_clear_around(gl, 5, 5, 3)
	gl.portals.append([Vector2i(2, 1), Vector2i(5, 5)])
	gl.try_start_move(gl.p1, 1, 0)
	for i in range(300):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		if gl.p1.aligned() and not gl.p1.moving:
			break
	T.assert_eq(gl.p1.gx, 5.0, "teleported x")
	T.assert_eq(gl.p1.gy, 5.0, "teleported y")
	T.assert_true(gl.p1.portal_cd > 0.0, "cooldown active")


# ── 缩圈 ─────────────────────────────────

func test_shrink_zone() -> void:
	T.begin("shrink_zone")
	var gl := _make()
	gl.p1.gx = 5.0; gl.p1.gy = 5.0; gl.p1.target_gx = 5.0; gl.p1.target_gy = 5.0; gl.p1.moving = false
	gl.p2.gx = 7.0; gl.p2.gy = 5.0; gl.p2.target_gx = 7.0; gl.p2.target_gy = 5.0; gl.p2.moving = false
	gl.shrink_enabled = true
	gl.shrink_timer = GameLogic.SHRINK_START + 0.1
	gl.tick_shrink(0.0)
	T.assert_eq(gl.shrink_ring, 1, "first ring shrunk")
	T.assert_eq(gl.grid[1][1], GameLogic.Cell.SHRINK_WALL, "corner became shrink wall")
	T.assert_true(gl.p1.alive, "p1 safe in center")
	T.assert_true(gl.p2.alive, "p2 safe in center")


func test_floor_grid_dimensions() -> void:
	T.begin("floor_grid_dimensions")
	var gl := _make()
	T.assert_eq(gl.floor_grid.size(), gl.cols, "floor cols")
	T.assert_eq(gl.floor_grid[0].size(), gl.rows, "floor rows")


# ── 动态网格尺寸 ─────────────────────────

func test_dynamic_grid_size() -> void:
	T.begin("dynamic_grid_size")
	var gl := GameLogic.new(42)
	var map_dict: Dictionary = {
		"cols": 21,
		"rows": 15,
		"template": [
			"#####################",
			"#.................G.#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#...................#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#...................#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#...................#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#...................#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#...................#",
			"#.#.#.#.#.#.#.#.#.#.#",
			"#.G.................#",
			"#####################",
		],
		"spawns": [Vector2i(1, 1), Vector2i(19, 13), Vector2i(19, 1), Vector2i(1, 13), Vector2i(10, 7)],
	}
	gl.reset(map_dict)
	T.assert_eq(gl.cols, 21, "cols=21")
	T.assert_eq(gl.rows, 15, "rows=15")
	T.assert_eq(gl.grid.size(), 21, "grid has 21 cols")
	T.assert_eq(gl.grid[0].size(), 15, "grid has 15 rows")
	T.assert_eq(gl.floor_grid[18][1], GameLogic.Floor.GRASS, "grass floor parsed")


# ── 水面不可通行 ─────────────────────────

func test_water_impassable() -> void:
	T.begin("water_impassable")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.grid[2][1] = GameLogic.Cell.WATER
	var ok := gl.try_start_move(gl.p1, 1, 0)
	T.assert_false(ok, "cannot walk into water")
	T.assert_eq(gl.p1.gx, 1.0, "stayed put")


# ── 草地 ─────────────────────────────────

func test_grass_floor() -> void:
	T.begin("grass_floor")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.floor_grid[2][1] = GameLogic.Floor.GRASS
	var ok := gl.try_start_move(gl.p1, 1, 0)
	T.assert_true(ok, "can walk on grass")
	_finish_move(gl, gl.p1)
	T.assert_eq(gl.p1.gx, 2.0, "reached grass cell")


# ── 雪地减速 ─────────────────────────────

func test_snow_speed() -> void:
	T.begin("snow_speed")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.try_start_move(gl.p1, 1, 0)
	var normal_frames := 0
	for i in range(200):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		normal_frames += 1
		if gl.p1.aligned():
			break
	gl.p1.gx = 1.0; gl.p1.gy = 1.0; gl.p1.target_gx = 1.0; gl.p1.target_gy = 1.0; gl.p1.moving = false
	gl.floor_grid[1][1] = GameLogic.Floor.SNOW
	gl.floor_grid[2][1] = GameLogic.Floor.SNOW
	gl.try_start_move(gl.p1, 1, 0)
	var snow_frames := 0
	for i in range(400):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		snow_frames += 1
		if gl.p1.aligned():
			break
	T.assert_true(snow_frames > normal_frames, "snow slowed movement")


# ── 沙地减速 ─────────────────────────────

func test_sand_speed() -> void:
	T.begin("sand_speed")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.try_start_move(gl.p1, 1, 0)
	var normal_frames := 0
	for i in range(200):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		normal_frames += 1
		if gl.p1.aligned():
			break
	gl.p1.gx = 1.0; gl.p1.gy = 1.0; gl.p1.target_gx = 1.0; gl.p1.target_gy = 1.0; gl.p1.moving = false
	gl.floor_grid[1][1] = GameLogic.Floor.SAND
	gl.floor_grid[2][1] = GameLogic.Floor.SAND
	gl.try_start_move(gl.p1, 1, 0)
	var sand_frames := 0
	for i in range(400):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
		sand_frames += 1
		if gl.p1.aligned():
			break
	T.assert_true(sand_frames > normal_frames, "sand slowed movement")


# ── 岩浆伤害 ─────────────────────────────

func test_lava_damage() -> void:
	T.begin("lava_damage")
	var gl := _make()
	_clear_around(gl, 1, 1, 5)
	gl.floor_grid[1][1] = GameLogic.Floor.LAVA
	T.assert_true(gl.p1.alive, "alive before lava")
	for i in range(40):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
	T.assert_true(gl.p1.alive, "still alive (< 0.8s)")
	T.assert_true(gl.p1.lava_timer > 0.0, "lava timer ticking")
	for i in range(20):
		gl.player_move_tick(gl.p1, 1.0 / 60.0)
	T.assert_false(gl.p1.alive, "killed by lava after > 0.8s")
