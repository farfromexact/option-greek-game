extends SceneTree

const Catalog = preload("res://scripts/game/level_catalog.gd")
const Evaluator = preload("res://scripts/game/objective_evaluator.gd")
const Ledger = preload("res://scripts/game/run_ledger.gd")
const Scores = preload("res://scripts/game/score_calculator.gd")
const Store = preload("res://scripts/game/progress_store.gd")

const SAVE_PATH := "user://volatility_forge_integration_smoke.json"

var failures: Array[String] = []


func _init() -> void:
    _catalog_has_full_campaign()
    _empty_and_clear_cannot_forge_horizon()
    _practice_cannot_enter_leaderboard()
    _probabilities_must_be_precommitted()
    _zero_quantity_structures_fail()
    _duplicate_save_is_rejected()
    _remove_test_save()

    if failures.is_empty():
        print("INTEGRATION_SMOKE_OK")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)


func _catalog_has_full_campaign() -> void:
    _expect(Catalog.core_levels().size() >= 12, "Expected at least 12 core levels.")
    _expect(Catalog.final_trials().size() >= 6, "Expected at least 6 final trials.")
    _expect(Catalog.validate_catalog().is_empty(), "Level catalog schema validation failed.")


func _empty_and_clear_cannot_forge_horizon() -> void:
    var level := Catalog.get_level("delta-wind")
    var run := Ledger.new_run(level)
    var empty_evaluation := Evaluator.evaluate(
        level,
        run,
        {"delta": 0.0},
        {"total_pnl": 100.0, "max_drawdown": 0.0, "risk_violations": 0},
        []
    )
    _expect(not bool(empty_evaluation["completed"]), "An empty zero-step run forged completion.")

    Ledger.record_action(run, &"delta_hedge", {"quantity": 5.0})
    var history_before_clear := Array(run["action_history"]).size()
    Ledger.clear_portfolio(run)
    _expect(int(run["market_steps"]) == 0, "Clear advanced or reset the market clock incorrectly.")
    _expect(
        Array(run["action_history"]).size() == history_before_clear + 1,
        "Clear erased prior action history."
    )
    var clear_evaluation := Evaluator.evaluate(
        level,
        run,
        {"delta": 0.0},
        {"total_pnl": 100.0, "max_drawdown": 0.0, "risk_violations": 0},
        run["portfolio"]
    )
    _expect(not bool(clear_evaluation["completed"]), "Clear forged the fixed horizon.")


func _practice_cannot_enter_leaderboard() -> void:
    var level := Catalog.get_level("delta-wind")
    var run := Ledger.new_run(level, true, 2)
    _advance_to_horizon(run)
    run["snapshot"] = {"delta": 0.0}
    run["attribution"] = {"total_pnl": 5.0, "max_drawdown": 0.0, "risk_violations": 0}
    var report := Scores.calculate_report(level, run)
    _expect(bool(report["completed"]), "Practice run did not complete its chosen horizon.")
    _expect(not bool(report["leaderboard_eligible"]), "Practice run became rank eligible.")
    var record := Store.record_run(level, run, report, {}, SAVE_PATH)
    _expect(not bool(record["saved"]), "Practice run was persisted to the leaderboard.")
    _expect(String(record["reason"]) == "practice_or_ineligible", "Practice rejection returned the wrong reason.")


func _probabilities_must_be_precommitted() -> void:
    var level := Catalog.get_level("probability-pit-final")
    var run := Ledger.new_run(level)
    Ledger.record_market_step(run)
    var late_commit := Ledger.commit_probabilities(run, [
        {"id": "spot_up", "probability": 0.5},
        {"id": "iv_up", "probability": 0.5},
        {"id": "tail", "probability": 0.5},
    ])
    _expect(not bool(late_commit["accepted"]), "Probability commitment was accepted after the run began.")
    _advance_to_horizon(run)
    var evaluation := Evaluator.evaluate(
        level,
        run,
        {"delta": 0.0},
        {"total_pnl": 0.0, "max_drawdown": 0.0, "risk_violations": 0},
        run["portfolio"]
    )
    _expect(not bool(evaluation["completed"]), "Uncommitted probability run passed its Brier objective.")


func _zero_quantity_structures_fail() -> void:
    var call_level := Catalog.get_level("build-call-spread")
    var call_run := Ledger.new_run(call_level)
    call_run["portfolio"] = [
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 100.0, "expiry_days": 30, "quantity": 0.0},
        {"kind": &"option", "side": &"short", "option_type": &"call", "strike": 110.0, "expiry_days": 30, "quantity": 0.0},
    ]
    _advance_to_horizon(call_run)
    var call_evaluation := Evaluator.evaluate(
        call_level,
        call_run,
        {"delta": 0.0},
        {"total_pnl": 0.0, "max_drawdown": 0.0, "risk_violations": 0},
        call_run["portfolio"]
    )
    _expect(not bool(call_evaluation["completed"]), "Zero-quantity call spread passed.")

    var fly_level := Catalog.get_level("build-butterfly")
    var fly_run := Ledger.new_run(fly_level)
    fly_run["portfolio"] = [
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 95.0, "expiry_days": 30, "quantity": 0.0},
        {"kind": &"option", "side": &"short", "option_type": &"call", "strike": 100.0, "expiry_days": 30, "quantity": 0.0},
        {"kind": &"option", "side": &"long", "option_type": &"call", "strike": 105.0, "expiry_days": 30, "quantity": 0.0},
    ]
    _advance_to_horizon(fly_run)
    var fly_evaluation := Evaluator.evaluate(
        fly_level,
        fly_run,
        {},
        {"total_pnl": 0.0, "max_drawdown": 0.0, "risk_violations": 0},
        fly_run["portfolio"]
    )
    _expect(not bool(fly_evaluation["completed"]), "Zero-quantity butterfly passed.")


func _duplicate_save_is_rejected() -> void:
    _remove_test_save()
    var level := Catalog.get_level("delta-wind")
    var run := Ledger.new_run(level)
    _advance_to_horizon(run)
    run["snapshot"] = {"delta": 0.0}
    run["attribution"] = {"total_pnl": 5.0, "max_drawdown": 0.0, "risk_violations": 0}
    var report := Scores.calculate_report(level, run)
    var first := Store.record_run(level, run, report, {}, SAVE_PATH)
    _expect(bool(first["saved"]), "Eligible official run was not saved.")
    var first_revision := int(first["progress"]["revision"])
    var first_count := Array(first["progress"]["leaderboard"]).size()

    var second := Store.record_run(level, run, report, first["progress"], SAVE_PATH)
    _expect(not bool(second["saved"]), "Duplicate run was saved twice.")
    _expect(String(second["reason"]) == "duplicate_run", "Duplicate save returned the wrong reason.")
    _expect(int(second["progress"]["revision"]) == first_revision, "Duplicate save changed progress revision.")
    _expect(Array(second["progress"]["leaderboard"]).size() == first_count, "Duplicate save added a leaderboard row.")


func _advance_to_horizon(run: Dictionary) -> void:
    while Ledger.can_advance_market(run):
        Ledger.record_market_step(run)


func _remove_test_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
