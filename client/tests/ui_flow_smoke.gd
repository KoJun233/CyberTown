extends SceneTree

class FakeApi extends CyberTownApiClient:
	var goal := "今天探索小镇"
	var constraints: Array[String] = ["精力不足就休息"]
	var messages := 0
	var fail_resident := false
	func get_resident() -> Dictionary:
		await get_tree().process_frame
		if fail_resident:
			return {"ok": false, "message": "测试断网", "status": 0}
		return {"ok": true, "data": {"displayName": "小柚", "appearanceSeed": 2, "energy": 80, "mood": 72, "coins": 120, "locationKey": "square"}}
	func get_town_snapshot() -> Dictionary:
		await get_tree().process_frame
		return {"ok": true, "data": {"serverTime": "2026-10-14T12:00:00Z", "townDate": "2026-10-14", "townTime": "20:00", "timeOfDay": "傍晚", "residents": [{"id": "fixture", "displayName": "小柚", "appearanceSeed": 2, "posX": 320, "posY": 196, "current": true}], "bubbles": []}}
	func get_today_report() -> Dictionary:
		await get_tree().process_frame
		return {"ok": true, "data": {"townDate": "2026-10-14", "goal": goal, "constraints": constraints, "actions": [{"timeSlot": "EVENING", "actionType": "TALK", "status": "COMPLETED", "outcomeJson": '{"narrative":"在广场与邻居聊了聊","coins":120,"energy":72,"mood":80}'}]}}
	func set_goal(instruction: String, limits: Array[String] = []) -> Dictionary:
		await get_tree().process_frame
		goal = instruction
		constraints = limits
		return {"ok": true, "data": {"instruction": goal, "constraints": constraints}}
	func send_bubble(_message: String) -> Dictionary:
		await get_tree().process_frame
		messages += 1
		return {"ok": true, "status": 201, "data": {}}

class UiHarness extends "res://scripts/main.gd":
	func _ready() -> void:
		theme = TownTheme.create()
		api = FakeApi.new()
		add_child(api)
		resident = {"displayName": "小柚", "appearanceSeed": 2, "energy": 80, "mood": 72, "coins": 120, "locationKey": "square"}

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _settle() -> void:
	for index in range(5):
		await process_frame

func _run() -> void:
	var ui := UiHarness.new()
	ui.size = Vector2(640, 360)
	root.add_child(ui)
	ui._build_map()
	await _settle()
	for name in ["ResidentCard", "Clock", "JournalButton", "ChatButton", "MenuButton"]:
		var control: Control = ui.screen.get_node(name)
		_check(Rect2(Vector2.ZERO, ui.size).encloses(control.get_rect()), name + " must fit inside the viewport")
	_check(ui.goal_text == "今天探索小镇", "Current goal must load from the report")
	_check(ui.screen.find_children("*", "Button", true, false).size() == 3, "The home screen must have only journal, chat and menu actions")
	ui.screen.get_node("JournalButton").pressed.emit()
	await _settle()
	_check(ui.drawer_section == "resident", "The journal must open resident status")
	_check(ui.modal.get_node("Panel").find_child("Body", true, false).find_children("*", "Button", true, false).is_empty(), "Status must not duplicate the journal's goal and report tabs")
	ui.modal.find_child("GoalTab", true, false).pressed.emit()
	await _settle()
	_check(ui.drawer_section == "goal", "Journal tabs must provide access to goal editing")
	ui._close_modal()
	ui.size = Vector2(800, 360)
	await _settle()
	_check(ui.town_view.view_to_world(Vector2(400, 180)) == Vector2(320, 180), "Wide phone layouts must retain the world aspect ratio")
	_check(Rect2(Vector2.ZERO, ui.size).encloses(ui.screen.get_node("JournalButton").get_rect()), "Journal entry must follow wide phone resizing")
	ui.size = Vector2(640, 360)
	ui._show_goal_panel()
	await _settle()
	_check(not ui.town_view.movement_enabled, "Opening a drawer must stop keyboard movement")
	_check(not ui._goal_dirty(), "Existing saved constraints must not count as an unsaved change")
	var editor: TextEdit = ui.modal.find_child("GoalInput", true, false)
	var submit: Button = ui.modal.find_child("SaveGoalButton", true, false)
	editor.text = "字".repeat(501)
	editor.text_changed.emit()
	_check(submit.disabled, "Overlong goals must not be submitted")
	editor.text = "今天多认识朋友"
	editor.text_changed.emit()
	ui.constraint_editors[0].text = "不要熬夜"
	_check(ui._goal_dirty(), "Changed goal constraints must be protected from accidental dismissal")
	await _settle()
	_check(submit.get_global_rect().end.y <= ui.size.y - 12, "Primary goal action must remain visible without scrolling")
	submit.pressed.emit()
	await _settle()
	_check(ui.modal == null and ui.goal_text == "今天多认识朋友", "Successful goal save must keep the current goal and close the drawer")
	_check(ui.goal_constraints == ["不要熬夜"], "Goal restrictions must survive saving and reloading")
	ui._show_bubble_panel()
	await _settle()
	var chat: LineEdit = ui.modal.find_child("ChatInput", true, false)
	var send: Button = ui.modal.find_child("SendChatButton", true, false)
	_check(send.disabled, "Empty chat must not be sent")
	chat.text = "你好"
	chat.text_changed.emit(chat.text)
	send.pressed.emit()
	await _settle()
	_check(ui.api.messages == 1 and ui.modal == null, "Chat must send once and close on success")
	ui._show_bubble_panel()
	await _settle()
	_check(ui.modal.find_child("SendChatButton", true, false).disabled, "Chat cooldown must survive reopening the drawer")
	ui._close_modal()
	_check(ui.town_view.movement_enabled, "Closing the drawer must restore movement")
	ui._show_report_panel()
	await _settle()
	_check(ui._narrative({"outcomeJson": '{"narrative":"真实经历"}'}) == "真实经历", "Diary must display the server narrative")
	ui._show_auth()
	await _settle()
	_check(Rect2(Vector2.ZERO, ui.size).encloses(ui.auth_panel.get_rect()), "Registration form must fit the phone canvas")
	var consent: CheckBox = ui.auth_panel.find_child("PrivacyConsent", true, false)
	_check(Rect2(Vector2.ZERO, ui.size).encloses(consent.get_global_rect()), "Consent must remain visible alongside the registration action")
	ui.api.fail_resident = true
	ui.api.access_token = "fixture-token"
	ui._show_dashboard()
	await _settle()
	_check(ui.api.access_token == "fixture-token", "Network failure must preserve the current account")
	ui.queue_free()
	await process_frame
	print("UI flow smoke checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
