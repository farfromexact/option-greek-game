extends Control

const ForgeTheme = preload("res://scripts/ui/theme_factory.gd")
const OnboardingOverlay = preload("res://scripts/ui/onboarding_overlay.gd")
const LevelCatalog = preload("res://scripts/game/level_catalog.gd")
const ChallengeGenerator = preload("res://scripts/game/challenge_generator.gd")
const RunLedger = preload("res://scripts/game/run_ledger.gd")
const ObjectiveEvaluator = preload("res://scripts/game/objective_evaluator.gd")
const ScoreCalculator = preload("res://scripts/game/score_calculator.gd")
const ProgressStore = preload("res://scripts/game/progress_store.gd")
const MarketSimulator = preload("res://scripts/engine/market_simulator.gd")
const PortfolioEngine = preload("res://scripts/engine/portfolio_engine.gd")
const PnlAttribution = preload("res://scripts/engine/pnl_attribution.gd")
const PayoffChart = preload("res://scripts/ui/controls/forge_payoff_chart.gd")
const SpotIvChart = preload("res://scripts/ui/controls/forge_spot_iv_chart.gd")
const GreekRiskMeter = preload("res://scripts/ui/controls/forge_greek_risk_meter.gd")
const ToastView = preload("res://scripts/ui/controls/forge_toast.gd")

enum Page { MISSION, BUILD, RUN, REVIEW }

const PAGE_LABELS := ["1  Mission", "2  Build", "3  Run", "4  Review"]
const REGIME_LABELS := {
	&"calm": "Calm lake",
	&"trending_up": "Slow trend up",
	&"trending_down": "Slow trend down",
	&"choppy": "Pinball market",
	&"volatility_spike": "Vega storm",
	&"earnings_event": "Event volcano",
	&"crash": "Crash storm",
}

var _current_page := Page.MISSION
var _current_mode: StringName = &"core"
var _all_levels: Array[Dictionary] = []
var _current_level: Dictionary = {}
var _run_state: Dictionary = {}
var _market: Dictionary = {}
var _legs: Array = []
var _snapshot: Dictionary = {}
var _attribution: Dictionary = {}
var _records: Array = []
var _baseline_value := 0.0
var _total_costs := 0.0
var _selected_leg_index := 0
var _settled := false
var _running := false
var _run_timer: Timer
var _forecast_values := {
	"spot_up": 0.55,
	"rv_beats_iv": 0.50,
	"iv_crush": 0.45,
	"risk_breach": 0.35,
}
var _forecast_committed := false
var _quote_sequence := 0
var _current_order: Dictionary = {}
var _progress: Dictionary = {
	"tutorial_completed": false,
	"completed_levels": [],
	"best_scores": {},
	"leaderboard": [],
}
var _compact_layout := false

var _page_scroll: ScrollContainer
var _page_content: VBoxContainer
var _nav_buttons: Array[Button] = []
var _top_pnl: Label
var _top_risk: Label
var _top_day: Label
var _top_practice: Label
var _bottom_hint: Label
var _bottom_secondary: Button
var _bottom_primary: Button
var _toast: Control
var _seed_field: LineEdit


func _ready() -> void:
	theme = ForgeTheme.build()
	_all_levels = LevelCatalog.all_levels()
	if _all_levels.is_empty():
		_show_fatal_error("No missions were found in the Godot catalog.")
		return
	_progress = ProgressStore.load_progress()
	var last_level_id := str(_progress.get("last_level_id", "delta-wind"))
	_current_level = LevelCatalog.get_level(last_level_id).duplicate(true)
	_reset_session()
	_compact_layout = get_viewport_rect().size.x < 980.0
	_build_shell()
	_run_timer = Timer.new()
	_run_timer.wait_time = 0.72
	_run_timer.timeout.connect(_step_market)
	add_child(_run_timer)
	_show_page(Page.MISSION)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if not bool(_progress.get("tutorial_completed", false)):
		call_deferred("_show_onboarding")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_mission"):
		_show_page(Page.MISSION)
	elif event.is_action_pressed("open_build"):
		_show_page(Page.BUILD)
	elif event.is_action_pressed("open_run"):
		_show_page(Page.RUN)
	elif event.is_action_pressed("open_review"):
		_show_page(Page.REVIEW)
	elif event.is_action_pressed("run_pause"):
		_toggle_run()
	elif event.is_action_pressed("step_market"):
		_step_market()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = ForgeTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 16)
	add_child(outer)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	outer.add_child(shell)

	shell.add_child(_build_topbar())
	shell.add_child(_build_navigation())

	_page_scroll = ScrollContainer.new()
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_page_scroll.follow_focus = true
	shell.add_child(_page_scroll)

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_right", 8)
	page_margin.add_theme_constant_override("margin_bottom", 8)
	_page_scroll.add_child(page_margin)

	_page_content = VBoxContainer.new()
	_page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_theme_constant_override("separation", 14)
	page_margin.add_child(_page_content)

	shell.add_child(_build_bottom_bar())

	_toast = ToastView.new()
	_toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast.position = Vector2(-392.0, 18.0)
	_toast.size = Vector2(370.0, 84.0)
	_toast.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_toast)


