class_name ProgressStore
extends RefCounted

const DEFAULT_SAVE_PATH := "user://volatility_forge_progress_v2.json"
const MAX_LEADERBOARD_ENTRIES := 25
const MAX_CALIBRATION_RESULTS := 30
const MAX_RECORDED_RUN_IDS := 500


static func load_progress(save_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return _default_progress()
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return _default_progress()
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return _default_progress()
    return _normalize(parsed)


static func save_progress(
        progress: Dictionary,
        save_path: String = DEFAULT_SAVE_PATH
    ) -> bool:
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(_normalize(progress), "  "))
    file.flush()
    return true


static func record_run(
        level: Dictionary,
        run_state: Dictionary,
        result: Dictionary,
        progress: Dictionary = {},
        save_path: String = DEFAULT_SAVE_PATH
    ) -> Dictionary:
    var current := _normalize(progress) if not progress.is_empty() else load_progress(save_path)
    var run_id := String(run_state.get("run_id", ""))
    if run_id.is_empty():
        return _record_response(false, "run_id_required", current)

    var recorded_run_ids: Array = current.get("recorded_run_ids", [])
    if run_id in recorded_run_ids:
        # No file write occurs for an already-recorded run.
        return _record_response(false, "duplicate_run", current)

    var completed := bool(result.get("completed", false))
    var leaderboard_eligible := bool(result.get("leaderboard_eligible", false))
    if result.has("evaluation") and result["evaluation"] is Dictionary:
        completed = completed and bool(result["evaluation"].get("completed", false))
        leaderboard_eligible = leaderboard_eligible and bool(result["evaluation"].get("leaderboard_eligible", false))

    if bool(run_state.get("run_failed", false)) or not completed:
        # Failed and incomplete runs are debrief-only. They never touch disk or
        # consume a leaderboard id, so Retry can safely create a fresh run.
        return _record_response(false, "failed_or_incomplete", current)
    if bool(run_state.get("practice_override", false)) or not leaderboard_eligible:
        return _record_response(false, "practice_or_ineligible", current)
    if not _official_horizon_complete(level, run_state):
        return _record_response(false, "fixed_horizon_required", current)

    var level_id := String(level.get("id", run_state.get("level_id", "")))
    var score := clampi(int(result.get("score", 0)), 0, 100)
    var attribution: Dictionary = run_state.get("attribution", {})
    var completed_levels: Array = current.get("completed_levels", [])
    if level_id not in completed_levels:
        completed_levels.append(level_id)
    current["completed_levels"] = completed_levels

    var best_scores: Dictionary = current.get("best_scores", {})
    best_scores[level_id] = maxi(int(best_scores.get(level_id, 0)), score)
    current["best_scores"] = best_scores
    current["last_level_id"] = level_id

    var leaderboard: Array = current.get("leaderboard", [])
    leaderboard.append({
        "id": run_id,
        "run_id": run_id,
        "level_id": level_id,
        "level_title": String(level.get("title", run_state.get("level_title", level_id))),
        "score": score,
        "pnl": float(attribution.get("total_pnl", 0.0)),
        "drawdown": float(attribution.get("max_drawdown", 0.0)),
        "risk_violations": int(attribution.get("risk_violations", 0)),
        "seed": int(level.get("seed", run_state.get("seed", 0))),
        "created_at_unix": Time.get_unix_time_from_system(),
    })
    leaderboard.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a.get("score", 0)) == int(b.get("score", 0)):
            return float(a.get("created_at_unix", 0.0)) < float(b.get("created_at_unix", 0.0))
        return int(a.get("score", 0)) > int(b.get("score", 0))
    )
    if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
        leaderboard.resize(MAX_LEADERBOARD_ENTRIES)
    current["leaderboard"] = leaderboard

    var commitment: Dictionary = run_state.get("probability_commitment", {})
    if bool(commitment.get("resolved", false)):
        var calibration_history: Array = current.get("calibration_history", [])
        calibration_history.push_front({
            "run_id": run_id,
            "level_id": level_id,
            "created_at_unix": Time.get_unix_time_from_system(),
            "average_brier": float(commitment.get("average_brier", -1.0)),
            "questions": commitment.get("questions", []).duplicate(true),
        })
        if calibration_history.size() > MAX_CALIBRATION_RESULTS:
            calibration_history.resize(MAX_CALIBRATION_RESULTS)
        current["calibration_history"] = calibration_history

    recorded_run_ids.append(run_id)
    if recorded_run_ids.size() > MAX_RECORDED_RUN_IDS:
        recorded_run_ids = recorded_run_ids.slice(recorded_run_ids.size() - MAX_RECORDED_RUN_IDS)
    current["recorded_run_ids"] = recorded_run_ids
    current["revision"] = int(current.get("revision", 0)) + 1
    current["updated_at_unix"] = Time.get_unix_time_from_system()

    # Exactly one persistence call after all mutations. Repeated calls with the
    # same run_id return above and therefore cannot duplicate or re-save it.
    if not save_progress(current, save_path):
        return _record_response(false, "save_failed", current)
    return _record_response(true, "recorded", current)


static func mark_tutorial_completed(
        progress: Dictionary = {},
        save_path: String = DEFAULT_SAVE_PATH
    ) -> Dictionary:
    var current := _normalize(progress) if not progress.is_empty() else load_progress(save_path)
    if bool(current.get("tutorial_completed", false)):
        return _record_response(false, "no_change", current)
    current["tutorial_completed"] = true
    current["revision"] = int(current.get("revision", 0)) + 1
    current["updated_at_unix"] = Time.get_unix_time_from_system()
    if not save_progress(current, save_path):
        return _record_response(false, "save_failed", current)
    return _record_response(true, "recorded", current)


static func _official_horizon_complete(level: Dictionary, run_state: Dictionary) -> bool:
    var horizon := int(level.get("horizon", 0))
    if bool(level.get("formal", false)):
        return (
            horizon > 0
            and int(run_state.get("market_steps", -1)) == horizon
            and int(run_state.get("official_horizon", horizon)) == horizon
            and int(run_state.get("effective_horizon", horizon)) == horizon
        )
    return true


static func _record_response(saved: bool, reason: String, progress: Dictionary) -> Dictionary:
    return {
        "saved": saved,
        "reason": reason,
        "progress": progress.duplicate(true),
    }


static func _normalize(value: Variant) -> Dictionary:
    var defaults := _default_progress()
    if not value is Dictionary:
        return defaults
    var progress: Dictionary = value
    for key in defaults:
        if not progress.has(key) or typeof(progress[key]) != typeof(defaults[key]):
            progress[key] = defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
    progress["schema_version"] = 2
    return progress


static func _default_progress() -> Dictionary:
    return {
        "schema_version": 2,
        "completed_levels": [],
        "best_scores": {},
        "last_level_id": "delta-wind",
        "tutorial_completed": false,
        "leaderboard": [],
        "calibration_history": [],
        "recorded_run_ids": [],
        "revision": 0,
        "updated_at_unix": 0.0,
    }
