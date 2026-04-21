class_name SpriteFactory
extends RefCounted

## Generates all pixel-art textures at runtime (16×16 base, nearest-neighbor scaling).
## No external assets required.

const SZ := 16
const T := Color.TRANSPARENT

# ── Character palettes ────────────────────

# Each palette: [hat/body, hat_dark, skin, skin_dark, eye, shoe]
const PAL_P1: Array[Color] = [
	Color(0.30, 0.62, 0.95), Color(0.20, 0.44, 0.72),
	Color(0.96, 0.80, 0.65), Color(0.85, 0.68, 0.52),
	Color(0.12, 0.12, 0.18), Color(0.22, 0.22, 0.30),
]
const PAL_P2: Array[Color] = [
	Color(1.0, 0.52, 0.30), Color(0.82, 0.38, 0.18),
	Color(0.96, 0.80, 0.65), Color(0.85, 0.68, 0.52),
	Color(0.12, 0.12, 0.18), Color(0.35, 0.22, 0.12),
]
const PAL_NPC0: Array[Color] = [
	Color(0.40, 0.80, 0.35), Color(0.28, 0.60, 0.22),
	Color(0.96, 0.80, 0.65), Color(0.85, 0.68, 0.52),
	Color(0.12, 0.12, 0.18), Color(0.20, 0.32, 0.15),
]
const PAL_NPC1: Array[Color] = [
	Color(0.90, 0.45, 0.80), Color(0.70, 0.30, 0.62),
	Color(0.96, 0.80, 0.65), Color(0.85, 0.68, 0.52),
	Color(0.12, 0.12, 0.18), Color(0.38, 0.18, 0.35),
]
const PAL_NPC2: Array[Color] = [
	Color(0.72, 0.55, 0.95), Color(0.52, 0.38, 0.75),
	Color(0.96, 0.80, 0.65), Color(0.85, 0.68, 0.52),
	Color(0.12, 0.12, 0.18), Color(0.30, 0.22, 0.42),
]

# ── Cached textures ──────────────────────

var _cache: Dictionary = {}

static var _instance: SpriteFactory = null

static func get_instance() -> SpriteFactory:
	if _instance == null:
		_instance = SpriteFactory.new()
		_instance._generate_all()
	return _instance


func get_tex(key: String) -> ImageTexture:
	return _cache.get(key, null)


# ── Generation entry ─────────────────────

func _generate_all() -> void:
	_gen_characters()
	_gen_items()
	_gen_bomb()
	_gen_explosion()
	_gen_shield_aura()
	_gen_terrain_tiles()
	_gen_theme_tiles()
	_gen_creature()


# ── Character sprites ────────────────────

func _gen_characters() -> void:
	var pals: Array[Array] = [PAL_P1, PAL_P2, PAL_NPC0, PAL_NPC1, PAL_NPC2]
	var names: Array[String] = ["p1", "p2", "npc0", "npc1", "npc2"]
	for i in range(pals.size()):
		_cache[names[i]] = _make_character(pals[i])


func _make_character(pal: Array) -> ImageTexture:
	# pal: [body, body_dark, skin, skin_dark, eye, shoe]
	var B: Color = pal[0]     # body / hat
	var BD: Color = pal[1]    # body dark
	var S: Color = pal[2]     # skin
	var SD: Color = pal[3]    # skin dark
	var E: Color = pal[4]     # eye
	var SH: Color = pal[5]    # shoe
	var W := Color.WHITE
	var o := T

	var rows: Array = [
		[o,  o,  o,  o,  o,  B,  B,  B,  B,  B,  B,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  B,  B,  B,  B,  B,  B,  B,  B,  o,  o,  o,  o],
		[o,  o,  o,  B,  B,  B,  B,  B,  B,  B,  B,  B,  B,  o,  o,  o],
		[o,  o,  o,  BD, BD, BD, BD, BD, BD, BD, BD, BD, BD, o,  o,  o],
		[o,  o,  o,  o,  S,  S,  S,  S,  S,  S,  S,  S,  o,  o,  o,  o],
		[o,  o,  o,  S,  S,  E,  S,  S,  S,  E,  S,  S,  S,  o,  o,  o],
		[o,  o,  o,  S,  S,  E,  S,  S,  S,  E,  S,  S,  S,  o,  o,  o],
		[o,  o,  o,  o,  SD, S,  S,  SD, SD, S,  S,  SD, o,  o,  o,  o],
		[o,  o,  o,  o,  o,  SD, SD, SD, SD, SD, SD, o,  o,  o,  o,  o],
		[o,  o,  o,  B,  B,  B,  B,  B,  B,  B,  B,  B,  B,  o,  o,  o],
		[o,  o,  B,  B,  B,  W,  W,  B,  B,  W,  W,  B,  B,  B,  o,  o],
		[o,  o,  B,  B,  BD, BD, BD, BD, BD, BD, BD, BD, B,  B,  o,  o],
		[o,  o,  o,  B,  B,  B,  B,  B,  B,  B,  B,  B,  B,  o,  o,  o],
		[o,  o,  o,  o,  B,  B,  o,  o,  o,  o,  B,  B,  o,  o,  o,  o],
		[o,  o,  o,  SH, SH, SH, o,  o,  o,  o,  SH, SH, SH, o,  o,  o],
		[o,  o,  o,  SH, SH, SH, o,  o,  o,  o,  SH, SH, SH, o,  o,  o],
	]
	return _rows_to_tex(rows)


# ── Item sprites ─────────────────────────

func _gen_items() -> void:
	_cache["item_bomb_up"] = _make_item_bomb_up()
	_cache["item_fire_up"] = _make_item_fire_up()
	_cache["item_speed"] = _make_item_speed()
	_cache["item_kick"] = _make_item_kick()
	_cache["item_remote"] = _make_item_remote()
	_cache["item_shield"] = _make_item_shield()
	_cache["item_curse"] = _make_item_curse()
	_cache["item_bouncy"] = _make_item_bouncy()
	_cache["item_ice_wall"] = _make_item_ice_wall()
	_cache["item_soul_swap"] = _make_item_soul_swap()
	_cache["item_clone"] = _make_item_clone()


