extends Control

const INK := TownTheme.INK
const PAPER := TownTheme.PAPER
const TEXT := Color("fff8df")
const MUTED := TownTheme.MUTED

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
var connection_label: Label
var goal_text := ""
var goal_constraints: Array[String] = []
var report_cache: Dictionary = {}
var report_loading := false
var report_revision := 0
var report_date := ""
var last_report_refresh := 0
var toast_revision := 0
var chat_ready_at := 0
var drawer_section := ""
var last_snapshot: Dictionary = {}
var auth_mode := "register"
var goal_editor: TextEdit
var drawer_layout: Control
var auth_panel: PanelContainer
var auth_footer: VBoxContainer
var drawer_footer: VBoxContainer
var constraint_editors: Array[LineEdit] = []
var confirmation: ConfirmationDialog
var editor_original_goal := ""
var editor_original_constraints: Array[String] = []

func _ready() -> void:
	theme = TownTheme.create()
	get_tree().auto_accept_quit = not OS.has_feature("android")
	get_tree().quit_on_go_back = false
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

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_request_close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(modal):
			_request_close()

func _reset_screen() -> void:
	map_generation += 1
	report_loading = false
	town_view = null
	date_label = null
	connection_label = null
	goal_editor = null
	drawer_layout = null
	drawer_footer = null
	constraint_editors.clear()
	auth_panel = null
	auth_footer = null
	resource_labels.clear()
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	content = null
	status_label = null
	modal = null
	toast = null
	drawer_section = ""

