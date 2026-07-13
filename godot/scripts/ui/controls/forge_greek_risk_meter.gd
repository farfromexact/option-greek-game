@tool
class_name ForgeGreekRiskMeter
extends ForgeCanvasControl

## Signed Greek bars plus a compact risk-budget gauge.
## Typical call:
## set_data({
##   "values": {"delta": 42, "gamma": -3, "theta": 120, "vega": 310},
##   "limits": {"delta": 120, "gamma": 12, "theta": 420, "vega": 850},
##   "risk": 0.58
## })

signal greek_activated(key: StringName, value: float, normalized: float)

@export var title: String = "Greek forces"
@export var eyebrow: String = "RISK COCKPIT"

var _rows: Array[Dictionary] = [
	{"key": &"delta", "label": "Delta", "value": 0.0, "limit": 120.0, "color": &"teal"},
	{"key": &"gamma", "label": "Gamma", "value": 0.0, "limit": 12.0, "color": &"magenta"},
	{"key": &"theta", "label": "Theta", "value": 0.0, "limit": 420.0, "color": &"amber"},
	{"key": &"vega", "label": "Vega", "value": 0.0, "limit": 850.0, "color": &"green"},
]
var _risk := 0.0
var _selected_row := 0
var _rows_rect := Rect2()
var _row_height := 0.0


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(max(custom_minimum_size.x, dp(340.0)), max(custom_minimum_size.y, dp(245.0)))