func _build_topbar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 70.0
	panel.add_theme_stylebox_override(
		"panel",
		ForgeTheme.panel_style(ForgeTheme.SURFACE, 18, ForgeTheme.BORDER, 1),
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	row.add_child(brand)
	brand.add_child(_make_label("RISK INTUITION, ONE STEP AT A TIME", 11, ForgeTheme.MUTED))
	brand.add_child(_make_label("Volatility Forge 2D", 22, ForgeTheme.TEXT))

	row.add_child(_flex_spacer())
	_top_practice = _status_chip("OFFICIAL", ForgeTheme.LIME)
	_top_pnl = _status_chip("P&L  $0.00", ForgeTheme.TEXT)
	_top_risk = _status_chip("RISK  0%", ForgeTheme.TEAL)
	_top_day = _status_chip("DAY  0/8", ForgeTheme.TEXT)
	row.add_child(_top_practice)
	row.add_child(_top_pnl)
	row.add_child(_top_risk)
	row.add_child(_top_day)
	return panel


func _build_navigation() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_nav_buttons.clear()
	for index in PAGE_LABELS.size():
		var button := Button.new()
		button.text = PAGE_LABELS[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "Open %s" % PAGE_LABELS[index].substr(3)
		button.pressed.connect(_show_page.bind(index))
		row.add_child(button)
		_nav_buttons.append(button)
	return row


func _build_bottom_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 72.0
	panel.add_theme_stylebox_override(
		"panel",
		ForgeTheme.panel_style(ForgeTheme.SURFACE_RAISED, 18, ForgeTheme.BORDER_STRONG, 1),
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	_bottom_hint = _make_label("Choose one focused mission.", 15, ForgeTheme.MUTED)
	_bottom_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bottom_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bottom_hint)

	_bottom_secondary = Button.new()
	_bottom_secondary.custom_minimum_size = Vector2(128.0, 48.0)
	row.add_child(_bottom_secondary)

	_bottom_primary = Button.new()
	_bottom_primary.custom_minimum_size = Vector2(170.0, 48.0)
	ForgeTheme.apply_primary(_bottom_primary)
	row.add_child(_bottom_primary)
	return panel


func _show_page(page: int, reset_scroll: bool = true) -> void:
	var previous_scroll := _page_scroll.scroll_vertical
	_current_page = clampi(page, Page.MISSION, Page.REVIEW)
	for index in _nav_buttons.size():
		ForgeTheme.apply_segment(_nav_buttons[index], index == _current_page)
	_clear_children(_page_content)
	match _current_page:
		Page.MISSION:
			_render_mission_page()
		Page.BUILD:
			_render_build_page()
		Page.RUN:
			_render_run_page()
		Page.REVIEW:
			_render_review_page()
	_update_chrome()
	_page_scroll.scroll_vertical = 0 if reset_scroll else previous_scroll


func _render_mission_page() -> void:
	_page_content.add_child(_page_heading(
		"Choose one focused mission",
		"The home screen recommends a next step instead of turning 126 levels into a debt counter.",
	))

	var grid := GridContainer.new()
	grid.columns = 1 if _compact_layout else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_child(grid)

	grid.add_child(_build_mission_picker())
	grid.add_child(_build_mission_detail())

	var progress_card := _card()
	var progress_row := HBoxContainer.new()
	progress_card.add_child(progress_row)
	var completed: Array = _progress.get("completed_levels", [])
	progress_row.add_child(_metric_block("CORE PATH", "%d / 12" % _count_completed_category(&"core", completed), "A deliberate learning route"))
	progress_row.add_child(_metric_block("DESK FINALS", "%d / 6" % _count_completed_category(&"final", completed), "Integrated risk exams"))
	progress_row.add_child(_metric_block("CURRENT BEST", _best_score_text(), "Only official completed runs"))
	_page_content.add_child(progress_card)


func _build_mission_picker() -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("MISSION LIBRARY"))
	column.add_child(_make_label("Pick the type of practice you need", 22, ForgeTheme.TEXT))

	var modes := HBoxContainer.new()
	column.add_child(modes)
	for mode_data in [
		{&"id": &"core", &"label": "Core"},
		{&"id": &"final", &"label": "Finals"},
		{&"id": &"challenge", &"label": "Seed lab"},
	]:
		var mode_id: StringName = mode_data[&"id"]
		var mode_button := Button.new()
		mode_button.text = str(mode_data[&"label"])
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ForgeTheme.apply_segment(mode_button, _current_mode == mode_id)
		mode_button.pressed.connect(_set_mission_mode.bind(mode_id))
		modes.add_child(mode_button)

	if _current_mode == &"challenge":
		column.add_child(_make_label("Challenge seed", 13, ForgeTheme.MUTED))
		_seed_field = LineEdit.new()
		_seed_field.placeholder_text = "e.g. calm-before-the-storm"
		_seed_field.text = "market-open-001"
		_seed_field.custom_minimum_size.y = 48.0
		_seed_field.text_submitted.connect(_launch_seed)
		column.add_child(_seed_field)
		var seed_actions := HBoxContainer.new()
		column.add_child(seed_actions)
		var daily_button := Button.new()
		daily_button.text = "Today’s challenge"
		daily_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		daily_button.custom_minimum_size.y = 48.0
		daily_button.pressed.connect(_launch_daily)
		seed_actions.add_child(daily_button)
		var launch_button := Button.new()
		launch_button.text = "Build from seed"
		launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		launch_button.custom_minimum_size.y = 48.0
		ForgeTheme.apply_primary(launch_button)
		launch_button.pressed.connect(func() -> void: _launch_seed(_seed_field.text))
		seed_actions.add_child(launch_button)
		column.add_child(_hint_panel(
			"Same text, same market",
			"Seeds are deterministic, so every replay is comparable.",
			ForgeTheme.TEAL,
		))
	else:
		column.add_child(_make_label("Mission", 13, ForgeTheme.MUTED))
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 48.0
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var filtered := _levels_for_mode(_current_mode)
		var selected_index := 0
		for index in filtered.size():
			var level: Dictionary = filtered[index]
			selector.add_item("D%d  ·  %s" % [int(level.get("difficulty", 1)), str(level.get("title", "Mission"))])
			selector.set_item_metadata(index, str(level.get("id", "")))
			if str(level.get("id", "")) == str(_current_level.get("id", "")):
				selected_index = index
		selector.select(selected_index)
		selector.item_selected.connect(func(index: int) -> void:
			var level_id := str(selector.get_item_metadata(index))
			_select_level(level_id)
		)
		column.add_child(selector)

		var recommendation := _hint_panel(
			"Recommended next",
			"Continue the core path until the risk vocabulary feels automatic." if _current_mode == &"core" else "Finals combine several systems. Finish the core path first.",
			ForgeTheme.LIME if _current_mode == &"core" else ForgeTheme.AMBER,
		)
		column.add_child(recommendation)
	return card


func _build_mission_detail() -> Control:
	var card := _card(ForgeTheme.SURFACE_RAISED, ForgeTheme.BORDER_STRONG)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	card.add_child(column)

	var difficulty := int(_current_level.get("difficulty", 1))
	var act := str(_current_level.get("act", "Core path"))
	column.add_child(_eyebrow("%s  ·  D%d" % [act.to_upper(), difficulty]))
	column.add_child(_make_label(str(_current_level.get("title", "Mission")), 30, ForgeTheme.TEXT))
	var goal := _make_label(str(_current_level.get("goal", "Build, run, and explain the risk.")), 17, ForgeTheme.MUTED)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(goal)

	column.add_child(_hint_panel(
		"Learning point",
		str(_current_level.get("learning_point", "One deliberate risk decision at a time.")),
		ForgeTheme.TEAL,
	))

	column.add_child(_eyebrow("PASS CONDITIONS"))
	var objectives: Array = _current_level.get("objectives", [])
	for objective_value: Variant in objectives:
		if not objective_value is Dictionary:
			continue
		var objective: Dictionary = objective_value
		var line := HBoxContainer.new()
		var dot := _make_label("○", 17, ForgeTheme.LIME)
		dot.custom_minimum_size.x = 26.0
		line.add_child(dot)
		var objective_label := _make_label(str(objective.get("label", "Objective")), 15, ForgeTheme.TEXT)
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(objective_label)
		column.add_child(line)

	var start_button := Button.new()
	start_button.text = "Start this mission"
	start_button.custom_minimum_size.y = 50.0
	ForgeTheme.apply_primary(start_button)
	start_button.pressed.connect(_start_selected_mission)
	column.add_child(start_button)
	return card


func _render_build_page() -> void:
	_page_content.add_child(_page_heading(
		"Build the risk machine",
		"Start with a clean thesis. Payoff and Greek risk update before the first market day.",
	))

	if _book_is_live():
		_page_content.add_child(_hint_panel(
			"Live desk",
			"The path has started. New legs and removals are real trades with cash offsets and transaction cost; detailed leg editing is locked.",
			ForgeTheme.AMBER,
		))

	var grid := GridContainer.new()
	grid.columns = 1 if _compact_layout else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_child(grid)
	grid.add_child(_build_positions_card())
	grid.add_child(_build_risk_preview_card())


func _render_run_page() -> void:
	_page_content.add_child(_page_heading(
		"Run one market day at a time",
		"Commit before hindsight, then use deliberate hedges. The fixed horizon ends the run automatically.",
	))

	if _compact_layout:
		# Forecasting is the gate to the first market step, so keep it first on
		# small screens instead of hiding the primary task below market diagnostics.
		_page_content.add_child(_build_forecast_card())
		_page_content.add_child(_build_market_strip())
	else:
		_page_content.add_child(_build_market_strip())

	var chart_grid := GridContainer.new()
	chart_grid.columns = 1 if _compact_layout else 2
	chart_grid.add_theme_constant_override("h_separation", 14)
	chart_grid.add_theme_constant_override("v_separation", 14)
	chart_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_child(chart_grid)

	var path_chart: Control = SpotIvChart.new()
	path_chart.custom_minimum_size.y = 280.0
	path_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_chart.call("set_data", _path_payload())
	chart_grid.add_child(path_chart)

	var meter: Control = GreekRiskMeter.new()
	meter.custom_minimum_size.y = 280.0
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.call("set_data", {
		"values": {
			"delta": float(_snapshot.get("delta", 0.0)),
			"gamma": float(_snapshot.get("gamma", 0.0)),
			"theta": float(_snapshot.get("theta", 0.0)),
			"vega": float(_snapshot.get("vega", 0.0)),
		},
		"limits": {"delta": 120.0, "gamma": 12.0, "theta": 1.2, "vega": 9.0},
		"risk": _risk_score(),
	})
	chart_grid.add_child(meter)

	if _compact_layout:
		_page_content.add_child(_build_run_actions_card())
	else:
		var tool_grid := GridContainer.new()
		tool_grid.columns = 2
		tool_grid.add_theme_constant_override("h_separation", 14)
		tool_grid.add_theme_constant_override("v_separation", 14)
		tool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page_content.add_child(tool_grid)
		tool_grid.add_child(_build_forecast_card())
		tool_grid.add_child(_build_run_actions_card())

	if _level_has_objective(&"market_making"):
		_page_content.add_child(_build_market_maker_card())


func _render_review_page() -> void:
	_page_content.add_child(_page_heading(
		"Explain the result",
		"Every objective is visible. The debrief names one next action instead of hiding failure behind a generic message.",
	))

	var report := _score_report()
	var evaluation: Dictionary = report.get("evaluation", {})
	_page_content.add_child(_build_score_hero(report, evaluation))

	var grid := GridContainer.new()
	grid.columns = 1 if _compact_layout else 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_content.add_child(grid)
	grid.add_child(_build_objective_review(evaluation))
	grid.add_child(_build_attribution_review())

	var replay: Control = SpotIvChart.new()
	replay.custom_minimum_size.y = 300.0
	replay.call("set_data", _path_payload())
	_page_content.add_child(replay)

	var lower_grid := GridContainer.new()
	lower_grid.columns = 1 if _compact_layout else 2
	lower_grid.add_theme_constant_override("h_separation", 14)
	lower_grid.add_theme_constant_override("v_separation", 14)
	_page_content.add_child(lower_grid)
	lower_grid.add_child(_build_action_history_card())
	lower_grid.add_child(_build_save_card(report, evaluation))


func _build_score_hero(report: Dictionary, evaluation: Dictionary) -> Control:
	var completed := bool(report.get("completed", false))
	var score := int(report.get("score", 0))
	var accent := ForgeTheme.LIME if completed else (ForgeTheme.AMBER if not _settled else ForgeTheme.RED)
	var card := _card(Color(accent, 0.08), Color(accent, 0.55))
	var row := HBoxContainer.new()
	card.add_child(row)

	var score_column := VBoxContainer.new()
	score_column.custom_minimum_size.x = 170.0
	row.add_child(score_column)
	score_column.add_child(_eyebrow("OFFICIAL SCORE" if not bool(_run_state.get("practice_override", false)) else "PRACTICE SCORE"))
	var score_label := _make_label("%d" % score, 56, accent)
	score_column.add_child(score_label)
	score_column.add_child(_make_label("PASS" if completed else ("IN PROGRESS" if not _settled else "NOT YET"), 13, accent))

	var narrative := VBoxContainer.new()
	narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(narrative)
	narrative.add_child(_make_label(
		"Controlled and explained" if completed else "One adjustment will matter most",
		25,
		ForgeTheme.TEXT,
	))
	var next_step := _most_useful_next_step(evaluation)
	var next_label := _make_label(next_step, 16, ForgeTheme.MUTED)
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative.add_child(next_label)

	var breakdown: Dictionary = report.get("breakdown", {})
	var chips := HBoxContainer.new()
	narrative.add_child(chips)
	chips.add_child(_small_chip("Objective %.0f" % float(breakdown.get("objective", 0.0)), ForgeTheme.TEAL))
	chips.add_child(_small_chip("P&L %.0f" % float(breakdown.get("pnl", 0.0)), ForgeTheme.LIME))
	chips.add_child(_small_chip("Risk %.0f" % float(breakdown.get("risk", 0.0)), ForgeTheme.AMBER))
	return card


func _build_objective_review(evaluation: Dictionary) -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("OBJECTIVE CHECKLIST"))
	column.add_child(_make_label("Pass conditions", 22, ForgeTheme.TEXT))
	var checks: Array = evaluation.get("checks", [])
	if checks.is_empty():
		column.add_child(_make_label("No objective results yet.", 15, ForgeTheme.MUTED))
	for check_value: Variant in checks:
		if not check_value is Dictionary:
			continue
		var check: Dictionary = check_value
		var passed := bool(check.get("passed", false))
		var row := HBoxContainer.new()
		column.add_child(row)
		var icon := _make_label("✓" if passed else "○", 18, ForgeTheme.LIME if passed else ForgeTheme.AMBER)
		icon.custom_minimum_size.x = 28.0
		row.add_child(icon)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_column)
		var label := _make_label(str(check.get("label", "Objective")), 14, ForgeTheme.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_column.add_child(label)
		if not passed and not str(check.get("message", "")).is_empty():
			var message := _make_label(str(check.get("message", "")), 12, ForgeTheme.MUTED)
			message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text_column.add_child(message)
	return card


func _build_attribution_review() -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("P&L ATTRIBUTION"))
	column.add_child(_make_label("What actually moved the book", 22, ForgeTheme.TEXT))
	for metric in [
		{&"label": "Total", &"key": "total_pnl", &"color": ForgeTheme.TEXT},
		{&"label": "Delta", &"key": "delta_pnl", &"color": ForgeTheme.TEAL},
		{&"label": "Gamma", &"key": "gamma_pnl", &"color": ForgeTheme.BLUE},
		{&"label": "Theta", &"key": "theta_pnl", &"color": ForgeTheme.AMBER},
		{&"label": "Vega", &"key": "vega_pnl", &"color": ForgeTheme.LIME},
		{&"label": "Costs", &"key": "transaction_cost", &"color": ForgeTheme.RED},
		{&"label": "Residual", &"key": "residual", &"color": ForgeTheme.MUTED},
	]:
		var key := str(metric[&"key"])
		var value := float(_attribution.get(key, 0.0))
		var value_row := _compact_value_row(str(metric[&"label"]), _format_money(value))
		var row_label := value_row.get_child(0) as Label
		if row_label != null:
			row_label.add_theme_color_override("font_color", metric[&"color"])
		column.add_child(value_row)

	column.add_child(_hint_panel(
		"Path quality",
		"Max drawdown %s · %d risk flags · RV %.1f%% vs IV %.1f%%" % [
			_format_money(float(_attribution.get("max_drawdown", 0.0))),
			int(_attribution.get("risk_violations", 0)),
			float(_attribution.get("realized_vol", 0.0)) * 100.0,
			float(_attribution.get("implied_vol", 0.0)) * 100.0,
		],
		ForgeTheme.TEAL,
	))
	return card


