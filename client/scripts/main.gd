extends Control

const BG := Color("10131f")
const GOLD := Color("ffe29a")
const PAPER := Color("f4dfaa")
const INK := Color("3b2d2a")
const TEXT := Color("fff8df")
const MUTED := Color("aebbc8")
const EDGE := Color("6b4f3b")

var api: CyberTownApiClient
var session := SessionStore.new()
var screen: Control
var content: VBoxContainer
var status_label: Label
var modal: Control
var toast: Label
var resident: Dictionary = {}
var busy := false
var town_view: TownView
var map_generation := 0
var syncing_generation := -1
var date_label: Label
var resource_labels: Dictionary = {}


func _ready() -> void:
	api = CyberTownApiClient.new()
	add_child(api)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--session-name="):
			session.use_profile(argument.trim_prefix("--session-name="))
	session.load_session()
	api.access_token = session.access_token
	api.refresh_token = session.refresh_token
	api.session_refreshed.connect(func(access: String, refresh: String) -> void:
		session.save_session(access, refresh, session.username)
	)
	if session.access_token.is_empty():
		_show_auth()
	else:
		_show_dashboard()


func _reset_screen() -> void:
	map_generation += 1
	town_view = null
	date_label = null
	resource_labels.clear()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	content = null
	status_label = null
	modal = null
	toast = null


func _build_form_shell() -> void:
	_reset_screen()
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	screen.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "赛博小镇  CYBERTOWN"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "让你的 AI 居民在小镇里继续生活"
	subtitle.add_theme_color_override("font_color", MUTED)
	column.add_child(subtitle)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", MUTED)
	column.add_child(status_label)


func _show_auth() -> void:
	_build_form_shell()
	_add_heading("使用邀请码进入小镇")
	_add_text("测试阶段不使用邮箱。注册成功后请立即保存恢复码。")
	var invite := _add_input("邀请码")
	var username := _add_input("用户名（3–20 位小写字母、数字或下划线）")
	var display_name := _add_input("居民名称")
	var privacy := CheckBox.new()
	privacy.text = "我已阅读并同意测试与隐私说明"
	content.add_child(privacy)
	var register := _form_button("生成我的居民")
	register.pressed.connect(func() -> void:
		if busy:
			return
		if not privacy.button_pressed:
			_set_status("请先同意测试与隐私说明", true)
			return
		busy = true
		register.disabled = true
		_set_status("正在创建居民…")
		var result := await api.register(invite.text, username.text, display_name.text)
		busy = false
		register.disabled = false
		if not result.ok:
			_set_status(result.message, true)
			return
		var data: Dictionary = result.data
		session.save_session(str(data.accessToken), str(data.refreshToken), str(data.username))
		api.access_token = session.access_token
		api.refresh_token = session.refresh_token
		_show_recovery_code(str(data.recoveryCode))
	)
	content.add_child(HSeparator.new())
	_add_heading("已有居民？")
	var recover_name := _add_input("用户名")
	var recovery_code := _add_input("恢复码")
	var recover := _form_button("恢复账号")
	recover.pressed.connect(func() -> void:
		if busy:
			return
		busy = true
		recover.disabled = true
		var result := await api.recover(recover_name.text, recovery_code.text)
		busy = false
		recover.disabled = false
		if not result.ok:
			_set_status(result.message, true)
			return
		var data: Dictionary = result.data
		session.save_session(str(data.accessToken), str(data.refreshToken), str(data.username))
		api.access_token = session.access_token
		api.refresh_token = session.refresh_token
		_show_dashboard()
	)


func _show_recovery_code(code: String) -> void:
	_build_form_shell()
	_add_heading("居民创建成功")
	_add_text("这是唯一一次完整显示恢复码。请保存到安全位置：")
	var code_label := Label.new()
	code_label.text = code
	code_label.selectable = true
	code_label.add_theme_color_override("font_color", GOLD)
	code_label.add_theme_font_size_override("font_size", 20)
	content.add_child(code_label)
	var copy := _form_button("复制恢复码")
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		_set_status("恢复码已复制")
	)
	var enter := _form_button("我已保存，进入小镇")
	enter.pressed.connect(_show_dashboard)


