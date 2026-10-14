extends SceneTree

# Run without --headless: this checks actual atlas rendering and mirroring.
class CharacterPreview extends TownView:
	var test_seed := 0
	var test_direction := Vector2.DOWN
	var test_moving := false
	func world_scale() -> float:
		return 1.0
	func world_offset() -> Vector2:
		return Vector2.ZERO
	func _process(_delta: float) -> void:
		pass
	func _draw() -> void:
		_draw_resident(Vector2(48, 44), "", test_seed, false, test_direction, test_moving)

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _opaque_count(image: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 0.99:
				count += 1
	return count

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run character_render_smoke.gd without --headless to verify rendered sprites")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := CharacterPreview.new()
	preview.size = Vector2(96, 64)
	preview.theme = TownTheme.create()
	viewport.add_child(preview)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2(128, 52)
	display.size = Vector2(384, 256)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(display)
	var directions := [Vector2.DOWN, Vector2(1, 1).normalized(), Vector2.RIGHT, Vector2(1, -1).normalized(), Vector2.UP, Vector2(-1, -1).normalized(), Vector2.LEFT, Vector2(-1, 1).normalized()]
	var checked := 0
	for seed in range(6):
		preview.test_seed = seed
		var sheet := preview._texture("resident_%s.png" % seed).get_image()
		for moving in [false, true]:
			preview.test_moving = moving
			for direction: Vector2 in directions:
				preview.test_direction = direction
				var suffix := "n" if direction == Vector2.UP else ("ne" if direction.y < -0.5 else ("s" if direction == Vector2.DOWN else "se"))
				var tag := ("walk-" if moving else "idle-") + suffix
				var animation: Dictionary = preview.animations[tag]
				for frame in range(int(animation.frames)):
					preview.elapsed = (frame + 0.1) * float(animation.seconds)
					preview.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var rendered := viewport.get_texture().get_image()
					var source := sheet.get_region(Rect2i(frame * 96, int(animation.row) * 64, 96, 64))
					var context := "seed %s %s frame %s direction %s" % [seed, tag, frame, direction]
					_check(_opaque_count(rendered, Rect2i(0, 22, 96, 24)) == _opaque_count(source, Rect2i(0, 0, 96, 64)), "Rendered sprite must retain every opaque body and hair pixel: " + context)
					_check(_opaque_count(rendered, Rect2i(34, 22, 28, 24)) > 50, "Sprite must remain centered above its feet: " + context)
					checked += 1
	viewport.queue_free()
	display.queue_free()
	await process_frame
	print("Character render smoke checks (%s frames): %s" % [checked, "FAILED" if failed else "PASSED"])
	quit(1 if failed else 0)