func _make_item_bomb_up() -> ImageTexture:
	var K := Color(0.10, 0.10, 0.14)
	var G := Color(0.35, 0.35, 0.40)
	var O := Color(1.0, 0.55, 0.15)
	var W := Color.WHITE
	var C := Color(0.28, 0.62, 1.0)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  O,  O,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  O,  O,  O,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  G,  G,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  K,  K,  K,  K,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  K,  K,  K,  G,  K,  K,  K,  K,  o,  o,  o,  o,  o],
		[o,  o,  o,  K,  K,  G,  G,  K,  K,  K,  K,  o,  o,  C,  o,  o],
		[o,  o,  o,  K,  K,  K,  K,  K,  K,  K,  K,  o,  C,  C,  C,  o],
		[o,  o,  o,  K,  K,  K,  K,  K,  K,  K,  K,  o,  o,  C,  o,  o],
		[o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  K,  K,  K,  K,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_fire_up() -> ImageTexture:
	var R := Color(1.0, 0.25, 0.10)
	var O := Color(1.0, 0.60, 0.10)
	var Y := Color(1.0, 0.90, 0.25)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  R,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  R,  R,  R,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  R,  R,  O,  R,  R,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  R,  O,  O,  O,  R,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  R,  R,  O,  Y,  O,  R,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  R,  O,  O,  Y,  O,  O,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  R,  R,  O,  Y,  Y,  Y,  O,  R,  R,  o,  o,  o,  o],
		[o,  o,  o,  R,  O,  O,  Y,  Y,  Y,  O,  O,  R,  o,  o,  o,  o],
		[o,  o,  o,  R,  O,  Y,  Y,  Y,  Y,  Y,  O,  R,  o,  o,  o,  o],
		[o,  o,  o,  R,  O,  O,  Y,  Y,  Y,  O,  O,  R,  o,  o,  o,  o],
		[o,  o,  o,  o,  R,  O,  O,  Y,  O,  O,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  R,  O,  O,  O,  R,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  R,  R,  R,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_speed() -> ImageTexture:
	var G := Color(0.20, 0.75, 0.35)
	var GD := Color(0.12, 0.50, 0.22)
	var W := Color(0.92, 0.92, 0.95)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  G,  G,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  G,  G,  G,  G,  G,  o,  o,  o],
		[o,  o,  o,  W,  W,  o,  o,  G,  G,  G,  G,  G,  G,  G,  o,  o],
		[o,  o,  W,  W,  W,  W,  o,  G,  G,  W,  G,  G,  G,  G,  o,  o],
		[o,  W,  W,  W,  W,  W,  G,  G,  G,  G,  G,  G,  G,  G,  o,  o],
		[o,  o,  W,  W,  W,  G,  G,  G,  G,  G,  G,  G,  G,  o,  o,  o],
		[o,  o,  o,  W,  G,  G,  G,  G,  GD, GD, G,  G,  o,  o,  o,  o],
		[o,  o,  o,  o,  G,  G,  G,  GD, GD, GD, G,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  G,  GD, GD, GD, G,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  GD, GD, GD, GD, G,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  GD, GD, GD, GD, GD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  GD, GD, GD, GD, GD, GD, GD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  GD, GD, GD, GD, GD, GD, GD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  GD, GD, GD, GD, GD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_kick() -> ImageTexture:
	var Y := Color(0.95, 0.82, 0.18)
	var YD := Color(0.75, 0.62, 0.10)
	var W := Color.WHITE
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  W,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  W,  W,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  W,  W,  W,  o,  o,  o,  o],
		[o,  o,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  W,  W,  W,  o,  o,  o],
		[o,  o,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  W,  W,  W,  o,  o],
		[o,  o,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  W,  W,  o,  o],
		[o,  o,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  W,  W,  W,  o,  o],
		[o,  o,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  Y,  W,  W,  W,  o,  o,  o],
		[o,  o,  YD, YD, YD, YD, YD, YD, YD, W,  W,  W,  o,  o,  o,  o],
		[o,  o,  o,  YD, YD, YD, YD, o,  o,  W,  W,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  YD, YD, o,  o,  o,  W,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  YD, YD, YD, o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  YD, YD, YD, YD, YD, o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  YD, YD, YD, YD, YD, o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_remote() -> ImageTexture:
	var P := Color(0.72, 0.38, 0.95)
	var PD := Color(0.50, 0.25, 0.70)
	var R := Color(1.0, 0.20, 0.20)
	var G := Color(0.45, 0.45, 0.50)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  R,  R,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  G,  G,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  G,  G,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  P,  P,  P,  P,  P,  P,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  P,  P,  P,  P,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  R,  R,  R,  R,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  R,  R,  R,  R,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  R,  R,  R,  R,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  P,  P,  P,  P,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  PD, PD, PD, PD, P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  PD, PD, PD, PD, P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  P,  P,  P,  P,  P,  P,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  P,  P,  P,  P,  P,  P,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_shield() -> ImageTexture:
	var C := Color(0.20, 0.75, 0.85)
	var CD := Color(0.12, 0.52, 0.62)
	var W := Color(0.90, 0.95, 1.0)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o,  o],
		[o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o],
		[o,  o,  C,  C,  W,  W,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o],
		[o,  o,  C,  C,  W,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o],
		[o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o],
		[o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o],
		[o,  o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o,  o],
		[o,  o,  o,  CD, CD, CD, CD, CD, CD, CD, CD, CD, CD, o,  o,  o],
		[o,  o,  o,  o,  CD, CD, CD, CD, CD, CD, CD, CD, o,  o,  o,  o],
		[o,  o,  o,  o,  o,  CD, CD, CD, CD, CD, CD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  CD, CD, CD, CD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  CD, CD, o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_curse() -> ImageTexture:
	var R := Color(0.80, 0.15, 0.20)
	var RD := Color(0.55, 0.10, 0.12)
	var W := Color.WHITE
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  R,  R,  R,  R,  R,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  R,  R,  R,  R,  R,  R,  R,  R,  o,  o,  o,  o],
		[o,  o,  o,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  o,  o,  o],
		[o,  o,  o,  R,  R,  W,  W,  R,  R,  W,  W,  R,  R,  o,  o,  o],
		[o,  o,  o,  R,  R,  W,  W,  R,  R,  W,  W,  R,  R,  o,  o,  o],
		[o,  o,  o,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  o,  o,  o],
		[o,  o,  o,  o,  R,  R,  R,  R,  R,  R,  R,  R,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  R,  R,  R,  R,  R,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  RD, RD, RD, RD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  RD, o,  o,  RD, RD, o,  o,  RD, o,  o,  o,  o],
		[o,  o,  o,  RD, RD, RD, o,  RD, RD, o,  RD, RD, RD, o,  o,  o],
		[o,  o,  o,  o,  RD, o,  o,  RD, RD, o,  o,  RD, o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  RD, RD, RD, RD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_bouncy() -> ImageTexture:
	var O := Color(1.0, 0.60, 0.10)
	var OL := Color(1.0, 0.78, 0.35)
	var OD := Color(0.80, 0.42, 0.08)
	var S := Color(0.70, 0.70, 0.72)
	var SD := Color(0.50, 0.50, 0.52)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  O,  O,  O,  O,  O,  O,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  O,  O,  OL, OL, O,  O,  O,  O,  o,  o,  o,  o],
		[o,  o,  o,  O,  O,  OL, OL, OL, O,  O,  O,  O,  O,  o,  o,  o],
		[o,  o,  o,  O,  O,  OL, O,  O,  O,  O,  O,  O,  O,  o,  o,  o],
		[o,  o,  o,  O,  O,  O,  O,  O,  O,  O,  O,  O,  O,  o,  o,  o],
		[o,  o,  o,  O,  O,  O,  O,  O,  O,  O,  OD, OD, O,  o,  o,  o],
		[o,  o,  o,  o,  O,  O,  O,  O,  O,  OD, OD, O,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  O,  O,  O,  O,  O,  O,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  S,  S,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  S,  o,  o,  S,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  S,  S,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  S,  o,  o,  S,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  S,  S,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  SD, SD, SD, SD, SD, SD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_ice_wall() -> ImageTexture:
	var IB := Color(0.55, 0.78, 1.0)
	var IL := Color(0.80, 0.92, 1.0)
	var ID := Color(0.35, 0.55, 0.80)
	var W := Color(0.95, 0.97, 1.0)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, o,  o],
		[o,  o,  ID, IB, IB, IB, IB, IL, IL, IB, IB, IB, IB, ID, o,  o],
		[o,  o,  ID, IB, IL, IL, IB, IB, IB, IB, IL, IL, IB, ID, o,  o],
		[o,  o,  ID, IB, IL, W,  IL, IB, IB, IL, W,  IL, IB, ID, o,  o],
		[o,  o,  ID, IB, IL, IL, IB, IB, IB, IB, IL, IL, IB, ID, o,  o],
		[o,  o,  ID, IB, IB, IB, IB, IL, IL, IB, IB, IB, IB, ID, o,  o],
		[o,  o,  ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, o,  o],
		[o,  o,  ID, IB, IB, IB, IB, IL, IL, IB, IB, IB, IB, ID, o,  o],
		[o,  o,  ID, IB, IL, IL, IB, IB, IB, IB, IL, IL, IB, ID, o,  o],
		[o,  o,  ID, IB, IL, W,  IL, IB, IB, IL, W,  IL, IB, ID, o,  o],
		[o,  o,  ID, IB, IB, IB, IB, IB, IB, IB, IB, IB, IB, ID, o,  o],
		[o,  o,  ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, ID, o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_soul_swap() -> ImageTexture:
	var P := Color(0.65, 0.30, 0.95)
	var PL := Color(0.82, 0.55, 1.0)
	var PD := Color(0.42, 0.18, 0.65)
	var W := Color.WHITE
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  PL, PL, o,  o,  o,  o,  PD, PD, o,  o,  o,  o],
		[o,  o,  o,  PL, PL, PL, PL, o,  o,  PD, PD, PD, PD, o,  o,  o],
		[o,  o,  PL, PL, W,  PL, PL, P,  P,  PD, PD, W,  PD, PD, o,  o],
		[o,  o,  PL, PL, PL, PL, P,  P,  P,  P,  PD, PD, PD, PD, o,  o],
		[o,  o,  o,  PL, PL, P,  P,  o,  o,  P,  P,  PD, PD, o,  o,  o],
		[o,  o,  o,  o,  P,  P,  o,  o,  o,  o,  P,  P,  o,  o,  o,  o],
		[o,  o,  o,  P,  P,  o,  o,  o,  o,  o,  o,  P,  P,  o,  o,  o],
		[o,  o,  P,  P,  o,  o,  o,  o,  o,  o,  o,  o,  P,  P,  o,  o],
		[o,  o,  o,  PD, PD, o,  o,  o,  o,  o,  o,  PL, PL, o,  o,  o],
		[o,  o,  o,  o,  PD, PD, o,  o,  o,  o,  PL, PL, o,  o,  o,  o],
		[o,  o,  o,  PD, PD, PD, PD, P,  P,  PL, PL, PL, PL, o,  o,  o],
		[o,  o,  PD, PD, W,  PD, P,  P,  P,  P,  PL, W,  PL, PL, o,  o],
		[o,  o,  o,  PD, PD, PD, PD, o,  o,  PL, PL, PL, PL, o,  o,  o],
		[o,  o,  o,  o,  PD, PD, o,  o,  o,  o,  PL, PL, o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


func _make_item_clone() -> ImageTexture:
	var D := Color(0.20, 0.20, 0.28)
	var DL := Color(0.35, 0.35, 0.45)
	var DD := Color(0.10, 0.10, 0.15)
	var G := Color(0.30, 1.0, 0.50)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  D,  D,  D,  D,  D,  D,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  D,  D,  DL, DL, D,  D,  D,  D,  o,  o,  o,  o],
		[o,  o,  o,  D,  D,  DL, DL, DL, D,  D,  D,  D,  D,  o,  o,  o],
		[o,  o,  o,  D,  D,  G,  D,  D,  D,  G,  D,  D,  D,  o,  o,  o],
		[o,  o,  o,  D,  D,  D,  D,  D,  D,  D,  D,  D,  D,  o,  o,  o],
		[o,  o,  o,  D,  D,  D,  DD, DD, DD, D,  D,  D,  D,  o,  o,  o],
		[o,  o,  o,  o,  D,  D,  D,  D,  D,  D,  D,  D,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  D,  D,  D,  D,  D,  D,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  DD, D,  D,  DD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  DD, DD, D,  D,  DD, DD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  DD, DD, o,  D,  D,  o,  DD, DD, o,  o,  o,  o],
		[o,  o,  o,  o,  DD, o,  o,  D,  D,  o,  o,  DD, o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  DD, DD, DD, DD, o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  DD, DD, o,  o,  DD, DD, o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	return _rows_to_tex(rows)


# ── Bomb sprite ──────────────────────────

func _gen_bomb() -> void:
	var K := Color(0.08, 0.08, 0.10)
	var G := Color(0.25, 0.25, 0.30)
	var O := Color(1.0, 0.55, 0.12)
	var Y := Color(1.0, 0.85, 0.20)
	var F := Color(0.50, 0.42, 0.35)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  o,  o,  o,  o,  Y,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  Y,  O,  Y,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  F,  F,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  F,  F,  F,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o],
		[o,  o,  o,  K,  K,  K,  G,  G,  K,  K,  K,  K,  K,  o,  o,  o],
		[o,  o,  o,  K,  K,  G,  G,  G,  K,  K,  K,  K,  K,  o,  o,  o],
		[o,  o,  o,  K,  K,  G,  G,  K,  K,  K,  K,  K,  K,  o,  o,  o],
		[o,  o,  o,  K,  K,  K,  K,  K,  K,  K,  K,  K,  K,  o,  o,  o],
		[o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  K,  K,  K,  K,  K,  K,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	_cache["bomb"] = _rows_to_tex(rows)


# ── Explosion sprite ─────────────────────

func _gen_explosion() -> void:
	var R := Color(1.0, 0.22, 0.08)
	var O := Color(1.0, 0.60, 0.10)
	var Y := Color(1.0, 0.92, 0.25)
	var W := Color(1.0, 1.0, 0.85)
	var o := T
	var rows: Array = [
		[o,  o,  o,  R,  o,  o,  o,  o,  o,  R,  o,  o,  R,  o,  o,  o],
		[o,  o,  R,  R,  o,  o,  R,  o,  R,  R,  o,  R,  R,  o,  o,  o],
		[o,  o,  R,  O,  R,  R,  R,  R,  R,  O,  R,  R,  o,  o,  o,  o],
		[o,  R,  O,  O,  O,  R,  O,  O,  R,  O,  O,  O,  R,  o,  o,  o],
		[o,  o,  R,  O,  O,  O,  O,  O,  O,  O,  O,  R,  o,  o,  o,  o],
		[o,  o,  R,  O,  O,  Y,  Y,  Y,  Y,  O,  O,  R,  o,  o,  o,  o],
		[o,  R,  O,  O,  Y,  Y,  W,  W,  Y,  Y,  O,  O,  R,  o,  o,  o],
		[o,  R,  O,  O,  Y,  W,  W,  W,  W,  Y,  O,  O,  R,  o,  o,  o],
		[o,  R,  O,  O,  Y,  W,  W,  W,  W,  Y,  O,  O,  R,  o,  o,  o],
		[o,  R,  O,  O,  Y,  Y,  W,  W,  Y,  Y,  O,  O,  R,  o,  o,  o],
		[o,  o,  R,  O,  O,  Y,  Y,  Y,  Y,  O,  O,  R,  o,  o,  o,  o],
		[o,  o,  R,  O,  O,  O,  O,  O,  O,  O,  O,  R,  o,  o,  o,  o],
		[o,  R,  O,  O,  O,  R,  O,  O,  R,  O,  O,  O,  R,  o,  o,  o],
		[o,  o,  R,  R,  R,  o,  R,  R,  o,  R,  R,  R,  o,  o,  o,  o],
		[o,  o,  o,  R,  o,  o,  o,  o,  o,  o,  R,  o,  o,  o,  o,  o],
		[o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o],
	]
	_cache["explosion"] = _rows_to_tex(rows)


# ── Shield aura ──────────────────────────

func _gen_shield_aura() -> void:
	var C := Color(0.25, 0.85, 0.90, 0.45)
	var CL := Color(0.50, 0.95, 1.0, 0.30)
	var o := T
	var rows: Array = [
		[o,  o,  o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o,  o,  o],
		[o,  o,  o,  C,  CL, o,  o,  o,  o,  o,  o,  CL, C,  o,  o,  o],
		[o,  o,  C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C,  o,  o],
		[o,  C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C,  o],
		[C,  CL, o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  CL, C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C],
		[C,  CL, o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  CL, C],
		[o,  C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C,  o],
		[o,  o,  C,  o,  o,  o,  o,  o,  o,  o,  o,  o,  o,  C,  o,  o],
		[o,  o,  o,  C,  CL, o,  o,  o,  o,  o,  o,  CL, C,  o,  o,  o],
		[o,  o,  o,  o,  C,  C,  C,  C,  C,  C,  C,  C,  o,  o,  o,  o],
	]
	_cache["shield_aura"] = _rows_to_tex(rows)


# ── Drawing helpers ──────────────────────


func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < SZ and y >= 0 and y < SZ:
		img.set_pixel(x, y, col)


func _fill_r(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	for yy in range(maxi(ry, 0), mini(ry + rh, SZ)):
		for xx in range(maxi(rx, 0), mini(rx + rw, SZ)):
			img.set_pixel(xx, yy, col)


# ── Terrain tiles (universal) ────────────


func _gen_terrain_tiles() -> void:
	_cache["tile_water"] = _make_tile_water()
	_cache["tile_grass"] = _make_tile_grass()
	_cache["tile_snow"] = _make_tile_snow()
	_cache["tile_sand"] = _make_tile_sand()
	_cache["tile_lava"] = _make_tile_lava()
	_cache["tile_ice"] = _make_tile_ice()
	_cache["tile_mud"] = _make_tile_mud()
	_cache["tile_bridge"] = _make_tile_bridge()
	_cache["tile_timed_wall"] = _make_tile_timed_wall()
	_cache["tile_tall_grass"] = _make_tile_tall_grass()
	_cache["tile_gate_n"] = _make_tile_gate(0, -1)
	_cache["tile_gate_e"] = _make_tile_gate(1, 0)
	_cache["tile_gate_s"] = _make_tile_gate(0, 1)
	_cache["tile_gate_w"] = _make_tile_gate(-1, 0)


func _make_tile_water() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var deep := Color(0.08, 0.38, 0.78)
	var mid := Color(0.22, 0.55, 0.95)
	for y in range(SZ):
		for x in range(SZ):
			var g := float(y) / 15.0 * 0.4
			var w := sin(float(x) * 0.7 + float(y) * 0.3) * 0.12
			img.set_pixel(x, y, deep.lerp(mid, clampf(g + w, 0.0, 1.0)))
	var wave_c := Color(0.48, 0.75, 1.0)
	for wi in range(3):
		var by: int = 2 + wi * 5
		for x in range(SZ):
			var py: int = by + int(sin(float(x) * 0.8 + float(wi) * 2.2) * 1.5)
			_px(img, x, clampi(py, 0, SZ - 1), wave_c)
			_px(img, x, clampi(py + 1, 0, SZ - 1), mid.lerp(wave_c, 0.35))
	var foam := Color(0.90, 0.97, 1.0)
	for s in [[3, 1], [10, 4], [1, 8], [14, 6], [7, 12], [12, 14]]:
		_px(img, s[0], s[1], foam)
	return ImageTexture.create_from_image(img)


func _make_tile_grass() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.30, 0.65, 0.22)
	var dark := Color(0.22, 0.52, 0.16)
	var light := Color(0.42, 0.78, 0.30)
	var tip := Color(0.52, 0.88, 0.38)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 1.2 + float(y) * 0.8) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(base, v))
	var blades: Array = [[1, 15], [4, 15], [7, 15], [10, 15], [13, 15], [3, 9], [9, 10], [14, 8]]
	for b in blades:
		var bx: int = b[0]
		var by: int = b[1]
		for j in range(5):
			var jc: Color = dark if j < 1 else (base if j < 3 else (light if j < 4 else tip))
			_px(img, bx, by - j, jc)
		_px(img, bx + 1, by - 3, light)
	_px(img, 6, 4, Color(1.0, 0.92, 0.22))
	_px(img, 7, 4, Color(1.0, 0.92, 0.22))
	_px(img, 12, 2, Color(1.0, 0.50, 0.62))
	_px(img, 2, 6, Color(0.98, 0.98, 1.0))
	return ImageTexture.create_from_image(img)


