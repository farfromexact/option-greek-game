class_name ObjectiveEvaluator
extends RefCounted

const Objectives = preload("res://scripts/game/objective_defs.gd")
const EPSILON := 0.000001


static func evaluate(
        level: Dictionary,
        run_state: Dictionary,
        snapshot: Dictionary = {},
        attribution: Dictionary = {},
        legs: Array = []
    ) -> Dictionary:
    var effective_snapshot := snapshot
    if effective_snapshot.is_empty():
        effective_snapshot = run_state.get("snapshot", {})
    var effective_attribution := attribution
    if effective_attribution.is_empty():
        effective_attribution = run_state.get("attribution", {})
    var effective_legs := legs
    if effective_legs.is_empty():
        effective_legs = run_state.get("portfolio", [])

    var checks: Array[Dictionary] = []
    var reasons: Array[String] = []
    var failed_ids: Array[String] = []
    var weighted_progress := 0.0
    var total_weight := 0.0

    for objective_value in level.get("objectives", []):
        if not objective_value is Dictionary:
            reasons.append("The level contains an invalid objective definition.")
            continue
        var objective: Dictionary = objective_value
        var check := _evaluate_objective(
            objective, level, run_state, effective_snapshot, effective_attribution, effective_legs
        )
        checks.append(check)
        var weight := float(objective.get("weight", 1.0))
        total_weight += weight
        weighted_progress += clampf(float(check.get("progress", 0.0)), 0.0, 1.0) * weight
        if bool(objective.get("required", true)) and not bool(check.get("passed", false)):
            failed_ids.append(String(objective.get("id", "unknown")))
            reasons.append(String(check.get("message", objective.get("label", "Objective not met."))))

    var failed_run := bool(run_state.get("run_failed", false))
    if failed_run:
        var failure_reason := String(run_state.get("failure_reason", "Run failed."))
        if failure_reason.is_empty():
            failure_reason = "Run failed."
        reasons.push_front(failure_reason)

    var all_required_passed := failed_ids.is_empty() and not failed_run
    var practice_override := bool(run_state.get("practice_override", false))
    var fixed_horizon_intact := _fixed_horizon_intact(level, run_state)
    var leaderboard_eligible := (
        all_required_passed
        and not practice_override
        and not failed_run
        and fixed_horizon_intact
    )
    if all_required_passed and reasons.is_empty():
        reasons.append("All required objectives met. Debrief attribution is ready.")

    return {
        "completed": all_required_passed,
        "passed": all_required_passed,
        "reasons": reasons,
        "checks": checks,
        "failed_objective_ids": failed_ids,
        "objective_progress": weighted_progress / total_weight if total_weight > 0.0 else 0.0,
        "formal_complete": all_required_passed and fixed_horizon_intact,
        "leaderboard_eligible": leaderboard_eligible,
        "practice_override": practice_override,
        "run_failed": failed_run,
        "fixed_horizon_intact": fixed_horizon_intact,
    }


static func _evaluate_objective(
        objective: Dictionary,
        level: Dictionary,
        run_state: Dictionary,
        snapshot: Dictionary,
        attribution: Dictionary,
        legs: Array
    ) -> Dictionary:
    var kind := StringName(objective.get("kind", &""))
    match kind:
        Objectives.KIND_METRIC:
            return _metric_check(objective, run_state, snapshot, attribution)
        Objectives.KIND_HORIZON:
            return _horizon_check(objective, level, run_state)
        Objectives.KIND_ACTION_COUNT:
            return _action_check(objective, run_state)
        Objectives.KIND_CALL_SPREAD:
            return _call_spread_check(objective, legs)
        Objectives.KIND_BUTTERFLY:
            return _butterfly_check(objective, legs)
        Objectives.KIND_MARKET_MAKING:
            return _market_making_check(objective, run_state)
        Objectives.KIND_PROBABILITY:
            return _probability_check(objective, run_state)
        _:
            return _check(objective, false, 0.0, 0.0, "Unknown objective type.")


