## main.gd  —  Minimal entry scene script.
## Role C owns this file. Do NOT add logic here.
## This only exists so the project opens without errors.
extends Node2D

func _ready() -> void:
	print("Rift Runner — main scene loaded.")
	var gameplay_scene: PackedScene = load("res://src/scenes/gameplay.tscn")
	if gameplay_scene:
		add_child(gameplay_scene.instantiate())