func _label(value: String, font_size := 14, color := INK) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _paragraph(value: String, font_size := 13, color := MUTED) -> Label:
	var label := _label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, primary := false, icon_name := "") -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 36)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not icon_name.is_empty():
		button.icon = TownTheme.icon(icon_name)
		button.add_theme_constant_override("icon_max_width", 16)
	if primary:
		TownTheme.primary(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	return row

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _line_input(parent: Node, placeholder: String, maximum := 0) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = maximum
	input.custom_minimum_size.y = 36
	parent.add_child(input)
	return input

func _field(parent: Node, title: String, placeholder: String, maximum := 0) -> LineEdit:
	var row := _row(parent)
	var title_label := _label(title, 12, MUTED)
	title_label.custom_minimum_size.x = 52
	row.add_child(title_label)
	var input := _line_input(row, placeholder, maximum)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.tooltip_text = title
	return input

func _panel(parent: Node, position_value: Vector2, size_value: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	parent.add_child(panel)
	return panel

func _auth_layout() -> void:
	if not is_instance_valid(auth_panel):
		return
	var width := minf(312, size.x - 24)
	auth_panel.position = Vector2(size.x - width - 14, 14)
	auth_panel.size = Vector2(width, size.y - 28)

func _build_form_shell() -> void:
	_reset_screen()
	var town := TownView.new()
	town.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	town.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(town)
	var veil := ColorRect.new()
	veil.color = Color(0.1, 0.2, 0.15, 0.45)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(veil)
	var welcome := VBoxContainer.new()
	welcome.position = Vector2(24, 116)
	welcome.size = Vector2(maxf(160, size.x - 374), 130)
	welcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(welcome)
	welcome.add_child(_label("赛博小镇", 32, TEXT))
	welcome.add_child(_label("给生活一点期待", 19, TEXT))
	welcome.add_child(_label("为 AI 居民安排一天，\n回来听听他的故事。", 13, Color("d5e6c8")))
	auth_panel = _panel(screen, Vector2.ZERO, Vector2(312, 332))
	auth_panel.name = "WelcomePanel"
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 5)
	auth_panel.add_child(shell)
	var header := _row(shell)
	header.add_child(_label("欢迎来到小镇", 18))
	_spacer(header)
	var mark := _label("AI", 12, TownTheme.TECH)
	header.add_child(mark)
	shell.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	auth_footer = VBoxContainer.new()
	shell.add_child(auth_footer)
	status_label = _paragraph("", 12, MUTED)
	status_label.visible = false
	shell.add_child(status_label)
	_auth_layout()
	screen.resized.connect(_auth_layout)

func _show_auth() -> void:
	_build_form_shell()
	var tabs := _row(content)
	for definition in [["register", "新居民入住"], ["recover", "找回我的居民"]]:
		var tab := _button(definition[1], auth_mode == definition[0])
		tab.add_theme_font_size_override("font_size", 12)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.disabled = busy
		tab.pressed.connect(func() -> void:
			if not busy:
				auth_mode = str(definition[0])
				_show_auth()
		)
		tabs.add_child(tab)
	if auth_mode == "recover":
		_build_recover_form()
		return
	content.add_child(_label("用邀请码开始，创建属于你的居民。", 12, MUTED))
	var invite := _field(content, "邀请码", "输入测试邀请码", 100)
	var username := _field(content, "用户名", "3–20 位小写字母、数字或下划线", 20)
	var display_name := _field(content, "居民名字", "你想怎样称呼他？", 40)
	var privacy := CheckBox.new()
	privacy.name = "PrivacyConsent"
	privacy.text = "同意测试与隐私说明"
	privacy.custom_minimum_size.y = 34
	privacy.add_theme_font_size_override("font_size", 12)
	auth_footer.add_child(privacy)
	content.add_child(_paragraph("测试版只保存账号、居民、目标和聊天数据。\n恢复码用于找回账号，请妥善保存。", 11, MUTED))
	var register := _button("创建我的居民", true, "confirm")
	auth_footer.add_child(register)
	var generation := map_generation
	register.pressed.connect(func() -> void:
		if busy:
			return
		var valid_name := RegEx.new()
		valid_name.compile("^[a-z0-9_]{3,20}$")
		if invite.text.strip_edges().is_empty() or display_name.text.strip_edges().is_empty():
			_set_status("请填写邀请码和居民名字", true)
			return
		if valid_name.search(username.text.strip_edges()) == null:
			_set_status("用户名需要 3–20 位小写字母、数字或下划线", true)
			return
		if not privacy.button_pressed:
			_set_status("请先勾选测试与隐私说明", true)
			return
		busy = true
		register.disabled = true
		_set_status("正在为居民办理入住…")
		var result := await api.register(invite.text.strip_edges(), username.text.strip_edges(), display_name.text.strip_edges())
		busy = false
		if generation != map_generation:
			return
		register.disabled = false
		if not result.ok:
			_set_status(str(result.message), true)
			return
		_save_auth(result.data)
		_show_recovery_code(str(result.data.recoveryCode))
	)
	display_name.text_submitted.connect(func(_value: String) -> void: register.pressed.emit())

func _build_recover_form() -> void:
	content.add_child(_paragraph("输入用户名和入住时保存的恢复码。", 12, MUTED))
	var username := _field(content, "用户名", "你的用户名", 20)
	var recovery := _field(content, "恢复码", "入住时保存的恢复码", 120)
	var submit := _button("找回居民，回到小镇", true)
	auth_footer.add_child(submit)
	var generation := map_generation
	submit.pressed.connect(func() -> void:
		if busy:
			return
		if username.text.strip_edges().is_empty() or recovery.text.strip_edges().is_empty():
			_set_status("请填写用户名和恢复码", true)
			return
		busy = true
		submit.disabled = true
		_set_status("正在找回你的居民…")
		var result := await api.recover(username.text.strip_edges(), recovery.text.strip_edges())
		busy = false
		if generation != map_generation:
			return
		submit.disabled = false
		if not result.ok:
			_set_status(str(result.message), true)
			return
		_save_auth(result.data)
		_show_dashboard()
	)
	recovery.text_submitted.connect(func(_value: String) -> void: submit.pressed.emit())

func _save_auth(data: Dictionary) -> void:
	session.save_session(str(data.accessToken), str(data.refreshToken), str(data.username))
	api.access_token = session.access_token
	api.refresh_token = session.refresh_token
	report_cache.clear()
	goal_text = ""
	goal_constraints.clear()
	report_revision += 1

func _show_recovery_code(code: String) -> void:
	_build_form_shell()
	content.add_child(_label("居民已经准备好了", 20))
	content.add_child(_paragraph("请先保存恢复码，再进入小镇。\n完整恢复码仅在这里显示一次。", 13))
	var code_label := _label(code, 20, TownTheme.TECH)
	code_label.selectable = true
	code_label.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(code_label)
	var copy := _button("复制恢复码", false, "confirm")
	content.add_child(copy)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		_set_status("恢复码已复制，请保存到安全的位置")
	)
	var saved := CheckBox.new()
	saved.text = "我已保存恢复码"
	saved.custom_minimum_size.y = 36
	content.add_child(saved)
	var enter := _button("进入小镇", true)
	enter.disabled = true
	content.add_child(enter)
	saved.toggled.connect(func(value: bool) -> void: enter.disabled = not value)
	enter.pressed.connect(_show_dashboard)

