@tool
class_name ForgeToast
extends ForgeCanvasControl

## Queued, self-drawn feedback banner. No textures or fonts are required.
## set_data accepts a String or a Dictionary with message, title, kind,
## duration, action_label and action_id. Kinds: success, warning, danger, info.

signal action_pressed(action_id: StringName)
signal dismissed(reason: StringName)
signal toast_shown(message: String)

enum Phase { HIDDEN, ENTERING, HOLDING, EXITING }

const ENTER_TIME := 0.20
const EXIT_TIME := 0.16

@export var default_duration := 2.8

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _phase := Phase.HIDDEN
var _elapsed := 0.0
var _action_rect := Rect2()
var _draw_offset := 0.0


func _ready() -> void:
	super._ready()
	clip_contents = false
	custom_minimum_size = Vector2(dp(320.0), dp(76.0))
	set_process(false)
	if Engine.is_editor_hint():
		_current = {"title": "Feedback", "message": "A clear next step, right when it matters.", "kind": &"success", "duration": 2.8, "action_label": "", "action_id": &""}
		_phase = Phase.HOLDING
		visible = true
	else:
		visible = false


func set_data(payload: Variant) -> void:
	if payload is Dictionary:
		show_toast(
			str(payload.get("message", "")),
			StringName(payload.get("kind", &"info")),
			float(payload.get("duration", default_duration)),
			str(payload.get("title", "")),
			str(payload.get("action_label", "")),
			StringName(payload.get("action_id", &""))
		)
	else:
		show_toast(str(payload))


func show_toast(message: String, kind: StringName = &"info", duration: float = -1.0, title: String = "", action_label: String = "", action_id: StringName = &"") -> void:
	if message.strip_edges().is_empty():
		return
	_queue.append({
		"title": title,
		"message": message,
		"kind": kind,
		"duration": default_duration if duration < 0.0 else duration,
		"action_label": action_label,
		"action_id": action_id,
	})
	if _phase == Phase.HIDDEN:
		_start_next()


func dismiss(reason: StringName = &"dismissed") -> void:
	if _phase in [Phase.HIDDEN, Phase.EXITING]:
		return
	_phase = Phase.EXITING
	_elapsed = 0.0
	dismissed.emit(reason)
	queue_redraw()


func clear_queue() -> void:
	_queue.clear()
	dismiss(&"cleared")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed += delta
	match _phase:
		Phase.ENTERING:
			if _elapsed >= ENTER_TIME:
				_phase = Phase.HOLDING
				_elapsed = 0.0
		Phase.HOLDING:
			var duration := float(_current.get("duration", default_duration))
			if duration > 0.0 and _elapsed >= duration:
				dismiss(&"timeout")
		Phase.EXITING:
			if _elapsed >= EXIT_TIME:
				_phase = Phase.HIDDEN
				_start_next()
	_update_motion()
	queue_redraw()


