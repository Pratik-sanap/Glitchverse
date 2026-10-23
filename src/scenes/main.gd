## main.gd  —  Minimal entry scene script.
## Role C owns this file. Do NOT add logic here.
## This only exists so the project opens without errors.
extends Node2D

func _ready() -> void:
	print("Rift Runner — main scene loaded.")
	get_tree().change_scene_to_file.call_deferred("res://src/scenes/title_screen.tscn")