static func _metric_check(
        objective: Dictionary,
        run_state: Dictionary,
        snapshot: Dictionary,
        attribution: Dictionary
    ) -> Dictionary:
    var field := StringName(objective.get("field", &""))
    var actual := _metric_value(field, run_state, snapshot, attribution)
    var target := float(objective.get("target", 0.0))
    var operator := StringName(objective.get("operator", Objectives.OP_AT_LEAST))
    var passed := false
    var progress := 0.0
    match operator:
        Objectives.OP_AT_LEAST:
            passed = actual + EPSILON >= target
            if target > 0.0:
                progress = clampf(actual / target, 0.0, 1.0)
            else:
                progress = 1.0 if passed else clampf(1.0 / (1.0 + absf(target - actual)), 0.0, 1.0)
        Objectives.OP_AT_MOST:
            passed = actual <= target + EPSILON
            if passed:
                progress = 1.0
            elif actual > 0.0 and target >= 0.0:
                progress = clampf(target / actual, 0.0, 1.0)
            else:
                progress = 0.0
        Objectives.OP_EXACTLY:
            passed = absf(actual - target) <= EPSILON
            progress = 1.0 if passed else clampf(1.0 - absf(actual - target) / maxf(absf(target), 1.0), 0.0, 1.0)

    var message := ""
    if not passed:
        if operator == Objectives.OP_AT_LEAST:
            message = "%s Current %.2f; need at least %.2f." % [objective.get("label", "Metric"), actual, target]
        elif operator == Objectives.OP_AT_MOST:
            message = "%s Current %.2f; limit %.2f." % [objective.get("label", "Metric"), actual, target]
        else:
            message = "%s Current %.2f; required %.2f." % [objective.get("label", "Metric"), actual, target]
    return _check(objective, passed, actual, target, message, progress)


static func _horizon_check(
        objective: Dictionary,
        level: Dictionary,
        run_state: Dictionary
    ) -> Dictionary:
    var official_target := int(objective.get("steps", level.get("horizon", 0)))
    var target := official_target
    if bool(run_state.get("practice_override", false)):
        target = int(run_state.get("effective_horizon", official_target))
    var actual := int(run_state.get("market_steps", 0))
    var passed := actual == target
    var message := ""
    if actual < target:
        message = "Advance the market %d more step%s." % [target - actual, "" if target - actual == 1 else "s"]
    elif actual > target:
        message = "The run exceeded its fixed %d-step horizon." % target
    return _check(
        objective,
        passed,
        actual,
        target,
        message,
        clampf(float(actual) / float(maxi(target, 1)), 0.0, 1.0) if actual <= target else 0.0
    )


static func _action_check(objective: Dictionary, run_state: Dictionary) -> Dictionary:
    var action_type := StringName(objective.get("action_type", &""))
    var minimum := int(objective.get("minimum", 1))
    var count := 0
    # Intentionally reads action_history only. Market steps are a separate clock.
    for action_value in run_state.get("action_history", []):
        if action_value is Dictionary and StringName(action_value.get("type", &"")) == action_type:
            count += 1
    var passed := count >= minimum
    var message := "" if passed else "%s Recorded %d; need %d." % [objective.get("label", "Action"), count, minimum]
    return _check(
        objective, passed, count, minimum, message,
        clampf(float(count) / float(maxi(minimum, 1)), 0.0, 1.0)
    )


static func _call_spread_check(objective: Dictionary, legs: Array) -> Dictionary:
    var candidate := _find_call_spread(legs, objective)
    var passed := bool(candidate.get("passed", false))
    var actual := {
        "long_quantity": float(candidate.get("long_quantity", 0.0)),
        "short_quantity": float(candidate.get("short_quantity", 0.0)),
        "ratio": float(candidate.get("ratio", 0.0)),
        "long_strike": float(candidate.get("long_strike", 0.0)),
        "short_strike": float(candidate.get("short_strike", 0.0)),
    }
    var message := "" if passed else "Use non-zero calls at one expiry: long the lower strike and short the higher strike in the required ratio."
    return _check(objective, passed, actual, float(objective.get("long_to_short_ratio", 1.0)), message, 1.0 if passed else float(candidate.get("progress", 0.0)))