func _build_action_history_card() -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("ACTION HISTORY"))
	column.add_child(_make_label("The audit trail stays intact", 22, ForgeTheme.TEXT))
	var history: Array = _run_state.get("action_history", [])
	if history.is_empty():
		column.add_child(_make_label("No desk actions yet. Market steps are tracked separately.", 14, ForgeTheme.MUTED))
	else:
		var start := maxi(0, history.size() - 8)
		for index in range(start, history.size()):
			var action: Dictionary = history[index]
			column.add_child(_compact_value_row(
				"#%d · T+%d" % [int(action.get("sequence", index + 1)), int(action.get("market_step", 0))],
				str(action.get("type", &"action")).replace("_", " ").capitalize(),
			))
	return card


func _build_save_card(report: Dictionary, evaluation: Dictionary) -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("LOCAL PROGRESS"))
	column.add_child(_make_label("Save only a real completion", 22, ForgeTheme.TEXT))

	var eligible := bool(evaluation.get("leaderboard_eligible", false)) and _settled
	var reason := "Completed official runs are saved locally and deduplicated by run id."
	var accent := ForgeTheme.LIME
	if bool(_run_state.get("practice_override", false)):
		reason = "Practice weather was used, so this debrief stays off the official leaderboard."
		accent = ForgeTheme.AMBER
	elif not _settled:
		reason = "Reach the fixed horizon before saving."
		accent = ForgeTheme.AMBER
	elif not bool(report.get("completed", false)):
		reason = "This run is useful for review, but incomplete or failed runs are never written to the leaderboard."
		accent = ForgeTheme.RED
	column.add_child(_hint_panel("Save gate", reason, accent))

	var save_button := Button.new()
	save_button.text = "Save official run"
	save_button.disabled = not eligible
	save_button.tooltip_text = reason
	ForgeTheme.apply_primary(save_button)
	save_button.pressed.connect(_save_current_run)
	column.add_child(save_button)

	var retry_button := Button.new()
	retry_button.text = "Retry same mission and seed"
	retry_button.custom_minimum_size.y = 48.0
	retry_button.pressed.connect(_start_selected_mission)
	column.add_child(retry_button)
	return card


func _score_report() -> Dictionary:
	_run_state["snapshot"] = _snapshot.duplicate(true)
	_run_state["attribution"] = _attribution.duplicate(true)
	_run_state["portfolio"] = _legs.duplicate(true)
	return ScoreCalculator.calculate_report(_current_level, _run_state, _snapshot, _attribution, _legs)


func _most_useful_next_step(evaluation: Dictionary) -> String:
	if bool(evaluation.get("completed", false)):
		return "All required objectives passed. Compare this run with the same seed and try to reduce friction or drawdown."
	var checks: Array = evaluation.get("checks", [])
	for check_value: Variant in checks:
		if check_value is Dictionary and not bool(check_value.get("passed", false)):
			var message := str(check_value.get("message", ""))
			return message if not message.is_empty() else str(check_value.get("label", "Complete the next objective."))
	return "Advance the fixed market horizon, then return for a complete debrief."


func _save_current_run() -> void:
	if not _settled:
		_show_toast("Reach the fixed horizon before saving.", &"warning", "Run still open")
		return
	var report := _score_report()
	var response: Dictionary = ProgressStore.record_run(_current_level, _run_state, report, _progress)
	_progress = response.get("progress", _progress)
	var reason := str(response.get("reason", "save_failed"))
	if bool(response.get("saved", false)):
		_show_toast("Official run saved locally. Duplicate clicks are blocked.", &"success", "Progress saved")
	elif reason == "duplicate_run":
		_show_toast("This run is already saved.", &"info", "No duplicate")
	elif reason == "practice_or_ineligible":
		_show_toast("Practice runs stay out of the official leaderboard.", &"warning", "Not eligible")
	else:
		_show_toast("Only completed official runs can be saved.", &"warning", "Save blocked")
	_show_page(Page.REVIEW)


func _settle_run() -> void:
	if _settled:
		return
	_running = false
	if _run_timer != null:
		_run_timer.stop()
	_resolve_forecast()
	RunLedger.finish_run(_run_state)
	_run_state["snapshot"] = _snapshot.duplicate(true)
	_run_state["attribution"] = _attribution.duplicate(true)
	_run_state["portfolio"] = _legs.duplicate(true)
	_settled = true
	_show_page(Page.REVIEW)
	var report := _score_report()
	_show_toast(
		"Score %d. %s" % [int(report.get("score", 0)), "Objectives met." if bool(report.get("completed", false)) else "Review the first unfinished objective."],
		&"success" if bool(report.get("completed", false)) else &"warning",
		"Run settled",
	)


func _resolve_forecast() -> void:
	var commitment: Dictionary = _run_state.get("probability_commitment", {})
	if not bool(commitment.get("committed", false)):
		return
	var initial_market: Dictionary = _current_level.get("initial_market", {})
	var initial_spot := float(initial_market.get("spot", 100.0))
	var initial_iv := float(initial_market.get("volatility", 0.2))
	var outcomes := {
		"spot_up": float(_market.get("spot", initial_spot)) > initial_spot,
		"rv_beats_iv": float(_attribution.get("realized_vol", 0.0)) > initial_iv,
		"iv_crush": initial_iv - float(_market.get("volatility", initial_iv)) >= 0.05,
		"risk_breach": int(_attribution.get("risk_violations", 0)) > 0,
	}
	RunLedger.resolve_probability_outcomes(_run_state, outcomes)