func _make_tile_snow() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.92, 0.95, 0.99)
	var shadow := Color(0.78, 0.85, 0.95)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.5 + float(y) * 0.3) * 0.5 + 0.5
			img.set_pixel(x, y, shadow.lerp(base, v * 0.6 + 0.4))
	var sparkle := Color(1.0, 1.0, 1.0)
	for s in [[3, 2], [10, 5], [6, 9], [14, 3], [1, 12], [8, 14], [13, 11]]:
		_px(img, s[0], s[1], sparkle)
	for x in range(SZ):
		if x % 3 == 0:
			_px(img, x, SZ - 1, shadow)
			_px(img, x, SZ - 2, shadow.lerp(base, 0.5))
	return ImageTexture.create_from_image(img)


func _make_tile_sand() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.94, 0.82, 0.55)
	var light := Color(1.0, 0.90, 0.65)
	var dark := Color(0.84, 0.72, 0.45)
	for y in range(SZ):
		for x in range(SZ):
			var ripple := sin(float(x) * 0.4 + float(y) * 0.9) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(light, ripple))
	for wi in range(4):
		var ry: int = 2 + wi * 4
		for x in range(SZ):
			var py: int = ry + int(sin(float(x) * 0.5 + float(wi) * 1.8) * 0.8)
			_px(img, x, clampi(py, 0, SZ - 1), light)
	var pebble := Color(0.72, 0.62, 0.42)
	for s in [[4, 5], [11, 3], [7, 10], [14, 12], [2, 13]]:
		_px(img, s[0], s[1], pebble)
	return ImageTexture.create_from_image(img)


