class_name MapDefs
extends RefCounted

## 地图定义（5 张预设 + JSON 自定义加载）

const COLS := 15
const ROWS := 11

const DEFAULT_SPAWNS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(13, 9),
	Vector2i(13, 9), Vector2i(1, 9), Vector2i(13, 1),
]


static func get_all_maps() -> Array:
	var maps := get_presets()
	maps.append_array(_load_json_maps())
	return maps


static func get_presets() -> Array:
	return [_classic(), _arena(), _maze(), _ice_mud(), _portal()]


static func _classic() -> Dictionary:
	return {
		"name": "经典",
		"template": [
			"###############",
			"#.............#",
			"#.#.#.#.#.#.#.#",
			"#..#.#.#.#.#..#",
			"#.#.#.#.#.#.#.#",
			"#..#.#.#.#.#..#",
			"#.#.#.#.#.#.#.#",
			"#..#.#.#.#.#..#",
			"#.#.#.#.#.#.#.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.52,
	}


static func _arena() -> Dictionary:
	return {
		"name": "竞技场（缩圈）",
		"template": [
			"###############",
			"#.............#",
			"#.##.......##.#",
			"#.............#",
			"#...##...##...#",
			"#.............#",
			"#...##...##...#",
			"#.............#",
			"#.##.......##.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.45,
		"shrink": true,
	}


static func _maze() -> Dictionary:
	return {
		"name": "迷宫",
		"template": [
			"###############",
			"#.....#.......#",
			"#.###.#.###.#.#",
			"#.#.....#...#.#",
			"#.#.###.#.###.#",
			"#...#.....#...#",
			"#.###.#.###.#.#",
			"#.#...#.....#.#",
			"#.#.###.#.###.#",
			"#.......#.....#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.40,
	}


static func _ice_mud() -> Dictionary:
	return {
		"name": "冰火地带",
		"template": [
			"###############",
			"#.............#",
			"#.#.#.#.#.#.#.#",
			"#..#~#.#%#.#..#",
			"#.#.#.#.#.#.#.#",
			"#.~~..#..%%...#",
			"#.#.#.#.#.#.#.#",
			"#..#%#.#~#.#..#",
			"#.#.#.#.#.#.#.#",
			"#.............#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.42,
	}


static func _portal() -> Dictionary:
	return {
		"name": "传送铁壁",
		"template": [
			"###############",
			"#T............#",
			"#.#I#.#.#I#.#.#",
			"#.#.....#...#.#",
			"#.#.###.#.###.#",
			"#...#..T..#...#",
			"#.###.T.###.#.#",
			"#.#...#.....#.#",
			"#.#I#.#.#I#.#.#",
			"#............T#",
			"###############",
		],
		"spawns": DEFAULT_SPAWNS.duplicate(),
		"crate_density": 0.38,
	}


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