func _small_chip(text: String, color: Color) -> Label:
	var label := _make_label(text, 12, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(104.0, 34.0)
	label.add_theme_stylebox_override("normal", ForgeTheme.panel_style(Color(color, 0.08), 9, Color(color, 0.32), 1))
	return label


func _format_money(value: float) -> String:
	return "%s$%.2f" % ["−" if value < 0.0 else "+", absf(value)]


func _build_market_strip() -> Control:
	var card := _card(ForgeTheme.SURFACE_RAISED, ForgeTheme.BORDER_STRONG)
	var metrics := GridContainer.new()
	metrics.columns = 2 if _compact_layout else 5
	metrics.add_theme_constant_override("h_separation", 10)
	metrics.add_theme_constant_override("v_separation", 10)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(metrics)
	var regime := StringName(_market.get("regime", &"calm"))
	metrics.add_child(_metric_block("WEATHER", str(REGIME_LABELS.get(regime, str(regime).capitalize())), "Official path" if not bool(_run_state.get("practice_override", false)) else "Practice override"))
	metrics.add_child(_metric_block("SPOT", "%.2f" % float(_market.get("spot", 0.0)), "Day %d" % int(_market.get("day", 0))))
	metrics.add_child(_metric_block("IMPLIED VOL", "%.1f%%" % (float(_market.get("volatility", 0.0)) * 100.0), "Surface pulse"))
	metrics.add_child(_metric_block("LIQUIDITY", "%d%%" % roundi(float(_market.get("liquidity", 0.0)) * 100.0), "Trading friction"))
	metrics.add_child(_metric_block("EVENT RISK", "%d%%" % roundi(float(_market.get("event_risk", 0.0)) * 100.0), "Jump pressure"))
	return card


func _build_forecast_card() -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("PRE-RUN FORECAST"))
	column.add_child(_make_label("Commit before hindsight", 22, ForgeTheme.TEXT))

	var commitment: Dictionary = _run_state.get("probability_commitment", {})
	if bool(commitment.get("committed", false)):
		column.add_child(_hint_panel(
			"Forecast locked",
			"Your probabilities were committed at market step 0. They will resolve at the fixed horizon.",
			ForgeTheme.LIME,
		))
		var questions: Array = commitment.get("questions", [])
		for question_value: Variant in questions:
			if not question_value is Dictionary:
				continue
			var question: Dictionary = question_value
			var value := float(question.get("probability", 0.0)) * 100.0
			column.add_child(_compact_value_row(str(question.get("label", "Forecast")), "%.0f%%" % value))
	else:
		var forecast_grid := GridContainer.new()
		forecast_grid.columns = 2
		forecast_grid.add_theme_constant_override("h_separation", 14)
		forecast_grid.add_theme_constant_override("v_separation", 6)
		forecast_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(forecast_grid)
		for forecast in [
			{&"id": "spot_up", &"label": "Final spot above start"},
			{&"id": "rv_beats_iv", &"label": "Realized vol beats implied"},
			{&"id": "iv_crush", &"label": "IV crush over 5 points"},
			{&"id": "risk_breach", &"label": "At least one risk breach"},
		]:
			forecast_grid.add_child(_forecast_slider(str(forecast[&"id"]), str(forecast[&"label"])))
		var commit_button := Button.new()
		commit_button.text = "Commit four forecasts"
		commit_button.disabled = int(_run_state.get("market_steps", 0)) > 0
		commit_button.tooltip_text = "Forecasts lock at market step 0 and cannot be changed later."
		ForgeTheme.apply_primary(commit_button)
		commit_button.pressed.connect(_commit_forecast)
		column.add_child(commit_button)
	return card


func _forecast_slider(id: String, label_text: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := _make_label(label_text, 14, ForgeTheme.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := _make_label("%.0f%%" % (float(_forecast_values.get(id, 0.5)) * 100.0), 14, ForgeTheme.TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 54.0
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 5.0
	slider.max_value = 95.0
	slider.step = 1.0
	slider.value = float(_forecast_values.get(id, 0.5)) * 100.0
	slider.custom_minimum_size.y = 44.0
	slider.value_changed.connect(func(value: float) -> void:
		_forecast_values[id] = value / 100.0
		value_label.text = "%.0f%%" % value
	)
	column.add_child(slider)
	return column


func _build_run_actions_card() -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("DESK ACTIONS"))
	column.add_child(_make_label("Repair the dominant risk", 22, ForgeTheme.TEXT))

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	column.add_child(actions)
	for action_data in [
		{&"label": "Delta hedge", &"callable": _delta_hedge},
		{&"label": "Buy tail wing", &"callable": _buy_tail_wing},
		{&"label": "Reduce Vega", &"callable": _vega_hedge},
		{&"label": "Surface hedge", &"callable": _surface_hedge},
		{&"label": "Close risk", &"callable": _close_all_risk},
	]:
		var action_button := Button.new()
		action_button.text = str(action_data[&"label"])
		action_button.custom_minimum_size.y = 48.0
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var action_callable: Callable = action_data[&"callable"]
		action_button.pressed.connect(action_callable)
		actions.add_child(action_button)

	column.add_child(_eyebrow("TRAINING CONTROLS"))
	var practice_toggle := CheckButton.new()
	practice_toggle.text = "Practice weather override"
	practice_toggle.button_pressed = bool(_run_state.get("practice_override", false))
	practice_toggle.tooltip_text = "Practice runs are never eligible for the official leaderboard."
	practice_toggle.custom_minimum_size.y = 48.0
	practice_toggle.toggled.connect(_toggle_practice_mode)
	column.add_child(practice_toggle)

	var regime_selector := OptionButton.new()
	regime_selector.custom_minimum_size.y = 48.0
	regime_selector.disabled = not bool(_run_state.get("practice_override", false))
	var selected_regime := 0
	var regime_index := 0
	for regime_value: Variant in REGIME_LABELS.keys():
		var regime_id := StringName(regime_value)
		regime_selector.add_item(str(REGIME_LABELS[regime_id]))
		regime_selector.set_item_metadata(regime_index, regime_id)
		if regime_id == StringName(_market.get("regime", &"calm")):
			selected_regime = regime_index
		regime_index += 1
	regime_selector.select(selected_regime)
	regime_selector.item_selected.connect(func(index: int) -> void:
		_apply_practice_regime(StringName(regime_selector.get_item_metadata(index)))
	)
	column.add_child(regime_selector)

	var status_text := "Official fixed horizon. Score can enter the leaderboard."
	var status_color := ForgeTheme.LIME
	if bool(_run_state.get("practice_override", false)):
		status_text = "Practice is active. You can experiment, but this run cannot be saved to the official leaderboard."
		status_color = ForgeTheme.AMBER
	column.add_child(_hint_panel("Run status", status_text, status_color))
	return card


func _build_market_maker_card() -> Control:
	if _current_order.is_empty():
		_generate_customer_order()
	var card := _card(ForgeTheme.SURFACE_RAISED, ForgeTheme.BORDER_STRONG)
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("MARKET MAKER ARENA"))
	column.add_child(_make_label("Quote the client, then own the inventory", 22, ForgeTheme.TEXT))

	var description := "%s %d × %dD K%.0f %s" % [
		str(_current_order.get("customer_side", "BUY")),
		int(_current_order.get("quantity", 1)),
		int(_current_order.get("expiry_days", 28)),
		float(_current_order.get("strike", 100.0)),
		str(_current_order.get("option_type", &"call")).to_upper(),
	]
	column.add_child(_hint_panel(
		str(_current_order.get("customer", "Client")).capitalize(),
		"%s  ·  Fair %.2f  ·  Toxicity %d%%" % [description, float(_current_order.get("fair", 1.0)), roundi(float(_current_order.get("toxicity", 0.2)) * 100.0)],
		ForgeTheme.TEAL,
	))

	var quote_row := HBoxContainer.new()
	column.add_child(quote_row)
	var fair := float(_current_order.get("fair", 1.0))
	var bid_field := _number_input(maxf(0.01, fair - 0.05), 0.0, 10000.0, 0.01)
	var ask_field := _number_input(fair + 0.05, 0.01, 10000.0, 0.01)
	quote_row.add_child(_labeled_control("Bid", bid_field))
	quote_row.add_child(_labeled_control("Ask", ask_field))
	var quote_button := Button.new()
	quote_button.text = "Send quote"
	quote_button.custom_minimum_size = Vector2(150.0, 48.0)
	quote_button.size_flags_vertical = Control.SIZE_SHRINK_END
	ForgeTheme.apply_primary(quote_button)
	quote_button.pressed.connect(func() -> void:
		_submit_quote(bid_field.value, ask_field.value)
	)
	quote_row.add_child(quote_button)

	var counters := HBoxContainer.new()
	counters.add_child(_metric_block("QUOTES", str(int(_run_state.get("quote_count", 0))), "Real attempts"))
	counters.add_child(_metric_block("FILLS", str(int(_run_state.get("fill_count", 0))), "Inventory created"))
	counters.add_child(_metric_block("CAPTURED EDGE", "$%.2f" % float(_run_state.get("market_making_edge", 0.0)), "At your actual quote"))
	column.add_child(counters)
	return card


func _forecast_questions() -> Array[Dictionary]:
	return [
		{"id": "spot_up", "label": "Final spot above start", "probability": float(_forecast_values["spot_up"])},
		{"id": "rv_beats_iv", "label": "Realized vol beats implied", "probability": float(_forecast_values["rv_beats_iv"])},
		{"id": "iv_crush", "label": "IV crush over 5 points", "probability": float(_forecast_values["iv_crush"])},
		{"id": "risk_breach", "label": "At least one risk breach", "probability": float(_forecast_values["risk_breach"])},
	]


func _commit_forecast() -> void:
	var response: Dictionary = RunLedger.commit_probabilities(_run_state, _forecast_questions())
	if bool(response.get("accepted", false)):
		_forecast_committed = true
		_show_toast(str(response.get("reason", "Forecasts committed.")), &"success", "Forecast locked")
	else:
		_show_toast(str(response.get("reason", "Forecasts could not be committed.")), &"warning", "Commit rejected")
	_show_page(Page.RUN)


func _toggle_practice_mode(enabled: bool) -> void:
	if enabled:
		_run_state["practice_override"] = true
		RunLedger.record_action(_run_state, &"practice_override", {"enabled": true})
		_show_toast("Practice weather enabled. This run is no longer leaderboard eligible.", &"warning", "Practice mode")
	else:
		# Once a path has been altered, the run remains practice for audit integrity.
		if int(_run_state.get("market_steps", 0)) > 0 or bool(_run_state.get("practice_override", false)):
			_show_toast("This run remains Practice. Restart for a new official run.", &"info", "Audit trail kept")
		else:
			_run_state["practice_override"] = false
	_show_page(Page.RUN)


func _apply_practice_regime(regime: StringName) -> void:
	if not bool(_run_state.get("practice_override", false)):
		return
	_market["regime"] = regime
	RunLedger.record_action(_run_state, &"regime_override", {"regime": regime})
	_show_page(Page.RUN)
	_show_toast("Practice weather changed to %s." % str(REGIME_LABELS.get(regime, regime)), &"info", "Weather override")


func _delta_hedge() -> void:
	var hedge_quantity := -float(_snapshot.get("delta", 0.0))
	if absf(hedge_quantity) < 0.05:
		_show_toast("Delta is already close to neutral.", &"info", "No hedge needed")
		return
	_execute_live_trade({"kind": &"stock", "quantity": hedge_quantity}, "Delta hedge", &"delta_hedge")
	_show_page(Page.RUN)


func _buy_tail_wing() -> void:
	var spot := float(_market.get("spot", 100.0))
	var iv := float(_market.get("volatility", 0.2))
	_execute_live_trade(_option_leg(&"long", &"put", roundf(spot * 0.88), 35, iv + 0.05, 1.0), "Bought tail wing", &"tail_hedge")
	_show_page(Page.RUN)


func _vega_hedge() -> void:
	var spot := float(_market.get("spot", 100.0))
	var iv := float(_market.get("volatility", 0.2))
	var side: StringName = &"short" if float(_snapshot.get("vega", 0.0)) > 0.0 else &"long"
	_execute_live_trade(_option_leg(side, &"call", roundf(spot), 30, iv, 1.0), "Vega hedge", &"vega_hedge")
	_show_page(Page.RUN)


func _surface_hedge() -> void:
	var spot := float(_market.get("spot", 100.0))
	var iv := float(_market.get("volatility", 0.2))
	var side: StringName = &"short" if float(_snapshot.get("vega", 0.0)) > 0.0 else &"long"
	_execute_live_trade(_option_leg(side, &"call", roundf(spot * 1.08), 60, iv, 1.0), "Surface hedge", &"surface_hedge")
	_show_page(Page.RUN)


func _generate_customer_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_market.get("seed", 1)) + _quote_sequence * 9973
	var spot := float(_market.get("spot", 100.0))
	var option_type: StringName = &"call" if rng.randf() > 0.45 else &"put"
	var customer_side := "BUY" if rng.randf() > 0.5 else "SELL"
	var strike_bias := rng.randf_range(0.94, 1.07)
	var strike := roundf(spot * strike_bias)
	var expiry_days: int = [14, 21, 28, 45][rng.randi_range(0, 3)]
	var fair_leg := _option_leg(&"long", option_type, strike, expiry_days, float(_market.get("volatility", 0.2)), 1.0)
	var fair_pricing: Dictionary = PortfolioEngine.price_leg(fair_leg, _market)
	var fair := maxf(0.01, float(fair_pricing.get("unit_price", 0.01)))
	_current_order = {
		"customer": ["retail", "hedge fund", "event trader", "vol arb"][rng.randi_range(0, 3)],
		"customer_side": customer_side,
		"option_type": option_type,
		"strike": strike,
		"expiry_days": expiry_days,
		"quantity": rng.randi_range(1, 4),
		"fair": fair,
		"toxicity": rng.randf_range(0.08, 0.72),
	}