func _make_tile_lava() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var crust := Color(0.38, 0.12, 0.06)
	var hot := Color(1.0, 0.58, 0.10)
	var bright := Color(1.0, 0.88, 0.25)
	var glow := Color(0.92, 0.32, 0.06)
	img.fill(crust)
	for ci in range(4):
		var cx: int = 2 + ci * 4
		for y in range(SZ):
			var ox: int = cx + int(sin(float(y) * 0.6 + float(ci) * 1.5) * 1.8)
			_px(img, ox, y, glow)
			_px(img, ox + 1, y, hot)
	for ci in range(3):
		var cy: int = 3 + ci * 5
		for x in range(SZ):
			var oy: int = cy + int(sin(float(x) * 0.5 + float(ci) * 2.0) * 1.5)
			_px(img, x, oy, glow)
			_px(img, x, oy + 1, hot)
	for s in [[4, 4], [10, 7], [7, 12], [13, 3], [2, 10]]:
		_px(img, s[0], s[1], bright)
		_px(img, s[0] + 1, s[1], bright)
	return ImageTexture.create_from_image(img)


func _make_tile_ice() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.70, 0.88, 1.0)
	var deep := Color(0.52, 0.75, 0.95)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.4 + float(y) * 0.6) * 0.5 + 0.5
			img.set_pixel(x, y, deep.lerp(base, v))
	var shine := Color(0.95, 0.98, 1.0)
	for i in range(SZ):
		_px(img, i, i, shine)
		_px(img, SZ - 1 - i, i, shine)
	for s in [[3, 5], [4, 5], [10, 10], [11, 10], [7, 3], [8, 12]]:
		_px(img, s[0], s[1], Color(1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


func _make_tile_mud() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.45, 0.34, 0.22)
	var dark := Color(0.32, 0.24, 0.15)
	var wet := Color(0.50, 0.40, 0.30)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.9 + float(y) * 0.6) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(base, v))
	var puddle := Color(0.38, 0.30, 0.20)
	for s in [[3, 4], [4, 4], [4, 5], [10, 8], [11, 8], [11, 9], [7, 13], [8, 13]]:
		_px(img, s[0], s[1], puddle)
	for s in [[5, 3], [12, 7], [2, 11], [14, 2]]:
		_px(img, s[0], s[1], wet)
	return ImageTexture.create_from_image(img)


