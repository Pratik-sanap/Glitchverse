## shield_effect.gd — Dynamic procedural energy shield aura around Nova.
extends Node2D

var _timer: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta * 3.5
	queue_redraw()


func _draw() -> void:
	var pulse: float = sin(_timer) * 2.5
	var r: float = 30.0 + pulse
	# Outer glowing ring
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(0.1, 1.0, 0.6, 0.85), 2.5)
	# Secondary inner energy ring
	draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 24, Color(0.0, 0.85, 1.0, 0.5), 1.5)
	# Translucent energy bubble fill
	draw_circle(Vector2.ZERO, r, Color(0.1, 0.9, 0.7, 0.16 + sin(_timer) * 0.06))
