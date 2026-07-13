extends RefCounted
class_name ForgeTheme

const BACKGROUND := Color("#08100F")
const SURFACE := Color("#121918")
const SURFACE_RAISED := Color("#192220")
const SURFACE_SOFT := Color("#202B28")
const BORDER := Color("#31413D")
const BORDER_STRONG := Color("#49635C")
const TEXT := Color("#F4F8F6")
const MUTED := Color("#A8B7B2")
const FAINT := Color("#71817C")
const TEAL := Color("#39E6D3")
const TEAL_SOFT := Color("#173D38")
const LIME := Color("#ADF06D")
const AMBER := Color("#FFBE5C")
const RED := Color("#FF746E")
const BLUE := Color("#77B8FF")


static func build() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16

	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", BACKGROUND)
	result.set_color("font_focus_color", "Button", TEXT)
	result.set_color("font_disabled_color", "Button", FAINT)
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", FAINT)
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_color("font_hover_color", "OptionButton", TEXT)
	result.set_color("font_pressed_color", "OptionButton", TEXT)
	result.set_color("font_color", "CheckButton", TEXT)
	result.set_color("font_hover_color", "CheckButton", TEXT)
	result.set_color("font_pressed_color", "CheckButton", TEXT)
	result.set_color("font_color", "SpinBox", TEXT)

	result.set_font_size("font_size", "Button", 15)
	result.set_font_size("font_size", "LineEdit", 15)
	result.set_font_size("font_size", "OptionButton", 15)
	result.set_font_size("font_size", "CheckButton", 15)
	result.set_font_size("font_size", "SpinBox", 15)
	result.set_font_size("font_size", "TooltipLabel", 14)

	result.set_stylebox("panel", "PanelContainer", panel_style(SURFACE, 16, BORDER, 1))
	result.set_stylebox("panel", "MarginContainer", StyleBoxEmpty.new())
	result.set_stylebox("normal", "Button", button_style(SURFACE_RAISED, BORDER, 12))
	result.set_stylebox("hover", "Button", button_style(SURFACE_SOFT, BORDER_STRONG, 12))
	result.set_stylebox("pressed", "Button", button_style(TEAL, TEAL, 12))
	result.set_stylebox("disabled", "Button", button_style(SURFACE, BORDER, 12))
	result.set_stylebox("focus", "Button", focus_style(12))
	result.set_stylebox("normal", "LineEdit", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("read_only", "LineEdit", input_style(SURFACE, BORDER))
	result.set_stylebox("focus", "LineEdit", focus_style(12))
	result.set_stylebox("normal", "OptionButton", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("hover", "OptionButton", input_style(SURFACE_SOFT, BORDER_STRONG))
	result.set_stylebox("pressed", "OptionButton", input_style(SURFACE_SOFT, TEAL))
	result.set_stylebox("focus", "OptionButton", focus_style(12))
	result.set_stylebox("normal", "SpinBox", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("focus", "SpinBox", focus_style(12))
	result.set_stylebox("normal", "TooltipPanel", panel_style(Color("#26302E"), 10, BORDER_STRONG, 1))

	result.set_constant("h_separation", "HBoxContainer", 12)
	result.set_constant("v_separation", "VBoxContainer", 12)
	result.set_constant("separation", "GridContainer", 12)
	result.set_constant("outline_size", "Label", 0)
	result.set_constant("minimum_character_width", "LineEdit", 8)
	result.set_constant("scroll_deadzone", "ScrollContainer", 12)

	result.set_color("font_color", "RichTextLabel", TEXT)
	result.set_color("default_color", "RichTextLabel", TEXT)
	result.set_color("font_outline_color", "RichTextLabel", Color.TRANSPARENT)
	result.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	result.set_color("grabber_area", "HSlider", TEAL_SOFT)
	result.set_color("grabber_area_highlight", "HSlider", TEAL_SOFT)
	result.set_icon("grabber", "HSlider", _circle_texture(10, TEAL))
	result.set_icon("grabber_highlight", "HSlider", _circle_texture(12, LIME))
	result.set_stylebox("slider", "HSlider", _track_style(SURFACE_SOFT, 6))
	result.set_stylebox("grabber_area", "HSlider", _track_style(TEAL, 6))
	result.set_stylebox("grabber_area_highlight", "HSlider", _track_style(LIME, 6))

	return result


static func panel_style(
	background: Color,
	radius: int = 16,
	border_color: Color = BORDER,
	border_width: int = 1,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.anti_aliasing = true
	return style


static func button_style(background: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := panel_style(background, radius, border_color, 1)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


static func primary_button_style() -> StyleBoxFlat:
	return button_style(TEAL, TEAL, 12)


static func input_style(background: Color, border_color: Color) -> StyleBoxFlat:
	var style := panel_style(background, 12, border_color, 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func focus_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = LIME
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.expand_margin_left = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_bottom = 2.0
	return style


static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(TEAL, TEAL, 12))
	button.add_theme_stylebox_override("hover", button_style(LIME, LIME, 12))
	button.add_theme_stylebox_override("pressed", button_style(Color("#25B9AA"), Color("#25B9AA"), 12))
	button.add_theme_color_override("font_color", BACKGROUND)
	button.add_theme_color_override("font_hover_color", BACKGROUND)
	button.add_theme_color_override("font_pressed_color", BACKGROUND)
	button.custom_minimum_size.y = 48.0


static func apply_danger(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color("#34201F"), Color("#6D3A37"), 12))
	button.add_theme_stylebox_override("hover", button_style(Color("#4A2927"), RED, 12))
	button.add_theme_color_override("font_color", RED)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.custom_minimum_size.y = 48.0


static func apply_segment(button: Button, active: bool) -> void:
	var background := TEAL_SOFT if active else SURFACE_RAISED
	var border_color := TEAL if active else BORDER
	button.add_theme_stylebox_override("normal", button_style(background, border_color, 12))
	button.add_theme_stylebox_override("hover", button_style(SURFACE_SOFT, BORDER_STRONG, 12))
	button.add_theme_color_override("font_color", TEXT if active else MUTED)
	button.custom_minimum_size.y = 48.0


static func _track_style(color: Color, height: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = height
	style.corner_radius_top_right = height
	style.corner_radius_bottom_left = height
	style.corner_radius_bottom_right = height
	style.content_margin_top = float(height) / 2.0
	style.content_margin_bottom = float(height) / 2.0
	return style


static func _circle_texture(radius: int, color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, color])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = radius * 2
	texture.height = radius * 2
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
