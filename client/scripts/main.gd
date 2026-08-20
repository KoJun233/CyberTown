extends Control

const BG_COLOR := Color("10131f")
const PANEL_COLOR := Color("1b2033")
const ACCENT_COLOR := Color("5eead4")
const TEXT_COLOR := Color("e7f7f5")
const MUTED_COLOR := Color("9aa9b8")

var api: CyberTownApiClient
var session := SessionStore.new()
var content: VBoxContainer
var status_label: Label
var busy := false


func _ready() -> void:
	api = CyberTownApiClient.new()
	add_child(api)
	session.load_session()
	api.access_token = session.access_token
	_build_shell()
	if session.access_token.is_empty():
		_show_auth()
	else:
		_show_dashboard()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 24)
	safe_margin.add_theme_constant_override("margin_right", 24)
	safe_margin.add_theme_constant_override("margin_top", 16)
	safe_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(safe_margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 12)
	safe_margin.add_child(root_column)

	var title := Label.new()
	title.text = "赛博小镇  CYBERTOWN"
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.add_theme_font_size_override("font_size", 24)
	root_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "让你的 AI 居民在霓虹灯下继续生活"
	subtitle.add_theme_color_override("font_color", MUTED_COLOR)
	root_column.add_child(subtitle)

	var separator := HSeparator.new()
	root_column.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_column.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", MUTED_COLOR)
	root_column.add_child(status_label)


func _show_auth() -> void:
	_clear_content()
	_add_heading("使用邀请码进入小镇")
	_add_paragraph("测试阶段不使用邮箱。注册成功后请立即保存恢复码。")

	var invite := _add_line_edit("邀请码")
	var username := _add_line_edit("用户名（3–20 位小写字母、数字或下划线）")
	var display_name := _add_line_edit("居民名称")
	var privacy := CheckBox.new()
	privacy.text = "我已阅读并同意测试与隐私说明"
	privacy.button_pressed = false
	content.add_child(privacy)

	var register_button := _add_button("生成我的居民")
	register_button.pressed.connect(func() -> void:
		if busy:
			return
		if not privacy.button_pressed:
			_set_status("请先同意测试与隐私说明", true)
			return
		busy = true
		register_button.disabled = true
		_set_status("正在创建居民…")
		var result := await api.register(invite.text, username.text, display_name.text)
		busy = false
		register_button.disabled = false
		if not result.ok:
			_set_status(result.message, true)
			return
		var data: Dictionary = result.data
		session.save_session(str(data.accessToken), str(data.refreshToken), str(data.username))
		api.access_token = session.access_token
		_show_recovery_code(str(data.recoveryCode))
	)

	var recover_separator := HSeparator.new()
	content.add_child(recover_separator)
	_add_heading("已有居民？")
	var recover_username := _add_line_edit("用户名")
	var recovery_code := _add_line_edit("恢复码")
	var recover_button := _add_button("恢复账号")
	recover_button.pressed.connect(func() -> void:
		if busy:
			return
		busy = true
		recover_button.disabled = true
		var result := await api.recover(recover_username.text, recovery_code.text)
		busy = false
		recover_button.disabled = false
		if not result.ok:
			_set_status(result.message, true)
			return
		var data: Dictionary = result.data
		session.save_session(str(data.accessToken), str(data.refreshToken), str(data.username))
		api.access_token = session.access_token
		_show_dashboard()
	)


func _show_recovery_code(code: String) -> void:
	_clear_content()
	_add_heading("居民创建成功")
	_add_paragraph("这是唯一一次完整显示恢复码。请保存到安全位置：")
	var code_label := Label.new()
	code_label.text = code
	code_label.selectable = true
	code_label.add_theme_color_override("font_color", ACCENT_COLOR)
	code_label.add_theme_font_size_override("font_size", 20)
	content.add_child(code_label)
	var copy_button := _add_button("复制恢复码")
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code)
		_set_status("恢复码已复制")
	)
	var continue_button := _add_button("我已保存，进入小镇")
	continue_button.pressed.connect(_show_dashboard)