func _submit_quote(bid: float, ask: float) -> void:
	if ask <= bid:
		_show_toast("Ask must be above bid.", &"warning", "Invalid quote")
		return
	var quote := {"bid": bid, "ask": ask, "size": float(_current_order.get("quantity", 1)), "order": _current_order.duplicate(true)}
	if not RunLedger.record_quote(_run_state, quote):
		_show_toast("The quote was rejected by the desk guardrails.", &"warning", "Quote rejected")
		return

	var fair := float(_current_order.get("fair", 1.0))
	var customer_side := str(_current_order.get("customer_side", "BUY"))
	var execution_price := ask if customer_side == "BUY" else bid
	var distance := ask - fair if customer_side == "BUY" else fair - bid
	var toxicity := float(_current_order.get("toxicity", 0.2))
	var fill_probability := clampf(0.72 - maxf(distance, 0.0) * 0.9 - (ask - bid) * 0.22 + toxicity * 0.10, 0.05, 0.96)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_market.get("seed", 1)) + _quote_sequence * 31337 + int(round(bid * 100.0 + ask * 100.0))
	_quote_sequence += 1
	if rng.randf() <= fill_probability:
		var quantity := float(_current_order.get("quantity", 1))
		var captured_edge := (execution_price - fair) * quantity if customer_side == "BUY" else (fair - execution_price) * quantity
		var fill := _current_order.duplicate(true)
		fill["quantity"] = quantity
		fill["price"] = execution_price
		fill["side"] = &"short" if customer_side == "BUY" else &"long"
		RunLedger.record_fill(_run_state, fill, captured_edge)
		_execute_fill(fill)
		_show_toast("Filled at %.2f. Captured edge %.2f." % [execution_price, captured_edge], &"success" if captured_edge >= 0.0 else &"warning", "Client fill")
	else:
		_show_toast("Client passed. Your width protected inventory but earned no fill.", &"info", "No trade")
	_generate_customer_order()
	_show_page(Page.RUN)


func _execute_fill(fill: Dictionary) -> void:
	var leg := _option_leg(
		StringName(fill.get("side", &"long")),
		StringName(fill.get("option_type", &"call")),
		float(fill.get("strike", 100.0)),
		int(fill.get("expiry_days", 28)),
		float(_market.get("volatility", 0.2)),
		float(fill.get("quantity", 1.0)),
	)
	var signed_cash := float(fill.get("price", 0.0)) * float(fill.get("quantity", 1.0))
	if StringName(fill.get("side", &"long")) == &"long":
		signed_cash = -signed_cash
	_legs.append(leg)
	_legs.append({"kind": &"cash", "amount": signed_cash})
	RunLedger.set_portfolio(_run_state, _legs)
	var traded_notional := absf(float(fill.get("price", 0.0)) * float(fill.get("quantity", 1.0)))
	var cost := MarketSimulator.transaction_cost(traded_notional, _market)
	_append_record("Client fill", cost, false)


func _level_has_objective(kind: StringName) -> bool:
	for objective_value: Variant in _current_level.get("objectives", []):
		if objective_value is Dictionary and StringName(objective_value.get("kind", &"")) == kind:
			return true
	return false


func _compact_value_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	var label := _make_label(label_text, 14, ForgeTheme.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_make_label(value_text, 14, ForgeTheme.TEXT))
	return row


func _number_input(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.custom_minimum_size = Vector2(132.0, 48.0)
	return field


func _labeled_control(label_text: String, control: Control) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_make_label(label_text, 12, ForgeTheme.MUTED))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(control)
	return column


func _path_payload() -> Dictionary:
	var labels: Array[String] = []
	var spots: Array[float] = []
	var ivs: Array[float] = []
	if _records.is_empty():
		labels.append("T+0")
		spots.append(float(_market.get("spot", 100.0)))
		ivs.append(float(_market.get("volatility", 0.2)))
	else:
		for record_value: Variant in _records:
			if not record_value is Dictionary:
				continue
			var record: Dictionary = record_value
			var record_market: Dictionary = record.get("market", {})
			labels.append("T+%d" % int(record_market.get("day", labels.size())))
			spots.append(float(record_market.get("spot", 100.0)))
			ivs.append(float(record_market.get("volatility", 0.2)))
	return {"labels": labels, "spots": spots, "ivs": ivs}


