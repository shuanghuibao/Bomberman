extends Control


func _ready() -> void:
	%BtnLocal.pressed.connect(_on_local_play)
	%BtnQuit.pressed.connect(_on_quit)


func _on_local_play() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit() -> void:
	get_tree().quit()