func _show_dashboard() -> void:
	_clear_content()
	_add_heading("今日居民状态")
	_set_status("正在连接小镇…")
	var resident_result := await api.get_resident()
	if not resident_result.ok and int(resident_result.status) == 401 and not session.refresh_token.is_empty():
		var refresh_result := await api.refresh_session(session.refresh_token)
		if refresh_result.ok:
			var refresh_data: Dictionary = refresh_result.data
			session.save_session(str(refresh_data.accessToken), str(refresh_data.refreshToken), session.username)
			api.access_token = session.access_token
			resident_result = await api.get_resident()
	if not resident_result.ok:
		_set_status(resident_result.message, true)
		var retry := _add_button("返回登录")
		retry.pressed.connect(func() -> void:
			session.clear()
			api.access_token = ""
			_show_auth()
		)
		return

	var resident: Dictionary = resident_result.data
	_add_stat_row("居民", str(resident.displayName))
	_add_stat_row("背景", str(resident.backgroundKey))
	_add_stat_row("金币", str(resident.coins))
	_add_stat_row("精力", str(resident.energy))
	_add_stat_row("心情", str(resident.mood))
	_add_stat_row("位置", str(resident.locationKey))

	_add_heading("小镇现场")
	_add_paragraph("点击道路或草地，让居民走到目标位置。当前是可交互的像素占位场景。")
	var town := TownView.new()
	town.configure(str(resident.displayName), int(resident.appearanceSeed))
	content.add_child(town)

	var separator := HSeparator.new()
	content.add_child(separator)
	_add_heading("今天想让居民做什么？")
	var goal_input := TextEdit.new()
	goal_input.placeholder_text = "例如：今天努力赚钱，但不要透支精力"
	goal_input.custom_minimum_size.y = 72
	content.add_child(goal_input)
	var goal_button := _add_button("确认今日目标")
	goal_button.pressed.connect(func() -> void:
		if busy:
			return
		busy = true
		goal_button.disabled = true
		var result := await api.set_goal(goal_input.text)
		busy = false
		goal_button.disabled = false
		_set_status("目标已确认，将从下一个行动时段生效" if result.ok else result.message, not result.ok)
	)

	var report_button := _add_button("查看今日日报")
	report_button.pressed.connect(_show_report)
	var logout_button := _add_button("退出本机账号")
	logout_button.pressed.connect(func() -> void:
		session.clear()
		api.access_token = ""
		_show_auth()
	)
	_set_status("已连接小镇")


func _show_report() -> void:
	_clear_content()
	_add_heading("今日日报")
	var result := await api.get_today_report()
	if not result.ok:
		_set_status(result.message, true)
		var back_error := _add_button("返回")
		back_error.pressed.connect(_show_dashboard)
		return
	var report: Dictionary = result.data
	_add_stat_row("小镇日期", str(report.townDate))
	_add_stat_row("今日目标", str(report.goal) if report.goal != null else "尚未设置")
	var actions: Array = report.get("actions", [])
	if actions.is_empty():
		_add_paragraph("今天还没有完成的行动。居民会在下一个时段继续生活。")
	else:
		for action: Dictionary in actions:
			_add_paragraph("%s · %s · %s" % [action.timeSlot, action.actionType, action.status])
	var back := _add_button("返回居民状态")
	back.pressed.connect(_show_dashboard)
	_set_status("日报已更新")


func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()
	_set_status("")


func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 20)
	content.add_child(label)


func _add_paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED_COLOR)
	content.add_child(label)


func _add_line_edit(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size.y = 40
	content.add_child(input)
	return input


func _add_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	content.add_child(button)
	return button


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 96
	label.add_theme_color_override("font_color", MUTED_COLOR)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(label)
	row.add_child(value)
	content.add_child(row)


func _set_status(message: String, is_error := false) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("fb7185") if is_error else MUTED_COLOR)
