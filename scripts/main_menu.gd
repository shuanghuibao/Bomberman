extends Control

var _map_option: OptionButton
var _all_maps: Array = []


func _ready() -> void:
	_all_maps = MapDefs.get_all_maps()

	_map_option = OptionButton.new()
	_map_option.custom_minimum_size = Vector2(200, 36)
	for m in _all_maps:
		var d: Dictionary = m
		_map_option.add_item(d["name"])
	if _map_option.item_count > 0:
		_map_option.selected = 0

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = "地图："
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	hbox.add_child(lbl)
	hbox.add_child(_map_option)

	var vbox: VBoxContainer = %BtnSolo.get_parent()
	var idx: int = %BtnSolo.get_index()
	vbox.add_child(hbox)
	vbox.move_child(hbox, idx)

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
	get_tree().root.add_child(instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instance


func _on_solo() -> void:
	_launch_game(true, 1)


func _on_local_play() -> void:
	_launch_game(false)


func _on_quit() -> void:
	get_tree().quit()
