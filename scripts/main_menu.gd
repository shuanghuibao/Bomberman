extends Control

var _map_option: OptionButton
var _mode_option: OptionButton
var _diff_option: OptionButton
var _all_maps: Array = []


func _ready() -> void:
	_all_maps = MapDefs.get_all_maps()
	var cfg := ConfigFile.new()
	cfg.load("user://progress.cfg")

	_map_option = OptionButton.new()
	_map_option.custom_minimum_size = Vector2(280, 36)
	for i in range(_all_maps.size()):
		var d: Dictionary = _all_maps[i]
		var map_key := "map_%d" % i
		var stars := ""
		if cfg.get_value(map_key, "star_win", false):
			stars += "*"
		if cfg.get_value(map_key, "star_score", false):
			stars += "*"
		if cfg.get_value(map_key, "star_hard", false):
			stars += "*"
		var best: int = cfg.get_value(map_key, "best_score", 0)
		var suffix := ""
		if stars != "":
			suffix = " [%s]" % stars
		if best > 0:
			suffix += " (最高:%d)" % best
		_map_option.add_item(d["name"] + suffix)
	if _map_option.item_count > 0:
		_map_option.selected = 0

	_mode_option = OptionButton.new()
	_mode_option.custom_minimum_size = Vector2(200, 36)
	_mode_option.add_item("经典模式")
	_mode_option.add_item("趣味模式")
	_mode_option.selected = 0

	_diff_option = OptionButton.new()
	_diff_option.custom_minimum_size = Vector2(200, 36)
	_diff_option.add_item("简单")
	_diff_option.add_item("中等")
	_diff_option.add_item("困难")
	_diff_option.selected = 0

	var map_hbox := HBoxContainer.new()
	map_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	map_hbox.add_theme_constant_override("separation", 10)
	var map_lbl := Label.new()
	map_lbl.text = "地图："
	map_lbl.add_theme_font_size_override("font_size", 16)
	map_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	map_hbox.add_child(map_lbl)
	map_hbox.add_child(_map_option)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", 10)
	var mode_lbl := Label.new()
	mode_lbl.text = "模式："
	mode_lbl.add_theme_font_size_override("font_size", 16)
	mode_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	mode_hbox.add_child(mode_lbl)
	mode_hbox.add_child(_mode_option)

	var diff_hbox := HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 10)
	var diff_lbl := Label.new()
	diff_lbl.text = "难度："
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	diff_hbox.add_child(diff_lbl)
	diff_hbox.add_child(_diff_option)

	var vbox: VBoxContainer = %BtnSolo.get_parent()
	var idx: int = %BtnSolo.get_index()
	vbox.add_child(diff_hbox)
	vbox.move_child(diff_hbox, idx)
	vbox.add_child(mode_hbox)
	vbox.move_child(mode_hbox, idx)
	vbox.add_child(map_hbox)
	vbox.move_child(map_hbox, idx)

	%BtnSolo.pressed.connect(_on_solo)
	%BtnLocal.pressed.connect(_on_local_play)
	%BtnQuit.pressed.connect(_on_quit)


func _launch_game(vs_npc: bool, npc_n: int = 1) -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	var instance: Node = scene.instantiate()
	instance.set_meta("vs_npc", vs_npc)
	if vs_npc:
		instance.set_meta("npc_count", npc_n)
	instance.set_meta("map_index", _map_option.selected if _map_option.selected >= 0 else 0)
	instance.set_meta("fun_mode", _mode_option.selected == 1)
	instance.set_meta("npc_difficulty", _diff_option.selected if _diff_option.selected >= 0 else 0)
	get_tree().root.add_child(instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instance


func _on_solo() -> void:
	_launch_game(true, 1)


func _on_local_play() -> void:
	_launch_game(false)


func _on_quit() -> void:
	get_tree().quit()
