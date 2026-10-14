extends SceneTree

class FakeApi extends CyberTownApiClient:
	var refresh_calls := 0

	func refresh_session(_token: String) -> Dictionary:
		refresh_calls += 1
		await get_tree().process_frame
		return {"ok": true, "data": {"accessToken": "new-access", "refreshToken": "new-refresh"}}

var results: Array[bool] = []
var failed := false
var saved_sessions := 0


func _initialize() -> void:
	_run.call_deferred()


func _collect(api: CyberTownApiClient) -> void:
	results.append(await api._renew_session())


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	var api := FakeApi.new()
	root.add_child(api)
	api.access_token = "old-access"
	api.refresh_token = "old-refresh"
	api.session_refreshed.connect(func(_access: String, _refresh: String) -> void: saved_sessions += 1)
	_collect(api)
	_collect(api)
	while results.size() < 2:
		await process_frame
	_check(api.refresh_calls == 1, "Concurrent requests must share a single refresh-token rotation")
	_check(results == [true, true], "Both waiting requests must receive the refresh outcome")
	_check(api.access_token == "new-access" and saved_sessions == 1, "Rotated session must be persisted exactly once")
	results.clear()
	_collect(api)
	api.access_token = ""
	api.refresh_token = ""
	while results.is_empty():
		await process_frame
	_check(results == [false] and api.access_token.is_empty() and saved_sessions == 1,
		"A pending renewal must not restore a session after logout")
	api.queue_free()
	await process_frame
	print("API session smoke checks: %s" % ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