func _build_positions_card() -> Control:
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_eyebrow("OPTIONS WORKSHOP"))
	column.add_child(_make_label("Shape the exposure", 22, ForgeTheme.TEXT))

	var templates := GridContainer.new()
	templates.columns = 3 if not _compact_layout else 2
	templates.add_theme_constant_override("h_separation", 8)
	templates.add_theme_constant_override("v_separation", 8)
	column.add_child(templates)
	for template_data in [
		{&"id": &"long_call", &"label": "+ Long call"},
		{&"id": &"short_call", &"label": "+ Short call"},
		{&"id": &"long_put", &"label": "+ Long put"},
		{&"id": &"short_put", &"label": "+ Short put"},
		{&"id": &"stock", &"label": "+ Stock hedge"},
		{&"id": &"cash", &"label": "+ Cash"},
	]:
		var template_id: StringName = template_data[&"id"]
		var template_button := Button.new()
		template_button.text = str(template_data[&"label"])
		template_button.custom_minimum_size.y = 48.0
		template_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		template_button.pressed.connect(_add_leg_template.bind(template_id))
		templates.add_child(template_button)

	column.add_child(_eyebrow("POSITIONS"))
	if _legs.is_empty():
		column.add_child(_hint_panel(
			"The cockpit is asleep",
			"Add one option or stock position to wake up the payoff and Greek gauges.",
			ForgeTheme.TEAL,
		))
	else:
		for index in _legs.size():
			column.add_child(_build_leg_row(index, _legs[index]))

	if not _legs.is_empty() and not _book_is_live():
		_selected_leg_index = clampi(_selected_leg_index, 0, _legs.size() - 1)
		column.add_child(_build_leg_inspector(_selected_leg_index))

	var clear_button := Button.new()
	clear_button.text = "Close all risk" if _book_is_live() else "Clear build"
	ForgeTheme.apply_danger(clear_button)
	clear_button.pressed.connect(_clear_portfolio)
	column.add_child(clear_button)
	return card


func _build_leg_row(index: int, leg: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var active := index == _selected_leg_index and not _book_is_live()
	panel.add_theme_stylebox_override(
		"panel",
		ForgeTheme.panel_style(
			ForgeTheme.TEAL_SOFT if active else ForgeTheme.SURFACE_RAISED,
			12,
			ForgeTheme.TEAL if active else ForgeTheme.BORDER,
			1,
		),
	)
	var row := HBoxContainer.new()
	panel.add_child(row)

	var text_button := Button.new()
	text_button.flat = true
	text_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_button.text = _leg_title(leg)
	text_button.tooltip_text = _leg_detail(leg)
	text_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_button.custom_minimum_size.y = 44.0
	text_button.disabled = _book_is_live()
	text_button.pressed.connect(_select_leg.bind(index))
	row.add_child(text_button)

	var quantity := _make_label(_leg_quantity_text(leg), 14, ForgeTheme.MUTED)
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.custom_minimum_size.x = 72.0
	row.add_child(quantity)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = "Close or remove this position"
	remove_button.custom_minimum_size = Vector2(44.0, 44.0)
	remove_button.pressed.connect(_remove_leg.bind(index))
	row.add_child(remove_button)
	return panel


func _build_leg_inspector(index: int) -> Control:
	var leg: Dictionary = _legs[index]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		ForgeTheme.panel_style(ForgeTheme.SURFACE_RAISED, 12, ForgeTheme.BORDER_STRONG, 1),
	)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(_eyebrow("POSITION DETAILS"))

	var fields := GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 10)
	fields.add_theme_constant_override("v_separation", 8)
	column.add_child(fields)
	var kind := StringName(leg.get("kind", &"cash"))
	if kind == &"option":
		fields.add_child(_number_field(
			"Quantity",
			float(leg.get("quantity", 1.0)),
			0.0,
			100.0,
			1.0,
			func(value: float) -> void: _update_leg_field(index, &"quantity", value),
		))
		fields.add_child(_number_field(
			"Strike",
			float(leg.get("strike", 100.0)),
			1.0,
			10000.0,
			1.0,
			func(value: float) -> void: _update_leg_field(index, &"strike", value),
		))
		fields.add_child(_number_field(
			"Expiry days",
			float(leg.get("expiry_days", 30)),
			1.0,
			730.0,
			1.0,
			func(value: float) -> void: _update_leg_field(index, &"expiry_days", int(value)),
		))
		fields.add_child(_number_field(
			"IV %",
			float(leg.get("iv", 0.2)) * 100.0,
			1.0,
			160.0,
			0.5,
			func(value: float) -> void: _update_leg_field(index, &"iv", value / 100.0),
		))
	elif kind == &"stock":
		fields.add_child(_number_field(
			"Shares",
			float(leg.get("quantity", 0.0)),
			-10000.0,
			10000.0,
			1.0,
			func(value: float) -> void: _update_leg_field(index, &"quantity", value),
		))
	else:
		fields.add_child(_number_field(
			"Cash amount",
			float(leg.get("amount", 0.0)),
			-1000000.0,
			1000000.0,
			10.0,
			func(value: float) -> void: _update_leg_field(index, &"amount", value),
		))
	return panel


func _build_risk_preview_card() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var meter: Control = GreekRiskMeter.new()
	meter.custom_minimum_size.y = 250.0
	meter.call("set_data", {
		"values": {
			"delta": float(_snapshot.get("delta", 0.0)),
			"gamma": float(_snapshot.get("gamma", 0.0)),
			"theta": float(_snapshot.get("theta", 0.0)),
			"vega": float(_snapshot.get("vega", 0.0)),
		},
		"limits": {"delta": 120.0, "gamma": 12.0, "theta": 1.2, "vega": 9.0},
		"risk": _risk_score(),
	})
	column.add_child(meter)

	var payoff: Control = PayoffChart.new()
	payoff.custom_minimum_size.y = 270.0
	payoff.call("set_data", _payoff_payload())
	column.add_child(payoff)
	return column


func _number_field(
	label_text: String,
	value: float,
	minimum: float,
	maximum: float,
	step: float,
	callback: Callable,
) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(_make_label(label_text, 12, ForgeTheme.MUTED))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.y = 44.0
	spin.value_changed.connect(callback)
	column.add_child(spin)
	return column


func _select_leg(index: int) -> void:
	_selected_leg_index = clampi(index, 0, maxi(_legs.size() - 1, 0))
	_show_page(Page.BUILD)


func _add_leg_template(template_id: StringName) -> void:
	var leg := _make_template_leg(template_id)
	if _book_is_live():
		_execute_live_trade(leg, "Added %s" % _leg_title(leg), &"trade")
	else:
		_legs.append(leg)
		RunLedger.set_portfolio(_run_state, _legs)
		_refresh_financials(true)
		_selected_leg_index = _legs.size() - 1
	_show_page(Page.BUILD)
	_show_toast("%s added." % _leg_title(leg), &"success", "Position updated")


func _remove_leg(index: int) -> void:
	if index < 0 or index >= _legs.size():
		return
	var leg: Dictionary = _legs[index]
	if _book_is_live():
		_close_live_leg(index, leg)
	else:
		_legs.remove_at(index)
		RunLedger.set_portfolio(_run_state, _legs)
		_refresh_financials(true)
	_selected_leg_index = clampi(_selected_leg_index, 0, maxi(_legs.size() - 1, 0))
	_show_page(Page.BUILD)
	_show_toast("Position removed.", &"info", "Build updated")


func _update_leg_field(index: int, key: StringName, value: Variant) -> void:
	if index < 0 or index >= _legs.size() or _book_is_live():
		return
	var leg: Dictionary = _legs[index]
	leg[key] = value
	_legs[index] = leg
	RunLedger.set_portfolio(_run_state, _legs)
	_refresh_financials(true)
	_update_chrome()


func _clear_portfolio() -> void:
	if _book_is_live():
		_close_all_risk()
	else:
		_legs = [{"kind": &"cash", "amount": 0.0}]
		RunLedger.set_portfolio(_run_state, _legs)
		_refresh_financials(true)
		_show_toast("Build returned to cash only.", &"info", "Clean slate")
	_show_page(Page.BUILD)


func _make_template_leg(template_id: StringName) -> Dictionary:
	var spot := float(_market.get("spot", 100.0))
	var iv := float(_market.get("volatility", 0.20))
	match template_id:
		&"long_call":
			return _option_leg(&"long", &"call", roundf(spot * 1.04), 30, iv, 1.0)
		&"short_call":
			return _option_leg(&"short", &"call", roundf(spot * 1.08), 30, iv, 1.0)
		&"long_put":
			return _option_leg(&"long", &"put", roundf(spot * 0.96), 30, iv, 1.0)
		&"short_put":
			return _option_leg(&"short", &"put", roundf(spot * 0.92), 30, iv, 1.0)
		&"stock":
			return {"kind": &"stock", "quantity": -10.0}
		_:
			return {"kind": &"cash", "amount": 250.0}


func _option_leg(
	side: StringName,
	option_type: StringName,
	strike: float,
	expiry_days: int,
	iv: float,
	quantity: float,
) -> Dictionary:
	return {
		"kind": &"option",
		"side": side,
		"option_type": option_type,
		"strike": strike,
		"expiry_days": expiry_days,
		"iv": iv,
		"quantity": quantity,
		"contract_size": 1.0,
	}


func _leg_title(leg: Dictionary) -> String:
	var kind := StringName(leg.get("kind", &"cash"))
	if kind == &"option":
		return "%s %s  K%.0f" % [
			str(leg.get("side", &"long")).capitalize(),
			str(leg.get("option_type", &"call")).capitalize(),
			float(leg.get("strike", 0.0)),
		]
	if kind == &"stock":
		return "Stock hedge"
	return "Cash reserve"


func _leg_detail(leg: Dictionary) -> String:
	if StringName(leg.get("kind", &"cash")) == &"option":
		return "%d days · IV %.1f%%" % [int(leg.get("expiry_days", 0)), float(leg.get("iv", 0.0)) * 100.0]
	return _leg_quantity_text(leg)


