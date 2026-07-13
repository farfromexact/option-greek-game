@tool
class_name ForgeCanvasControl
extends Control

## Shared drawing and interaction foundation for Volatility Forge's asset-free UI.
## Godot already renders Controls in logical pixels. ui_scale is an extra theme
## multiplier for projects that intentionally use larger touch or HiDPI layouts.

signal accessibility_announcement(text: String)

@export_range(0.75, 2.50, 0.05) var ui_scale: float = 1.0:
	set(value):
		ui_scale = clamp(value, 0.75, 2.50)
		queue_redraw()

var _palette: Dictionary = {
	"background": Color("#08100F"),
	"surface": Color("#121918"),
	"surface_high": Color("#192220"),
	"surface_low": Color("#202B28"),
	"border": Color("#31413D"),
	"grid": Color("#49635C"),
	"text": Color("#F4F8F6"),
	"muted": Color("#A8B7B2"),
	"teal": Color("#39E6D3"),
	"amber": Color("#FFBE5C"),
	"magenta": Color("#DD65B7"),
	"red": Color("#FF746E"),
	"green": Color("#ADF06D"),
	"shadow": Color(0.0, 0.0, 0.0, 0.28),
}


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	custom_minimum_size = Vector2(240.0, 180.0)


func _ready() -> void:
	queue_redraw()


## Accepted keys match the defaults above. Values may be Color or HTML strings.
func set_palette(overrides: Dictionary) -> void:
	for key in overrides:
		if not _palette.has(key):
			continue
		var candidate: Variant = overrides[key]
		if typeof(candidate) == TYPE_COLOR:
			_palette[key] = candidate
		elif typeof(candidate) == TYPE_STRING:
			_palette[key] = Color.from_string(candidate, _palette[key])
	queue_redraw()


func set_ui_scale(value: float) -> void:
	ui_scale = value


func palette(key: StringName) -> Color:
	return _palette.get(key, Color.WHITE)


func dp(value: float) -> float:
	return value * ui_scale


func font_size(role: StringName = &"body") -> int:
	var base_size: int = maxi(12, get_theme_default_font_size())
	match role:
		&"caption":
			return max(10, int(round(base_size * 0.72 * ui_scale)))
		&"label":
			return max(11, int(round(base_size * 0.82 * ui_scale)))
		&"title":
			return max(14, int(round(base_size * 1.08 * ui_scale)))
		&"metric":
			return max(16, int(round(base_size * 1.32 * ui_scale)))
		_:
			return max(12, int(round(base_size * ui_scale)))


func content_rect(inset: float = 14.0) -> Rect2:
	var pad := dp(inset)
	return Rect2(Vector2(pad, pad), Vector2(max(0.0, size.x - pad * 2.0), max(0.0, size.y - pad * 2.0)))


func draw_card(rect: Rect2, elevated: bool = false, fill_override: Color = Color.TRANSPARENT) -> void:
	var radius := int(round(dp(12.0)))
	if elevated:
		var shadow_style := _make_box(palette(&"shadow"), Color.TRANSPARENT, radius, 0)
		draw_style_box(shadow_style, Rect2(rect.position + Vector2(0.0, dp(5.0)), rect.size))
	var fill := palette(&"surface") if fill_override.a <= 0.0 else fill_override
	var style := _make_box(fill, palette(&"border"), radius, max(1, int(round(dp(1.0)))))
	draw_style_box(style, rect)


func draw_focus_ring(rect: Rect2) -> void:
	if not has_focus():
		return
	var style := _make_box(Color.TRANSPARENT, palette(&"teal").lightened(0.12), int(round(dp(13.0))), max(2, int(round(dp(2.0)))))
	draw_style_box(style, rect.grow(-dp(2.0)))


func draw_text_line(text: String, baseline: Vector2, color: Color, role: StringName = &"body", width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(get_theme_default_font(), baseline, text, alignment, width, font_size(role), color)


func fit_text(text: String, max_width: float, role: StringName = &"body") -> String:
	var font := get_theme_default_font()
	var size_px := font_size(role)
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x <= max_width:
		return text
	var suffix := "…"
	var result := text
	while not result.is_empty():
		result = result.left(result.length() - 1)
		if font.get_string_size(result + suffix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x <= max_width:
			return result + suffix
	return suffix


func range_with_padding(values: PackedFloat32Array, include_zero: bool = false, padding_ratio: float = 0.10) -> Vector2:
	if values.is_empty():
		return Vector2(-1.0, 1.0)
	var low := INF
	var high := -INF
	for value in values:
		low = min(low, value)
		high = max(high, value)
	if include_zero:
		low = min(low, 0.0)
		high = max(high, 0.0)
	if is_equal_approx(low, high):
		var fallback: float = maxf(1.0, absf(low) * 0.1)
		return Vector2(low - fallback, high + fallback)
	var padding := (high - low) * padding_ratio
	return Vector2(low - padding, high + padding)


func to_float_array(values: Variant) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	if values == null or not values is Array and not values is PackedFloat32Array and not values is PackedFloat64Array and not values is PackedInt32Array and not values is PackedInt64Array:
		return result
	for value in values:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			result.append(float(value))
	return result


func announce(text: String) -> void:
	tooltip_text = text
	accessibility_announcement.emit(text)


func _make_box(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _notification(what: int) -> void:
	if what in [NOTIFICATION_THEME_CHANGED, NOTIFICATION_RESIZED, NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]:
		queue_redraw()