func _show_dashboard() -> void:
	_show_loading()
	var result := await api.get_resident()
	if not result.ok:
		_build_form_shell()
		_add_heading("暂时无法进入小镇")
		_add_text(str(result.message))
		var back := _form_button("返回登录")
		back.pressed.connect(func() -> void:
			session.clear()
			api.access_token = ""
			api.refresh_token = ""
			_show_auth()
		)
		return
	resident = result.data
	_build_map()


func _show_loading() -> void:
	_reset_screen()
	var background := ColorRect.new()
	background.color = Color("244334")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var label := Label.new()
	label.text = "正在进入小镇…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 22)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(label)


func _build_map() -> void:
	_reset_screen()
	var town := TownView.new()
	town_view = town
	town.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	town.configure(str(resident.get("displayName", "居民")), int(resident.get("appearanceSeed", 1)))
	screen.add_child(town)
	_build_top_hud()
	_build_toolbar()
	toast = Label.new()
	toast.text = "点击地图，让居民在小镇中移动"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", TEXT)
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 1)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-180, 64)
	toast.size = Vector2(360, 24)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(toast)
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(_sync_town)
	screen.add_child(timer)
	timer.start()
	_sync_town()


func _sync_town() -> void:
	var generation := map_generation
	if not is_instance_valid(town_view) or syncing_generation == generation:
		return
	syncing_generation = generation
	var active_town := town_view
	if active_town.has_pending_position():
		var position := active_town.resident_position
		var update := await api.update_presence(position)
		if generation != map_generation:
			return
		if update.ok:
			active_town.confirm_position(position)
		else:
			_show_toast(str(update.message), true)
	var snapshot := await api.get_town_snapshot()
	if generation != map_generation:
		return
	syncing_generation = -1
	if not snapshot.ok:
		_show_toast("小镇同步失败：%s" % str(snapshot.message), true)
		return
	active_town.apply_snapshot(snapshot.data)
	resident = snapshot.data.get("resident", resident)
	_update_hud(snapshot.data)


func _update_hud(snapshot: Dictionary) -> void:
	if is_instance_valid(date_label):
		var date := str(snapshot.get("townDate", "")).split("-")
		var day := "%s月%s日" % [int(date[1]), int(date[2])] if date.size() == 3 else "今日"
		date_label.text = "%s\n%s %s" % [day, snapshot.get("timeOfDay", ""), snapshot.get("townTime", "")]
	for key: String in resource_labels:
		resource_labels[key].text = str(int(resident.get(key, 0)))


func _build_top_hud() -> void:
	var day := PanelContainer.new()
	day.add_theme_stylebox_override("panel", _panel_style(PAPER))
	day.position = Vector2(10, 8)
	day.size = Vector2(164, 50)
	screen.add_child(day)
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 8)
	day.add_child(day_row)
	var sun := Label.new()
	sun.text = "☀"
	sun.add_theme_font_size_override("font_size", 24)
	sun.add_theme_color_override("font_color", Color("d17a34"))
	day_row.add_child(sun)
	var day_text := Label.new()
	date_label = day_text
	day_text.text = "小镇 · 今日\n正在同步时间"
	day_text.add_theme_font_size_override("font_size", 14)
	day_text.add_theme_color_override("font_color", INK)
	day_row.add_child(day_text)

	var resources := PanelContainer.new()
	resources.add_theme_stylebox_override("panel", _panel_style(PAPER))
	resources.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	resources.position = Vector2(-218, 8)
	resources.size = Vector2(208, 50)
	screen.add_child(resources)
	var values := HBoxContainer.new()
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation", 12)
	resources.add_child(values)
	values.add_child(_hud_value("◎", "coins", Color("b96b25")))
	values.add_child(_hud_value("⚡", "energy", Color("487a42")))
	values.add_child(_hud_value("♥", "mood", Color("b84f58")))


