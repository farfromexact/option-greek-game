class_name ScoreCalculator
extends RefCounted

const Evaluator = preload("res://scripts/game/objective_evaluator.gd")
const Objectives = preload("res://scripts/game/objective_defs.gd")


static func calculate(
        level: Dictionary,
        run_state: Dictionary,
        snapshot: Dictionary = {},
        attribution: Dictionary = {},
        legs: Array = []
    ) -> int:
    return int(calculate_report(level, run_state, snapshot, attribution, legs)["score"])


static func calculate_report(
        level: Dictionary,
        run_state: Dictionary,
        snapshot: Dictionary = {},
        attribution: Dictionary = {},
        legs: Array = []
    ) -> Dictionary:
    var effective_snapshot := snapshot if not snapshot.is_empty() else Dictionary(run_state.get("snapshot", {}))
    var effective_attribution := attribution if not attribution.is_empty() else Dictionary(run_state.get("attribution", {}))
    var evaluation := Evaluator.evaluate(level, run_state, effective_snapshot, effective_attribution, legs)
    if bool(run_state.get("run_failed", false)):
        return {
            "score": 0,
            "completed": false,
            "leaderboard_eligible": false,
            "evaluation": evaluation,
            "breakdown": {
                "objective": 0.0,
                "pnl": 0.0,
                "risk": 0.0,
                "calibration_modifier": 0.0,
            },
        }

    var objective_points := clampf(float(evaluation.get("objective_progress", 0.0)), 0.0, 1.0) * 60.0
    var total_pnl := float(effective_attribution.get("total_pnl", 0.0))
    var pnl_quality := clampf(0.5 + total_pnl / 40.0, 0.0, 1.0)
    var pnl_points := pnl_quality * 20.0

    var drawdown := maxf(float(effective_attribution.get("max_drawdown", 0.0)), 0.0)
    var risk_violations := maxi(int(effective_attribution.get("risk_violations", 0)), 0)
    var risk_quality := clampf(1.0 - drawdown / 50.0 - risk_violations * 0.12, 0.0, 1.0)
    var risk_points := risk_quality * 20.0

    # Brier already has a required objective and therefore contributes to the
    # 60 objective points. This small modifier also rewards genuinely sharp,
    # calibrated forecasts instead of treating every passing score as equal.
    var calibration_modifier := 0.0
    var brier := _resolved_brier(level, run_state)
    if brier >= 0.0:
        calibration_modifier = clampf((0.25 - brier) * 20.0, -5.0, 5.0)

    var raw_score := objective_points + pnl_points + risk_points + calibration_modifier
    var completed := bool(evaluation.get("completed", false))
    if not completed:
        raw_score = minf(raw_score, 69.0)
    var score := clampi(roundi(raw_score), 0, 100)
    return {
        "score": score,
        "completed": completed,
        "leaderboard_eligible": bool(evaluation.get("leaderboard_eligible", false)),
        "evaluation": evaluation,
        "breakdown": {
            "objective": objective_points,
            "pnl": pnl_points,
            "risk": risk_points,
            "calibration_modifier": calibration_modifier,
            "raw": raw_score,
        },
    }


static func _resolved_brier(level: Dictionary, run_state: Dictionary) -> float:
    var has_probability_objective := false
    for objective_value in level.get("objectives", []):
        if objective_value is Dictionary and StringName(objective_value.get("kind", &"")) == Objectives.KIND_PROBABILITY:
            has_probability_objective = true
            break
    if not has_probability_objective:
        return -1.0
    var commitment: Dictionary = run_state.get("probability_commitment", {})
    if not bool(commitment.get("resolved", false)):
        return -1.0
    return float(commitment.get("average_brier", -1.0))
