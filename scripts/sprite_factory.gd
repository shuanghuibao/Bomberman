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


# ── Terrain tiles (universal) ────────────

func _gen_terrain_tiles() -> void:
	_cache["tile_water"] = _make_tile_water()
	_cache["tile_grass"] = _make_tile_grass()
	_cache["tile_snow"] = _make_tile_snow()
	_cache["tile_sand"] = _make_tile_sand()
	_cache["tile_lava"] = _make_tile_lava()
	_cache["tile_ice"] = _make_tile_ice()
	_cache["tile_mud"] = _make_tile_mud()


func _make_tile_water() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.15, 0.35, 0.65)
	var light := Color(0.25, 0.50, 0.80)
	var dark := Color(0.10, 0.25, 0.50)
	for y in range(SZ):
		for x in range(SZ):
			var wave := sin((x + y) * 0.8) * 0.5 + 0.5
			img.set_pixel(x, y, base.lerp(light if wave > 0.6 else dark, 0.3))
	for x in range(SZ):
		var wy: int = (x * 3 + 4) % SZ
		if wy < SZ:
			img.set_pixel(x, wy, Color(0.40, 0.65, 0.90, 0.7))
	return ImageTexture.create_from_image(img)


func _make_tile_grass() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.22, 0.45, 0.18)
	img.fill(base)
	var blade := Color(0.30, 0.58, 0.22)
	var tip := Color(0.38, 0.68, 0.28)
	for i in range(6):
		var bx: int = (i * 5 + 2) % SZ
		var by: int = SZ - 1
		for j in range(4):
			if by - j >= 0 and bx < SZ:
				img.set_pixel(bx, by - j, blade if j < 3 else tip)
	return ImageTexture.create_from_image(img)


func _make_tile_snow() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.82, 0.88, 0.94)
	img.fill(base)
	var flake := Color(0.95, 0.97, 1.0)
	var shadow := Color(0.70, 0.76, 0.85)
	for i in range(5):
		var fx: int = (i * 7 + 3) % SZ
		var fy: int = (i * 5 + 1) % SZ
		if fx < SZ and fy < SZ:
			img.set_pixel(fx, fy, flake)
	for x in range(SZ):
		if x % 4 == 0:
			img.set_pixel(x, SZ - 1, shadow)
	return ImageTexture.create_from_image(img)


func _make_tile_sand() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.82, 0.72, 0.48)
	img.fill(base)
	var light := Color(0.88, 0.78, 0.55)
	var dark := Color(0.72, 0.62, 0.40)
	for y in range(SZ):
		for x in range(SZ):
			if (x + y * 3) % 7 == 0:
				img.set_pixel(x, y, light)
			elif (x * 2 + y) % 11 == 0:
				img.set_pixel(x, y, dark)
	return ImageTexture.create_from_image(img)


func _make_tile_lava() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.85, 0.25, 0.05)
	var hot := Color(1.0, 0.65, 0.10)
	var dark := Color(0.55, 0.12, 0.02)
	for y in range(SZ):
		for x in range(SZ):
			var t := sin(x * 0.6 + y * 0.4) * 0.5 + 0.5
			if t > 0.7:
				img.set_pixel(x, y, hot)
			elif t < 0.3:
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, base)
	return ImageTexture.create_from_image(img)


func _make_tile_ice() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.55, 0.72, 0.88)
	img.fill(base)
	var shine := Color(0.75, 0.88, 0.98)
	img.set_pixel(4, 5, shine)
	img.set_pixel(5, 5, shine)
	img.set_pixel(10, 10, shine)
	img.set_pixel(11, 10, shine)
	return ImageTexture.create_from_image(img)


func _make_tile_mud() -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var base := Color(0.30, 0.22, 0.14)
	img.fill(base)
	var dark := Color(0.22, 0.16, 0.10)
	for i in range(4):
		var mx: int = (i * 5 + 2) % SZ
		var my: int = (i * 4 + 3) % SZ
		if mx < SZ and my < SZ:
			img.set_pixel(mx, my, dark)
			if mx + 1 < SZ:
				img.set_pixel(mx + 1, my, dark)
	return ImageTexture.create_from_image(img)


