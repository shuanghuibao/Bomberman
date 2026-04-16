class_name MapDefs
extends RefCounted

## 地图定义（5 张预设 + JSON 自定义加载）
##
## 设计原则：
## - 多路线：任意两点间至少 2 条通路，避免死胡同
## - 风险 / 收益：中心区域资源多但暴露，边缘安全但贫瘠
## - 掩体 + 视野：长走廊提供视野，墙柱提供掩体
## - 180° 旋转对称：双方起始条件等价

const COLS := 15
const ROWS := 11

const DEFAULT_SPAWNS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(13, 9),
	Vector2i(13, 1), Vector2i(1, 9), Vector2i(7, 5),
]


static func get_all_maps() -> Array:
	var maps := get_presets()
	maps.append_array(_load_json_maps())
	return maps


static func get_presets() -> Array:
	return [_classic(), _arena(), _maze(), _ice_mud(), _portal()]


# ── 1. 棋局 ────────────────────────────────
# 外圈标准柱阵，中心 5×3 钻石形开阔区。
# 长走廊 + 中央交火区，适合对称攻防。
static func _classic() -> Dictionary:
	return {
		"name": "棋局",
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
# 极度开阔，稀疏掩体。30s 后毒圈开始收缩，
# 迫使双方在中心交战。资源稀缺，每个道具都重要。
static func _arena() -> Dictionary:
	return {
		"name": "竞技场（缩圈）",
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
# 蜿蜒回廊，多条路径，180° 旋转对称。
# 左右各有纵向高速通道 (x=1, x=13)，
# 中央横向走廊 (y=5) 连通两翼。
# 适合伏击、绕后、控制交叉路口。
static func _maze() -> Dictionary:
	return {
		"name": "蛇形迷宫",
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
# 左翼冰面高速滑行道（~），右翼泥地减速区（%），
# 上下半区地形互换形成 180° 旋转公平性。
# 冰面可快速穿越但难以停下，泥地安全但缓慢。
static func _ice_mud() -> Dictionary:
	return {
		"name": "冰火试炼",
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
# 两对跨图传送门创造出其不意的包抄路线。
# 铁箱（I）封锁关键路口，需要两次爆炸才能打通。
# 传送门入口略偏僻，踏入即承诺——无法中途反悔。
static func _portal() -> Dictionary:
	return {
		"name": "虫洞迷阵",
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
	if not (tpl is Array):
		return {}
	var template: Array = tpl
	if template.size() != ROWS:
		push_warning("MapDefs: template needs %d rows in %s" % [ROWS, path])
		return {}
	for row in template:
		if not (row is String) or row.length() != COLS:
			push_warning("MapDefs: each row must be %d chars in %s" % [COLS, path])
			return {}
	var spawns: Array[Vector2i] = []
	var raw = d.get("spawns", [])
	if raw is Array:
		for s in raw:
			if s is Array and s.size() >= 2:
				spawns.append(Vector2i(int(s[0]), int(s[1])))
	while spawns.size() < 5:
		var idx := spawns.size()
		spawns.append(DEFAULT_SPAWNS[idx] if idx < DEFAULT_SPAWNS.size() else Vector2i(1, 1))
	return {
		"name": str(d["name"]),
		"template": template,
		"spawns": spawns,
		"crate_density": float(d.get("crate_density", 0.5)),
		"shrink": bool(d.get("shrink", false)),
	}
