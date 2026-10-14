class_name TownView
extends Control

signal movement_hint(message: String)

const TILE := 16.0
const SPEED := 150.0
const WORLD_SIZE := Vector2(640, 360)
const ART := "res://assets/sunnyside/"

var resident_name := "居民"
var appearance_seed := 1
var resident_position := Vector2(320, 190)
var move_target := resident_position
var initialized := false
var resident_id := ""
var position_dirty := false
var neighbors: Dictionary = {}
var bubble_panels: Dictionary = {}
var movement_enabled := true
var textures: Dictionary = {}
var animations: Dictionary = {}
var navigation := AStarGrid2D.new()
var route := PackedVector2Array()
var facing := Vector2(0, 1)
var walking := false
var elapsed := 0.0
var objects: Array[Dictionary] = []
var obstacles: Array[Rect2] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	animations = JSON.parse_string(FileAccess.get_file_as_string(ART + "animations.json"))
	_build_world()

func configure(display_name: String, seed: int) -> void:
	resident_name = display_name
	appearance_seed = seed
	queue_redraw()

func world_scale() -> float:
	return maxf(0.01, minf(size.x / WORLD_SIZE.x, size.y / WORLD_SIZE.y))

func world_offset() -> Vector2:
	return (size - WORLD_SIZE * world_scale()) * 0.5

func view_to_world(point: Vector2) -> Vector2:
	return (point - world_offset()) / world_scale()

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(ART + path)
	return textures[path]

func _build_world() -> void:
	objects = [
		{"kind": "house", "position": Vector2(32, 30), "image": "house_0.png", "depth": 126.0},
		{"kind": "house", "position": Vector2(240, 4), "image": "house_1.png", "depth": 100.0},
		{"kind": "house", "position": Vector2(400, 36), "image": "house_2.png", "depth": 132.0},
		{"kind": "notice", "position": Vector2(370, 136), "depth": 164.0},
		{"kind": "well", "position": Vector2(336, 148), "image": "well.png", "depth": 196.0},
		{"kind": "windmill", "position": Vector2(410, 246), "image": "Elements/Other/spr_deco_windmill_withshadow_strip9.png", "depth": 334.0},
		{"kind": "animal", "position": Vector2(346, 258), "image": "Elements/Animals/spr_deco_cow_strip4.png", "depth": 284.0},
		{"kind": "animal", "position": Vector2(200, 232), "image": "Elements/Animals/spr_deco_chicken_01_strip4.png", "depth": 258.0},
	]
	obstacles = [Rect2(44, 80, 104, 47), Rect2(252, 54, 104, 47), Rect2(412, 86, 104, 47), Rect2(370, 148, 24, 16), Rect2(342, 182, 20, 14), Rect2(456, 310, 24, 25)]
	for point in [Vector2(20, 108), Vector2(194, 84), Vector2(214, 130), Vector2(390, 92), Vector2(510, 148), Vector2(18, 252), Vector2(216, 284), Vector2(392, 296), Vector2(470, 270), Vector2(608, 116), Vector2(620, 292), Vector2(250, 36), Vector2(582, 312)]:
		objects.append({"kind": "tree", "position": point - Vector2(16, 32), "depth": point.y, "image": "Elements/Plants/spr_deco_tree_01_strip4.png"})
		obstacles.append(Rect2(point - Vector2(5, 3), Vector2(10, 8)))
	navigation.region = Rect2i(0, 0, 80, 45)
	navigation.cell_size = Vector2(8, 8)
	navigation.offset = Vector2(4, 4)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(45):
		for x in range(80):
			navigation.set_point_solid(Vector2i(x, y), not is_walkable(Vector2(x * 8 + 4, y * 8 + 4)))

func is_walkable(point: Vector2) -> bool:
	if point.x < 8 or point.x > 632 or point.y < 70 or point.y > 330:
		return false
	if point.x >= 522 and point.x < 600 and (point.y < 188 or point.y > 218):
		return false
	for area in obstacles:
		if area.grow(3).has_point(point):
			return false
	return true

func _nearest_cell(point: Vector2) -> Vector2i:
	var origin := Vector2i(clampi(int(point.x / 8), 1, 78), clampi(int(point.y / 8), 9, 40))
	if not navigation.is_point_solid(origin):
		return origin
	for radius in range(1, 80):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var cell := origin + Vector2i(x, y)
				if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell):
					return cell
	return origin

