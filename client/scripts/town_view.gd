class_name TownView
extends Control

const TILE := 16.0
const SPEED := 150.0
const WORLD_SIZE := Vector2(640, 360)

var resident_name := "居民"
var appearance_seed := 1
var resident_position := Vector2(320, 190)
var move_target := resident_position
var initialized := false
var resident_id := ""
var position_dirty := false
var neighbors: Dictionary = {}
var bubble_panels: Dictionary = {}


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
	var changed := false
	if resident_position.distance_to(move_target) > 1.0:
		resident_position = resident_position.move_toward(move_target, SPEED * delta)
		position_dirty = true
		changed = true
	for id: String in neighbors:
		var neighbor: Dictionary = neighbors[id]
		var previous: Vector2 = neighbor.position
		neighbor.position = previous.move_toward(neighbor.target, SPEED * delta)
		changed = changed or previous != neighbor.position
	_update_bubble_positions()
	if changed:
		queue_redraw()


func has_pending_position() -> bool:
	return initialized and position_dirty


func confirm_position(sent_position: Vector2) -> void:
	if resident_position.distance_to(sent_position) < 1.0:
		position_dirty = false


func apply_snapshot(snapshot: Dictionary) -> void:
	var present: Dictionary = {}
	for entry: Dictionary in snapshot.get("residents", []):
		var position := Vector2(float(entry.posX), float(entry.posY))
		if bool(entry.get("current", false)):
			resident_id = str(entry.id)
			if not initialized or (not position_dirty and resident_position.distance_to(move_target) <= 1.0):
				resident_position = position
				move_target = position
			initialized = true
			continue
		var id := str(entry.id)
		present[id] = true
		if not neighbors.has(id):
			neighbors[id] = {"position": position}
		neighbors[id].target = position
		neighbors[id].name = str(entry.displayName)
		neighbors[id].seed = int(entry.appearanceSeed)
	for id: String in neighbors.keys():
		if not present.has(id):
			neighbors.erase(id)
	_rebuild_bubbles(snapshot)
	queue_redraw()


func _rebuild_bubbles(snapshot: Dictionary) -> void:
	for entry: Dictionary in bubble_panels.values():
		entry.panel.queue_free()
	bubble_panels.clear()
	var server_time := Time.get_unix_time_from_datetime_string(str(snapshot.get("serverTime", "")).split(".")[0])
	for bubble: Dictionary in snapshot.get("bubbles", []):
		var id := str(bubble.residentId)
		if bubble_panels.has(id):
			continue
		if id != resident_id and not neighbors.has(id):
			continue
		var expires := Time.get_unix_time_from_datetime_string(str(bubble.expiresAt).split(".")[0])
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size.x = 128
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fff7dc")
		style.border_color = Color("6b4f3b")
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = str(bubble.message)
		label.custom_minimum_size.x = 116
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("3b2d2a"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		add_child(panel)
		var current := id == resident_id
		bubble_panels[id] = {
			"panel": panel,
			"current": current,
			"until": Time.get_ticks_msec() + int(maxi(0, expires - server_time)) * 1000,
		}
	_update_bubble_positions()


func _update_bubble_positions() -> void:
	for id: String in bubble_panels.keys():
		var entry: Dictionary = bubble_panels[id]
		var panel: PanelContainer = entry.panel
		if Time.get_ticks_msec() >= int(entry.until) or (not entry.current and not neighbors.has(id)):
			panel.queue_free()
			bubble_panels.erase(id)
			continue
		var position: Vector2 = resident_position if entry.current else neighbors[id].position
		var view_position := position * (size / WORLD_SIZE)
		panel.position = Vector2(
			clampf(view_position.x - panel.size.x / 2.0, 4.0, size.x - panel.size.x - 4.0),
			maxf(4.0, view_position.y - panel.size.y - 26.0))


func _gui_input(event: InputEvent) -> void:
	if not initialized:
		return
	var point := Vector2.ZERO
	var move := false
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
		move = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
		move = true
	if move:
		point /= size / WORLD_SIZE
		move_target = Vector2(
			clampf(snappedf(point.x, 2.0), 8.0, 632.0),
			clampf(snappedf(point.y, 2.0), 70.0, 330.0)
		)
		queue_redraw()
		accept_event()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / WORLD_SIZE)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("78ae5d"))
	_draw_grass()
	_draw_river()
	_draw_paths()
	_draw_farm()
	_draw_building(Vector2(28, 34), Vector2(116, 76), Color("e8a35d"), Color("774b45"), "家")
	_draw_building(Vector2(WORLD_SIZE.x * 0.38, 24), Vector2(140, 88), Color("e6cf8a"), Color("6f5365"), "镇民中心")
	_draw_building(Vector2(WORLD_SIZE.x - 176, 46), Vector2(112, 72), Color("79a9c2"), Color("405b72"), "杂货店")
	_draw_square()
	_draw_pond()
	_draw_decorations()
	_draw_move_marker()
	var people: Array = []
	for id: String in neighbors:
		var neighbor: Dictionary = neighbors[id]
		people.append({"position": neighbor.position, "name": neighbor.name, "seed": neighbor.seed, "current": false})
	if initialized:
		people.append({"position": resident_position, "name": resident_name, "seed": appearance_seed, "current": true})
	people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y)
	for person: Dictionary in people:
		_draw_resident(person.position, person.name, person.seed, person.current)