static func _butterfly_check(objective: Dictionary, legs: Array) -> Dictionary:
    var candidate := _find_butterfly(legs, objective)
    var passed := bool(candidate.get("passed", false))
    var message := "" if passed else "Use non-zero, equally spaced strikes at one expiry with signed quantities proportional to 1:-2:1."
    return _check(objective, passed, candidate, [1.0, -2.0, 1.0], message, 1.0 if passed else float(candidate.get("progress", 0.0)))


static func _market_making_check(objective: Dictionary, run_state: Dictionary) -> Dictionary:
    var quote_count := int(run_state.get("quote_count", 0))
    var fill_count := int(run_state.get("fill_count", 0))
    var edge := float(run_state.get("market_making_edge", 0.0))
    var min_quotes := int(objective.get("minimum_quotes", 1))
    var min_fills := int(objective.get("minimum_fills", 1))
    var min_edge := float(objective.get("minimum_edge", 0.0))
    var passed := quote_count >= min_quotes and fill_count >= min_fills and edge + EPSILON >= min_edge
    var progress := minf(
        clampf(float(quote_count) / float(maxi(min_quotes, 1)), 0.0, 1.0),
        clampf(float(fill_count) / float(maxi(min_fills, 1)), 0.0, 1.0)
    )
    if min_edge > 0.0:
        progress = minf(progress, clampf(edge / min_edge, 0.0, 1.0))
    elif edge < min_edge:
        progress = 0.0
    var message := "" if passed else "Market making: %d/%d quotes, %d/%d fills, %.2f/%.2f edge." % [quote_count, min_quotes, fill_count, min_fills, edge, min_edge]
    return _check(
        objective,
        passed,
        {"quotes": quote_count, "fills": fill_count, "edge": edge},
        {"quotes": min_quotes, "fills": min_fills, "edge": min_edge},
        message,
        progress
    )


static func _probability_check(objective: Dictionary, run_state: Dictionary) -> Dictionary:
    var commitment: Dictionary = run_state.get("probability_commitment", {})
    var committed := bool(commitment.get("committed", false))
    var commit_step := int(commitment.get("committed_at_market_step", -1))
    var resolved := bool(commitment.get("resolved", false))
    var questions: Array = commitment.get("questions", [])
    var minimum_questions := int(objective.get("minimum_questions", 1))
    var maximum_brier := float(objective.get("maximum_brier", 1.0))
    var average_brier := float(commitment.get("average_brier", run_state.get("average_brier", -1.0)))
    var probabilities_valid := true
    for question_value in questions:
        if not question_value is Dictionary:
            probabilities_valid = false
            break
        var probability := float(question_value.get("probability", -1.0))
        if probability < 0.0 or probability > 1.0:
            probabilities_valid = false
            break
    var passed := (
        committed
        and commit_step == int(objective.get("commit_before_step", 0))
        and resolved
        and questions.size() >= minimum_questions
        and probabilities_valid
        and average_brier >= 0.0
        and average_brier <= maximum_brier + EPSILON
    )
    var progress := 0.0
    if committed and commit_step == 0 and questions.size() >= minimum_questions and probabilities_valid:
        progress = 0.5
        if resolved and average_brier >= 0.0:
            progress = clampf(1.0 - average_brier, 0.0, 1.0)
            if passed:
                progress = 1.0
    var message := ""
    if not committed or commit_step != 0:
        message = "Commit all probabilities before the first market step."
    elif questions.size() < minimum_questions:
        message = "Commit at least %d probability questions." % minimum_questions
    elif not resolved:
        message = "Resolve the committed questions before scoring."
    elif not probabilities_valid:
        message = "Every committed probability must be between 0 and 1."
    elif average_brier > maximum_brier:
        message = "Average Brier %.3f exceeds the %.3f target." % [average_brier, maximum_brier]
    return _check(
        objective,
        passed,
        {"average_brier": average_brier, "question_count": questions.size(), "commit_step": commit_step},
        {"maximum_brier": maximum_brier, "minimum_questions": minimum_questions, "commit_step": 0},
        message,
        progress
    )


