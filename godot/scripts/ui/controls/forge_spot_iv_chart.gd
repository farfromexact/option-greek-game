@tool
class_name ForgeSpotIvChart
extends ForgeCanvasControl

## Dual-scale spot and implied-volatility path chart.
## set_data accepts either:
##   set_data({"labels": [...], "spots": [...], "ivs": [...]})
## or set_data(labels, spots, ivs). IV values may be decimals or percentages.

signal sample_changed(index: int, label: String, spot: float, iv: float)

@export var title: String = "Market path"
@export var eyebrow: String = "SPOT + IV"

var _labels := PackedStringArray()
var _spots := PackedFloat32Array()
var _ivs := PackedFloat32Array()
var _spot_range := Vector2(0.0, 1.0)
var _iv_range := Vector2(0.0, 1.0)
var _plot_rect := Rect2()
var _selected_index := -1


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(max(custom_minimum_size.x, dp(320.0)), max(custom_minimum_size.y, dp(230.0)))


func set_data(labels_or_payload: Variant, spot_values: Variant = null, iv_values: Variant = null) -> void:
	var labels_input: Variant = labels_or_payload
	var spots_input: Variant = spot_values
	var ivs_input: Variant = iv_values
	if labels_or_payload is Dictionary:
		var payload: Dictionary = labels_or_payload
		labels_input = payload.get("labels", payload.get("times", []))
		spots_input = payload.get("spots", payload.get("spot", []))
		ivs_input = payload.get("ivs", payload.get("iv", payload.get("volatility", [])))
	_spots = to_float_array(spots_input)
	_ivs = to_float_array(ivs_input)
	var count: int = mini(_spots.size(), _ivs.size())
	_spots.resize(count)
	_ivs.resize(count)
	_labels = PackedStringArray()
	if labels_input is Array or labels_input is PackedStringArray:
		for value in labels_input:
			_labels.append(str(value))
	_labels.resize(count)
	for index in range(count):
		if _labels[index].is_empty():
			_labels[index] = "T+%d" % index
	_selected_index = count - 1 if count > 0 else -1
	queue_redraw()
	if _selected_index >= 0:
		_emit_sample()


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_card(card, true)
	var outer := content_rect()
	draw_text_line(eyebrow, outer.position + Vector2(0.0, dp(10.0)), palette(&"muted"), &"caption")
	draw_text_line(title, outer.position + Vector2(0.0, dp(34.0)), palette(&"text"), &"title")
	_draw_legend(outer)

	_plot_rect = Rect2(
		outer.position + Vector2(dp(8.0), dp(61.0)),
		Vector2(max(1.0, outer.size.x - dp(16.0)), max(1.0, outer.size.y - dp(75.0)))
	)
	if _spots.size() < 2:
		_draw_empty_state()
		draw_focus_ring(card)
		return
	_spot_range = range_with_padding(_spots, false, 0.12)
	_iv_range = range_with_padding(_ivs, false, 0.14)
	_draw_grid()
	_draw_paths()
	_draw_probe()
	_draw_axis_labels()
	draw_focus_ring(card)


func _draw_legend(outer: Rect2) -> void:
	var base_y := outer.position.y + dp(28.0)
	var right := outer.end.x
	draw_circle(Vector2(right - dp(111.0), base_y - dp(3.0)), dp(3.0), palette(&"amber"), true)
	draw_text_line("Spot", Vector2(right - dp(103.0), base_y), palette(&"muted"), &"caption")
	draw_circle(Vector2(right - dp(49.0), base_y - dp(3.0)), dp(3.0), palette(&"teal"), true)
	draw_text_line("IV", Vector2(right - dp(41.0), base_y), palette(&"muted"), &"caption")


func _draw_grid() -> void:
	for index in range(5):
		var ratio := float(index) / 4.0
		var x: float = lerpf(_plot_rect.position.x, _plot_rect.end.x, ratio)
		var y: float = lerpf(_plot_rect.position.y, _plot_rect.end.y, ratio)
		draw_line(Vector2(x, _plot_rect.position.y), Vector2(x, _plot_rect.end.y), Color(palette(&"grid"), 0.14), dp(1.0), true)
		draw_line(Vector2(_plot_rect.position.x, y), Vector2(_plot_rect.end.x, y), Color(palette(&"grid"), 0.14), dp(1.0), true)


func _draw_paths() -> void:
	var spot_points := PackedVector2Array()
	var iv_points := PackedVector2Array()
	for index in range(_spots.size()):
		spot_points.append(Vector2(_x_for(index), _spot_y(_spots[index])))
		iv_points.append(Vector2(_x_for(index), _iv_y(_ivs[index])))

	var iv_fill := PackedVector2Array([Vector2(iv_points[0].x, _plot_rect.end.y)])
	iv_fill.append_array(iv_points)
	iv_fill.append(Vector2(iv_points[iv_points.size() - 1].x, _plot_rect.end.y))
	draw_colored_polygon(iv_fill, Color(palette(&"teal"), 0.07))
	draw_polyline(spot_points, palette(&"amber"), dp(2.5), true)
	draw_polyline(iv_points, palette(&"teal"), dp(2.0), true)
	for index in range(_spots.size()):
		if index == _spots.size() - 1 or index % max(1, int(_spots.size() / 8.0)) == 0:
			draw_circle(spot_points[index], dp(2.5), palette(&"amber"), true)
			draw_circle(iv_points[index], dp(2.2), palette(&"teal"), true)


