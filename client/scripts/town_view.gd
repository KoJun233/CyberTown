class_name TownView
extends Control

const TILE := 16.0
const SPEED := 150.0

var resident_name := "居民"
var appearance_seed := 1
var resident_position := Vector2(320, 190)
var move_target := resident_position


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	set_process(true)


func configure(display_name: String, seed: int) -> void:
	resident_name = display_name
	appearance_seed = seed
	queue_redraw()


func _process(delta: float) -> void:
	if resident_position.distance_to(move_target) > 1.0:
		resident_position = resident_position.move_toward(move_target, SPEED * delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var move := false
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
		move = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
		move = true
	if move:
		move_target = Vector2(
			clampf(snappedf(point.x, 2.0), 14.0, size.x - 14.0),
			clampf(snappedf(point.y, 2.0), 22.0, size.y - 14.0)
		)
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("78ae5d"))
	_draw_grass()
	_draw_river()
	_draw_paths()
	_draw_farm()
	_draw_building(Vector2(28, 34), Vector2(116, 76), Color("e8a35d"), Color("774b45"), "家")
	_draw_building(Vector2(size.x * 0.38, 24), Vector2(140, 88), Color("e6cf8a"), Color("6f5365"), "镇民中心")
	_draw_building(Vector2(size.x - 176, 46), Vector2(112, 72), Color("79a9c2"), Color("405b72"), "杂货店")
	_draw_square()
	_draw_pond()
	_draw_decorations()
	_draw_move_marker()
	_draw_resident(resident_position)


func _draw_grass() -> void:
	for y in range(int(ceil(size.y / TILE))):
		for x in range(int(ceil(size.x / TILE))):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("73a957"))
			if (x * 7 + y * 11) % 29 == 0:
				draw_rect(Rect2(x * TILE + 4, y * TILE + 6, 2, 5), Color("4e873f"))


func _draw_river() -> void:
	var river_x := size.x * 0.78
	draw_rect(Rect2(river_x, 0, 58, size.y), Color("3f82a0"))
	for y in range(8, int(size.y), 30):
		draw_rect(Rect2(river_x + 8, y, 20, 3), Color("72b2c2"))
		draw_rect(Rect2(river_x + 34, y + 14, 16, 3), Color("2d6f91"))


func _draw_paths() -> void:
	var road_y := size.y * 0.50
	var road_x := size.x * 0.48
	draw_rect(Rect2(0, road_y, size.x, 54), Color("d9bf83"))
	draw_rect(Rect2(road_x, 0, 58, size.y), Color("d9bf83"))
	for x in range(8, int(size.x), 32):
		draw_rect(Rect2(x, road_y + 12, 18, 3), Color("eed79f"))
		draw_rect(Rect2(x + 12, road_y + 36, 14, 3), Color("bfa56f"))
	var river_x := size.x * 0.78
	draw_rect(Rect2(river_x - 4, road_y - 3, 66, 60), Color("805a3c"))
	for x in range(int(river_x), int(river_x + 58), 9):
		draw_rect(Rect2(x, road_y, 7, 54), Color("c58b51"))


func _draw_farm() -> void:
	var origin := Vector2(26, size.y - 112)
	draw_rect(Rect2(origin, Vector2(178, 82)), Color("9a653f"))
	for y in range(4):
		draw_rect(Rect2(origin + Vector2(8, 8 + y * 18), Vector2(162, 10)), Color("6f4934"))
		for x in range(10):
			var crop := origin + Vector2(13 + x * 16, 6 + y * 18)
			draw_rect(Rect2(crop, Vector2(4, 7)), Color("4e8c45"))
			draw_rect(Rect2(crop + Vector2(-2, 2), Vector2(8, 3)), Color("6aaa50"))
	_draw_fence(Rect2(origin - Vector2(8, 8), Vector2(194, 98)))


func _draw_fence(area: Rect2) -> void:
	for x in range(int(area.position.x), int(area.end.x), 20):
		draw_rect(Rect2(x, area.position.y, 4, 10), Color("e1bd79"))
		draw_rect(Rect2(x, area.end.y - 10, 4, 10), Color("e1bd79"))
	draw_rect(Rect2(area.position + Vector2(0, 4), Vector2(area.size.x, 3)), Color("b98c57"))
	draw_rect(Rect2(area.position + Vector2(0, area.size.y - 7), Vector2(area.size.x, 3)), Color("b98c57"))