func _make_tile_bridge() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var water_d := Color(0.08, 0.38, 0.78)
	var water_m := Color(0.22, 0.55, 0.95)
	for y in range(SZ):
		for x in range(SZ):
			var g := float(y) / 15.0 * 0.4
			img.set_pixel(x, y, water_d.lerp(water_m, clampf(g, 0.0, 1.0)))
	var wood := Color(0.70, 0.52, 0.28)
	var wood_d := Color(0.55, 0.38, 0.18)
	var plank := Color(0.78, 0.60, 0.32)
	_fill_r(img, 2, 2, 12, 12, wood)
	for i in range(SZ):
		_px(img, 2, i, wood_d)
		_px(img, 13, i, wood_d)
	for py in [4, 7, 10]:
		for x in range(3, 13):
			_px(img, x, py, wood_d)
	for py in [3, 6, 9]:
		for x in range(3, 13):
			_px(img, x, py, plank)
	var nail := Color(0.42, 0.42, 0.48)
	for s in [[3, 3], [12, 3], [3, 9], [12, 9]]:
		_px(img, s[0], s[1], nail)
	return ImageTexture.create_from_image(img)


func _make_tile_timed_wall() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.50, 0.50, 0.58)
	var edge := Color(0.35, 0.35, 0.42)
	var glow := Color(0.85, 0.72, 0.20)
	img.fill(base)
	for i in range(SZ):
		_px(img, i, 0, edge)
		_px(img, i, SZ - 1, edge)
		_px(img, 0, i, edge)
		_px(img, SZ - 1, i, edge)
	for d in range(SZ):
		_px(img, d, d, glow)
		_px(img, SZ - 1 - d, d, glow)
	for s in [[7, 7], [8, 7], [7, 8], [8, 8]]:
		_px(img, s[0], s[1], Color(1.0, 0.90, 0.30))
	return ImageTexture.create_from_image(img)


