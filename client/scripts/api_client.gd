class_name CyberTownApiClient
extends Node

var access_token := ""
var base_url := "http://127.0.0.1:8080/api"


func _ready() -> void:
	base_url = str(ProjectSettings.get_setting("cybertown/api_base_url", base_url)).trim_suffix("/")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--api-base-url="):
			base_url = argument.trim_prefix("--api-base-url=").trim_suffix("/")


func register(invite_code: String, username: String, display_name: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/auth/register", {
		"inviteCode": invite_code,
		"username": username,
		"displayName": display_name,
		"privacyAccepted": true,
	}, false)


func recover(username: String, recovery_code: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/auth/recover", {
		"username": username,
		"recoveryCode": recovery_code,
	}, false)


func refresh_session(refresh_token: String) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/auth/refresh", {
		"refreshToken": refresh_token,
	}, false)


func get_resident() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/me/resident")


func set_goal(instruction: String, constraints: Array[String] = []) -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/goals", {
		"instruction": instruction,
		"constraints": constraints,
	})


func get_today_report() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/reports/today")


func _request_json(method: HTTPClient.Method, path: String, payload: Dictionary = {}, authenticated := true) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated and not access_token.is_empty():
		headers.append("Authorization: Bearer %s" % access_token)
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var request_error := request.request(base_url + path, headers, method, body)
	if request_error != OK:
		request.queue_free()
		return {"ok": false, "status": 0, "message": "无法发送网络请求（%s）" % request_error}
	var response: Array = await request.request_completed
	request.queue_free()
	var response_code := int(response[1])
	var raw_body: PackedByteArray = response[3]
	var text := raw_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.strip_edges().is_empty() else null
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if response_code >= 200 and response_code < 300:
		return {"ok": true, "status": response_code, "data": data}
	return {
		"ok": false,
		"status": response_code,
		"message": str(data.get("message", "服务器返回错误 %s" % response_code)),
		"data": data,
	}