static func _metric_value(
        field: StringName,
        run_state: Dictionary,
        snapshot: Dictionary,
        attribution: Dictionary
    ) -> float:
    match field:
        &"abs_delta":
            return absf(float(snapshot.get("delta", 0.0)))
        &"abs_gamma":
            return absf(float(snapshot.get("gamma", 0.0)))
        &"abs_vega":
            return absf(float(snapshot.get("vega", 0.0)))
        &"abs_theta":
            return absf(float(snapshot.get("theta", 0.0)))
    if attribution.has(field):
        return float(attribution[field])
    if snapshot.has(field):
        return float(snapshot[field])
    var metrics: Dictionary = run_state.get("metrics", {})
    if metrics.has(field):
        return float(metrics[field])
    return float(run_state.get(field, 0.0))


static func _find_call_spread(legs: Array, objective: Dictionary) -> Dictionary:
    var positions := _aggregate_options(legs, &"call")
    var target_ratio := float(objective.get("long_to_short_ratio", 1.0))
    var tolerance := float(objective.get("ratio_tolerance", 0.08))
    var minimum := float(objective.get("minimum_contracts", 1.0))
    var best_progress := 0.0
    for long_position in positions:
        var long_quantity := float(long_position["quantity"])
        if long_quantity < minimum - EPSILON:
            continue
        for short_position in positions:
            var short_quantity := float(short_position["quantity"])
            if short_quantity > -minimum + EPSILON:
                continue
            if bool(objective.get("same_expiry", true)) and int(long_position["expiry_days"]) != int(short_position["expiry_days"]):
                continue
            if float(short_position["strike"]) <= float(long_position["strike"]) + EPSILON:
                continue
            var ratio := long_quantity / absf(short_quantity)
            var ratio_error := absf(ratio - target_ratio) / maxf(absf(target_ratio), EPSILON)
            var progress := clampf(1.0 - ratio_error, 0.0, 1.0)
            best_progress = maxf(best_progress, progress)
            if ratio_error <= tolerance:
                return {
                    "passed": true,
                    "progress": 1.0,
                    "long_quantity": long_quantity,
                    "short_quantity": absf(short_quantity),
                    "ratio": ratio,
                    "long_strike": long_position["strike"],
                    "short_strike": short_position["strike"],
                    "expiry_days": long_position["expiry_days"],
                }
    return {"passed": false, "progress": best_progress}