func _draw_building(origin: Vector2, building_size: Vector2, wall: Color, roof: Color, label: String) -> void:
	draw_rect(Rect2(origin + Vector2(5, 23), Vector2(building_size.x - 10, building_size.y - 23)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(origin + Vector2(8, 22), Vector2(building_size.x - 16, building_size.y - 22)), wall)
	draw_rect(Rect2(origin, Vector2(building_size.x, 26)), roof)
	draw_rect(Rect2(origin + Vector2(9, 26), Vector2(building_size.x - 18, 4)), roof.darkened(0.14))
	draw_rect(Rect2(origin + Vector2(18, 43), Vector2(22, 20)), Color("f7df8d"))
	draw_rect(Rect2(origin + Vector2(building_size.x - 39, 39), Vector2(22, building_size.y - 39)), Color("60463e"))
	draw_rect(Rect2(origin + Vector2(building_size.x - 33, 52), Vector2(3, 3)), Color("e7bd62"))
	draw_string(ThemeDB.fallback_font, origin + Vector2(4, -5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff4ce"))


func _draw_square() -> void:
	var center := Vector2(size.x * 0.48 + 29, size.y * 0.50 + 27)
	draw_circle(center, 42, Color("c7ad75"))
	draw_circle(center, 27, Color("d7c38f"))
	draw_rect(Rect2(center + Vector2(-3, -24), Vector2(6, 39)), Color("75604e"))
	draw_circle(center + Vector2(0, -28), 10, Color("d9edf0"))


func _draw_pond() -> void:
	var pond := Rect2(size.x - 114, size.y - 76, 96, 54)
	draw_rect(Rect2(pond.position - Vector2(5, 4), pond.size + Vector2(10, 8)), Color("5f8d55"))
	draw_rect(pond, Color("397a98"))
	draw_rect(Rect2(pond.position + Vector2(8, 11), Vector2(36, 3)), Color("72b2c2"))
	draw_rect(Rect2(pond.position + Vector2(54, 34), Vector2(27, 3)), Color("72b2c2"))
	draw_circle(pond.position + Vector2(70, 16), 5, Color("5b9a58"))


func _draw_decorations() -> void:
	_draw_tree(Vector2(174, 48))
	_draw_tree(Vector2(218, size.y - 76))
	_draw_tree(Vector2(size.x - 42, 150))
	_draw_tree(Vector2(size.x * 0.66, size.y - 66))
	for flower in [Vector2(158, 140), Vector2(205, 128), Vector2(420, 132), Vector2(454, 290), Vector2(238, 304)]:
		draw_rect(Rect2(flower, Vector2(3, 3)), Color("f4c2d7"))
		draw_rect(Rect2(flower + Vector2(2, 3), Vector2(2, 4)), Color("3f7e42"))


func _draw_tree(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(12, 22), Vector2(8, 23)), Color("795548"))
	draw_rect(Rect2(origin, Vector2(34, 27)), Color("2f7342"))
	draw_rect(Rect2(origin + Vector2(6, -7), Vector2(22, 17)), Color("4b934f"))
	draw_rect(Rect2(origin + Vector2(3, 4), Vector2(7, 5)), Color("65a95d"))


func _draw_move_marker() -> void:
	if resident_position.distance_to(move_target) < 3.0:
		return
	var pulse := 4.0 + sin(Time.get_ticks_msec() / 120.0) * 2.0
	draw_arc(move_target, pulse, 0.0, TAU, 8, Color("fff1ad"), 2.0)
	queue_redraw()


func _draw_resident(center: Vector2) -> void:
	var palette := [Color("f472b6"), Color("60a5fa"), Color("fbbf24"), Color("a78bfa")]
	var outfit: Color = palette[abs(appearance_seed) % palette.size()]
	var p := center.floor()
	draw_rect(Rect2(p + Vector2(-9, 11), Vector2(18, 4)), Color(0, 0, 0, 0.24))
	draw_rect(Rect2(p + Vector2(-6, -12), Vector2(12, 10)), Color("f1c7a5"))
	draw_rect(Rect2(p + Vector2(-7, -14), Vector2(14, 4)), Color("243447"))
	draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 14)), outfit)
	draw_rect(Rect2(p + Vector2(-6, 12), Vector2(5, 6)), Color("25324a"))
	draw_rect(Rect2(p + Vector2(2, 12), Vector2(5, 6)), Color("25324a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-28, -20), resident_name, HORIZONTAL_ALIGNMENT_CENTER, 56, 11, Color("fff7df"))
