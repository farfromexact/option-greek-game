class_name ObjectiveDefs
extends RefCounted

## Canonical Dictionary schema for every level objective.
##
## Dictionaries remain easy to serialize and render in Godot UI, while `kind`
## and the constructors below keep the rule layer from relying on display text.

const SCHEMA_VERSION := 1

const KIND_METRIC: StringName = &"metric"
const KIND_HORIZON: StringName = &"horizon"
const KIND_ACTION_COUNT: StringName = &"action_count"
const KIND_CALL_SPREAD: StringName = &"call_spread"
const KIND_BUTTERFLY: StringName = &"butterfly"
const KIND_MARKET_MAKING: StringName = &"market_making"
const KIND_PROBABILITY: StringName = &"probability"

const OP_AT_LEAST: StringName = &"at_least"
const OP_AT_MOST: StringName = &"at_most"
const OP_EXACTLY: StringName = &"exactly"


static func metric(
        id: StringName,
        label: String,
        field: StringName,
        operator: StringName,
        target: float,
        weight: float = 1.0
    ) -> Dictionary:
    return _base(id, KIND_METRIC, label, weight).merged({
        "field": field,
        "operator": operator,
        "target": target,
    })


static func fixed_horizon(steps: int, weight: float = 1.0) -> Dictionary:
    return _base(
        &"fixed_horizon",
        KIND_HORIZON,
        "Complete exactly %d market steps." % steps,
        weight
    ).merged({"steps": steps})


static func action_count(
        id: StringName,
        label: String,
        action_type: StringName,
        minimum: int,
        weight: float = 1.0
    ) -> Dictionary:
    return _base(id, KIND_ACTION_COUNT, label, weight).merged({
        "action_type": action_type,
        "minimum": minimum,
    })


static func call_spread(
        minimum_contracts: float = 1.0,
        long_to_short_ratio: float = 1.0,
        ratio_tolerance: float = 0.08,
        weight: float = 1.35
    ) -> Dictionary:
    return _base(
        &"call_spread_structure",
        KIND_CALL_SPREAD,
        "Build a non-zero 1:1 call spread with the short strike above the long strike.",
        weight
    ).merged({
        "minimum_contracts": minimum_contracts,
        "long_to_short_ratio": long_to_short_ratio,
        "ratio_tolerance": ratio_tolerance,
        "same_expiry": true,
    })


static func butterfly(
        minimum_wing_contracts: float = 1.0,
        ratio_tolerance: float = 0.08,
        weight: float = 1.5
    ) -> Dictionary:
    return _base(
        &"butterfly_structure",
        KIND_BUTTERFLY,
        "Build a non-zero 1:-2:1 butterfly at equally spaced strikes.",
        weight
    ).merged({
        "minimum_wing_contracts": minimum_wing_contracts,
        "target_ratio": [1.0, -2.0, 1.0],
        "ratio_tolerance": ratio_tolerance,
        "strike_tolerance": 0.001,
        "same_expiry": true,
    })


static func market_making(
        minimum_quotes: int,
        minimum_fills: int,
        minimum_edge: float,
        weight: float = 1.35
    ) -> Dictionary:
    return _base(
        &"market_making_quality",
        KIND_MARKET_MAKING,
        "Quote, earn fills, and finish with positive captured edge.",
        weight
    ).merged({
        "minimum_quotes": minimum_quotes,
        "minimum_fills": minimum_fills,
        "minimum_edge": minimum_edge,
    })


static func probability(
        maximum_brier: float,
        minimum_questions: int = 3,
        weight: float = 1.5
    ) -> Dictionary:
    return _base(
        &"probability_calibration",
        KIND_PROBABILITY,
        "Commit probabilities before the first market step and meet the Brier target.",
        weight
    ).merged({
        "maximum_brier": maximum_brier,
        "minimum_questions": minimum_questions,
        "commit_before_step": 0,
    })


static func validate(objective: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    for required_key in ["schema_version", "id", "kind", "label", "weight", "required"]:
        if not objective.has(required_key):
            errors.append("Objective is missing '%s'." % required_key)
    if not errors.is_empty():
        return errors

    var kind := StringName(objective.get("kind", &""))
    if kind not in [
        KIND_METRIC,
        KIND_HORIZON,
        KIND_ACTION_COUNT,
        KIND_CALL_SPREAD,
        KIND_BUTTERFLY,
        KIND_MARKET_MAKING,
        KIND_PROBABILITY,
    ]:
        errors.append("Unknown objective kind '%s'." % kind)

    if float(objective.get("weight", 0.0)) <= 0.0:
        errors.append("Objective weight must be positive.")

    match kind:
        KIND_METRIC:
            if not objective.has("field") or not objective.has("operator") or not objective.has("target"):
                errors.append("Metric objective requires field, operator, and target.")
            elif StringName(objective["operator"]) not in [OP_AT_LEAST, OP_AT_MOST, OP_EXACTLY]:
                errors.append("Metric objective has an unsupported operator.")
        KIND_HORIZON:
            if int(objective.get("steps", 0)) <= 0:
                errors.append("Horizon steps must be positive.")
        KIND_ACTION_COUNT:
            if String(objective.get("action_type", "")).is_empty() or int(objective.get("minimum", 0)) <= 0:
                errors.append("Action objective requires an action type and positive minimum.")
        KIND_MARKET_MAKING:
            if int(objective.get("minimum_quotes", 0)) <= 0 or int(objective.get("minimum_fills", 0)) <= 0:
                errors.append("Market-making counts must be positive.")
        KIND_PROBABILITY:
            var maximum_brier := float(objective.get("maximum_brier", -1.0))
            if maximum_brier < 0.0 or maximum_brier > 1.0:
                errors.append("Brier target must be between 0 and 1.")
    return errors


static func _base(
        id: StringName,
        kind: StringName,
        label: String,
        weight: float
    ) -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "id": id,
        "kind": kind,
        "label": label,
        "weight": weight,
        "required": true,
    }