func _build_toolbar() -> void:
	var toolbar := PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", _panel_style(Color("e9c984")))
	toolbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toolbar.position = Vector2(-218, -58)
	toolbar.size = Vector2(436, 50)
	screen.add_child(toolbar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	toolbar.add_child(row)
	for definition in [
		["居民状态", _show_resident_panel],
		["今日目标", _show_goal_panel],
		["居民经历", _show_report_panel],
		["附近说话", _show_bubble_panel],
		["离开", _show_leave_panel],
	]:
		var button := _map_button(definition[0])
		button.pressed.connect(definition[1])
		row.add_child(button)


func _hud_value(icon: String, key: String, color: Color) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_color_override("font_color", color)
	var value_label := Label.new()
	value_label.text = str(int(resident.get(key, 0)))
	resource_labels[key] = value_label
	value_label.add_theme_color_override("font_color", INK)
	box.add_child(icon_label)
	box.add_child(value_label)
	return box


func _panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _map_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(80, 34)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f8e6b2")
	normal.border_color = Color("9b6d45")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("fff3c9")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _open_modal(title_text: String) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.08, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("f8e8ba")))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -130)
	panel.size = Vector2(380, 260)
	modal.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", INK)
	column.add_child(title)
	column.add_child(HSeparator.new())
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	column.add_child(body)
	var close := _map_button("关闭")
	close.custom_minimum_size.y = 30
	close.pressed.connect(_close_modal)
	column.add_child(close)
	return body


func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null


func _show_bubble_panel() -> void:
	var body := _open_modal("在居民身旁说句话")
	var active_modal := modal
	body.add_child(_dark_label("附近的居民能看到这条气泡，18 秒后消失。每 10 秒可发送一次，最多 60 字。"))
	var input := LineEdit.new()
	input.placeholder_text = "和附近的邻居打个招呼…"
	input.max_length = 60
	input.custom_minimum_size.y = 36
	body.add_child(input)
	var feedback := _dark_label("")
	body.add_child(feedback)
	var submit := _map_button("发送气泡")
	submit.pressed.connect(func() -> void:
		if busy:
			return
		var message := input.text.strip_edges()
		if message.is_empty():
			feedback.text = "请先写一句话"
			return
		busy = true
		submit.disabled = true
		var generation := map_generation
		if not is_instance_valid(town_view) or not town_view.initialized:
			busy = false
			submit.disabled = false
			feedback.text = "小镇尚未同步，请稍后重试"
			return
		# Wait for an ongoing poll before flushing position; two overlapping
		# writes could otherwise make an older snapshot snap the resident back.
		while syncing_generation == generation and generation == map_generation:
			await get_tree().process_frame
		if generation != map_generation or modal != active_modal:
			busy = false
			return
		if is_instance_valid(town_view) and town_view.has_pending_position():
			var position := town_view.resident_position
			var update := await api.update_presence(position)
			if generation != map_generation:
				busy = false
				return
			if not update.ok:
				busy = false
				if is_instance_valid(submit):
					submit.disabled = false
					feedback.text = str(update.message)
				return
			town_view.confirm_position(position)
		var result := await api.send_bubble(message)
		busy = false
		if generation != map_generation or modal != active_modal or not is_instance_valid(submit):
			return
		if result.ok:
			_close_modal()
			_show_toast("气泡已发送，附近的居民可以看到")
			_sync_town()
		else:
			submit.disabled = false
			feedback.text = str(result.message)
	)
	body.add_child(submit)


func _show_resident_panel() -> void:
	var body := _open_modal("居民状态 · %s" % str(resident.get("displayName", "居民")))
	for item in [
		["当前位置", _location_name(str(resident.get("locationKey", "")))],
		["生活背景", _background_name(str(resident.get("backgroundKey", "")))],
		["金币", resident.get("coins", 0)],
		["精力", resident.get("energy", 0)],
		["心情", resident.get("mood", 0)],
	]:
		body.add_child(_stat_row(str(item[0]), str(item[1])))


