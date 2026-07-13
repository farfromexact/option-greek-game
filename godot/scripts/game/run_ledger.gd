class_name RunLedger
extends RefCounted

## Owns the pieces of run state that must not be conflated by the UI.
## Market time advances only through `record_market_step`; actions never do.


static func new_run(
        level: Dictionary,
        practice_override: bool = false,
        horizon_override: int = -1
    ) -> Dictionary:
    var official_horizon := int(level.get("horizon", 1))
    var effective_horizon := official_horizon
    if practice_override and horizon_override > 0:
        effective_horizon = horizon_override
    var now_usec := Time.get_ticks_usec()
    var run_id := "%s-%d-%d" % [
        String(level.get("id", "run")),
        int(level.get("seed", 0)),
        now_usec,
    ]
    return {
        "schema_version": 1,
        "run_id": run_id,
        "level_id": String(level.get("id", "")),
        "level_title": String(level.get("title", "")),
        "seed": int(level.get("seed", 0)),
        "formal_level": bool(level.get("formal", false)),
        "official_horizon": official_horizon,
        "effective_horizon": effective_horizon,
        "practice_override": practice_override,
        "market_steps": 0,
        "action_history": [],
        "portfolio": level.get("initial_portfolio", []).duplicate(true),
        "snapshot": {},
        "attribution": {},
        "quote_count": 0,
        "fill_count": 0,
        "market_making_edge": 0.0,
        "probability_commitment": {},
        "cleared_count": 0,
        "run_failed": false,
        "failure_reason": "",
        "finished": false,
        "started_at_unix": Time.get_unix_time_from_system(),
    }


static func can_advance_market(run_state: Dictionary) -> bool:
    if bool(run_state.get("run_failed", false)) or bool(run_state.get("finished", false)):
        return false
    return int(run_state.get("market_steps", 0)) < int(run_state.get("effective_horizon", 0))


static func record_market_step(
        run_state: Dictionary,
        snapshot: Dictionary = {},
        attribution: Dictionary = {}
    ) -> bool:
    if not can_advance_market(run_state):
        return false
    run_state["market_steps"] = int(run_state.get("market_steps", 0)) + 1
    if not snapshot.is_empty():
        run_state["snapshot"] = snapshot.duplicate(true)
    if not attribution.is_empty():
        run_state["attribution"] = attribution.duplicate(true)
    run_state["horizon_reached"] = (
        int(run_state["market_steps"]) == int(run_state.get("effective_horizon", 0))
    )
    return true


static func record_action(
        run_state: Dictionary,
        action_type: StringName,
        payload: Dictionary = {}
    ) -> bool:
    if bool(run_state.get("finished", false)):
        return false
    var history: Array = run_state.get("action_history", [])
    history.append({
        "sequence": history.size() + 1,
        "type": action_type,
        "market_step": int(run_state.get("market_steps", 0)),
        "payload": payload.duplicate(true),
        "created_at_unix": Time.get_unix_time_from_system(),
    })
    run_state["action_history"] = history
    return true


static func set_portfolio(run_state: Dictionary, portfolio: Array) -> bool:
    if bool(run_state.get("finished", false)):
        return false
    run_state["portfolio"] = portfolio.duplicate(true)
    return true


static func clear_portfolio(run_state: Dictionary) -> bool:
    if bool(run_state.get("finished", false)):
        return false
    var before: Array = run_state.get("portfolio", [])
    var cash_amount := 0.0
    for leg_value in before:
        if leg_value is Dictionary and StringName(leg_value.get("kind", &"")) == &"cash":
            cash_amount += float(leg_value.get("amount", 0.0))
    # Clear removes risk legs but deliberately preserves the full action history,
    # market step count, quote/fill counters, and probability commitment.
    run_state["portfolio"] = [{"kind": &"cash", "amount": cash_amount}]
    run_state["cleared_count"] = int(run_state.get("cleared_count", 0)) + 1
    return record_action(run_state, &"clear", {"removed_leg_count": maxi(before.size() - 1, 0)})


static func record_quote(run_state: Dictionary, quote: Dictionary) -> bool:
    if float(quote.get("size", 0.0)) <= 0.0:
        return false
    if not quote.has("bid") or not quote.has("ask"):
        return false
    if float(quote["ask"]) <= float(quote["bid"]):
        return false
    run_state["quote_count"] = int(run_state.get("quote_count", 0)) + 1
    return record_action(run_state, &"quote", quote)