# ── Per-theme tiles ─────────────────────

func _gen_theme_tiles() -> void:
	_gen_theme("classic", Color(0.22, 0.24, 0.30), Color(0.78, 0.52, 0.28),
		Color(0.12, 0.13, 0.16), Color(0.50, 0.52, 0.58))
	_gen_theme("grassland", Color(0.38, 0.50, 0.32), Color(0.60, 0.45, 0.25),
		Color(0.22, 0.35, 0.18), Color(0.45, 0.48, 0.42))
	_gen_theme("tundra", Color(0.55, 0.60, 0.68), Color(0.62, 0.68, 0.75),
		Color(0.78, 0.84, 0.90), Color(0.48, 0.52, 0.58))
	_gen_theme("desert", Color(0.58, 0.48, 0.32), Color(0.65, 0.55, 0.38),
		Color(0.82, 0.72, 0.48), Color(0.52, 0.45, 0.35))
	_gen_theme("volcano", Color(0.18, 0.14, 0.12), Color(0.38, 0.25, 0.18),
		Color(0.25, 0.18, 0.15), Color(0.35, 0.30, 0.28))


func _gen_theme(theme: String, wall_col: Color, crate_col: Color,
		ground_col: Color, iron_col: Color) -> void:
	_cache["wall_" + theme] = _make_solid_tile(wall_col, wall_col.darkened(0.2))
	_cache["crate_" + theme] = _make_crate_tile(crate_col)
	_cache["ground_" + theme] = _make_ground_tile(ground_col)
	_cache["iron_" + theme] = _make_iron_tile(iron_col)
	_cache["shrink_" + theme] = _make_solid_tile(Color(0.65, 0.12, 0.15), Color(0.50, 0.08, 0.10))


func _make_solid_tile(col: Color, shade: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for x in range(SZ):
		img.set_pixel(x, 0, shade)
		img.set_pixel(x, SZ - 1, shade)
	for y in range(SZ):
		img.set_pixel(0, y, shade)
		img.set_pixel(SZ - 1, y, shade)
	return ImageTexture.create_from_image(img)


func _make_crate_tile(col: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var light := col.lightened(0.15)
	var dark := col.darkened(0.25)
	img.fill(col)
	for i in range(SZ):
		img.set_pixel(i, 0, dark)
		img.set_pixel(i, SZ - 1, dark)
		img.set_pixel(0, i, dark)
		img.set_pixel(SZ - 1, i, dark)
	for i in range(2, SZ - 2):
		img.set_pixel(i, SZ / 2, dark)
		img.set_pixel(SZ / 2, i, dark)
	img.set_pixel(3, 3, light)
	img.set_pixel(4, 3, light)
	img.set_pixel(3, 4, light)
	return ImageTexture.create_from_image(img)


func _make_ground_tile(col: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(col)
	var accent := col.lightened(0.08)
	for i in range(3):
		var gx: int = (i * 7 + 2) % SZ
		var gy: int = (i * 5 + 4) % SZ
		if gx < SZ and gy < SZ:
			img.set_pixel(gx, gy, accent)
	return ImageTexture.create_from_image(img)


func _make_iron_tile(col: Color) -> ImageTexture:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	var dark := col.darkened(0.2)
	var rivet := Color(0.35, 0.35, 0.40)
	img.fill(col)
	for i in range(SZ):
		img.set_pixel(i, 0, dark)
		img.set_pixel(i, SZ - 1, dark)
		img.set_pixel(0, i, dark)
		img.set_pixel(SZ - 1, i, dark)
	for x in range(2, SZ - 2):
		img.set_pixel(x, SZ / 2, dark)
		img.set_pixel(SZ / 2, x, dark)
	img.set_pixel(3, 3, rivet)
	img.set_pixel(12, 3, rivet)
	img.set_pixel(3, 12, rivet)
	img.set_pixel(12, 12, rivet)
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
