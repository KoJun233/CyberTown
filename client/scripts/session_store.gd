class_name SessionStore
extends RefCounted

const SESSION_PATH := "user://session.cfg"

var session_path := SESSION_PATH
var access_token := ""
var refresh_token := ""
var username := ""


func use_profile(profile: String) -> void:
	var pattern := RegEx.new()
	pattern.compile("^[a-zA-Z0-9_-]{1,32}$")
	if pattern.search(profile) != null:
		session_path = "user://session-%s.cfg" % profile


func load_session() -> void:
	var config := ConfigFile.new()
	if config.load(session_path) != OK:
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
	config.save(session_path)


func clear() -> void:
	access_token = ""
	refresh_token = ""
	username = ""
	var config := ConfigFile.new()
	config.save(session_path)