func _show_goal_panel() -> void:
	var body := _open_modal("给居民安排今日目标")
	var active_modal := modal
	var hint := Label.new()
	hint.text = "居民会在后续行动时段参考你的安排。"
	hint.add_theme_color_override("font_color", INK)
	body.add_child(hint)
	var input := TextEdit.new()
	input.placeholder_text = "例如：去认识邻居，但不要耗尽精力"
	input.custom_minimum_size.y = 88
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(input)
	var submit := _map_button("确认目标")
	submit.pressed.connect(func() -> void:
		if busy or input.text.strip_edges().is_empty():
			return
		busy = true
		submit.disabled = true
		var result := await api.set_goal(input.text.strip_edges())
		busy = false
		if not is_instance_valid(submit) or modal != active_modal:
			return
		if result.ok:
			_close_modal()
			_show_toast("目标已记录，将从下一个行动时段生效")
		else:
			submit.disabled = false
			_show_toast(str(result.message), true)
	)
	body.add_child(submit)


func _show_report_panel() -> void:
	var body := _open_modal("居民经历 · 今日")
	var active_modal := modal
	var loading := Label.new()
	loading.text = "正在翻阅居民日记…"
	loading.add_theme_color_override("font_color", INK)
	body.add_child(loading)
	var result := await api.get_today_report()
	if not is_instance_valid(body) or modal != active_modal:
		return
	loading.queue_free()
	if not result.ok:
		body.add_child(_dark_label(str(result.message)))
		return
	var report: Dictionary = result.data
	body.add_child(_dark_label("今日目标：%s" % (str(report.goal) if report.get("goal") != null else "尚未设置")))
	var actions: Array = report.get("actions", [])
	if actions.is_empty():
		body.add_child(_dark_label("今天还没有行动记录。居民会在下一个时段继续生活。"))
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for action: Dictionary in actions:
			list.add_child(_dark_label("• %s  %s  %s" % [action.get("timeSlot", ""), action.get("actionType", ""), action.get("status", "")]))


func _show_leave_panel() -> void:
	var body := _open_modal("离开小镇")
	body.add_child(_dark_label("退出后，本机保存的登录信息会被清除。"))
	var logout := _map_button("退出本机账号")
	logout.pressed.connect(func() -> void:
		session.clear()
		api.access_token = ""
		api.refresh_token = ""
		_show_auth()
	)
	body.add_child(logout)


func _stat_row(name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _dark_label(name)
	label.custom_minimum_size.x = 100
	label.add_theme_color_override("font_color", Color("765a45"))
	var value_label := _dark_label(value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(value_label)
	return row


func _location_name(key: String) -> String:
	return str({
		"residential": "住宅区",
		"square": "中心广场",
		"workshop": "工坊",
	}.get(key, key if not key.is_empty() else "小镇"))


func _background_name(key: String) -> String:
	return str({
		"corporate_clerk": "公司职员",
		"repair_apprentice": "维修学徒",
		"street_artist": "街头艺术家",
		"data_archivist": "数据档案员",
		"courier": "快递员",
		"traveler": "旅行者",
	}.get(key, key if not key.is_empty() else "未知"))


func _dark_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", INK)
	return label


func _show_toast(message: String, is_error := false) -> void:
	if is_instance_valid(toast):
		toast.text = message
		toast.add_theme_color_override("font_color", Color("ff9d9d") if is_error else TEXT)


func _add_heading(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 20)
	content.add_child(label)


func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	content.add_child(label)


func _add_input(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size.y = 40
	content.add_child(input)
	return input


func _form_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 42
	content.add_child(button)
	return button


func _set_status(message: String, is_error := false) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
		status_label.add_theme_color_override("font_color", Color("fb7185") if is_error else MUTED)
