@tool
class_name ForgePayoffChart
extends ForgeCanvasControl

## Expiry payoff chart with a keyboard/touch data probe.
## set_data accepts either:
##   set_data({"spots": [...], "payoffs": [...], "current_spot": 100.0})
## or set_data(spots, payoffs, current_spot).

signal probe_changed(index: int, spot: float, payoff: float)

@export var title: String = "Payoff"
@export var eyebrow: String = "EXPIRY SHAPE"

var _spots := PackedFloat32Array()
var _payoffs := PackedFloat32Array()
var _current_spot: float = 0.0
var _has_current_spot := false
var _selected_index := -1
var _plot_rect := Rect2()
var _x_range := Vector2(0.0, 1.0)
var _y_range := Vector2(-1.0, 1.0)


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(max(custom_minimum_size.x, dp(300.0)), max(custom_minimum_size.y, dp(230.0)))


func set_data(spots_or_payload: Variant, payoff_values: Variant = null, current_spot: Variant = null) -> void:
	var new_spots: Variant = spots_or_payload
	var new_payoffs: Variant = payoff_values
	var new_marker: Variant = current_spot
	if spots_or_payload is Dictionary:
		var payload: Dictionary = spots_or_payload
		new_spots = payload.get("spots", payload.get("x", []))
		new_payoffs = payload.get("payoffs", payload.get("values", payload.get("y", [])))
		new_marker = payload.get("current_spot", payload.get("spot", null))
	_spots = to_float_array(new_spots)
	_payoffs = to_float_array(new_payoffs)
	var count: int = mini(_spots.size(), _payoffs.size())
	_spots.resize(count)
	_payoffs.resize(count)
	_has_current_spot = new_marker != null and typeof(new_marker) in [TYPE_INT, TYPE_FLOAT]
	if _has_current_spot:
		_current_spot = float(new_marker)
	_selected_index = _nearest_spot_index(_current_spot) if _has_current_spot and count > 0 else (count - 1 if count > 0 else -1)
	queue_redraw()
	if _selected_index >= 0:
		_emit_probe()


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_card(card, true)
	var outer := content_rect()
	draw_text_line(eyebrow, outer.position + Vector2(0.0, dp(10.0)), palette(&"muted"), &"caption")
	draw_text_line(title, outer.position + Vector2(0.0, dp(34.0)), palette(&"text"), &"title")

	_plot_rect = Rect2(
		outer.position + Vector2(dp(6.0), dp(56.0)),
		Vector2(max(1.0, outer.size.x - dp(12.0)), max(1.0, outer.size.y - dp(68.0)))
	)
	if _spots.size() < 2 or _payoffs.size() < 2:
		_draw_empty_state()
		draw_focus_ring(card)
		return

	_x_range = range_with_padding(_spots, false, 0.0)
	_y_range = range_with_padding(_payoffs, true, 0.12)
	_draw_grid()
	_draw_payoff()
	_draw_current_spot()
	_draw_probe()
	_draw_range_labels()
	draw_focus_ring(card)


func _draw_grid() -> void:
	for index in range(5):
		var ratio := float(index) / 4.0
		var x: float = lerpf(_plot_rect.position.x, _plot_rect.end.x, ratio)
		var y: float = lerpf(_plot_rect.position.y, _plot_rect.end.y, ratio)
		draw_line(Vector2(x, _plot_rect.position.y), Vector2(x, _plot_rect.end.y), palette(&"grid") * Color(1.0, 1.0, 1.0, 0.14), dp(1.0), true)
		draw_line(Vector2(_plot_rect.position.x, y), Vector2(_plot_rect.end.x, y), palette(&"grid") * Color(1.0, 1.0, 1.0, 0.14), dp(1.0), true)
	var zero_y := _map_y(0.0)
	draw_line(Vector2(_plot_rect.position.x, zero_y), Vector2(_plot_rect.end.x, zero_y), palette(&"grid") * Color(1.0, 1.0, 1.0, 0.72), dp(1.0), true)


func _draw_payoff() -> void:
	var points := PackedVector2Array()
	for index in range(_spots.size()):
		points.append(_point_for(index))
	var baseline: float = clampf(_map_y(0.0), _plot_rect.position.y, _plot_rect.end.y)
	for index in range(1, points.size()):
		var point_a := points[index - 1]
		var point_b := points[index]
		var base_a := Vector2(point_a.x, baseline)
		var base_b := Vector2(point_b.x, baseline)
		var value_a: float = _payoffs[index - 1]
		var value_b: float = _payoffs[index]
		if value_a * value_b < 0.0:
			var crossing_ratio: float = inverse_lerp(value_a, value_b, 0.0)
			var crossing := point_a.lerp(point_b, crossing_ratio)
			_draw_fill_triangle(base_a, point_a, crossing)
			_draw_fill_triangle(crossing, point_b, base_b)
		else:
			_draw_fill_triangle(base_a, point_a, point_b)
			_draw_fill_triangle(base_a, point_b, base_b)
	draw_polyline(points, palette(&"teal"), dp(2.5), true)
	for index in range(1, points.size()):
		if sign(_payoffs[index - 1]) != sign(_payoffs[index]):
				draw_circle(points[index], dp(3.0), palette(&"text"), true)