static func _find_butterfly(legs: Array, objective: Dictionary) -> Dictionary:
    var minimum := float(objective.get("minimum_wing_contracts", 1.0))
    var ratio_tolerance := float(objective.get("ratio_tolerance", 0.08))
    var strike_tolerance := float(objective.get("strike_tolerance", 0.001))
    var best_progress := 0.0
    for option_type in [&"call", &"put"]:
        var positions := _aggregate_options(legs, option_type)
        positions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            if int(a["expiry_days"]) == int(b["expiry_days"]):
                return float(a["strike"]) < float(b["strike"])
            return int(a["expiry_days"]) < int(b["expiry_days"])
        )
        for low_index in range(positions.size()):
            for mid_index in range(low_index + 1, positions.size()):
                for high_index in range(mid_index + 1, positions.size()):
                    var low: Dictionary = positions[low_index]
                    var mid: Dictionary = positions[mid_index]
                    var high: Dictionary = positions[high_index]
                    if int(low["expiry_days"]) != int(mid["expiry_days"]) or int(mid["expiry_days"]) != int(high["expiry_days"]):
                        continue
                    var low_quantity := float(low["quantity"])
                    var mid_quantity := float(mid["quantity"])
                    var high_quantity := float(high["quantity"])
                    if low_quantity < minimum - EPSILON or high_quantity < minimum - EPSILON or mid_quantity >= -EPSILON:
                        continue
                    var left_width := float(mid["strike"]) - float(low["strike"])
                    var right_width := float(high["strike"]) - float(mid["strike"])
                    if left_width <= EPSILON or right_width <= EPSILON:
                        continue
                    var spacing_error := absf(left_width - right_width) / maxf(left_width, right_width)
                    var scale := (low_quantity + high_quantity) * 0.5
                    var low_error := absf(low_quantity / scale - 1.0)
                    var mid_error := absf(mid_quantity / scale + 2.0) / 2.0
                    var high_error := absf(high_quantity / scale - 1.0)
                    var largest_error := maxf(maxf(low_error, mid_error), maxf(high_error, spacing_error))
                    best_progress = maxf(best_progress, clampf(1.0 - largest_error, 0.0, 1.0))
                    if spacing_error <= strike_tolerance and low_error <= ratio_tolerance and mid_error <= ratio_tolerance and high_error <= ratio_tolerance:
                        return {
                            "passed": true,
                            "progress": 1.0,
                            "option_type": option_type,
                            "expiry_days": low["expiry_days"],
                            "strikes": [low["strike"], mid["strike"], high["strike"]],
                            "quantities": [low_quantity, mid_quantity, high_quantity],
                        }
    return {"passed": false, "progress": best_progress}


static func _aggregate_options(legs: Array, required_type: StringName) -> Array[Dictionary]:
    var buckets := {}
    for leg_value in legs:
        if not leg_value is Dictionary:
            continue
        var leg: Dictionary = leg_value
        if StringName(leg.get("kind", &"")) != &"option":
            continue
        if StringName(leg.get("option_type", &"")) != required_type:
            continue
        var quantity := _signed_quantity(leg)
        if absf(quantity) <= EPSILON:
            continue
        var expiry_days := int(leg.get("expiry_days", 0))
        var strike := float(leg.get("strike", 0.0))
        var key := "%d|%.6f" % [expiry_days, strike]
        if not buckets.has(key):
            buckets[key] = {
                "option_type": required_type,
                "expiry_days": expiry_days,
                "strike": strike,
                "quantity": 0.0,
            }
        buckets[key]["quantity"] = float(buckets[key]["quantity"]) + quantity
    var positions: Array[Dictionary] = []
    for position_value in buckets.values():
        var position: Dictionary = position_value
        if absf(float(position["quantity"])) > EPSILON:
            positions.append(position)
    return positions


static func _signed_quantity(leg: Dictionary) -> float:
    var quantity := float(leg.get("quantity", 0.0))
    var side := StringName(leg.get("side", &""))
    if side == &"short":
        return -absf(quantity)
    if side == &"long":
        return absf(quantity)
    return quantity


static func _fixed_horizon_intact(level: Dictionary, run_state: Dictionary) -> bool:
    if not bool(level.get("formal", false)):
        return true
    var horizon := int(level.get("horizon", 0))
    return (
        not bool(run_state.get("practice_override", false))
        and int(run_state.get("market_steps", -1)) == horizon
        and int(run_state.get("official_horizon", horizon)) == horizon
        and int(run_state.get("effective_horizon", horizon)) == horizon
    )


static func _check(
        objective: Dictionary,
        passed: bool,
        actual: Variant,
        target: Variant,
        message: String,
        progress: float = -1.0
    ) -> Dictionary:
    return {
        "id": String(objective.get("id", "unknown")),
        "kind": StringName(objective.get("kind", &"")),
        "label": String(objective.get("label", "")),
        "passed": passed,
        "actual": actual,
        "target": target,
        "message": message,
        "progress": (1.0 if passed else 0.0) if progress < 0.0 else clampf(progress, 0.0, 1.0),
        "weight": float(objective.get("weight", 1.0)),
    }