func _leg_quantity_text(leg: Dictionary) -> String:
	var kind := StringName(leg.get("kind", &"cash"))
	if kind == &"cash":
		return "$%.0f" % float(leg.get("amount", 0.0))
	var quantity := float(leg.get("quantity", 0.0))
	if kind == &"option" and StringName(leg.get("side", &"long")) == &"short":
		quantity = -absf(quantity)
	return "%+.1f" % quantity


func _risk_score() -> float:
	var delta_load := absf(float(_snapshot.get("delta", 0.0))) / 120.0
	var gamma_load := absf(float(_snapshot.get("gamma", 0.0))) / 12.0
	var theta_load := absf(float(_snapshot.get("theta", 0.0))) / 1.2
	var vega_load := absf(float(_snapshot.get("vega", 0.0))) / 9.0
	return clampf(delta_load * 0.25 + gamma_load * 0.25 + theta_load * 0.20 + vega_load * 0.30, 0.0, 1.0)


func _payoff_payload() -> Dictionary:
	var spots: Array[float] = []
	var payoffs: Array[float] = []
	var center := float(_market.get("spot", 100.0))
	for index in 41:
		var shifted_spot := center * (0.60 + float(index) * 0.02)
		spots.append(shifted_spot)
		payoffs.append(_expiry_payoff(shifted_spot))
	return {"spots": spots, "payoffs": payoffs, "current_spot": center}


func _expiry_payoff(spot_at_expiry: float) -> float:
	return PortfolioEngine.payoff_at_expiry(_legs, _market, spot_at_expiry)


func _refresh_financials(rebase_opening_book: bool = false) -> void:
	_snapshot = PortfolioEngine.summarize(_legs, _market)
	_run_state["snapshot"] = _snapshot.duplicate(true)
	_run_state["portfolio"] = _legs.duplicate(true)
	if rebase_opening_book:
		_baseline_value = float(_snapshot.get("value", 0.0))
		_total_costs = 0.0
		_records = [{
			"step": int(_market.get("day", 0)),
			"market": _market.duplicate(true),
			"portfolio": _snapshot.duplicate(true),
			"pnl": 0.0,
			"action": "Opening book",
			"transaction_cost": 0.0,
			"is_market_step": false,
		}]
		_attribution = PnlAttribution.calculate(_records)
		_run_state["attribution"] = _attribution.duplicate(true)


func _append_record(action_label: String, transaction_cost: float, is_market_step: bool) -> void:
	_total_costs += maxf(transaction_cost, 0.0)
	_refresh_financials()
	var live_pnl := float(_snapshot.get("value", 0.0)) - _baseline_value - _total_costs
	_records.append({
		"step": int(_market.get("day", 0)),
		"market": _market.duplicate(true),
		"portfolio": _snapshot.duplicate(true),
		"pnl": live_pnl,
		"action": action_label,
		"transaction_cost": maxf(transaction_cost, 0.0),
		"is_market_step": is_market_step,
	})
	_attribution = PnlAttribution.calculate(_records)
	_run_state["snapshot"] = _snapshot.duplicate(true)
	_run_state["attribution"] = _attribution.duplicate(true)
	_run_state["portfolio"] = _legs.duplicate(true)


func _book_is_live() -> bool:
	return int(_run_state.get("market_steps", 0)) > 0 or _records.size() > 1


func _empty_snapshot() -> Dictionary:
	return {
		"value": 0.0,
		"delta": 0.0,
		"gamma": 0.0,
		"theta": 0.0,
		"vega": 0.0,
		"rho": 0.0,
		"vanna": 0.0,
		"vomma": 0.0,
		"charm": 0.0,
		"speed": 0.0,
		"color": 0.0,
		"margin_estimate": 0.0,
	}


func _execute_live_trade(leg: Dictionary, label_text: String, action_type: StringName) -> void:
	if _settled:
		_show_toast("This run is settled. Retry before changing inventory.", &"warning", "Book locked")
		return
	var priced: Dictionary = PortfolioEngine.price_leg(leg, _market)
	var signed_value := float(priced.get("value", 0.0))
	var cost := MarketSimulator.transaction_cost(absf(signed_value), _market)
	_legs.append(leg.duplicate(true))
	_legs.append(PortfolioEngine.create_cash(-signed_value))
	RunLedger.set_portfolio(_run_state, _legs)
	RunLedger.record_action(_run_state, action_type, {
		"label": label_text,
		"signed_value": signed_value,
		"transaction_cost": cost,
	})
	_append_record(label_text, cost, false)


func _close_live_leg(index: int, leg: Dictionary) -> void:
	if _settled or index < 0 or index >= _legs.size():
		return
	if StringName(leg.get("kind", &"cash")) == &"cash":
		_show_toast("Cash is the settlement account, not a risk leg.", &"info", "Nothing to close")
		return
	var priced: Dictionary = PortfolioEngine.price_leg(leg, _market)
	var close_value := float(priced.get("value", 0.0))
	var cost := MarketSimulator.transaction_cost(absf(close_value), _market)
	_legs.remove_at(index)
	_legs.append(PortfolioEngine.create_cash(close_value))
	RunLedger.set_portfolio(_run_state, _legs)
	RunLedger.record_action(_run_state, &"close_leg", {
		"leg": leg.duplicate(true),
		"close_value": close_value,
		"transaction_cost": cost,
	})
	_append_record("Closed %s" % _leg_title(leg), cost, false)


func _close_all_risk() -> void:
	if _settled:
		return
	var cash_balance := 0.0
	var close_proceeds := 0.0
	var gross_close_value := 0.0
	var risk_leg_count := 0
	for leg_value: Variant in _legs:
		if not leg_value is Dictionary:
			continue
		var leg: Dictionary = leg_value
		if StringName(leg.get("kind", &"cash")) == &"cash":
			cash_balance += float(leg.get("amount", 0.0))
		else:
			var priced: Dictionary = PortfolioEngine.price_leg(leg, _market)
			var signed_value := float(priced.get("value", 0.0))
			close_proceeds += signed_value
			gross_close_value += absf(signed_value)
			risk_leg_count += 1
	if risk_leg_count == 0:
		_show_toast("The book is already cash only.", &"info", "No risk open")
		return
	var cost := MarketSimulator.transaction_cost(gross_close_value, _market)
	_legs = [PortfolioEngine.create_cash(cash_balance + close_proceeds)]
	RunLedger.set_portfolio(_run_state, _legs)
	_run_state["cleared_count"] = int(_run_state.get("cleared_count", 0)) + 1
	RunLedger.record_action(_run_state, &"clear", {
		"removed_leg_count": risk_leg_count,
		"close_proceeds": close_proceeds,
		"transaction_cost": cost,
	})
	_append_record("Closed all risk", cost, false)
	_show_toast("Risk closed without deleting history, drawdown, or steps.", &"warning", "Book flattened")


func _reset_session() -> void:
	_running = false
	if _run_timer != null:
		_run_timer.stop()
	_run_state = RunLedger.new_run(_current_level)
	_market = Dictionary(_current_level.get("initial_market", {})).duplicate(true)
	_legs = Array(_current_level.get("initial_portfolio", [])).duplicate(true)
	_records = []
	_attribution = {
		"total_pnl": 0.0,
		"delta_pnl": 0.0,
		"gamma_pnl": 0.0,
		"theta_pnl": 0.0,
		"vega_pnl": 0.0,
		"transaction_cost": 0.0,
		"residual": 0.0,
		"max_drawdown": 0.0,
		"risk_violations": 0,
		"realized_vol": 0.0,
		"implied_vol": float(_market.get("volatility", 0.0)),
	}
	_total_costs = 0.0
	_baseline_value = 0.0
	_selected_leg_index = 0
	_settled = false
	_forecast_committed = false
	_forecast_values = {"spot_up": 0.55, "rv_beats_iv": 0.50, "iv_crush": 0.45, "risk_breach": 0.35}
	_quote_sequence = 0
	_current_order = {}
	_refresh_financials(true)


func _step_market() -> void:
	if _settled:
		_show_page(Page.REVIEW)
		return
	if not bool(Dictionary(_run_state.get("probability_commitment", {})).get("committed", false)):
		_running = false
		if _run_timer != null:
			_run_timer.stop()
		_show_toast("Commit the four forecasts before revealing the first day.", &"warning", "Forecast first")
		_update_chrome()
		return
	if not RunLedger.can_advance_market(_run_state):
		_settle_run()
		return

	var previous_volatility := float(_market.get("volatility", 0.20))
	var next_market: Dictionary = MarketSimulator.step(_market)
	var volatility_move := float(next_market.get("volatility", previous_volatility)) - previous_volatility
	var decayed_legs: Array = PortfolioEngine.decay_expiries(_legs, 1.0)
	for index in decayed_legs.size():
		if not decayed_legs[index] is Dictionary:
			continue
		var leg: Dictionary = decayed_legs[index]
		if StringName(leg.get("kind", &"cash")) == &"option":
			leg["iv"] = clampf(float(leg.get("iv", previous_volatility)) + volatility_move, 0.03, 1.40)
			decayed_legs[index] = leg
	_market = next_market
	_legs = decayed_legs
	RunLedger.set_portfolio(_run_state, _legs)
	_append_record("Market day %d" % int(_market.get("day", 0)), 0.0, true)
	RunLedger.record_market_step(_run_state, _snapshot, _attribution)
	_current_order = {}

	if int(_run_state.get("market_steps", 0)) >= int(_run_state.get("effective_horizon", 0)):
		_settle_run()
		return
	if _current_page == Page.RUN:
		_show_page(Page.RUN, false)
	else:
		_update_chrome()