func _make_tile_tall_grass() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.25, 0.55, 0.18)
	var dark := Color(0.18, 0.42, 0.12)
	var tip := Color(0.40, 0.72, 0.28)
	var tip2 := Color(0.48, 0.80, 0.32)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 1.0 + float(y) * 0.6) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(base, v))
	var blades: Array = [[1, 15], [3, 15], [5, 15], [7, 15], [9, 15], [11, 15], [13, 15],
		[2, 12], [6, 11], [10, 12], [14, 11], [4, 10], [8, 9], [12, 10]]
	for b in blades:
		var bx: int = b[0]
		var by: int = b[1]
		for j in range(8):
			var jc: Color
			if j < 2: jc = dark
			elif j < 4: jc = base
			elif j < 6: jc = tip
			else: jc = tip2
			_px(img, bx, by - j, jc)
		_px(img, bx + 1, by - 5, tip)
		_px(img, bx - 1, by - 6, tip2)
	return ImageTexture.create_from_image(img)


func _make_tile_gate(dx: int, dy: int) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var bg := Color(0.32, 0.32, 0.38)
	var frame := Color(0.62, 0.52, 0.28)
	var arrow := Color(0.95, 0.82, 0.18)
	img.fill(bg)
	for i in range(SZ):
		_px(img, i, 0, frame)
		_px(img, i, SZ - 1, frame)
		_px(img, 0, i, frame)
		_px(img, SZ - 1, i, frame)
	_px(img, 1, 0, frame); _px(img, 0, 1, frame)
	var cx := SZ / 2
	var cy := SZ / 2
	if dx == 1:
		for i in range(-3, 4):
			_px(img, cx, cy + i, arrow)
		for i in range(4):
			_px(img, cx + 1 + i, cy - i, arrow)
			_px(img, cx + 1 + i, cy + i, arrow)
	elif dx == -1:
		for i in range(-3, 4):
			_px(img, cx, cy + i, arrow)
		for i in range(4):
			_px(img, cx - 1 - i, cy - i, arrow)
			_px(img, cx - 1 - i, cy + i, arrow)
	elif dy == -1:
		for i in range(-3, 4):
			_px(img, cx + i, cy, arrow)
		for i in range(4):
			_px(img, cx - i, cy - 1 - i, arrow)
			_px(img, cx + i, cy - 1 - i, arrow)
	elif dy == 1:
		for i in range(-3, 4):
			_px(img, cx + i, cy, arrow)
		for i in range(4):
			_px(img, cx - i, cy + 1 + i, arrow)
			_px(img, cx + i, cy + 1 + i, arrow)
	return ImageTexture.create_from_image(img)


# ── Per-theme tiles ─────────────────────


func _gen_theme_tiles() -> void:
	_gen_classic_theme()
	_gen_grassland_theme()
	_gen_tundra_theme()
	_gen_desert_theme()
	_gen_volcano_theme()


func _gen_classic_theme() -> void:
	_cache["wall_classic"] = _make_brick_wall(
		Color(0.50, 0.55, 0.65), Color(0.30, 0.32, 0.40))
	_cache["crate_classic"] = _make_wood_crate(Color(0.85, 0.60, 0.32))
	_cache["ground_classic"] = _make_floor_tile(
		Color(0.28, 0.30, 0.38), Color(0.35, 0.37, 0.45))
	_cache["iron_classic"] = _make_iron_plate(
		Color(0.60, 0.64, 0.72), Color(0.40, 0.42, 0.50))
	_cache["shrink_classic"] = _make_shrink_wall()


func _gen_grassland_theme() -> void:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_bricks(img, Color(0.55, 0.62, 0.52), Color(0.35, 0.38, 0.32))
	for s in [[2, 2], [3, 2], [2, 3], [10, 10], [11, 10], [10, 11], [6, 5], [13, 3]]:
		_px(img, s[0], s[1], Color(0.38, 0.75, 0.30))
	for s in [[3, 3], [11, 11], [7, 5]]:
		_px(img, s[0], s[1], Color(0.45, 0.82, 0.35))
	_cache["wall_grassland"] = ImageTexture.create_from_image(img)
	_cache["crate_grassland"] = _make_vine_crate()
	_cache["ground_grassland"] = _make_grass_floor()
	_cache["iron_grassland"] = _make_iron_plate(
		Color(0.52, 0.58, 0.50), Color(0.38, 0.45, 0.35))
	_cache["shrink_grassland"] = _make_shrink_wall()


func _make_vine_crate() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_wood_planks(img, Color(0.75, 0.58, 0.35))
	var vine := Color(0.32, 0.72, 0.25)
	for v in [[1, 2], [1, 3], [2, 4], [2, 5], [3, 6], [3, 7], [2, 8]]:
		_px(img, v[0], v[1], vine)
	_px(img, 2, 3, Color(0.28, 0.60, 0.20))
	_px(img, 1, 4, Color(0.35, 0.78, 0.28))
	return ImageTexture.create_from_image(img)