func _show_dashboard() -> void:
	_show_loading()
	var generation := map_generation
	var result := await api.get_resident()
	if generation != map_generation:
		return
	if not result.ok:
		_build_form_shell()
		content.add_child(_label("暂时连接不上小镇", 20))
		content.add_child(_paragraph(str(result.message), 13))
		var retry := _button("重新连接", true)
		content.add_child(retry)
		retry.pressed.connect(_show_dashboard)
		var back := _button("切换账号")
		content.add_child(back)
		back.pressed.connect(_logout)
		return
	resident = result.data
	_build_map()

func _show_loading() -> void:
	_reset_screen()
	var background := ColorRect.new()
	background.color = TownTheme.GREEN
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var label := _label("正在回到小镇…", 22, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(label)

func _build_map() -> void:
	_reset_screen()
	town_view = TownView.new()
	town_view.name = "Town"
	town_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	town_view.configure(str(resident.get("displayName", "居民")), int(resident.get("appearanceSeed", 1)))
	screen.add_child(town_view)
	town_view.movement_hint.connect(_show_toast)
	_build_top_hud()
	_build_toolbar()
	toast = _label("", 12, TEXT)
	toast.name = "Toast"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", TownTheme.box(Color("355445"), Color("557b5a"), 8))
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-200, -98)
	toast.size = Vector2(400, 30)
	toast.visible = false
	screen.add_child(toast)
	var timer := Timer.new()
	timer.wait_time = 3
	timer.timeout.connect(_sync_town)
	screen.add_child(timer)
	timer.start()
	_sync_town()
	_refresh_report()
	_show_toast("点地面散步，在居民手帐里照看居民")

