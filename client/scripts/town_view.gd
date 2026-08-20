class_name TownView
extends Control

const TILE := 32.0
const MOVE_SPEED := 150.0

var resident_name := "居民"
var appearance_seed := 1
var resident_position := Vector2(288, 128)
var move_target := resident_position


func _ready() -> void:
	custom_minimum_size = Vector2(576, 224)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func configure(display_name: String, seed: int) -> void:
	resident_name = display_name
	appearance_seed = seed
	queue_redraw()


func _process(delta: float) -> void:
	if resident_position.distance_to(move_target) > 1.0:
		resident_position = resident_position.move_toward(move_target, MOVE_SPEED * delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var should_move := false
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
		should_move = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
		should_move = true
	if should_move:
		move_target = Vector2(
			clampf(snappedf(point.x, 2.0), 16.0, size.x - 16.0),
			clampf(snappedf(point.y, 2.0), 32.0, size.y - 12.0)
		)
		accept_event()


func _draw() -> void:
	# Code-drawn placeholder art keeps the first playable slice license-safe.
	draw_rect(Rect2(Vector2.ZERO, size), Color("86b96b"))
	_draw_checker_grass()
	_draw_road()
	_draw_pond()
	_draw_building(Vector2(32, 28), Color("e59b59"), Color("69464b"))
	_draw_building(Vector2(size.x - 144, 28), Color("77a8c9"), Color("344e68"))
	_draw_tree(Vector2(176, 52))
	_draw_tree(Vector2(size.x - 190, 170))
	_draw_tree(Vector2(62, 180))
	_draw_resident(resident_position)


func _draw_checker_grass() -> void:
	var columns := int(ceil(size.x / TILE))
	var rows := int(ceil(size.y / TILE))
	for y in range(rows):
		for x in range(columns):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("80b164"))


func _draw_road() -> void:
	draw_rect(Rect2(0, 112, size.x, 64), Color("d7bd82"))
	draw_rect(Rect2(size.x * 0.45, 0, 64, size.y), Color("d7bd82"))
	for x in range(0, int(size.x), 32):
		draw_rect(Rect2(x + 4, 140, 16, 4), Color("ead49c"))


func _draw_pond() -> void:
	var pond := Rect2(size.x - 112, size.y - 72, 96, 56)
	draw_rect(pond, Color("4a7fa1"))
	draw_rect(Rect2(pond.position + Vector2(8, 10), Vector2(46, 4)), Color("76b5c5"))
	draw_rect(Rect2(pond.position + Vector2(56, 34), Vector2(26, 4)), Color("76b5c5"))


func _draw_building(origin: Vector2, wall: Color, roof: Color) -> void:
	draw_rect(Rect2(origin + Vector2(8, 24), Vector2(104, 68)), wall)
	draw_rect(Rect2(origin, Vector2(120, 28)), roof)
	draw_rect(Rect2(origin + Vector2(16, 52), Vector2(24, 24)), Color("f4d58d"))
	draw_rect(Rect2(origin + Vector2(72, 52), Vector2(24, 40)), Color("553f46"))


func _draw_tree(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(12, 22), Vector2(8, 22)), Color("795548"))
	draw_rect(Rect2(origin, Vector2(32, 26)), Color("2f7d4a"))
	draw_rect(Rect2(origin + Vector2(6, -6), Vector2(20, 14)), Color("4e9b58"))


func _draw_resident(center: Vector2) -> void:
	var palette := [Color("f472b6"), Color("60a5fa"), Color("fbbf24"), Color("a78bfa")]
	var outfit: Color = palette[abs(appearance_seed) % palette.size()]
	var p := center.floor()
	draw_rect(Rect2(p + Vector2(-8, 10), Vector2(16, 4)), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(p + Vector2(-6, -12), Vector2(12, 10)), Color("f1c7a5"))
	draw_rect(Rect2(p + Vector2(-7, -14), Vector2(14, 4)), Color("243447"))
	draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 14)), outfit)
	draw_rect(Rect2(p + Vector2(-6, 12), Vector2(5, 6)), Color("25324a"))
	draw_rect(Rect2(p + Vector2(2, 12), Vector2(5, 6)), Color("25324a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-24, -20), resident_name, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("fff7df"))