func request_move(point: Vector2) -> void:
	var target := Vector2(clampf(snappedf(point.x, 2), 8, 632), clampf(snappedf(point.y, 2), 70, 330))
	var start := _nearest_cell(resident_position)
	var finish := _nearest_cell(target)
	if not is_walkable(target):
		target = navigation.get_point_position(finish)
	route = navigation.get_point_path(start, finish)
	if route.is_empty():
		movement_hint.emit("这里暂时到不了，试试道路或桥边")
		return
	if route.size() > 1:
		route.remove_at(0)
	route.append(target)
	move_target = target
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	walking = false
	if initialized and movement_enabled:
		var keyboard := Vector2.ZERO
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit):
			keyboard = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
		if keyboard != Vector2.ZERO:
			route.clear()
			var next := resident_position + keyboard * SPEED * delta
			if is_walkable(next):
				facing = keyboard
				resident_position = next
				move_target = next
				walking = true
				position_dirty = true
		elif resident_position.distance_to(move_target) > 1 and not route.is_empty():
			var budget := SPEED * delta
			while budget > 0 and not route.is_empty():
				var next := route[0]
				var distance := resident_position.distance_to(next)
				if distance > 0.01:
					facing = (next - resident_position).normalized()
				var travel := minf(distance, budget)
				resident_position = resident_position.move_toward(next, travel)
				budget -= travel
				if distance <= travel + 0.01:
					route.remove_at(0)
			walking = true
			position_dirty = true
		else:
			route.clear()
	for id: String in neighbors:
		var person: Dictionary = neighbors[id]
		var previous: Vector2 = person.position
		person.position = previous.move_toward(person.target, SPEED * delta)
		person.walking = previous.distance_to(person.position) > 0.1
		if person.walking:
			person.facing = (person.target - previous).normalized()
	_update_bubble_positions()
	queue_redraw()

func has_pending_position() -> bool:
	return initialized and position_dirty

func confirm_position(sent_position: Vector2) -> void:
	if resident_position.distance_to(sent_position) < 1:
		position_dirty = false

func apply_snapshot(snapshot: Dictionary) -> void:
	var present: Dictionary = {}
	for entry: Dictionary in snapshot.get("residents", []):
		var point := Vector2(float(entry.posX), float(entry.posY))
		if bool(entry.get("current", false)):
			resident_id = str(entry.id)
			if not initialized or (not position_dirty and resident_position.distance_to(move_target) <= 1):
				resident_position = point
				move_target = point
				route.clear()
			initialized = true
			continue
		var id := str(entry.id)
		present[id] = true
		if not neighbors.has(id):
			neighbors[id] = {"position": point, "facing": Vector2(0, 1), "walking": false}
		neighbors[id].target = point
		neighbors[id].name = str(entry.displayName)
		neighbors[id].seed = int(entry.appearanceSeed)
	for id: String in neighbors.keys():
		if not present.has(id):
			neighbors.erase(id)
	_rebuild_bubbles(snapshot)
	queue_redraw()

func _rebuild_bubbles(snapshot: Dictionary) -> void:
	var server_time := Time.get_unix_time_from_datetime_string(str(snapshot.get("serverTime", "")).split(".")[0])
	var present: Dictionary = {}
	for bubble: Dictionary in snapshot.get("bubbles", []):
		var id := str(bubble.residentId)
		if present.has(id) or (id != resident_id and not neighbors.has(id)):
			continue
		present[id] = true
		var expires := Time.get_unix_time_from_datetime_string(str(bubble.expiresAt).split(".")[0])
		if not bubble_panels.has(id):
			var panel := PanelContainer.new()
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.custom_minimum_size.x = 128
			var style := StyleBoxFlat.new()
			style.bg_color = Color("fff9e7")
			style.border_color = Color("765b48")
			style.set_border_width_all(1)
			style.set_corner_radius_all(4)
			style.set_content_margin_all(6)
			panel.add_theme_stylebox_override("panel", style)
			var label := Label.new()
			label.custom_minimum_size.x = 116
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("334b3e"))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(label)
			add_child(panel)
			bubble_panels[id] = {"panel": panel, "label": label}
		bubble_panels[id].label.text = str(bubble.message)
		bubble_panels[id].current = id == resident_id
		bubble_panels[id].until = Time.get_ticks_msec() + maxi(0, expires - server_time) * 1000
	for id: String in bubble_panels.keys():
		if not present.has(id):
			bubble_panels[id].panel.queue_free()
			bubble_panels.erase(id)
	_update_bubble_positions()

func _update_bubble_positions() -> void:
	for id: String in bubble_panels.keys():
		var entry: Dictionary = bubble_panels[id]
		var panel: PanelContainer = entry.panel
		if Time.get_ticks_msec() >= int(entry.until) or (not entry.current and not neighbors.has(id)):
			panel.queue_free()
			bubble_panels.erase(id)
			continue
		var point: Vector2 = resident_position if entry.current else neighbors[id].position
		var view_point := world_offset() + point * world_scale()
		panel.position = Vector2(clampf(view_point.x - panel.size.x / 2, 4, maxf(4, size.x - panel.size.x - 4)), maxf(4, view_point.y - panel.size.y - 27 * world_scale()))