func _draw_probe() -> void:
	if _selected_index < 0 or _selected_index >= _spots.size():
		return
	var x := _x_for(_selected_index)
	var spot_point := Vector2(x, _spot_y(_spots[_selected_index]))
	var iv_point := Vector2(x, _iv_y(_ivs[_selected_index]))
	draw_line(Vector2(x, _plot_rect.position.y), Vector2(x, _plot_rect.end.y), Color(palette(&"text"), 0.28), dp(1.0), true)
	draw_circle(spot_point, dp(6.0), Color(palette(&"amber"), 0.20), true)
	draw_circle(spot_point, dp(3.2), palette(&"text"), true)
	draw_circle(iv_point, dp(6.0), Color(palette(&"teal"), 0.20), true)
	draw_circle(iv_point, dp(3.2), palette(&"text"), true)

	var bubble_size := Vector2(dp(154.0), dp(51.0))
	var bubble_x: float = clampf(x - bubble_size.x * 0.5, _plot_rect.position.x, _plot_rect.end.x - bubble_size.x)
	var preferred_y: float = minf(spot_point.y, iv_point.y) - bubble_size.y - dp(9.0)
	if preferred_y < _plot_rect.position.y:
		preferred_y = max(spot_point.y, iv_point.y) + dp(9.0)
	var bubble := Rect2(Vector2(bubble_x, preferred_y), bubble_size)
	draw_style_box(_make_box(Color(palette(&"surface_high"), 0.97), Color(palette(&"border"), 0.95), int(dp(8.0)), 1), bubble)
	draw_text_line(fit_text(_labels[_selected_index], bubble.size.x - dp(18.0), &"caption"), bubble.position + Vector2(dp(9.0), dp(16.0)), palette(&"muted"), &"caption")
	draw_text_line("S %.2f" % _spots[_selected_index], bubble.position + Vector2(dp(9.0), dp(37.0)), palette(&"amber"), &"label")
	draw_text_line("IV %s" % _iv_text(_ivs[_selected_index]), bubble.position + Vector2(dp(81.0), dp(37.0)), palette(&"teal"), &"label")


func _draw_axis_labels() -> void:
	draw_text_line("%.2f" % _spot_range.y, _plot_rect.position + Vector2(dp(3.0), dp(11.0)), Color(palette(&"amber"), 0.78), &"caption")
	draw_text_line(_iv_text(_iv_range.y), Vector2(_plot_rect.end.x - dp(54.0), _plot_rect.position.y + dp(11.0)), Color(palette(&"teal"), 0.78), &"caption", dp(51.0), HORIZONTAL_ALIGNMENT_RIGHT)
	var label_y := _plot_rect.end.y + dp(13.0)
	draw_text_line(_labels[0], Vector2(_plot_rect.position.x, label_y), palette(&"muted"), &"caption")
	draw_text_line(_labels[_labels.size() - 1], Vector2(_plot_rect.end.x - dp(72.0), label_y), palette(&"muted"), &"caption", dp(72.0), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_empty_state() -> void:
	draw_style_box(_make_box(palette(&"surface_low"), Color(palette(&"border"), 0.65), int(dp(9.0)), 1), _plot_rect)
	draw_text_line("Run the market to begin the path", _plot_rect.position + Vector2(dp(14.0), _plot_rect.size.y * 0.5), palette(&"muted"), &"label", _plot_rect.size.x - dp(28.0), HORIZONTAL_ALIGNMENT_CENTER)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_select_from_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_select_from_position(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		grab_focus()
		_select_from_position(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		_select_from_position(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_set_selected(max(0, _selected_index - 1))
			KEY_RIGHT:
				_set_selected(min(_spots.size() - 1, _selected_index + 1))
			KEY_HOME:
				_set_selected(0)
			KEY_END:
				_set_selected(_spots.size() - 1)
			_:
				return
		accept_event()


func _select_from_position(position: Vector2) -> void:
	if not _plot_rect.has_point(position) or _spots.is_empty():
		return
	var ratio := inverse_lerp(_plot_rect.position.x, _plot_rect.end.x, position.x)
	_set_selected(int(round(ratio * (_spots.size() - 1))))


func _set_selected(index: int) -> void:
	if _spots.is_empty():
		return
	var next_index: int = clampi(index, 0, _spots.size() - 1)
	if next_index == _selected_index:
		return
	_selected_index = next_index
	queue_redraw()
	_emit_sample()


func _emit_sample() -> void:
	sample_changed.emit(_selected_index, _labels[_selected_index], _spots[_selected_index], _ivs[_selected_index])
	announce("%s, spot %.2f, implied volatility %s" % [_labels[_selected_index], _spots[_selected_index], _iv_text(_ivs[_selected_index])])


func _x_for(index: int) -> float:
	return lerp(_plot_rect.position.x, _plot_rect.end.x, float(index) / float(max(1, _spots.size() - 1)))


func _spot_y(value: float) -> float:
	return lerp(_plot_rect.end.y, _plot_rect.position.y, inverse_lerp(_spot_range.x, _spot_range.y, value))


func _iv_y(value: float) -> float:
	return lerp(_plot_rect.end.y, _plot_rect.position.y, inverse_lerp(_iv_range.x, _iv_range.y, value))


func _iv_text(value: float) -> String:
	var percentage := value * 100.0 if abs(value) <= 2.0 else value
	return "%.1f%%" % percentage
