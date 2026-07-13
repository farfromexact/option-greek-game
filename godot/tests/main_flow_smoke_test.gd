extends SceneTree

const Catalog = preload("res://scripts/game/level_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    var main: Control = packed.instantiate()
    get_root().add_child(main)
    main.set("_current_level", Catalog.get_level("vega-storm").duplicate(true))
    main.call("_reset_session")

    var initial_run: Dictionary = main.get("_run_state")
    _expect(int(initial_run.get("market_steps", -1)) == 0, "A new UI run did not start at market step zero.")
    _expect(Array(main.get("_records")).size() == 1, "Opening book did not create exactly one immutable replay record.")

    main.call("_commit_forecast")
    main.call("_step_market")
    var stepped_run: Dictionary = main.get("_run_state")
    _expect(int(stepped_run.get("market_steps", -1)) == 1, "The UI market step did not advance exactly once.")
    _expect(int(Dictionary(main.get("_market")).get("day", -1)) == 1, "The simulator day and run ledger diverged.")
    _expect(Array(main.get("_records")).size() == 2, "The first market day did not append one replay record.")

    var history_before_trade := Array(stepped_run.get("action_history", [])).size()
    var records_before_trade := Array(main.get("_records")).size()
    main.call("_execute_live_trade", {"kind": &"stock", "quantity": 1.0}, "Smoke hedge", &"delta_hedge")
    var traded_run: Dictionary = main.get("_run_state")
    _expect(int(traded_run.get("market_steps", -1)) == 1, "A trade incorrectly advanced the market clock.")
    _expect(Array(traded_run.get("action_history", [])).size() == history_before_trade + 1, "A live trade was not recorded in the action audit trail.")
    _expect(Array(main.get("_records")).size() == records_before_trade + 1, "A live trade did not append a priced replay record.")

    var history_before_clear := Array(traded_run.get("action_history", [])).size()
    var records_before_clear := Array(main.get("_records")).size()
    main.call("_close_all_risk")
    var cleared_run: Dictionary = main.get("_run_state")
    _expect(int(cleared_run.get("market_steps", -1)) == 1, "Close-all changed the market clock.")
    _expect(Array(cleared_run.get("action_history", [])).size() == history_before_clear + 1, "Close-all erased or skipped the action history.")
    _expect(Array(main.get("_records")).size() == records_before_clear + 1, "Close-all failed to preserve a replay event.")

    main.queue_free()
    if failures.is_empty():
        print("MAIN_FLOW_SMOKE_OK")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
