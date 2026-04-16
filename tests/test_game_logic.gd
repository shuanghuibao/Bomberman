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
	print("  done.\n")


# ── helpers ───────────────────────────────

func _make(seed_v: int = 42) -> GameLogic:
	var gl := GameLogic.new(seed_v)
	gl.reset()
	return gl


func _clear_around(gl: GameLogic, cx: int, cy: int, radius: int = 3) -> void:
	for x in range(maxi(1, cx - radius), mini(GameLogic.COLS - 1, cx + radius + 1)):
		for y in range(maxi(1, cy - radius), mini(GameLogic.ROWS - 1, cy + radius + 1)):
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
	T.assert_eq(gl.grid.size(), GameLogic.COLS, "cols")
	T.assert_eq(gl.grid[0].size(), GameLogic.ROWS, "rows")


func test_grid_borders_are_walls() -> void:
	T.begin("grid_borders_are_walls")
	var gl := _make()
	for x in range(GameLogic.COLS):
		T.assert_eq(gl.grid[x][0], GameLogic.Cell.WALL, "bottom border x=%d" % x)
		T.assert_eq(gl.grid[x][GameLogic.ROWS - 1], GameLogic.Cell.WALL, "top border x=%d" % x)
	for y in range(GameLogic.ROWS):
		T.assert_eq(gl.grid[0][y], GameLogic.Cell.WALL, "left border y=%d" % y)
		T.assert_eq(gl.grid[GameLogic.COLS - 1][y], GameLogic.Cell.WALL, "right border y=%d" % y)


func test_spawn_zones_clear() -> void:
	T.begin("spawn_zones_clear")
	var gl := _make()
	T.assert_eq(gl.grid[1][1], GameLogic.Cell.EMPTY, "p1 spawn")
	T.assert_eq(gl.grid[GameLogic.COLS - 2][GameLogic.ROWS - 2], GameLogic.Cell.EMPTY, "p2 spawn")


func test_deterministic_seed() -> void:
	T.begin("deterministic_seed")
	var a := _make(123)
	var b := _make(123)
	var same := true
	for x in range(GameLogic.COLS):
		for y in range(GameLogic.ROWS):
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
	# move player away so they survive
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	gl.try_start_move(gl.p1, 1, 0)
	_finish_move(gl, gl.p1)
	# tick past fuse
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
	# don't move - player stays on bomb
	gl.tick_bombs(GameLogic.BOMB_FUSE + 0.1)
	T.assert_false(gl.p1.alive, "p1 killed by own bomb")


func test_chain_explosion() -> void:
	T.begin("chain_explosion")
	var gl := _make()
	_clear_around(gl, 1, 1, 6)
	# place p1 bomb at (1,1)
	gl.try_place_bomb(gl.p1)
	# manually place a second bomb at (2,1) that would be in range
	gl.bombs.append(GameLogic.BombData.new(2, 1, 1, 999.0, 1))
	# move p1 far away
	gl.p1.gx = 1.0; gl.p1.gy = 3.0; gl.p1.moving = false
	# detonate first bomb
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
