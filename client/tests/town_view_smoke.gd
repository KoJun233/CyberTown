extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	var town := TownView.new()
	town.size = Vector2(640, 360)
	town.configure("自己", 1)
	root.add_child(town)
	var now := int(Time.get_unix_time_from_system())
	var snapshot := {
		"serverTime": Time.get_datetime_string_from_unix_time(now) + "Z",
		"residents": [
			{"id": "own", "displayName": "自己", "appearanceSeed": 1, "posX": 100, "posY": 150, "current": true},
			{"id": "neighbor", "displayName": "邻居", "appearanceSeed": 2, "posX": 140, "posY": 160, "current": false},
		],
		"bubbles": [
			{"residentId": "neighbor", "message": "邻居的气泡".repeat(10), "expiresAt": Time.get_datetime_string_from_unix_time(now + 18) + "Z"},
		],
	}
	town.apply_snapshot(snapshot)
	await process_frame
	await process_frame
	for path in ["ground.png", "house_0.png", "house_1.png", "house_2.png", "resident_1.png", "mill_base.png"]:
		_check(town._texture(path) != null, "Required imported art must load: " + path)
	var sheets: Array[Image] = []
	for seed in range(6):
		sheets.append(town._texture("resident_%s.png" % seed).get_image())
	for tag: String in town.animations:
		var animation: Dictionary = town.animations[tag]
		for frame in range(int(animation.frames)):
			var variants: Dictionary = {}
			for sheet: Image in sheets:
				var sprite := sheet.get_region(Rect2i(frame * 96, int(animation.row) * 64, 96, 64))
				var bounds := sprite.get_used_rect()
				_check(bounds.size.y >= 15 and bounds.end.y == 39, "Animation must retain a complete body: " + tag)
				variants[sprite.get_data()] = true
			_check(variants.size() == 6, "All six hairstyles must remain distinct in every frame: " + tag)
	_check(town.initialized and town.resident_position == Vector2(100, 150), "Snapshot must initialize the current resident")
	_check(town.neighbors.size() == 1, "Shared map must include other residents exactly once")
	_check(town.bubble_panels.size() == 1, "Nearby bubble must be displayed")
	var panel: PanelContainer = town.bubble_panels["neighbor"].panel
	_check(panel.size.x >= 128 and panel.size.x <= 160, "Bubble must have a readable bounded width")
	_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bubble must not swallow movement clicks")
	town.size = Vector2(960, 540)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(900, 450)
	town._gui_input(click)
	_check(town.move_target == Vector2(600, 300), "Resized canvas must translate clicks into canonical map coordinates")
	_check(not town.is_walkable(Vector2(560, 280)), "River must block walking away from the bridge")
	_check(town.is_walkable(Vector2(560, 204)), "Bridge must remain walkable")
	for point in town.route:
		_check(town.is_walkable(point), "Navigation route must stay on walkable ground")
	town.size = Vector2(960, 360)
	_check(town.view_to_world(Vector2(480, 180)) == Vector2(320, 180), "Wide windows must use letterbox offsets instead of stretching the world")
	town.size = Vector2(960, 540)
	click.position = Vector2(100, 100)
	town._gui_input(click)
	_check(town.is_walkable(town.move_target), "Clicking a decorative building must choose walkable nearby ground")
	_check(town.move_target != Vector2(100, 100), "The resident must not be sent into a building")
	town.request_move(Vector2(600, 300))
	town._process(1.0)
	_check(town.has_pending_position(), "Movement must mark position for synchronization")
	var moving_position := town.resident_position
	town.apply_snapshot(snapshot)
	_check(town.resident_position == moving_position, "Old snapshot must not snap an unsynchronized move back")
	town.move_target = town.resident_position
	town.confirm_position(town.resident_position)
	_check(not town.has_pending_position(), "Acknowledged position must stop redundant updates")
	town.apply_snapshot(snapshot)
	_check(town.resident_position == Vector2(100, 150), "Idle resident must follow an authoritative offline update")
	town.bubble_panels["neighbor"].until = Time.get_ticks_msec() - 1
	town._update_bubble_positions()
	_check(town.bubble_panels.is_empty(), "Bubble must disappear without waiting for another server poll")
	snapshot.residents.resize(1)
	town.apply_snapshot(snapshot)
	_check(town.neighbors.is_empty(), "Removed residents must disappear from the shared map")
	town.queue_free()
	await process_frame
	print("Town view smoke checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