func _build_top_hud() -> void:
	var resident_card := _panel(screen, Vector2(12, 10), Vector2(180, 60))
	resident_card.name = "ResidentCard"
	resident_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resident_card.add_theme_stylebox_override("panel", TownTheme.box(PAPER, TownTheme.WOOD, 8))
	var card := VBoxContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 2)
	resident_card.add_child(card)
	var top := _row(card)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar := TextureRect.new()
	var portrait := AtlasTexture.new()
	portrait.atlas = load("res://assets/sunnyside/resident_%s.png" % (absi(int(resident.get("appearanceSeed", 1))) % 6))
	portrait.region = Rect2(36, 12, 24, 30)
	avatar.texture = portrait
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(24, 24)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(avatar)
	var name_label := _label(str(resident.get("displayName", "居民")), 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	var ai := _label("AI 居民", 10, TownTheme.TECH)
	top.add_child(ai)
	var values := _row(card)
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for definition in [["金币", "coins", "basket"], ["精力", "energy", "expression_working"], ["心情", "mood", "expression_love"]]:
		var value := _label("", 11)
		resource_labels[definition[1]] = value
		value.tooltip_text = str(definition[0])
		values.add_child(value)
	_update_resource_values()

	var clock := _panel(screen, Vector2(-190, 10), Vector2(132, 44))
	clock.name = "Clock"
	clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock.offset_left = -190
	clock.offset_right = -58
	var clock_column := VBoxContainer.new()
	clock_column.add_theme_constant_override("separation", 1)
	clock.add_child(clock_column)
	date_label = _label("小镇时间 · 同步中", 12)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_column.add_child(date_label)
	connection_label = _label("正在连接", 10, MUTED)
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_column.add_child(connection_label)
	var settings := _button("菜单")
	settings.name = "MenuButton"
	settings.add_theme_font_size_override("font_size", 11)
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.position = Vector2(-54, 10)
	settings.size = Vector2(42, 40)
	settings.pressed.connect(_show_leave_panel)
	screen.add_child(settings)

func _update_resource_values() -> void:
	var names := {"coins": "金币", "energy": "精力", "mood": "心情"}
	for key: String in resource_labels:
		resource_labels[key].text = "%s %s" % [names[key], int(resident.get(key, 0))]

func _build_toolbar() -> void:
	var journal := _button("居民手帐", true, "stopwatch")
	journal.name = "JournalButton"
	journal.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	journal.position = Vector2(12, -52)
	journal.size = Vector2(124, 40)
	journal.pressed.connect(_show_resident_panel)
	screen.add_child(journal)
	var chat := _button("附近聊天", false, "expression_chat")
	chat.name = "ChatButton"
	chat.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chat.position = Vector2(-110, -52)
	chat.size = Vector2(98, 40)
	chat.pressed.connect(_show_bubble_panel)
	screen.add_child(chat)

func _sync_town() -> void:
	var generation := map_generation
	if not is_instance_valid(town_view) or syncing_generation == generation:
		return
	syncing_generation = generation
	var active_town := town_view
	if active_town.has_pending_position():
		var point := active_town.resident_position
		var update := await api.update_presence(point)
		if generation != map_generation:
			return
		if update.ok:
			active_town.confirm_position(point)
		else:
			_show_toast(str(update.message), true)
	var snapshot := await api.get_town_snapshot()
	if generation != map_generation:
		return
	syncing_generation = -1
	if not snapshot.ok:
		connection_label.text = "连接中断 · 自动重试"
		connection_label.add_theme_color_override("font_color", TownTheme.ERROR)
		return
	active_town.apply_snapshot(snapshot.data)
	resident = snapshot.data.get("resident", resident)
	last_snapshot = snapshot.data
	_update_hud(snapshot.data)
	var date := str(snapshot.data.get("townDate", ""))
	if date != report_date or Time.get_ticks_msec() - last_report_refresh > 60000:
		_refresh_report()

func _update_hud(snapshot: Dictionary) -> void:
	var date := str(snapshot.get("townDate", "")).split("-")
	var day := "%s月%s日" % [int(date[1]), int(date[2])] if date.size() == 3 else "今日"
	date_label.text = "%s  %s" % [day, snapshot.get("townTime", "")]
	connection_label.text = "%s · %s 位居民" % [snapshot.get("timeOfDay", ""), town_view.neighbors.size() + 1]
	connection_label.add_theme_color_override("font_color", TownTheme.TECH)
	_update_resource_values()

func _refresh_report() -> void:
	if report_loading:
		return
	report_loading = true
	var generation := map_generation
	var revision := report_revision
	var result := await api.get_today_report()
	if generation != map_generation:
		return
	report_loading = false
	if not result.ok or revision != report_revision:
		return
	report_cache = result.data
	report_date = str(report_cache.get("townDate", ""))
	last_report_refresh = Time.get_ticks_msec()
	var previous_goal := goal_text
	goal_text = str(report_cache.goal) if report_cache.get("goal") != null else ""
	if report_cache.has("constraints") or previous_goal != goal_text:
		goal_constraints.clear()
		for value in report_cache.get("constraints", []):
			goal_constraints.append(str(value))

func _show_section(section: String) -> void:
	match section:
		"resident": _show_resident_panel()
		"goal": _show_goal_panel()
		"report": _show_report_panel()

func _drawer_layout() -> void:
	if not is_instance_valid(drawer_layout):
		return
	var width := minf(330, size.x - 24)
	drawer_layout.position = Vector2(size.x - width - 12, 12)
	drawer_layout.size = Vector2(width, size.y - 24)

func _open_modal(title_text: String, section := "") -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.name = "Drawer"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(modal)
	if is_instance_valid(town_view):
		town_view.movement_enabled = false
	drawer_section = section
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.1, 0.18, 0.13, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_request_close()
		elif event is InputEventScreenTouch and event.pressed:
			_request_close()
	)
	modal.add_child(shade)
	var panel := PanelContainer.new()
	drawer_layout = panel
	panel.name = "Panel"
	modal.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := _row(column)
	heading.add_child(_label("居民手帐" if not section.is_empty() else title_text, 20))
	_spacer(heading)
	var close := _button("×")
	close.name = "CloseButton"
	close.custom_minimum_size = Vector2(36, 36)
	close.tooltip_text = "收起 · Esc / 返回"
	close.pressed.connect(_request_close)
	heading.add_child(close)
	if not section.is_empty():
		var tabs := _row(column)
		for definition in [["近况", "resident"], ["目标", "goal"], ["日报", "report"]]:
			var tab := _button(definition[0], str(definition[1]) == section)
			tab.name = str(definition[1]).capitalize() + "Tab"
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.pressed.connect(func() -> void:
				if busy or drawer_section == str(definition[1]):
					return
				if _goal_dirty():
					_show_toast("目标还没保存，先保存或收起后放弃修改", true)
					return
				_show_section(str(definition[1]))
			)
			tabs.add_child(tab)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	drawer_footer = VBoxContainer.new()
	drawer_footer.name = "Footer"
	column.add_child(drawer_footer)
	_drawer_layout()
	modal.resized.connect(_drawer_layout)
	close.grab_focus.call_deferred()
	return body