func _make_grass_floor() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.35, 0.65, 0.25)
	var light := Color(0.45, 0.78, 0.32)
	var dark := Color(0.26, 0.52, 0.18)
	var dirt := Color(0.58, 0.45, 0.30)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.8 + float(y) * 0.5) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(light, v * 0.6 + 0.2))
	for s in [[7, 7], [8, 7], [7, 8], [8, 8], [9, 8]]:
		_px(img, s[0], s[1], dirt)
	return ImageTexture.create_from_image(img)


func _gen_tundra_theme() -> void:
	_cache["wall_tundra"] = _make_ice_crystal_wall()
	_cache["crate_tundra"] = _make_snow_crate()
	_cache["ground_tundra"] = _make_snow_floor()
	_cache["iron_tundra"] = _make_iron_plate(
		Color(0.65, 0.72, 0.82), Color(0.48, 0.52, 0.62))
	_cache["shrink_tundra"] = _make_shrink_wall()


func _make_ice_crystal_wall() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.58, 0.75, 0.95)
	var crystal := Color(0.80, 0.92, 1.0)
	var deep := Color(0.40, 0.58, 0.80)
	img.fill(base)
	for i in range(SZ):
		_px(img, 8 + i, i, crystal)
		_px(img, 7 - i, i, crystal)
		_px(img, 8 + i, SZ - 1 - i, crystal)
		_px(img, 7 - i, SZ - 1 - i, crystal)
	for s in [[4, 4], [11, 4], [4, 11], [11, 11], [8, 8]]:
		_px(img, s[0], s[1], Color(1.0, 1.0, 1.0))
	for i in range(SZ):
		_px(img, i, 0, deep)
		_px(img, i, SZ - 1, deep)
		_px(img, 0, i, deep)
		_px(img, SZ - 1, i, deep)
	return ImageTexture.create_from_image(img)


func _make_snow_crate() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_wood_planks(img, Color(0.58, 0.50, 0.42))
	var snow := Color(0.94, 0.96, 1.0)
	var snow_s := Color(0.80, 0.86, 0.94)
	_fill_r(img, 1, 1, 14, 4, snow)
	for x in range(1, 15):
		_px(img, x, 5, snow_s)
	_px(img, 3, 5, snow)
	_px(img, 3, 6, snow_s)
	_px(img, 10, 5, snow)
	_px(img, 10, 6, snow_s)
	return ImageTexture.create_from_image(img)


func _make_snow_floor() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var shadow := Color(0.78, 0.85, 0.95)
	var bright := Color(0.96, 0.98, 1.0)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.6 + float(y) * 0.4) * 0.5 + 0.5
			img.set_pixel(x, y, shadow.lerp(bright, v * 0.5 + 0.3))
	for s in [[5, 3], [12, 7], [3, 11], [9, 2], [14, 13]]:
		_px(img, s[0], s[1], Color(1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


func _gen_desert_theme() -> void:
	_cache["wall_desert"] = _make_sandstone_wall()
	_cache["crate_desert"] = _make_clay_crate()
	_cache["ground_desert"] = _make_sand_floor()
	_cache["iron_desert"] = _make_iron_plate(
		Color(0.65, 0.55, 0.40), Color(0.50, 0.40, 0.30))
	_cache["shrink_desert"] = _make_shrink_wall()


func _make_sandstone_wall() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_bricks(img, Color(0.85, 0.72, 0.48), Color(0.68, 0.55, 0.35))
	var mark := Color(0.75, 0.62, 0.38)
	_px(img, 3, 3, mark)
	_px(img, 4, 2, mark)
	_px(img, 5, 3, mark)
	_px(img, 10, 10, mark)
	_px(img, 11, 9, mark)
	_px(img, 12, 10, mark)
	return ImageTexture.create_from_image(img)


func _make_clay_crate() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var clay := Color(0.82, 0.58, 0.35)
	var dark := Color(0.62, 0.42, 0.25)
	var light := Color(0.92, 0.70, 0.45)
	img.fill(clay)
	for i in range(SZ):
		_px(img, i, 0, dark)
		_px(img, i, SZ - 1, dark)
		_px(img, 0, i, dark)
		_px(img, SZ - 1, i, dark)
	for x in range(1, SZ - 1):
		_px(img, x, 5, dark)
		_px(img, x, 10, dark)
	_px(img, 7, 7, dark)
	_px(img, 8, 7, dark)
	_px(img, 8, 8, dark)
	_px(img, 3, 3, light)
	_px(img, 4, 3, light)
	return ImageTexture.create_from_image(img)


func _make_sand_floor() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var light := Color(0.98, 0.88, 0.62)
	var dark := Color(0.82, 0.70, 0.45)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.5 + float(y) * 0.8) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(light, v * 0.5 + 0.25))
	return ImageTexture.create_from_image(img)


func _gen_volcano_theme() -> void:
	_cache["wall_volcano"] = _make_obsidian_wall()
	_cache["crate_volcano"] = _make_charred_crate()
	_cache["ground_volcano"] = _make_basalt_floor()
	_cache["iron_volcano"] = _make_iron_plate(
		Color(0.48, 0.40, 0.38), Color(0.32, 0.25, 0.22))
	_cache["shrink_volcano"] = _make_shrink_wall()


func _make_obsidian_wall() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var obsidian := Color(0.18, 0.14, 0.16)
	var edge := Color(0.10, 0.08, 0.10)
	img.fill(obsidian)
	for i in range(SZ):
		_px(img, i, 0, edge)
		_px(img, i, SZ - 1, edge)
		_px(img, 0, i, edge)
		_px(img, SZ - 1, i, edge)
	var magma := Color(1.0, 0.48, 0.10)
	var glow := Color(0.88, 0.30, 0.06)
	for v in [[3, 2], [4, 3], [5, 4], [5, 5], [6, 6], [7, 7]]:
		_px(img, v[0], v[1], magma)
	for v in [[11, 9], [10, 10], [9, 11], [9, 12], [8, 13]]:
		_px(img, v[0], v[1], magma)
	for v in [[4, 2], [6, 5], [10, 9], [8, 12]]:
		_px(img, v[0], v[1], glow)
	return ImageTexture.create_from_image(img)


func _make_charred_crate() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_wood_planks(img, Color(0.30, 0.20, 0.14))
	var ember := Color(1.0, 0.52, 0.12)
	var ember2 := Color(0.92, 0.38, 0.10)
	for s in [[3, 4], [10, 6], [5, 11], [12, 13]]:
		_px(img, s[0], s[1], ember)
	for s in [[4, 5], [11, 7]]:
		_px(img, s[0], s[1], ember2)
	return ImageTexture.create_from_image(img)


