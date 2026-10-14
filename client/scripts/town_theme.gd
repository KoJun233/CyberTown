class_name TownTheme
extends RefCounted

const INK := Color("314e40")
const MUTED := Color("78836d")
const PAPER := Color("fff6db")
const WOOD := Color("a57552")
const GREEN := Color("406750")
const TECH := Color("388c88")
const ERROR := Color("b34e47")

static func box(fill: Color, border := Color("bea078"), padding := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(padding)
	return style

static func panel_style() -> StyleBoxFlat:
	var style := box(PAPER, WOOD, 10)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.14, 0.22, 0.14, 0.2)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style

static func create() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	result.default_font_size = 14
	result.set_color("font_color", "Label", INK)
	result.set_constant("line_spacing", "Label", 3)
	result.set_stylebox("panel", "PanelContainer", panel_style())
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := PAPER
		if state == "hover":
			fill = Color("e6edcf")
		elif state == "pressed":
			fill = Color("b6cfaa")
		elif state == "disabled":
			fill = Color("dddcc9")
		var style := box(fill)
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		result.set_stylebox(state, "Button", style)
		result.set_color("font_" + state + "_color" if state != "normal" else "font_color", "Button", MUTED if state == "disabled" else INK)
	var focus := box(Color.TRANSPARENT, TECH, 0)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_color("font_focus_color", "Button", INK)
	for type in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type, box(Color("fffdf0")))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, TECH, 8))
		result.set_color("font_color", type, INK)
		result.set_color("font_placeholder_color", type, MUTED)
		result.set_color("caret_color", type, TECH)
		result.set_color("selection_color", type, Color("bddfc9"))
	result.set_color("font_color", "CheckBox", INK)
	result.set_color("font_hover_color", "CheckBox", GREEN)
	result.set_stylebox("background", "ProgressBar", box(Color("d7dec5"), Color("d7dec5"), 0))
	result.set_stylebox("fill", "ProgressBar", box(TECH, TECH, 0))
	result.set_stylebox("separator", "HSeparator", box(Color("dcc8a2"), Color("dcc8a2"), 0))
	result.set_constant("separation", "VBoxContainer", 7)
	result.set_constant("separation", "HBoxContainer", 7)
	return result

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(GREEN, GREEN))
	button.add_theme_stylebox_override("hover", box(Color("537c5d"), GREEN))
	button.add_theme_stylebox_override("pressed", box(Color("305242"), GREEN))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, PAPER)

static func icon(name: String) -> Texture2D:
	return load("res://assets/sunnyside/UI/" + name + ".png")
