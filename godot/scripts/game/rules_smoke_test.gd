extends SceneTree

const Catalog = preload("res://scripts/game/level_catalog.gd")
const Evaluator = preload("res://scripts/game/objective_evaluator.gd")
const Ledger = preload("res://scripts/game/run_ledger.gd")
const Scores = preload("res://scripts/game/score_calculator.gd")
const Store = preload("res://scripts/game/progress_store.gd")

var failures: Array[String] = []


func _init() -> void:
    _test_catalog()
    _test_separate_clocks_and_clear()
    _test_practice_is_not_ranked()
    _test_structures()
    _test_market_making()
    _test_probability_commitment()
    _test_failed_and_duplicate_saves()
    if failures.is_empty():
        print("RULES_SMOKE_OK")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)


func _test_catalog() -> void:
    _expect(Catalog.core_levels().size() >= 12, "Catalog has fewer than 12 core levels.")
    _expect(Catalog.final_trials().size() >= 6, "Catalog has fewer than 6 final trials.")
    for error in Catalog.validate_catalog():
        failures.append("Catalog validation: %s" % error)
    var challenge_a := Catalog.seeded_challenge("smoke-seed", 2)
    var challenge_b := Catalog.seeded_challenge("smoke-seed", 2)
    _expect(challenge_a == challenge_b, "Seeded challenge generation is not deterministic.")


func _test_separate_clocks_and_clear() -> void:
    var level := Catalog.get_level("delta-wind")
    var run := Ledger.new_run(level)
    Ledger.record_action(run, &"delta_hedge", {"quantity": 2})
    Ledger.record_action(run, &"inspect_surface")
    _expect(int(run["market_steps"]) == 0, "Actions advanced the market clock.")
    var history_before := Array(run["action_history"]).size()
    Ledger.clear_portfolio(run)
    _expect(Array(run["action_history"]).size() == history_before + 1, "Clear reset action history.")
    _expect(int(run["market_steps"]) == 0, "Clear changed market steps.")
    for step in int(level["horizon"]):
        _expect(Ledger.record_market_step(run), "Official run refused market step %d." % step)
    var snapshot := {"delta": 10.0, "gamma": 0.2, "vega": 2.0}
    var attribution := {"total_pnl": 2.0, "max_drawdown": 1.0, "risk_violations": 0}
    run["snapshot"] = snapshot
    run["attribution"] = attribution
    var evaluation := Evaluator.evaluate(level, run, snapshot, attribution, run["portfolio"])
    _expect(bool(evaluation["completed"]), "A valid fixed-horizon run did not complete.")
    _expect(bool(evaluation["leaderboard_eligible"]), "A valid official run was not rank eligible.")
    _expect(Scores.calculate(level, run, snapshot, attribution, run["portfolio"]) is int, "ScoreCalculator did not return int.")


func _test_practice_is_not_ranked() -> void:
    var level := Catalog.get_level("delta-wind")
    var run := Ledger.new_run(level, true, 4)
    for step in 4:
        _expect(Ledger.record_market_step(run), "Practice run refused step %d." % step)
    var snapshot := {"delta": 5.0}
    var attribution := {"total_pnl": 2.0, "max_drawdown": 0.0, "risk_violations": 0}
    var evaluation := Evaluator.evaluate(level, run, snapshot, attribution, run["portfolio"])
    _expect(bool(evaluation["completed"]), "Practice override could not complete its chosen horizon.")
    _expect(not bool(evaluation["leaderboard_eligible"]), "Practice override became leaderboard eligible.")


func _test_structures() -> void:
    var call_level := Catalog.get_level("build-call-spread")
    var call_run := Ledger.new_run(call_level)
    call_run["portfolio"] = [
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 100.0, "expiry_days": 30, "quantity": 1.0},
        {"kind": &"option", "side": &"short", "option_type": &"call", "strike": 110.0, "expiry_days": 30, "quantity": 1.0},
    ]
    _advance_to_horizon(call_run)
    var safe_snapshot := {"delta": 20.0}
    var safe_attribution := {"total_pnl": 0.0, "max_drawdown": 1.0, "risk_violations": 0}
    var call_evaluation := Evaluator.evaluate(call_level, call_run, safe_snapshot, safe_attribution, call_run["portfolio"])
    _expect(bool(call_evaluation["completed"]), "Valid non-zero 1:1 call spread failed.")
    call_run["portfolio"][0]["quantity"] = 0.0
    call_evaluation = Evaluator.evaluate(call_level, call_run, safe_snapshot, safe_attribution, call_run["portfolio"])
    _expect(not bool(call_evaluation["completed"]), "Zero-quantity call spread passed.")

    var fly_level := Catalog.get_level("build-butterfly")
    var fly_run := Ledger.new_run(fly_level)
    fly_run["portfolio"] = [
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 95.0, "expiry_days": 30, "quantity": 1.0},
        {"kind": &"option", "side": &"short", "option_type": &"call", "strike": 100.0, "expiry_days": 30, "quantity": 2.0},
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 105.0, "expiry_days": 30, "quantity": 1.0},
    ]
    _advance_to_horizon(fly_run)
    var fly_evaluation := Evaluator.evaluate(fly_level, fly_run, {}, safe_attribution, fly_run["portfolio"])
    _expect(bool(fly_evaluation["completed"]), "Valid 1:-2:1 butterfly failed.")
    fly_run["portfolio"][1]["quantity"] = 1.0
    fly_evaluation = Evaluator.evaluate(fly_level, fly_run, {}, safe_attribution, fly_run["portfolio"])
    _expect(not bool(fly_evaluation["completed"]), "Wrong-ratio butterfly passed.")