func _make_basalt_floor() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.25, 0.20, 0.18)
	var dark := Color(0.17, 0.13, 0.12)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 1.0 + float(y) * 0.7) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(base, v))
	var ember := Color(1.0, 0.48, 0.10)
	for s in [[5, 3], [11, 8], [3, 12], [14, 5]]:
		_px(img, s[0], s[1], ember)
	var crack := Color(0.32, 0.26, 0.22)
	for s in [[7, 4], [8, 5], [9, 6], [4, 10], [5, 11]]:
		_px(img, s[0], s[1], crack)
	return ImageTexture.create_from_image(img)


# ── Shared tile pattern helpers ──────────


func _draw_bricks(img: Image, stone: Color, mortar: Color) -> void:
	var light := stone.lightened(0.15)
	var dark := stone.darkened(0.18)
	img.fill(mortar)
	_fill_r(img, 0, 0, 7, 7, stone)
	_fill_r(img, 8, 0, 7, 7, stone)
	_fill_r(img, 0, 8, 3, 7, stone)
	_fill_r(img, 4, 8, 7, 7, stone)
	_fill_r(img, 12, 8, 4, 7, stone)
	for x in range(7):
		_px(img, x, 0, light)
	for x in range(8, 15):
		_px(img, x, 0, light)
	for x in range(3):
		_px(img, x, 8, light)
	for x in range(4, 11):
		_px(img, x, 8, light)
	for x in range(12, 16):
		_px(img, x, 8, light)
	for x in range(7):
		_px(img, x, 6, dark)
	for x in range(8, 15):
		_px(img, x, 6, dark)
	for x in range(3):
		_px(img, x, 14, dark)
	for x in range(4, 11):
		_px(img, x, 14, dark)
	for x in range(12, 16):
		_px(img, x, 14, dark)


func _draw_wood_planks(img: Image, wood: Color) -> void:
	var light := wood.lightened(0.12)
	var dark := wood.darkened(0.22)
	var band := wood.darkened(0.35)
	img.fill(wood)
	for i in range(SZ):
		_px(img, i, 0, dark)
		_px(img, i, SZ - 1, dark)
		_px(img, 0, i, dark)
		_px(img, SZ - 1, i, dark)
	for x in range(1, SZ - 1):
		_px(img, x, 7, dark)
	for y in range(1, SZ - 1):
		_px(img, 7, y, dark)
	for d in range(SZ):
		_px(img, d, d, band)
		_px(img, SZ - 1 - d, d, band)
	_px(img, 3, 3, light)
	_px(img, 4, 3, light)
	_px(img, 10, 10, light)
	_px(img, 11, 10, light)


func _make_brick_wall(stone: Color, mortar: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_bricks(img, stone, mortar)
	return ImageTexture.create_from_image(img)


func _make_wood_crate(wood: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	_draw_wood_planks(img, wood)
	return ImageTexture.create_from_image(img)


func _make_floor_tile(base: Color, accent: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var dark := base.darkened(0.1)
	for y in range(SZ):
		for x in range(SZ):
			var v := sin(float(x) * 0.7 + float(y) * 0.5) * 0.5 + 0.5
			img.set_pixel(x, y, dark.lerp(base, v * 0.4 + 0.3))
	for s in [[4, 3], [11, 7], [7, 12], [2, 9], [14, 4]]:
		_px(img, s[0], s[1], accent)
	return ImageTexture.create_from_image(img)


func _make_iron_plate(metal: Color, rivet: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var light := metal.lightened(0.12)
	var dark := metal.darkened(0.2)
	img.fill(metal)
	for i in range(SZ):
		_px(img, i, 0, dark)
		_px(img, i, SZ - 1, dark)
		_px(img, 0, i, dark)
		_px(img, SZ - 1, i, dark)
		_px(img, i, 1, light)
	for x in range(2, SZ - 2):
		_px(img, x, SZ / 2, dark)
		_px(img, SZ / 2, x, dark)
	for s in [[3, 3], [12, 3], [3, 12], [12, 12]]:
		_px(img, s[0], s[1], rivet)
		_px(img, s[0] + 1, s[1], rivet)
	return ImageTexture.create_from_image(img)


func _make_shrink_wall() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.75, 0.14, 0.18)
	var dark := Color(0.52, 0.10, 0.12)
	var warn := Color(0.98, 0.28, 0.20)
	img.fill(base)
	for i in range(SZ):
		_px(img, i, 0, dark)
		_px(img, i, SZ - 1, dark)
		_px(img, 0, i, dark)
		_px(img, SZ - 1, i, dark)
	for d in range(SZ):
		_px(img, d, d, warn)
		_px(img, SZ - 1 - d, d, warn)
	return ImageTexture.create_from_image(img)


# ── Utility ──────────────────────────────

func _rows_to_tex(rows: Array) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	for y in range(SZ):
		var row: Array = rows[y]
		for x in range(SZ):
			var c: Color = row[x]
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


# ── Creature sprite ──────────────────────

func _gen_creature() -> void:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(T)
	var body := Color(0.85, 0.65, 0.30)
	var dark := Color(0.65, 0.48, 0.20)
	var belly := Color(0.95, 0.85, 0.60)
	var eye := Color(0.10, 0.10, 0.15)
	# Body (round slime shape)
	for y in range(5, 14):
		for x in range(3, 13):
			var dx := float(x) - 7.5
			var dy := float(y) - 9.5
			if dx * dx / 25.0 + dy * dy / 20.0 < 1.0:
				var c := body.lerp(dark, clampf(float(y - 5) / 9.0, 0.0, 1.0) * 0.5)
				if dy > 1.0 and absf(dx) < 3.5:
					c = belly
				_px(img, x, y, c)
	# Eyes
	_px(img, 6, 8, eye)
	_px(img, 9, 8, eye)
	_px(img, 6, 7, Color(1.0, 1.0, 1.0, 0.8))
	_px(img, 9, 7, Color(1.0, 1.0, 1.0, 0.8))
	# Mouth
	_px(img, 7, 10, dark)
	_px(img, 8, 10, dark)
	_cache["creature"] = ImageTexture.create_from_image(img)