func _toggle_run() -> void:
	if _settled:
		_show_page(Page.REVIEW)
		return
	if not bool(Dictionary(_run_state.get("probability_commitment", {})).get("committed", false)):
		_show_toast("Commit the four forecasts before starting the path.", &"warning", "Forecast first")
		return
	_running = not _running
	if _running:
		_run_timer.start()
		_show_toast("Auto run started. Pause any time to hedge.", &"info", "Market running")
	else:
		_run_timer.stop()
		_show_toast("Market paused. The desk is ready for an adjustment.", &"info", "Paused")
	_update_chrome()


func _update_chrome() -> void:
	var horizon := int(_current_level.get("horizon", 0))
	var steps := int(_run_state.get("market_steps", 0))
	_top_day.text = "DAY  %d/%d" % [steps, horizon]
	_top_practice.text = "PRACTICE" if bool(_run_state.get("practice_override", false)) else "OFFICIAL"
	_top_practice.add_theme_color_override(
		"font_color",
		ForgeTheme.AMBER if bool(_run_state.get("practice_override", false)) else ForgeTheme.LIME,
	)
	var live_pnl := float(_attribution.get("total_pnl", 0.0))
	var risk := _risk_score()
	_top_pnl.text = "P&L  %s" % _format_money(live_pnl)
	_top_pnl.add_theme_color_override("font_color", ForgeTheme.LIME if live_pnl >= 0.0 else ForgeTheme.RED)
	_top_risk.text = "RISK  %d%%" % roundi(risk * 100.0)
	_top_risk.add_theme_color_override("font_color", ForgeTheme.RED if risk > 0.70 else (ForgeTheme.AMBER if risk > 0.42 else ForgeTheme.TEAL))

	_disconnect_button(_bottom_secondary)
	_disconnect_button(_bottom_primary)
	_bottom_secondary.visible = true
	match _current_page:
		Page.MISSION:
			_bottom_hint.text = "One mission. One fixed horizon. One clear learning point."
			_bottom_secondary.text = "How it works"
			_bottom_secondary.pressed.connect(_show_onboarding)
			_bottom_primary.text = "Start mission"
			_bottom_primary.pressed.connect(_start_selected_mission)
		Page.BUILD:
			_bottom_hint.text = "Build before the first market step; live changes have cost."
			_bottom_secondary.text = "Back to Mission"
			_bottom_secondary.pressed.connect(_show_page.bind(Page.MISSION))
			_bottom_primary.text = "Ready to run"
			_bottom_primary.pressed.connect(_show_page.bind(Page.RUN))
		Page.RUN:
			if _settled:
				_bottom_hint.text = "The fixed horizon is complete. Open the full debrief."
				_bottom_secondary.text = "Retry"
				_bottom_secondary.pressed.connect(_start_selected_mission)
				_bottom_primary.text = "Open review"
				_bottom_primary.pressed.connect(_show_page.bind(Page.REVIEW))
			else:
				_bottom_hint.text = "Forecast first. Then step, hedge, and stay inside the risk budget."
				_bottom_secondary.text = "Pause" if _running else "Auto run"
				_bottom_secondary.pressed.connect(_toggle_run)
				_bottom_primary.text = "Advance one day"
				_bottom_primary.pressed.connect(_step_market)
		Page.REVIEW:
			var report := _score_report()
			var evaluation: Dictionary = report.get("evaluation", {})
			_bottom_hint.text = "The best next step is the one the debrief can explain."
			_bottom_secondary.text = "Retry"
			_bottom_secondary.pressed.connect(_start_selected_mission)
			if _settled and bool(evaluation.get("leaderboard_eligible", false)):
				_bottom_primary.text = "Save official run"
				_bottom_primary.pressed.connect(_save_current_run)
			else:
				_bottom_primary.text = "Next mission"
				_bottom_primary.pressed.connect(_select_next_core_mission)


func _set_mission_mode(mode: StringName) -> void:
	_current_mode = mode
	if mode != &"challenge":
		var filtered := _levels_for_mode(mode)
		if not filtered.is_empty():
			_current_level = filtered[0].duplicate(true)
			_run_state = RunLedger.new_run(_current_level)
	_show_page(Page.MISSION)


func _select_level(level_id: String) -> void:
	_current_level = LevelCatalog.get_level(level_id).duplicate(true)
	_reset_session()
	_show_page(Page.MISSION)


func _start_selected_mission() -> void:
	_reset_session()
	_show_page(Page.BUILD)
	_show_toast("Mission reset to its official starting state.", &"success", "Build first")


func _launch_seed(seed_text: String) -> void:
	var clean_seed := seed_text.strip_edges()
	if clean_seed.is_empty():
		_show_toast("Enter a seed so this challenge can be replayed.", &"warning", "Seed required")
		return
	_current_level = ChallengeGenerator.generate(clean_seed, 0)
	_reset_session()
	_show_page(Page.MISSION)
	_show_toast("Challenge built. The same seed will recreate it.", &"success", "Seed locked")


func _launch_daily() -> void:
	_current_level = ChallengeGenerator.daily()
	_reset_session()
	_show_page(Page.MISSION)
	_show_toast("Today’s deterministic challenge is ready.", &"success", "Daily desk")


func _select_next_core_mission() -> void:
	var core := LevelCatalog.core_levels()
	var current_id := str(_current_level.get("id", ""))
	var next_index := 0
	for index in core.size():
		if str(core[index].get("id", "")) == current_id:
			next_index = mini(index + 1, core.size() - 1)
			break
	_current_mode = &"core"
	_current_level = core[next_index].duplicate(true)
	_reset_session()
	_show_page(Page.MISSION)


func _show_onboarding() -> void:
	if get_node_or_null("Onboarding") != null:
		return
	var overlay := OnboardingOverlay.new()
	overlay.name = "Onboarding"
	overlay.finished.connect(_finish_onboarding)
	overlay.skipped.connect(_skip_onboarding)
	add_child(overlay)


func _finish_onboarding() -> void:
	var response: Dictionary = ProgressStore.mark_tutorial_completed(_progress)
	_progress = response.get("progress", _progress)
	_show_toast("You are ready. Start with one Delta decision.", &"success", "First mission")


func _skip_onboarding() -> void:
	_show_toast("Introduction skipped. Reopen it from “How it works”.", &"info", "Saved for later")


func _on_viewport_resized() -> void:
	var compact_now := get_viewport_rect().size.x < 980.0
	if compact_now == _compact_layout:
		return
	_compact_layout = compact_now
	_show_page(_current_page)


func _levels_for_mode(mode: StringName) -> Array[Dictionary]:
	if mode == &"final":
		return LevelCatalog.final_trials()
	return LevelCatalog.core_levels()


func _count_completed_category(category: StringName, completed: Array) -> int:
	var count := 0
	for level: Dictionary in _all_levels:
		if StringName(level.get("category", &"")) == category and completed.has(str(level.get("id", ""))):
			count += 1
	return count


func _best_score_text() -> String:
	var scores: Dictionary = _progress.get("best_scores", {})
	var best := 0
	for value: Variant in scores.values():
		best = maxi(best, int(value))
	return "%d" % best if best > 0 else "—"


func _page_heading(title: String, subtitle: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_make_label(title, 28, ForgeTheme.TEXT))
	var subtitle_label := _make_label(subtitle, 15, ForgeTheme.MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(subtitle_label)
	var badge := _make_label("%s  ·  D%d" % [str(_current_level.get("title", "Mission")), int(_current_level.get("difficulty", 1))], 13, ForgeTheme.TEAL)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(badge)
	return row


func _card(
	background: Color = ForgeTheme.SURFACE,
	border: Color = ForgeTheme.BORDER,
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ForgeTheme.panel_style(background, 16, border, 1))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _hint_panel(title: String, body: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	var style := ForgeTheme.panel_style(Color(accent, 0.08), 12, Color(accent, 0.38), 1)
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	column.add_child(_make_label(title, 13, accent))
	var body_label := _make_label(body, 14, ForgeTheme.MUTED)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body_label)
	return panel


func _metric_block(eyebrow_text: String, value: String, detail: String) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_make_label(eyebrow_text, 11, ForgeTheme.MUTED))
	column.add_child(_make_label(value, 25, ForgeTheme.TEXT))
	column.add_child(_make_label(detail, 13, ForgeTheme.FAINT))
	return column


func _status_chip(text: String, color: Color) -> Label:
	var label := _make_label(text, 13, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(108.0, 40.0)
	label.add_theme_stylebox_override(
		"normal",
		ForgeTheme.panel_style(ForgeTheme.SURFACE_RAISED, 11, ForgeTheme.BORDER, 1),
	)
	return label


func _eyebrow(text: String) -> Label:
	return _make_label(text, 11, ForgeTheme.MUTED)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _flex_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _disconnect_button(button: Button) -> void:
	for connection: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])


func _show_toast(message: String, kind: StringName = &"info", title: String = "") -> void:
	if _toast != null and _toast.has_method("show_toast"):
		_toast.call("show_toast", message, kind, 2.8, title)


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ForgeTheme.RED)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