func _draw() -> void:
	if _phase == Phase.HIDDEN or _current.is_empty():
		return
	var rect := Rect2(Vector2(dp(4.0), dp(4.0) + _draw_offset), size - Vector2(dp(8.0), dp(8.0)))
	draw_card(rect, true, palette(&"surface_high"))
	var accent := _kind_color(StringName(_current.get("kind", &"info")))
	var icon_center := rect.position + Vector2(dp(28.0), rect.size.y * 0.5)
	draw_circle(icon_center, dp(13.0), Color(accent, 0.18), true)
	draw_arc(icon_center, dp(12.5), 0.0, TAU, 28, Color(accent, 0.72), dp(1.2), true)
	_draw_kind_icon(icon_center, accent)

	var action_label := str(_current.get("action_label", ""))
	var action_width := dp(0.0)
	if not action_label.is_empty():
		action_width = max(dp(70.0), get_theme_default_font().get_string_size(action_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size(&"label")).x + dp(24.0))
		_action_rect = Rect2(Vector2(rect.end.x - action_width - dp(10.0), rect.position.y + (rect.size.y - dp(40.0)) * 0.5), Vector2(action_width, dp(40.0)))
		draw_style_box(_make_box(Color(accent, 0.12), Color(accent, 0.55), int(dp(10.0)), 1), _action_rect)
		draw_text_line(action_label, _action_rect.position + Vector2(0.0, dp(25.0)), accent, &"label", _action_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_action_rect = Rect2()

	var text_x := rect.position.x + dp(50.0)
	var available := rect.end.x - text_x - dp(12.0) - action_width
	var title_text := str(_current.get("title", ""))
	if title_text.is_empty():
		title_text = _default_title(StringName(_current.get("kind", &"info")))
	draw_text_line(fit_text(title_text, available, &"label"), Vector2(text_x, rect.position.y + dp(25.0)), palette(&"text"), &"label")
	draw_text_line(fit_text(str(_current.get("message", "")), available, &"caption"), Vector2(text_x, rect.position.y + dp(47.0)), palette(&"muted"), &"caption")

	if _phase == Phase.HOLDING and float(_current.get("duration", 0.0)) > 0.0:
		var remaining: float = 1.0 - clampf(_elapsed / float(_current["duration"]), 0.0, 1.0)
		var progress := Rect2(Vector2(rect.position.x + dp(12.0), rect.end.y - dp(3.0)), Vector2((rect.size.x - dp(24.0)) * remaining, dp(1.5)))
		draw_rect(progress, Color(accent, 0.48), true)
	draw_focus_ring(rect)


func _draw_kind_icon(center: Vector2, color: Color) -> void:
	var kind := StringName(_current.get("kind", &"info"))
	if kind == &"success":
		draw_polyline(PackedVector2Array([center + Vector2(dp(-5.0), 0.0), center + Vector2(dp(-1.0), dp(4.0)), center + Vector2(dp(6.0), dp(-5.0))]), color, dp(2.2), true)
	elif kind in [&"warning", &"danger"]:
		draw_line(center + Vector2(0.0, dp(-6.0)), center + Vector2(0.0, dp(2.0)), color, dp(2.0), true)
		draw_circle(center + Vector2(0.0, dp(6.0)), dp(1.4), color, true)
	else:
		draw_circle(center + Vector2(0.0, dp(-5.0)), dp(1.4), color, true)
		draw_line(center + Vector2(0.0, dp(-1.0)), center + Vector2(0.0, dp(6.0)), color, dp(2.0), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_handle_press(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		grab_focus()
		_handle_press(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not str(_current.get("action_label", "")).is_empty():
					_activate_action()
				else:
					dismiss(&"keyboard")
			KEY_ESCAPE:
				dismiss(&"keyboard")
			_:
				return
		accept_event()


func _handle_press(position: Vector2) -> void:
	if not _action_rect.size.is_zero_approx() and _action_rect.has_point(position):
		_activate_action()
	else:
		dismiss(&"tap")


func _activate_action() -> void:
	action_pressed.emit(StringName(_current.get("action_id", &"")))
	dismiss(&"action")


func _start_next() -> void:
	if _queue.is_empty():
		_current = {}
		_phase = Phase.HIDDEN
		visible = false
		set_process(false)
		self_modulate = Color.WHITE
		return
	_current = _queue.pop_front()
	_phase = Phase.ENTERING
	_elapsed = 0.0
	visible = true
	set_process(true)
	grab_focus()
	_update_motion()
	toast_shown.emit(str(_current["message"]))
	announce(str(_current["message"]))


func _update_motion() -> void:
	var alpha := 1.0
	if _phase == Phase.ENTERING:
		var t := _ease_out(clamp(_elapsed / ENTER_TIME, 0.0, 1.0))
		_draw_offset = lerp(dp(-10.0), 0.0, t)
		alpha = t
	elif _phase == Phase.EXITING:
		var t: float = clampf(_elapsed / EXIT_TIME, 0.0, 1.0)
		_draw_offset = lerp(0.0, dp(-7.0), t)
		alpha = 1.0 - t
	else:
		_draw_offset = 0.0
	self_modulate = Color(1.0, 1.0, 1.0, alpha)


func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _kind_color(kind: StringName) -> Color:
	match kind:
		&"success":
			return palette(&"green")
		&"warning":
			return palette(&"amber")
		&"danger":
			return palette(&"red")
		_:
			return palette(&"teal")


func _default_title(kind: StringName) -> String:
	match kind:
		&"success":
			return "Nice adjustment"
		&"warning":
			return "Watch the risk budget"
		&"danger":
			return "Limit breached"
		_:
			return "Volatility Forge"