func _draw_grass() -> void:
	for y in range(int(ceil(WORLD_SIZE.y / TILE))):
		for x in range(int(ceil(WORLD_SIZE.x / TILE))):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("73a957"))
			if (x * 7 + y * 11) % 29 == 0:
				draw_rect(Rect2(x * TILE + 4, y * TILE + 6, 2, 5), Color("4e873f"))


func _draw_river() -> void:
	var river_x := WORLD_SIZE.x * 0.78
	draw_rect(Rect2(river_x, 0, 58, WORLD_SIZE.y), Color("3f82a0"))
	for y in range(8, int(WORLD_SIZE.y), 30):
		draw_rect(Rect2(river_x + 8, y, 20, 3), Color("72b2c2"))
		draw_rect(Rect2(river_x + 34, y + 14, 16, 3), Color("2d6f91"))


func _draw_paths() -> void:
	var road_y := WORLD_SIZE.y * 0.50
	var road_x := WORLD_SIZE.x * 0.48
	draw_rect(Rect2(0, road_y, WORLD_SIZE.x, 54), Color("d9bf83"))
	draw_rect(Rect2(road_x, 0, 58, WORLD_SIZE.y), Color("d9bf83"))
	for x in range(8, int(WORLD_SIZE.x), 32):
		draw_rect(Rect2(x, road_y + 12, 18, 3), Color("eed79f"))
		draw_rect(Rect2(x + 12, road_y + 36, 14, 3), Color("bfa56f"))
	var river_x := WORLD_SIZE.x * 0.78
	draw_rect(Rect2(river_x - 4, road_y - 3, 66, 60), Color("805a3c"))
	for x in range(int(river_x), int(river_x + 58), 9):
		draw_rect(Rect2(x, road_y, 7, 54), Color("c58b51"))


func _draw_farm() -> void:
	var origin := Vector2(26, WORLD_SIZE.y - 112)
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
	var center := Vector2(WORLD_SIZE.x * 0.48 + 29, WORLD_SIZE.y * 0.50 + 27)
	draw_circle(center, 42, Color("c7ad75"))
	draw_circle(center, 27, Color("d7c38f"))
	draw_rect(Rect2(center + Vector2(-3, -24), Vector2(6, 39)), Color("75604e"))
	draw_circle(center + Vector2(0, -28), 10, Color("d9edf0"))


func _draw_pond() -> void:
	var pond := Rect2(WORLD_SIZE.x - 114, WORLD_SIZE.y - 76, 96, 54)
	draw_rect(Rect2(pond.position - Vector2(5, 4), pond.size + Vector2(10, 8)), Color("5f8d55"))
	draw_rect(pond, Color("397a98"))
	draw_rect(Rect2(pond.position + Vector2(8, 11), Vector2(36, 3)), Color("72b2c2"))
	draw_rect(Rect2(pond.position + Vector2(54, 34), Vector2(27, 3)), Color("72b2c2"))
	draw_circle(pond.position + Vector2(70, 16), 5, Color("5b9a58"))


func _draw_decorations() -> void:
	_draw_tree(Vector2(174, 48))
	_draw_tree(Vector2(218, WORLD_SIZE.y - 76))
	_draw_tree(Vector2(WORLD_SIZE.x - 42, 150))
	_draw_tree(Vector2(WORLD_SIZE.x * 0.66, WORLD_SIZE.y - 66))
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


func _draw_resident(center: Vector2, display_name: String, seed: int, current: bool) -> void:
	var palette := [Color("f472b6"), Color("60a5fa"), Color("fbbf24"), Color("a78bfa")]
	var outfit: Color = palette[abs(seed) % palette.size()]
	var p := center.floor()
	if current:
		draw_arc(p + Vector2(0, 12), 12, 0, TAU, 12, Color("ffe29a"), 1.0)
	draw_rect(Rect2(p + Vector2(-9, 11), Vector2(18, 4)), Color(0, 0, 0, 0.24))
	draw_rect(Rect2(p + Vector2(-6, -12), Vector2(12, 10)), Color("f1c7a5"))
	draw_rect(Rect2(p + Vector2(-7, -14), Vector2(14, 4)), Color("243447"))
	draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 14)), outfit)
	draw_rect(Rect2(p + Vector2(-6, 12), Vector2(5, 6)), Color("25324a"))
	draw_rect(Rect2(p + Vector2(2, 12), Vector2(5, 6)), Color("25324a"))
	draw_string(ThemeDB.fallback_font, p + Vector2(-40, -20), display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color("fff7df"))