func _draw_fill_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	var twice_area: float = absf((b - a).cross(c - a))
	if twice_area <= 0.01:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), Color(palette(&"teal"), 0.10))


func _draw_current_spot() -> void:
	if not _has_current_spot or _current_spot < _x_range.x or _current_spot > _x_range.y:
		return
	var x := _map_x(_current_spot)
	draw_dashed_line(Vector2(x, _plot_rect.position.y), Vector2(x, _plot_rect.end.y), palette(&"magenta"), dp(1.5), dp(5.0), true, true)
	draw_circle(Vector2(x, _plot_rect.position.y + dp(5.0)), dp(3.5), palette(&"magenta"), true)


func _draw_probe() -> void:
	if _selected_index < 0 or _selected_index >= _spots.size():
		return
	var point := _point_for(_selected_index)
	draw_line(Vector2(point.x, _plot_rect.position.y), Vector2(point.x, _plot_rect.end.y), Color(palette(&"text"), 0.20), dp(1.0), true)
	draw_circle(point, dp(7.0), Color(palette(&"teal"), 0.18), true)
	draw_circle(point, dp(3.5), palette(&"text"), true)

	var bubble_size := Vector2(dp(142.0), dp(44.0))
	var bubble_x: float = clampf(point.x - bubble_size.x * 0.5, _plot_rect.position.x, _plot_rect.end.x - bubble_size.x)
	var bubble_y := point.y - bubble_size.y - dp(10.0)
	if bubble_y < _plot_rect.position.y:
		bubble_y = point.y + dp(10.0)
	var bubble := Rect2(Vector2(bubble_x, bubble_y), bubble_size)
	var style := _make_box(Color(palette(&"surface_high"), 0.97), Color(palette(&"teal"), 0.45), int(dp(8.0)), 1)
	draw_style_box(style, bubble)
	draw_text_line("S %.2f" % _spots[_selected_index], bubble.position + Vector2(dp(9.0), dp(17.0)), palette(&"muted"), &"caption")
	draw_text_line(_money(_payoffs[_selected_index]), bubble.position + Vector2(dp(9.0), dp(35.0)), palette(&"green") if _payoffs[_selected_index] >= 0.0 else palette(&"red"), &"label")


func _draw_range_labels() -> void:
	var label_y := _plot_rect.end.y + dp(13.0)
	draw_text_line("%.0f" % _x_range.x, Vector2(_plot_rect.position.x, label_y), palette(&"muted"), &"caption")
	draw_text_line("%.0f" % _x_range.y, Vector2(_plot_rect.end.x - dp(52.0), label_y), palette(&"muted"), &"caption", dp(52.0), HORIZONTAL_ALIGNMENT_RIGHT)
	var max_label := _money(_y_range.y)
	draw_text_line(max_label, _plot_rect.position + Vector2(dp(4.0), dp(12.0)), Color(palette(&"muted"), 0.78), &"caption")


func _draw_empty_state() -> void:
	var style := _make_box(palette(&"surface_low"), Color(palette(&"border"), 0.65), int(dp(9.0)), 1)
	draw_style_box(style, _plot_rect)
	draw_text_line("Add an option leg to reveal the curve", _plot_rect.position + Vector2(dp(14.0), _plot_rect.size.y * 0.5), palette(&"muted"), &"label", _plot_rect.size.x - dp(28.0), HORIZONTAL_ALIGNMENT_CENTER)


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
			KEY_ESCAPE:
				_selected_index = -1
				queue_redraw()
			_:
				return
		accept_event()


func _select_from_position(position: Vector2) -> void:
	if not _plot_rect.has_point(position) or _spots.is_empty():
		return
	var spot: float = lerpf(_x_range.x, _x_range.y, inverse_lerp(_plot_rect.position.x, _plot_rect.end.x, position.x))
	_set_selected(_nearest_spot_index(spot))


func _set_selected(index: int) -> void:
	if _spots.is_empty():
		return
	var next_index: int = clampi(index, 0, _spots.size() - 1)
	if next_index == _selected_index:
		return
	_selected_index = next_index
	queue_redraw()
	_emit_probe()


func _emit_probe() -> void:
	probe_changed.emit(_selected_index, _spots[_selected_index], _payoffs[_selected_index])
	announce("Spot %.2f, payoff %s" % [_spots[_selected_index], _money(_payoffs[_selected_index])])


func _nearest_spot_index(target: float) -> int:
	var result := -1
	var best_distance := INF
	for index in range(_spots.size()):
		var distance: float = absf(_spots[index] - target)
		if distance < best_distance:
			best_distance = distance
			result = index
	return result


func _point_for(index: int) -> Vector2:
	return Vector2(_map_x(_spots[index]), _map_y(_payoffs[index]))


func _map_x(value: float) -> float:
	return lerp(_plot_rect.position.x, _plot_rect.end.x, inverse_lerp(_x_range.x, _x_range.y, value))


func _map_y(value: float) -> float:
	return lerp(_plot_rect.end.y, _plot_rect.position.y, inverse_lerp(_y_range.x, _y_range.y, value))


func _money(value: float) -> String:
	return "%s$%.2f" % ["−" if value < 0.0 else "+", abs(value)]
