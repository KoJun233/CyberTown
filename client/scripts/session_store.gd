class_name SessionStore
extends RefCounted

const SESSION_PATH := "user://session.cfg"

var access_token := ""
var refresh_token := ""
var username := ""


func load_session() -> void:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return
	access_token = str(config.get_value("session", "access_token", ""))
	refresh_token = str(config.get_value("session", "refresh_token", ""))
	username = str(config.get_value("session", "username", ""))


func save_session(new_access_token: String, new_refresh_token: String, new_username: String) -> void:
	access_token = new_access_token
	refresh_token = new_refresh_token
	username = new_username
	var config := ConfigFile.new()
	config.set_value("session", "access_token", access_token)
	config.set_value("session", "refresh_token", refresh_token)
	config.set_value("session", "username", username)
	config.save(SESSION_PATH)


func clear() -> void:
	access_token = ""
	refresh_token = ""
	username = ""
	var config := ConfigFile.new()
	config.save(SESSION_PATH)
