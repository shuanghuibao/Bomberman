extends Control


func _ready() -> void:
	%BtnSolo.pressed.connect(_on_solo)
	%BtnLocal.pressed.connect(_on_local_play)
	%BtnQuit.pressed.connect(_on_quit)


func _on_solo() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	var instance: Node = scene.instantiate()
	instance.set_meta("vs_npc", true)
	instance.set_meta("npc_count", 1)
	get_tree().root.add_child(instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instance


func _on_local_play() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	var instance: Node = scene.instantiate()
	instance.set_meta("vs_npc", false)
	get_tree().root.add_child(instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instance


func _on_quit() -> void:
	get_tree().quit()