func _request_close() -> void:
	if busy:
		_show_toast("正在保存，请稍等一下")
		return
	if is_instance_valid(confirmation):
		return
	if _goal_dirty():
		var current_modal := modal
		var prompt := ConfirmationDialog.new()
		confirmation = prompt
		prompt.title = "目标尚未保存"
		prompt.dialog_text = "收起面板会放弃这次修改。"
		prompt.ok_button_text = "放弃修改"
		prompt.cancel_button_text = "继续编辑"
		add_child(prompt)
		prompt.confirmed.connect(func() -> void:
			if modal == current_modal:
				_close_modal()
			prompt.queue_free()
		)
		prompt.canceled.connect(prompt.queue_free)
		prompt.popup_centered(Vector2i(280, 140))
		return
	_close_modal()

func _goal_dirty() -> bool:
	if not is_instance_valid(goal_editor):
		return false
	if goal_editor.text.strip_edges() != editor_original_goal:
		return true
	var values: Array[String] = []
	for input in constraint_editors:
		if is_instance_valid(input) and not input.text.strip_edges().is_empty():
			values.append(input.text.strip_edges())
	return values != editor_original_constraints

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null
	drawer_layout = null
	drawer_footer = null
	constraint_editors.clear()
	goal_editor = null
	drawer_section = ""
	if is_instance_valid(town_view):
		town_view.movement_enabled = true

func _show_resident_panel() -> void:
	var body := _open_modal("我的居民", "resident")
	body.add_child(_label(str(resident.get("displayName", "居民")), 23))
	body.add_child(_label("%s · %s" % [_background_name(str(resident.get("backgroundKey", ""))), _location_name(str(resident.get("locationKey", "")))], 12, MUTED))
	for definition in [["精力", "energy"], ["心情", "mood"]]:
		var row := _row(body)
		row.add_child(_label(definition[0], 13))
		_spacer(row)
		row.add_child(_label("%s / 100" % int(resident.get(definition[1], 0)), 13, TownTheme.TECH))
		var bar := ProgressBar.new()
		bar.value = int(resident.get(definition[1], 0))
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		body.add_child(bar)
	body.add_child(_label("金币  %s" % int(resident.get("coins", 0)), 14))
	body.add_child(HSeparator.new())
	body.add_child(_label("生活节奏", 14))
	body.add_child(_paragraph("每天 06:00、12:00、18:00、22:00 行动。\n目标会影响下一次行动，回来可在日报里查看。", 12, MUTED))