func _gui_input(event: InputEvent) -> void:
	if not initialized or not movement_enabled:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if pressed:
		var point := view_to_world(event.position)
		if not Rect2(Vector2.ZERO, WORLD_SIZE).has_point(point):
			return
		request_move(point)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("344f43"))
	draw_set_transform(world_offset(), 0, Vector2.ONE * world_scale())
	draw_texture(_texture("ground.png"), Vector2.ZERO)
	var layers: Array = objects.duplicate()
	for id: String in neighbors:
		var person: Dictionary = neighbors[id]
		layers.append({"kind": "resident", "position": person.position, "name": person.name, "seed": person.seed, "current": false, "facing": person.facing, "walking": person.walking, "depth": person.position.y})
	if initialized:
		layers.append({"kind": "resident", "position": resident_position, "name": resident_name, "seed": appearance_seed, "current": true, "facing": facing, "walking": walking, "depth": resident_position.y})
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	if walking and not route.is_empty():
		for point in route:
			draw_circle(point, 1.2, Color(1, 0.98, 0.8, 0.45))
		draw_arc(move_target, 5, 0, TAU, 12, Color("fff0b1"), 1.5)
	for object: Dictionary in layers:
		_draw_object(object)
	for y in range(32, 350, 64):
		draw_line(Vector2(548 + sin(elapsed + y) * 5, y), Vector2(558 + sin(elapsed + y) * 5, y), Color(0.8, 1, 1, 0.45), 1)

func _draw_object(object: Dictionary) -> void:
	var point: Vector2 = object.position
	match str(object.kind):
		"resident":
			_draw_resident(point, str(object.name), int(object.seed), bool(object.current), object.facing, bool(object.walking))
		"tree":
			draw_texture_rect_region(_texture(object.image), Rect2(point, Vector2(32, 34)), Rect2(int(elapsed * 3) % 4 * 32, 0, 32, 34))
		"windmill":
			draw_texture(_texture("mill_base.png"), point + Vector2(28, 18))
			draw_texture_rect_region(_texture(object.image), Rect2(point, Vector2(112, 112)), Rect2(int(elapsed * 7) % 9 * 112, 0, 112, 112))
		"animal":
			draw_texture_rect_region(_texture(object.image), Rect2(point, Vector2(32, 32)), Rect2(int(elapsed * 3) % 4 * 32, 0, 32, 32))
		"notice":
			draw_rect(Rect2(point + Vector2(12, 14), Vector2(4, 16)), Color("785744"))
			draw_style_box(TownTheme.panel_style(), Rect2(point, Vector2(28, 22)))
			draw_texture(_texture("UI/plant.png"), point + Vector2(9, 4))
		"house", "well":
			draw_texture(_texture(object.image), point)

func _draw_resident(point: Vector2, display_name: String, seed: int, current: bool, direction: Vector2, moving: bool) -> void:
	draw_set_transform(world_offset() + (point + Vector2(0, 2)) * world_scale(), 0, Vector2(1, 0.35) * world_scale())
	draw_circle(Vector2.ZERO, 8, Color(0.15, 0.26, 0.18, 0.25))
	draw_set_transform(world_offset(), 0, Vector2.ONE * world_scale())
	if current:
		draw_arc(point + Vector2(0, 1), 10, 0, TAU, 20, Color("fff1a2"), 1.5)
	var direction_index := 0
	if direction.y < -0.5:
		direction_index = 3 if absf(direction.x) < 0.3 else 2
	elif absf(direction.x) > 0.3:
		direction_index = 1
	var tag := ("walk-" if moving else "idle-") + str(["s", "se", "ne", "n"][direction_index])
	var animation: Dictionary = animations.get(tag, {"row": 0, "frames": 4, "seconds": 0.2})
	var frame := int(elapsed / float(animation.seconds)) % int(animation.frames)
	# Keep the source frame fixed and mirror around the resident's feet.
	var horizontal_scale := -1.0 if direction.x < -0.1 else 1.0
	draw_set_transform(world_offset() + point.floor() * world_scale(), 0, Vector2(horizontal_scale, 1) * world_scale())
	draw_texture_rect_region(_texture("resident_%s.png" % (absi(seed) % 6)), Rect2(-48, -39, 96, 64), Rect2(frame * 96, int(animation.row) * 64, 96, 64))
	draw_set_transform(world_offset(), 0, Vector2.ONE * world_scale())
	var font := get_theme_default_font()
	var name_size := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_rect(Rect2(point + Vector2(-name_size.x / 2 - 3, -36), Vector2(name_size.x + 6, 14)), Color(0.13, 0.24, 0.2, 0.82))
	draw_string(font, point + Vector2(-name_size.x / 2, -25), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff9e5"))