func set_data(values_or_payload: Variant, limits_input: Variant = null, risk_input: float = -1.0) -> void:
	var values: Dictionary = {}
	var limits: Dictionary = {}
	var provided_risk := risk_input
	if values_or_payload is Dictionary:
		var payload: Dictionary = values_or_payload
		if payload.get("values", null) is Dictionary:
			values = payload["values"]
		else:
			values = payload
		if payload.get("limits", null) is Dictionary:
			limits = payload["limits"]
		if payload.has("risk"):
			provided_risk = float(payload["risk"])
	if limits_input is Dictionary:
		limits = limits_input

	var computed_risk := 0.0
	for row in _rows:
		var key: StringName = row["key"]
		if values.has(key) or values.has(String(key)):
			row["value"] = float(values.get(key, values.get(String(key), row["value"])))
		if limits.has(key) or limits.has(String(key)):
			row["limit"] = max(0.0001, abs(float(limits.get(key, limits.get(String(key), row["limit"])))))
		computed_risk = max(computed_risk, abs(float(row["value"])) / float(row["limit"]))
	_risk = clamp(provided_risk if provided_risk >= 0.0 else computed_risk, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_card(card, true)
	var outer := content_rect()
	draw_text_line(eyebrow, outer.position + Vector2(0.0, dp(10.0)), palette(&"muted"), &"caption")
	draw_text_line(title, outer.position + Vector2(0.0, dp(34.0)), palette(&"text"), &"title")
	_draw_risk_gauge(Rect2(Vector2(outer.end.x - dp(87.0), outer.position.y), Vector2(dp(87.0), dp(62.0))))

	_rows_rect = Rect2(
		outer.position + Vector2(0.0, dp(64.0)),
		Vector2(outer.size.x, max(1.0, outer.size.y - dp(68.0)))
	)
	_row_height = _rows_rect.size.y / float(_rows.size())
	for index in range(_rows.size()):
		_draw_row(index, _rows[index])
	draw_focus_ring(card)


func _draw_risk_gauge(rect: Rect2) -> void:
	var center := rect.position + Vector2(rect.size.x - dp(29.0), dp(29.0))
	var radius := dp(22.0)
	var start := -PI * 0.75
	var finish := PI * 0.75
	var accent := _risk_color()
	draw_arc(center, radius, start, finish, 40, Color(palette(&"border"), 0.9), dp(5.0), true)
	draw_arc(center, radius, start, lerp(start, finish, _risk), 40, accent, dp(5.0), true)
	draw_text_line("%d%%" % int(round(_risk * 100.0)), center + Vector2(-dp(21.0), dp(5.0)), palette(&"text"), &"label", dp(42.0), HORIZONTAL_ALIGNMENT_CENTER)
	var status := "CALM" if _risk <= 0.42 else ("WATCH" if _risk <= 0.70 else "HOT")
	draw_text_line(status, Vector2(rect.position.x, rect.position.y + dp(32.0)), accent, &"caption", rect.size.x - dp(55.0), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_row(index: int, row: Dictionary) -> void:
	var y := _rows_rect.position.y + _row_height * index
	var row_rect := Rect2(Vector2(_rows_rect.position.x, y + dp(3.0)), Vector2(_rows_rect.size.x, _row_height - dp(6.0)))
	if index == _selected_row:
		draw_style_box(_make_box(Color(palette(&"surface_high"), 0.72), Color(palette(&"border"), 0.90), int(dp(8.0)), 1), row_rect)
	var label_width: float = minf(dp(66.0), row_rect.size.x * 0.22)
	var value_width: float = minf(dp(72.0), row_rect.size.x * 0.23)
	var track := Rect2(
		Vector2(row_rect.position.x + label_width + dp(8.0), row_rect.position.y + row_rect.size.y * 0.5 - dp(3.0)),
		Vector2(max(dp(52.0), row_rect.size.x - label_width - value_width - dp(19.0)), dp(6.0))
	)
	draw_text_line(row["label"], row_rect.position + Vector2(dp(7.0), row_rect.size.y * 0.5 + dp(5.0)), palette(&"muted"), &"label")
	draw_style_box(_make_box(palette(&"surface_low"), Color.TRANSPARENT, int(dp(4.0)), 0), track)
	var center_x := track.position.x + track.size.x * 0.5
	draw_line(Vector2(center_x, track.position.y - dp(3.0)), Vector2(center_x, track.end.y + dp(3.0)), Color(palette(&"text"), 0.25), dp(1.0), true)
	var normalized: float = clampf(float(row["value"]) / float(row["limit"]), -1.0, 1.0)
	var fill_width: float = absf(normalized) * track.size.x * 0.5
	var fill_x: float = center_x - fill_width if normalized < 0.0 else center_x
	var fill := Rect2(Vector2(fill_x, track.position.y), Vector2(fill_width, track.size.y))
	if fill.size.x > 0.0:
		draw_style_box(_make_box(palette(row["color"]), Color.TRANSPARENT, int(dp(4.0)), 0), fill)
	var value_text := "%+.2f" % float(row["value"])
	draw_text_line(value_text, Vector2(row_rect.end.x - value_width, row_rect.position.y + row_rect.size.y * 0.5 + dp(5.0)), palette(&"text"), &"label", value_width - dp(7.0), HORIZONTAL_ALIGNMENT_RIGHT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_select_from_position(event.position, false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_select_from_position(event.position, true)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		grab_focus()
		_select_from_position(event.position, true)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_set_selected(max(0, _selected_row - 1), false)
			KEY_DOWN:
				_set_selected(min(_rows.size() - 1, _selected_row + 1), false)
			KEY_HOME:
				_set_selected(0, false)
			KEY_END:
				_set_selected(_rows.size() - 1, false)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_selected()
			_:
				return
		accept_event()


func _select_from_position(position: Vector2, activate: bool) -> void:
	if not _rows_rect.has_point(position):
		return
	var index := int(floor((position.y - _rows_rect.position.y) / max(1.0, _row_height)))
	_set_selected(clamp(index, 0, _rows.size() - 1), activate)


func _set_selected(index: int, activate: bool) -> void:
	_selected_row = clamp(index, 0, _rows.size() - 1)
	queue_redraw()
	var row: Dictionary = _rows[_selected_row]
	var normalized: float = clampf(float(row["value"]) / float(row["limit"]), -1.0, 1.0)
	announce("%s %+.2f, %d percent of limit" % [row["label"], float(row["value"]), int(round(abs(normalized) * 100.0))])
	if activate:
		_activate_selected()


func _activate_selected() -> void:
	var row: Dictionary = _rows[_selected_row]
	greek_activated.emit(row["key"], float(row["value"]), clamp(float(row["value"]) / float(row["limit"]), -1.0, 1.0))


func _risk_color() -> Color:
	if _risk > 0.70:
		return palette(&"red")
	if _risk > 0.42:
		return palette(&"amber")
	return palette(&"teal")
