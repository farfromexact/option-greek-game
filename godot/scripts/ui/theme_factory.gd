extends RefCounted
class_name ForgeTheme

const BACKGROUND := Color("#F8F8F7")
const SURFACE := Color("#FFFFFF")
const SURFACE_RAISED := Color("#FAFAF9")
const SURFACE_SOFT := Color("#F1F1EF")
const BORDER := Color("#E5E5E2")
const BORDER_STRONG := Color("#D4D4D0")
const TEXT := Color("#121212")
const MUTED := Color("#686865")
const FAINT := Color("#92928D")
const TEAL := Color("#168B72")
const TEAL_SOFT := Color("#E8F3F0")
const LIME := Color("#2D8A4E")
const AMBER := Color("#B87518")
const RED := Color("#C94545")
const BLUE := Color("#2375C9")


static func build() -> Theme:
	var result := Theme.new()
	result.default_font = _system_font(430)
	result.default_font_size = 16
	result.set_font("font", "Button", _system_font(520))
	result.set_type_variation("ForgeHeading", "Label")
	result.set_font("font", "ForgeHeading", _system_font(610))
	result.set_type_variation("ForgeStrong", "Label")
	result.set_font("font", "ForgeStrong", _system_font(540))

	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_pressed_color", "Button", TEXT)
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

	result.set_color("caret_color", "LineEdit", TEXT)
	result.set_color("selection_color", "LineEdit", Color(TEAL, 0.18))

	result.set_stylebox("panel", "PanelContainer", panel_style(SURFACE, 12, BORDER, 1))
	result.set_stylebox("panel", "MarginContainer", StyleBoxEmpty.new())
	result.set_stylebox("normal", "Button", button_style(SURFACE, BORDER, 10))
	result.set_stylebox("hover", "Button", button_style(SURFACE_SOFT, BORDER_STRONG, 10))
	result.set_stylebox("pressed", "Button", button_style(SURFACE_SOFT, TEXT, 10))
	result.set_stylebox("disabled", "Button", button_style(SURFACE_RAISED, BORDER, 10))
	result.set_stylebox("focus", "Button", focus_style(10))
	result.set_stylebox("normal", "LineEdit", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("read_only", "LineEdit", input_style(SURFACE, BORDER))
	result.set_stylebox("focus", "LineEdit", focus_style(10))
	result.set_stylebox("normal", "OptionButton", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("hover", "OptionButton", input_style(SURFACE_SOFT, BORDER_STRONG))
	result.set_stylebox("pressed", "OptionButton", input_style(SURFACE_SOFT, TEXT))
	result.set_stylebox("focus", "OptionButton", focus_style(10))
	result.set_stylebox("normal", "SpinBox", input_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("focus", "SpinBox", focus_style(10))
	result.set_stylebox("normal", "TooltipPanel", panel_style(Color("#FFFFFF"), 9, BORDER_STRONG, 1))

	result.set_constant("h_separation", "HBoxContainer", 14)
	result.set_constant("v_separation", "VBoxContainer", 14)
	result.set_constant("separation", "GridContainer", 14)
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
	result.set_stylebox("scroll", "VScrollBar", _scroll_style(Color.TRANSPARENT, 7))
	result.set_stylebox("grabber", "VScrollBar", _scroll_style(Color("#D8D8D4"), 7))
	result.set_stylebox("grabber_highlight", "VScrollBar", _scroll_style(Color("#BEBEB9"), 7))
	result.set_stylebox("grabber_pressed", "VScrollBar", _scroll_style(Color("#A7A7A2"), 7))
	result.set_constant("minimum_grab_thickness", "VScrollBar", 28)

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
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	style.anti_aliasing = true
	return style


static func button_style(background: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := panel_style(background, radius, border_color, 1)
	style.content_margin_left = 17.0
	style.content_margin_right = 17.0
	style.content_margin_top = 11.0
	style.content_margin_bottom = 11.0
	return style


static func primary_button_style() -> StyleBoxFlat:
	return button_style(TEXT, TEXT, 10)


static func input_style(background: Color, border_color: Color) -> StyleBoxFlat:
	var style := panel_style(background, 10, border_color, 1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func focus_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = TEXT
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
	button.add_theme_stylebox_override("normal", button_style(TEXT, TEXT, 10))
	button.add_theme_stylebox_override("hover", button_style(Color("#2B2B2B"), Color("#2B2B2B"), 10))
	button.add_theme_stylebox_override("pressed", button_style(Color("#3B3B3B"), Color("#3B3B3B"), 10))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.custom_minimum_size.y = 48.0


static func apply_danger(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color("#FFF7F7"), Color("#E8CACA"), 10))
	button.add_theme_stylebox_override("hover", button_style(Color("#FDEDED"), RED, 10))
	button.add_theme_color_override("font_color", RED)
	button.add_theme_color_override("font_hover_color", RED)
	button.custom_minimum_size.y = 48.0


static func apply_segment(button: Button, active: bool) -> void:
	var background := SURFACE_SOFT if active else Color.TRANSPARENT
	var border_color := Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", button_style(background, border_color, 10))
	button.add_theme_stylebox_override("hover", button_style(SURFACE_SOFT, Color.TRANSPARENT, 10))
	button.add_theme_stylebox_override("pressed", button_style(Color("#E8E8E5"), Color.TRANSPARENT, 10))
	button.add_theme_color_override("font_color", TEXT if active else MUTED)
	button.custom_minimum_size.y = 44.0


static func _system_font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "SF Pro Text", "SF Pro Display", "Helvetica Neue", "Arial"])
	font.font_weight = weight
	return font


static func _scroll_style(color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = width
	style.corner_radius_top_right = width
	style.corner_radius_bottom_left = width
	style.corner_radius_bottom_right = width
	style.content_margin_left = float(width) / 2.0
	style.content_margin_right = float(width) / 2.0
	return style


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