static func record_fill(
        run_state: Dictionary,
        fill: Dictionary,
        captured_edge: float
    ) -> bool:
    if absf(float(fill.get("quantity", 0.0))) <= 0.000001:
        return false
    run_state["fill_count"] = int(run_state.get("fill_count", 0)) + 1
    run_state["market_making_edge"] = float(run_state.get("market_making_edge", 0.0)) + captured_edge
    var payload := fill.duplicate(true)
    payload["captured_edge"] = captured_edge
    return record_action(run_state, &"fill", payload)


static func commit_probabilities(
        run_state: Dictionary,
        questions: Array
    ) -> Dictionary:
    if int(run_state.get("market_steps", 0)) != 0:
        return {"accepted": false, "reason": "Probabilities must be committed before the first market step."}
    if not Dictionary(run_state.get("probability_commitment", {})).is_empty():
        return {"accepted": false, "reason": "The probability commitment is locked for this run."}
    if questions.is_empty():
        return {"accepted": false, "reason": "At least one probability is required."}

    var normalized: Array[Dictionary] = []
    var seen_ids := {}
    for index in questions.size():
        var question_value: Variant = questions[index]
        if not question_value is Dictionary:
            return {"accepted": false, "reason": "Probability question %d is invalid." % (index + 1)}
        var question: Dictionary = question_value
        var question_id := String(question.get("id", "question-%d" % (index + 1)))
        var probability := float(question.get("probability", -1.0))
        if seen_ids.has(question_id):
            return {"accepted": false, "reason": "Probability question ids must be unique."}
        if probability < 0.0 or probability > 1.0:
            return {"accepted": false, "reason": "Probabilities must stay between 0 and 1."}
        seen_ids[question_id] = true
        normalized.append({
            "id": question_id,
            "label": String(question.get("label", question_id)),
            "probability": probability,
            "resolved": false,
        })

    run_state["probability_commitment"] = {
        "committed": true,
        "committed_at_market_step": 0,
        "questions": normalized,
        "resolved": false,
        "average_brier": -1.0,
    }
    record_action(run_state, &"probability_commit", {"question_count": normalized.size()})
    return {"accepted": true, "reason": "Forecasts committed and locked."}


static func resolve_probability_outcomes(
        run_state: Dictionary,
        outcomes_by_id: Dictionary
    ) -> Dictionary:
    var commitment: Dictionary = run_state.get("probability_commitment", {})
    if not bool(commitment.get("committed", false)):
        return {"resolved": false, "reason": "No pre-run probability commitment exists."}
    if bool(commitment.get("resolved", false)):
        return {
            "resolved": true,
            "average_brier": float(commitment.get("average_brier", -1.0)),
            "reason": "Probability commitment was already resolved.",
        }

    var questions: Array = commitment.get("questions", [])
    var brier_total := 0.0
    for index in questions.size():
        var question: Dictionary = questions[index]
        var question_id := String(question.get("id", ""))
        if not outcomes_by_id.has(question_id):
            return {"resolved": false, "reason": "Missing outcome for '%s'." % question_id}
        var outcome := 1.0 if bool(outcomes_by_id[question_id]) else 0.0
        var probability := float(question.get("probability", 0.0))
        var brier := pow(probability - outcome, 2.0)
        question["outcome"] = bool(outcomes_by_id[question_id])
        question["brier"] = brier
        question["resolved"] = true
        questions[index] = question
        brier_total += brier

    var average_brier := brier_total / float(questions.size())
    commitment["questions"] = questions
    commitment["resolved"] = true
    commitment["average_brier"] = average_brier
    run_state["probability_commitment"] = commitment
    run_state["average_brier"] = average_brier
    return {"resolved": true, "average_brier": average_brier, "reason": "Forecasts scored."}


static func fail_run(run_state: Dictionary, reason: String) -> void:
    if bool(run_state.get("finished", false)):
        return
    run_state["run_failed"] = true
    run_state["failure_reason"] = reason
    record_action(run_state, &"run_failed", {"reason": reason})


static func finish_run(run_state: Dictionary) -> bool:
    if bool(run_state.get("run_failed", false)):
        run_state["finished"] = true
        run_state["finished_at_unix"] = Time.get_unix_time_from_system()
        return false
    if int(run_state.get("market_steps", 0)) != int(run_state.get("effective_horizon", 0)):
        return false
    run_state["finished"] = true
    run_state["finished_at_unix"] = Time.get_unix_time_from_system()
    return true