func _show_goal_panel() -> void:
	var body := _open_modal("今天想做什么", "goal")
	var active_modal := modal
	var generation := map_generation
	if report_cache.is_empty():
		var loading := _label("正在读取今天的安排…", 13, MUTED)
		body.add_child(loading)
		var current := await api.get_today_report()
		if modal != active_modal or not is_instance_valid(body):
			return
		body.remove_child(loading)
		loading.queue_free()
		if not current.ok:
			body.add_child(_paragraph(str(current.message), 13, TownTheme.ERROR))
			var retry := _button("重新读取目标", true)
			retry.pressed.connect(_show_goal_panel)
			body.add_child(retry)
			return
		report_cache = current.data
		goal_text = str(current.data.goal) if current.data.get("goal") != null else ""
		goal_constraints.clear()
		for value in current.data.get("constraints", []):
			goal_constraints.append(str(value))
	editor_original_goal = goal_text
	editor_original_constraints = goal_constraints.duplicate()
	body.add_child(_label("选一个小心愿，再按你的想法修改。", 12, MUTED))
	var suggestions := _row(body)
	for definition in [["交朋友", "今天多认识朋友，和邻居交谈"], ["去探索", "今天探索小镇，看看新鲜的事"], ["好好休息", "今天好好休息，恢复精力"]]:
		var button := _button(definition[0])
		button.add_theme_font_size_override("font_size", 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		suggestions.add_child(button)
		button.pressed.connect(func() -> void:
			if is_instance_valid(goal_editor):
				goal_editor.text = str(definition[1])
				goal_editor.text_changed.emit()
		)
	var input := TextEdit.new()
	input.name = "GoalInput"
	goal_editor = input
	input.text = goal_text
	input.placeholder_text = "例如：今天多交朋友，精力不足时休息"
	input.custom_minimum_size.y = 92
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(input)
	var counter := _label("%s / 500 字" % input.text.length(), 11, MUTED)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(counter)
	body.add_child(_label("希望他注意什么？（最多两条）", 12))
	var limits: Array[LineEdit] = []
	for index in range(2):
		var limit := _line_input(body, "可选，例如：不要工作到太晚", 200)
		limit.name = "Constraint%s" % index
		if index < goal_constraints.size():
			limit.text = goal_constraints[index]
		limits.append(limit)
	constraint_editors = limits
	var feedback := _label("", 12, TownTheme.ERROR)
	drawer_footer.add_child(feedback)
	var submit := _button("保存今日目标", true, "confirm")
	submit.name = "SaveGoalButton"
	drawer_footer.add_child(submit)
	body.add_child(_paragraph("再次保存会替换今天的安排，下个行动时段生效。", 11, MUTED))
	input.text_changed.connect(func() -> void:
		counter.text = "%s / 500 字" % input.text.length()
		counter.add_theme_color_override("font_color", TownTheme.ERROR if input.text.length() > 500 else MUTED)
		submit.disabled = input.text.strip_edges().is_empty() or input.text.length() > 500 or busy
	)
	input.text_changed.emit()
	submit.pressed.connect(func() -> void:
		if busy or input.text.strip_edges().is_empty() or input.text.length() > 500:
			return
		busy = true
		submit.disabled = true
		feedback.text = "正在保存…"
		var constraints: Array[String] = []
		for limit in limits:
			if not limit.text.strip_edges().is_empty():
				constraints.append(limit.text.strip_edges())
		var instruction := input.text.strip_edges()
		var result := await api.set_goal(instruction, constraints)
		busy = false
		if generation != map_generation:
			return
		if result.ok:
			report_revision += 1
			goal_text = instruction
			goal_constraints = constraints.duplicate()
			if modal == active_modal:
				_close_modal()
			_show_toast("今日目标已保存，下次行动会参考你的安排")
			_refresh_report()
		elif modal == active_modal and is_instance_valid(submit):
			submit.disabled = false
			feedback.text = str(result.message)
	)

func _narrative(action: Dictionary) -> String:
	var outcome: Variant = JSON.parse_string(str(action.get("outcomeJson", "{}")))
	if outcome is Dictionary and not str(outcome.get("narrative", "")).is_empty():
		return str(outcome.narrative)
	return str({"WORK": "完成了一段工作", "TALK": "和邻居聊了聊", "EXPLORE": "探索了小镇", "HELP": "帮助了小镇居民", "REST": "回家好好休息"}.get(str(action.get("actionType", "")), "记录了一段小镇生活"))

func _show_report_panel() -> void:
	var body := _open_modal("居民的这一天", "report")
	var active_modal := modal
	var loading := _label("正在翻阅居民日记…", 13, MUTED)
	body.add_child(loading)
	var result := await api.get_today_report()
	if not is_instance_valid(body) or modal != active_modal:
		return
	body.remove_child(loading)
	loading.queue_free()
	if not result.ok:
		body.add_child(_paragraph(str(result.message), 13, TownTheme.ERROR))
		var retry := _button("再试一次")
		retry.pressed.connect(_show_report_panel)
		body.add_child(retry)
		return
	var report: Dictionary = result.data
	report_cache = report
	body.add_child(_label(str(report.get("townDate", "")), 12, TownTheme.TECH))
	var current_goal := str(report.goal) if report.get("goal") != null else "尚未设置，按自己的节奏生活"
	body.add_child(_label("今日目标", 14))
	body.add_child(_paragraph(current_goal, 12, MUTED))
	body.add_child(HSeparator.new())
	var actions: Array = report.get("actions", [])
	if actions.is_empty():
		body.add_child(_label("故事还在路上", 18))
		body.add_child(_paragraph("今天还没有完成的行动。居民会在下一个时段继续生活，可在「目标」里安排一个小心愿。", 13, MUTED))
		return
	for action: Dictionary in actions:
		var entry := PanelContainer.new()
		entry.add_theme_stylebox_override("panel", TownTheme.box(Color("f7eccb"), Color("decca7"), 9))
		body.add_child(entry)
		var column := VBoxContainer.new()
		entry.add_child(column)
		var slot := str({"MORNING": "早晨 · 06:00", "AFTERNOON": "午后 · 12:00", "EVENING": "傍晚 · 18:00", "NIGHT": "夜晚 · 22:00"}.get(str(action.get("timeSlot", "")), "今日"))
		column.add_child(_label(slot, 11, TownTheme.TECH))
		column.add_child(_paragraph(_narrative(action), 14))
		var outcome: Variant = JSON.parse_string(str(action.get("outcomeJson", "{}")))
		if outcome is Dictionary:
			column.add_child(_label("行动后 · 金币 %s  精力 %s  心情 %s" % [outcome.get("coins", "—"), outcome.get("energy", "—"), outcome.get("mood", "—")], 11, MUTED))
		var status := str({"COMPLETED": "已完成", "FAILED": "未完成", "PENDING": "等待行动"}.get(str(action.get("status", "")), "已记录"))
		column.add_child(_label(status, 10, MUTED))

func _show_bubble_panel() -> void:
	var body := _open_modal("和邻居打个招呼")
	var active_modal := modal
	body.add_child(_paragraph("附近的居民会看到你的话，18 秒后气泡消失。", 12, MUTED))
	var input := _line_input(body, "今天的小镇真不错…", 60)
	input.name = "ChatInput"
	var counter := _label("0 / 60 字", 11, MUTED)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(counter)
	input.text_changed.connect(func(value: String) -> void: counter.text = "%s / 60 字" % value.length())
	var feedback := _label("", 12, TownTheme.ERROR)
	body.add_child(feedback)
	var submit := _button("发送气泡", true, "expression_chat")
	submit.name = "SendChatButton"
	drawer_footer.add_child(submit)
	body.add_child(_label("每 10 秒可发一次。只对附近的居民可见。", 11, MUTED))
	var cooldown := Timer.new()
	cooldown.wait_time = 0.2
	modal.add_child(cooldown)
	var refresh := func() -> void:
		var seconds := maxi(0, ceili((chat_ready_at - Time.get_ticks_msec()) / 1000.0))
		submit.text = "再等 %s 秒" % seconds if seconds > 0 else "发送气泡"
		submit.disabled = seconds > 0 or busy or input.text.strip_edges().is_empty()
	cooldown.timeout.connect(refresh)
	input.text_changed.connect(func(_value: String) -> void: refresh.call())
	cooldown.start()
	refresh.call()
	input.grab_focus.call_deferred()
	submit.pressed.connect(func() -> void:
		var message := input.text.strip_edges()
		if busy or message.is_empty() or Time.get_ticks_msec() < chat_ready_at:
			return
		if not is_instance_valid(town_view) or not town_view.initialized:
			feedback.text = "小镇还在同步，请稍后再试"
			return
		busy = true
		submit.disabled = true
		feedback.text = "正在发送…"
		var generation := map_generation
		while syncing_generation == generation and generation == map_generation:
			await get_tree().process_frame
		if generation != map_generation or modal != active_modal:
			busy = false
			return
		if town_view.has_pending_position():
			var point := town_view.resident_position
			var update := await api.update_presence(point)
			if generation != map_generation:
				busy = false
				return
			if not update.ok:
				busy = false
				if modal == active_modal:
					feedback.text = str(update.message)
					refresh.call()
				return
			town_view.confirm_position(point)
		var result := await api.send_bubble(message)
		busy = false
		if generation != map_generation:
			return
		if result.ok:
			chat_ready_at = Time.get_ticks_msec() + 10000
			if modal == active_modal:
				_close_modal()
			_show_toast("气泡已发送，附近的居民可以看到")
			_sync_town()
		elif modal == active_modal and is_instance_valid(submit):
			feedback.text = str(result.message)
			if int(result.status) == 429:
				chat_ready_at = Time.get_ticks_msec() + 10000
			refresh.call()
	)
	input.text_submitted.connect(func(_value: String) -> void:
		if not submit.disabled:
			submit.pressed.emit()
	)

func _show_leave_panel() -> void:
	var body := _open_modal("小镇菜单")
	body.add_child(_label("散步与交流", 16))
	body.add_child(_paragraph("点地面散步，在居民手帐里查看近况、目标和日报。\n电脑也可以用 WASD / 方向键移动。\nEsc 或返回键可以收起面板。", 12, MUTED))
	body.add_child(HSeparator.new())
	body.add_child(_label("离开游戏后，居民仍会继续生活。", 13))
	body.add_child(_paragraph("切换账号会清除本机登录信息，之后需用恢复码找回。", 12, MUTED))
	var logout := _button("退出本机账号")
	logout.pressed.connect(func() -> void:
		var confirm := ConfirmationDialog.new()
		confirm.title = "退出本机账号"
		confirm.dialog_text = "请确认已经保存恢复码。退出后需要恢复码重新进入。"
		confirm.ok_button_text = "退出账号"
		confirm.cancel_button_text = "留在小镇"
		add_child(confirm)
		confirm.confirmed.connect(func() -> void:
			_logout()
			confirm.queue_free()
		)
		confirm.canceled.connect(confirm.queue_free)
		confirm.popup_centered(Vector2i(300, 160))
	)
	body.add_child(logout)

func _logout() -> void:
	session.clear()
	api.access_token = ""
	api.refresh_token = ""
	report_cache.clear()
	goal_text = ""
	goal_constraints.clear()
	report_revision += 1
	_show_auth()

func _show_toast(message: String, is_error := false) -> void:
	if not is_instance_valid(toast):
		return
	toast_revision += 1
	var revision := toast_revision
	var active_toast := toast
	active_toast.text = message
	active_toast.visible = true
	active_toast.add_theme_color_override("font_color", Color("ffdbb8") if is_error else TEXT)
	await get_tree().create_timer(4 if is_error else 3).timeout
	if revision == toast_revision and is_instance_valid(active_toast):
		active_toast.visible = false

func _set_status(message: String, is_error := false) -> void:
	if is_instance_valid(status_label):
		status_label.visible = not message.is_empty()
		status_label.text = message
		status_label.add_theme_color_override("font_color", TownTheme.ERROR if is_error else TownTheme.TECH)

func _location_name(key: String) -> String:
	return str({"residential": "在住宅区", "square": "在中心广场", "workshop": "在居民工坊"}.get(key, "在小镇里"))

func _background_name(key: String) -> String:
	return str({"corporate_clerk": "公司职员", "repair_apprentice": "维修学徒", "street_artist": "街头艺术家", "data_archivist": "数据档案员", "courier": "快递员", "traveler": "旅行者"}.get(key, "小镇居民"))