func _test_market_making() -> void:
    var level := Catalog.get_level("market-maker-intro")
    var run := Ledger.new_run(level)
    for index in 4:
        _expect(Ledger.record_quote(run, {"bid": 1.0, "ask": 1.2, "size": 1.0}), "Quote %d rejected." % index)
    _expect(Ledger.record_fill(run, {"quantity": 1.0}, 0.15), "First fill rejected.")
    _expect(Ledger.record_fill(run, {"quantity": -1.0}, 0.15), "Second fill rejected.")
    _advance_to_horizon(run)
    var evaluation := Evaluator.evaluate(
        level,
        run,
        {"delta": 0.0},
        {"total_pnl": 0.0, "max_drawdown": 1.0, "risk_violations": 0},
        run["portfolio"]
    )
    _expect(bool(evaluation["completed"]), "Valid quote/fill/edge run failed.")
    run["market_making_edge"] = -0.1
    evaluation = Evaluator.evaluate(level, run, {"delta": 0.0}, {"total_pnl": 0.0, "risk_violations": 0}, run["portfolio"])
    _expect(not bool(evaluation["completed"]), "Negative market-making edge passed.")


func _test_probability_commitment() -> void:
    var level := Catalog.get_level("probability-pit-final")
    var run := Ledger.new_run(level)
    var commit := Ledger.commit_probabilities(run, [
        {"id": "up", "label": "Spot up", "probability": 0.5},
        {"id": "vol", "label": "IV up", "probability": 0.5},
        {"id": "tail", "label": "Tail event", "probability": 0.5},
    ])
    _expect(bool(commit["accepted"]), "Pre-run probability commitment was rejected.")
    _advance_to_horizon(run)
    var late_commit := Ledger.commit_probabilities(run, [{"id": "late", "probability": 0.5}])
    _expect(not bool(late_commit["accepted"]), "Post-run probability edit was accepted.")
    var resolution := Ledger.resolve_probability_outcomes(run, {"up": true, "vol": false, "tail": false})
    _expect(bool(resolution["resolved"]), "Probability outcomes did not resolve.")
    var attribution := {"total_pnl": 0.0, "max_drawdown": 1.0, "risk_violations": 0}
    var evaluation := Evaluator.evaluate(level, run, {"delta": 0.0}, attribution, run["portfolio"])
    _expect(bool(evaluation["completed"]), "Brier-passing probability run failed.")


func _test_failed_and_duplicate_saves() -> void:
    var save_path := "user://volatility_forge_rules_smoke.json"
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    var level := Catalog.get_level("delta-wind")
    var failed_run := Ledger.new_run(level)
    Ledger.fail_run(failed_run, "smoke failure")
    var failed_result := {"completed": false, "leaderboard_eligible": false, "score": 0}
    var failed_record := Store.record_run(level, failed_run, failed_result, {}, save_path)
    _expect(not bool(failed_record["saved"]), "Failed run was saved to the leaderboard.")
    _expect(not FileAccess.file_exists(save_path), "Failed run wrote a progress file.")

    var run := Ledger.new_run(level)
    _advance_to_horizon(run)
    run["snapshot"] = {"delta": 0.0}
    run["attribution"] = {"total_pnl": 2.0, "max_drawdown": 0.0, "risk_violations": 0}
    var report := Scores.calculate_report(level, run)
    var first := Store.record_run(level, run, report, {}, save_path)
    _expect(bool(first["saved"]), "Eligible successful run was not saved.")
    var revision := int(first["progress"]["revision"])
    var second := Store.record_run(level, run, report, first["progress"], save_path)
    _expect(not bool(second["saved"]) and String(second["reason"]) == "duplicate_run", "Duplicate run was not rejected.")
    _expect(int(second["progress"]["revision"]) == revision, "Duplicate run changed progress revision.")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _advance_to_horizon(run: Dictionary) -> void:
    while Ledger.can_advance_market(run):
        Ledger.record_market_step(run)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
