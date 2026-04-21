class_name MapDefs
extends RefCounted

## 地图定义（9 张预设 + JSON 自定义加载）
##
## 设计原则：
## - 多路线：任意两点间至少 2 条通路，避免死胡同
## - 风险 / 收益：中心区域资源多但暴露，边缘安全但贫瘠
## - 掩体 + 视野：长走廊提供视野，墙柱提供掩体
## - 180° 旋转对称：双方起始条件等价

const DEFAULT_SPAWNS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(13, 9),
	Vector2i(13, 1), Vector2i(1, 9), Vector2i(7, 5),
]


static func _spawns_for(c: int, r: int) -> Array[Vector2i]:
	return [
		Vector2i(1, 1),
		Vector2i(c - 2, r - 2),
		Vector2i(c - 2, 1),
		Vector2i(1, r - 2),
		Vector2i(c / 2, r / 2),
	]


static func get_all_maps() -> Array:
	var maps := get_presets()
	maps.append_array(_load_json_maps())
	return maps


static func get_presets() -> Array:
	return [_classic(), _arena(), _maze(), _ice_mud(), _portal(),
		_green_valley(), _frozen_tundra(), _desert_wasteland(), _volcanic_crater()]


# ── 1. 棋局 ────────────────────────────────
static func _classic() -> Dictionary:
	return {
		"name": "棋局",
		"theme": "classic",
		"template": [
			"###############",
			"#.............#",
			"#.#.#.#.#.#.#.#",
			"#.............#",
			"#.#.#.....#.#.#",
			"#.....#.#.....#",
			"#.#.#.....#.#.#",
			"#.............#",
			"#.#.#.#.#.#.#.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.50,
	}


# ── 2. 竞技场（缩圈）───────────────────────
static func _arena() -> Dictionary:
	return {
		"name": "竞技场（缩圈）",
		"theme": "classic",
		"template": [
			"###############",
			"#.............#",
			"#..#.......#..#",
			"#..#..#.#..#..#",
			"#.............#",
			"#.#...#.#...#.#",
			"#.............#",
			"#..#..#.#..#..#",
			"#..#.......#..#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.32,
		"shrink": true,
	}


# ── 3. 蛇形迷宫 ────────────────────────────
static func _maze() -> Dictionary:
	return {
		"name": "蛇形迷宫",
		"theme": "classic",
		"template": [
			"###############",
			"#.....#.......#",
			"#.###.#.#.###.#",
			"#.#...#.#...#.#",
			"#.#.###.###.#.#",
			"#.#...........#",
			"#.#.###.###.#.#",
			"#.#...#.#...#.#",
			"#.###.#.#.###.#",
			"#.......#.....#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.35,
	}


# ── 4. 冰火试炼 ────────────────────────────
static func _ice_mud() -> Dictionary:
	return {
		"name": "冰火试炼",
		"theme": "classic",
		"template": [
			"###############",
			"#.............#",
			"#.#.#.#.#.#.#.#",
			"#..#~~.#.%%#..#",
			"#.#.#~...%#.#.#",
			"#...~~...%%...#",
			"#.#.#%...~#.#.#",
			"#..#%%.#.~~#..#",
			"#.#.#.#.#.#.#.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.42,
	}


# ── 5. 虫洞迷阵 ────────────────────────────
static func _portal() -> Dictionary:
	return {
		"name": "虫洞迷阵",
		"theme": "classic",
		"template": [
			"###############",
			"#.............#",
			"#.#I#.#.#I#.T.#",
			"#T#.....#...#.#",
			"#.#.#.###.#.#.#",
			"#...#.....#...#",
			"#.#.#.###.#.#.#",
			"#.#...#.....#T#",
			"#.T.#I#.#.#I#.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.36,
	}


# ── 6. 洪泛三角洲 ──────────────────────────
# 21x15 草地主题：河流 + 4 座桥 + 高草伏击区 + 洪水事件 + 宝藏岛 + 单向门
static func _green_valley() -> Dictionary:
	return {
		"name": "洪泛三角洲",
		"cols": 21,
		"rows": 15,
		"theme": "grassland",
		"template": [
			"#####################",
			"#H.H.]..WWBWW..[H.H#",
			"#.#.#.#.#.W.#.#.#.#.#",
			"#G.T.H...GWBWG...H.G#",
			"#.#H#G#.#.W.#.#G#H#.#",
			"#G...H..(.W.)..H...G#",
			"#.#.#.#.#BWB#.#.#.#.#",
			"#H..G.H..G.G..H.G..H#",
			"#.#.#.#.#BWB#.#.#.#.#",
			"#G...H..(.W.)..H...G#",
			"#.#H#G#.#.W.#.#G#H#.#",
			"#G...H...GWBWG..T..G#",
			"#.#.#.#.#.W.#.#.#.#.#",
			"#H.H.]..WWBWW..[H.H#",
			"#####################",
		],
		"spawns": _spawns_for(21, 15),
		"crate_density": 0.42,
		"treasure_zones": [[9, 6, 11, 8]],
	}


# ── 7. 雪崩隘口 ────────────────────────────
# 23x17 雪地主题：时控冰墙交替走廊 + 雪崩 + 高草(雪堆) + 宝藏中心 + 环形单向门
static func _frozen_tundra() -> Dictionary:
	return {
		"name": "雪崩隘口",
		"cols": 23,
		"rows": 17,
		"theme": "tundra",
		"template": [
			"#######################",
			"#SS.SS.H.......H.SS.SS#",
			"#S#.#.#X#..#..#X#.#.#S#",
			"#S.T.SH.]~~.~~[.HS.T.S#",
			"#.#S#.#.#X...X#.#.#S#.#",
			"#S..(.S.~~.#.~~.S.)..S#",
			"#.#.#X#.~..#..~.#X#.#.#",
			"#S.....~..~~~..~.....S#",
			"#.#.#.#.~.....~.#.#.#.#",
			"#S.....~..~~~..~.....S#",
			"#.#.#X#.~..#..~.#X#.#.#",
			"#S..(.S.~~.#.~~.S.)..S#",
			"#.#S#.#.#X...X#.#.#S#.#",
			"#S.T.SH.]~~.~~[.HS.T.S#",
			"#S#.#.#X#..#..#X#.#.#S#",
			"#SS.SS.H.......H.SS.SS#",
			"#######################",
		],
		"spawns": _spawns_for(23, 17),
		"crate_density": 0.36,
		"treasure_zones": [[9, 7, 13, 9]],
	}


# ── 8. 沙暴竞技场 ──────────────────────────
# 25x17 沙漠主题：环形单向门走廊 + 沙暴推力 + 绿洲宝藏 + 桥 + 时控墙
static func _desert_wasteland() -> Dictionary:
	return {
		"name": "沙暴竞技场",
		"cols": 25,
		"rows": 17,
		"theme": "desert",
		"template": [
			"#########################",
			"#A..].#AA...#...AA#.[..A#",
			"#.#.#.#.#.#X#X#.#.#.#.#.#",
			"#A.AAA.#.(.A.A.).#.AAA.A#",
			"#.#AWWBA#.#.#.#.#ABWWA#.#",
			"#AI.AAA..]..>>..[.AAA.IA#",
			"#.#.#.#.#.#.#.v.#.#.#.#.#",
			"#A..C..#A....Av.#A..C..A#",
			"#.#I#.#.#..#.#..#.#.#I#.#",
			"#A..C..#A.^.A....#A..C.A#",
			"#.#.#.#.#.^.#.#.#.#.#.#.#",
			"#AI.AAA..]..<<..[.AAA.IA#",
			"#.#ABWWA#.#.#.#.#AWWB#.#",
			"#A.AAA.#.(.A.A.).#.AAA.A#",
			"#.#.#.#.#.#X#X#.#.#.#.#.#",
			"#A..].#AA...#...AA#.[..A#",
			"#########################",
		],
		"spawns": _spawns_for(25, 17),
		"crate_density": 0.38,
		"shrink": true,
		"treasure_zones": [[10, 3, 14, 5], [10, 11, 14, 13]],
	}


# ── 9. 火山口 ─────────────────────────────
# 27x19 火山主题：熔岩湖 + 桥 + 时控墙 + 岩浆扩散 + 高草外环 + 宝藏中心
static func _volcanic_crater() -> Dictionary:
	return {
		"name": "火山口",
		"cols": 27,
		"rows": 19,
		"theme": "volcano",
		"template": [
			"###########################",
			"#H.H..H..#..T..#..H..H.H.#",
			"#.#.#.#.#X#.#.#X#.#.#.#.#.#",
			"#H.T.H#..C.LBLB.C..#H.T.H#",
			"#.#H#.#.#.#LLLLL#.#.#.#H#.#",
			"#H..I.#.(.#LBLBL#.)..#.I.H#",
			"#.#.#.#.#X#LLLLL#X#.#.#.#.#",
			"#H......#.LBLBLBL.#......H#",
			"#.#.#.#.#.LLLLLLL.#.#.#.#.#",
			"#.......#.LLBTBLL.#.......#",
			"#.#.#.#.#.LLLLLLL.#.#.#.#.#",
			"#H......#.LBLBLBL.#......H#",
			"#.#.#.#.#X#LLLLL#X#.#.#.#.#",
			"#H..I.#.(.#LBLBL#.)..#.I.H#",
			"#.#H#.#.#.#LLLLL#.#.#.#H#.#",
			"#H.T.H#..C.LBLB.C..#H.T.H#",
			"#.#.#.#.#X#.#.#X#.#.#.#.#.#",
			"#H.H..H..#.....#..H..H.H.#",
			"###########################",
		],
		"spawns": [
			Vector2i(1, 1), Vector2i(25, 17),
			Vector2i(25, 1), Vector2i(1, 17), Vector2i(13, 1),
		],
		"crate_density": 0.32,
		"treasure_zones": [[11, 8, 15, 10]],
	}


# ── JSON 加载 ───────────────────────────────

static func _load_json_maps() -> Array:
	var maps: Array = []
	for dir_path in ["res://maps", "user://maps"]:
		maps.append_array(_scan_dir(dir_path))
	return maps


static func _scan_dir(dir_path: String) -> Array:
	var maps: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return maps
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var m := _parse_json_file(dir_path.path_join(fname))
			if not m.is_empty():
				maps.append(m)
		fname = dir.get_next()
	return maps


static func _parse_json_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("MapDefs: JSON parse error in %s" % path)
		return {}
	var data = json.data
	if not (data is Dictionary):
		return {}
	var d: Dictionary = data
	if not d.has("name") or not d.has("template"):
		return {}
	var tpl = d["template"]
	if not (tpl is Array) or tpl.is_empty():
		return {}
	var template: Array = tpl
	var map_rows: int = template.size()
	var first_row: String = template[0]
	var map_cols: int = first_row.length()
	if map_cols < 5 or map_rows < 5:
		push_warning("MapDefs: map too small in %s" % path)
		return {}
	for row in template:
		if not (row is String) or row.length() != map_cols:
			push_warning("MapDefs: inconsistent row widths in %s" % path)
			return {}
	var spawns: Array[Vector2i] = []
	var raw = d.get("spawns", [])
	if raw is Array:
		for s in raw:
			if s is Array and s.size() >= 2:
				spawns.append(Vector2i(int(s[0]), int(s[1])))
	var def_spawns := _spawns_for(map_cols, map_rows)
	while spawns.size() < 5:
		var idx := spawns.size()
		spawns.append(def_spawns[idx] if idx < def_spawns.size() else Vector2i(1, 1))
	var tz_raw = d.get("treasure_zones", [])
	var tz: Array = []
	if tz_raw is Array:
		for zone in tz_raw:
			if zone is Array and zone.size() >= 4:
				tz.append([int(zone[0]), int(zone[1]), int(zone[2]), int(zone[3])])
	return {
		"name": str(d["name"]),
		"cols": map_cols,
		"rows": map_rows,
		"template": template,
		"spawns": spawns,
		"crate_density": float(d.get("crate_density", 0.5)),
		"shrink": bool(d.get("shrink", false)),
		"theme": str(d.get("theme", "classic")),
		"treasure_zones": tz,
	}
