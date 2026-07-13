class_name LevelCatalog
extends RefCounted

const Objectives = preload("res://scripts/game/objective_defs.gd")
const Challenges = preload("res://scripts/game/challenge_generator.gd")

static var _cached_levels: Array[Dictionary] = []


static func all_levels() -> Array[Dictionary]:
    if _cached_levels.is_empty():
        _cached_levels = _build_core_levels()
        _cached_levels.append_array(_build_final_trials())
    return _cached_levels.duplicate(true)


static func core_levels() -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    for level in all_levels():
        if StringName(level.get("category", &"")) == &"core":
            output.append(level)
    return output


static func final_trials() -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    for level in all_levels():
        if StringName(level.get("category", &"")) == &"final":
            output.append(level)
    return output


static func get_level(id: String) -> Dictionary:
    for level in all_levels():
        if String(level.get("id", "")) == id:
            return level
    var fallback := all_levels()
    return fallback[0] if not fallback.is_empty() else {}


static func has_level(id: String) -> bool:
    for level in all_levels():
        if String(level.get("id", "")) == id:
            return true
    return false


static func seeded_challenge(seed_text: String, ordinal: int = 0) -> Dictionary:
    return Challenges.generate(seed_text, ordinal)


static func validate_catalog() -> PackedStringArray:
    var errors := PackedStringArray()
    var seen_ids := {}
    for level in all_levels():
        var id := String(level.get("id", ""))
        if id.is_empty():
            errors.append("A level has no id.")
        elif seen_ids.has(id):
            errors.append("Duplicate level id '%s'." % id)
        seen_ids[id] = true

        var horizon := int(level.get("horizon", 0))
        if bool(level.get("formal", false)) and horizon <= 0:
            errors.append("Formal level '%s' needs a fixed horizon." % id)

        var horizon_objectives := 0
        for objective_value in level.get("objectives", []):
            if not objective_value is Dictionary:
                errors.append("Level '%s' contains a non-Dictionary objective." % id)
                continue
            var objective: Dictionary = objective_value
            for objective_error in Objectives.validate(objective):
                errors.append("%s: %s" % [id, objective_error])
            if StringName(objective.get("kind", &"")) == Objectives.KIND_HORIZON:
                horizon_objectives += 1
                if int(objective.get("steps", -1)) != horizon:
                    errors.append("Level '%s' horizon objective disagrees with its fixed horizon." % id)
        if bool(level.get("formal", false)) and horizon_objectives != 1:
            errors.append("Formal level '%s' must have exactly one horizon objective." % id)
    if core_levels().size() < 12:
        errors.append("Catalog must contain at least 12 core levels.")
    if final_trials().size() < 6:
        errors.append("Catalog must contain at least 6 final trials.")
    return errors


static func _build_core_levels() -> Array[Dictionary]:
    var levels: Array[Dictionary] = []
    levels.append(_level(
        "delta-wind", "Delta Wind", "Greek Sense Lab", &"trending_up", 8,
        _market(&"trending_up", 100.0, 0.20, 1101), [_cash()],
        "Shape directional exposure, then survive a slow rightward price wind.",
        "Delta is the first push from spot movement.",
        "The book drifted with the wind instead of being steered deliberately.",
        "Separate intended Delta P&L from accidental exposure.",
        [
            Objectives.metric(&"minimum_pnl", "Finish with positive P&L.", &"total_pnl", Objectives.OP_AT_LEAST, 1.0),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 80.", &"abs_delta", Objectives.OP_AT_MOST, 80.0),
        ], 1
    ))

    levels.append(_level(
        "gamma-spring", "Gamma Spring", "Greek Sense Lab", &"choppy", 10,
        _market(&"choppy", 100.0, 0.24, 1201),
        [_cash(), _option("long", "call", 100.0, 18, 0.24), _option("long", "put", 100.0, 18, 0.24)],
        "Use long Gamma to absorb a pinball market without letting Theta dominate.",
        "Gamma changes Delta; movement helps long Gamma, while Theta leaks fuel.",
        "The spring was too expensive or hedged too late.",
        "Compare realized movement gains with Theta and trading cost.",
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -2.", &"total_pnl", Objectives.OP_AT_LEAST, -2.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
        ], 1
    ))

    levels.append(_level(
        "theta-desert", "Theta Desert", "Greek Sense Lab", &"calm", 12,
        _market(&"calm", 100.0, 0.20, 1301),
        [_cash(), _option("short", "call", 112.0, 24, 0.22), _option("short", "put", 88.0, 24, 0.24)],
        "Harvest quiet-market Theta while keeping the tail shield alive.",
        "Short premium earns rent while selling jump insurance.",
        "Theta income hid an oversized convexity loss.",
        "Check whether collected premium paid enough for the tail exposure.",
        [
            Objectives.metric(&"minimum_pnl", "Earn at least 2 P&L.", &"total_pnl", Objectives.OP_AT_LEAST, 2.0),
            Objectives.metric(&"risk_flags", "Use no more than one risk violation.", &"risk_violations", Objectives.OP_AT_MOST, 1.0),
        ], 2
    ))

    levels.append(_level(
        "vega-storm", "Vega Storm", "Greek Sense Lab", &"volatility_spike", 8,
        _market(&"volatility_spike", 100.0, 0.24, 1401),
        [_cash(), _option("long", "call", 102.0, 35, 0.24), _option("long", "put", 98.0, 35, 0.24)],
        "Ride a rising-volatility weather system without confusing Vega with direction.",
        "Vega is storm sensitivity; the book can change before spot picks a side.",
        "The storm was visible, but the portfolio had the wrong sensitivity.",
        "Attribute the result between IV expansion, Delta, and residual.",
        [
            Objectives.metric(&"minimum_pnl", "Earn at least 1 P&L.", &"total_pnl", Objectives.OP_AT_LEAST, 1.0),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 90.", &"abs_delta", Objectives.OP_AT_MOST, 90.0),
        ], 2
    ))

    levels.append(_level(
        "direction-right-lost", "Direction Right, Still Lost", "Strategy Forge", &"earnings_event", 7,
        _market(&"earnings_event", 100.0, 0.78, 1501),
        [_cash(), _option("long", "call", 103.0, 28, 0.78)],
        "Experience earnings IV crush and repair a naive long-call thesis.",
        "Correct direction can still lose when implied volatility collapses.",
        "The spot move helped, but the collapsing airbag erased the thesis.",
        "Compare Delta P&L with Vega P&L after the event.",
        [
            Objectives.metric(&"loss_floor", "Keep event loss above -6.", &"total_pnl", Objectives.OP_AT_LEAST, -6.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
            Objectives.action_count(&"vega_repairs", "Reduce or hedge Vega before resolution.", &"vega_hedge", 1),
        ], 2
    ))

    levels.append(_level(
        "short-gamma-nightmare", "Short Gamma Nightmare", "Risk Desk", &"crash", 6,
        _market(&"crash", 100.0, 0.28, 1601),
        [_cash(), _option("short", "call", 112.0, 24, 0.30), _option("short", "put", 88.0, 24, 0.32)],
        "Manage a high-win-rate short-premium book through a jump.",
        "Short Gamma looks calm until path dependence becomes the whole game.",
        "Small daily income did not compensate for the jump.",
        "Find the first point where sizing or protection changes the result.",
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -18.", &"total_pnl", Objectives.OP_AT_LEAST, -18.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 22.", &"max_drawdown", Objectives.OP_AT_MOST, 22.0),
        ], 3
    ))

    levels.append(_level(
        "gamma-scalping-intro", "Gamma Scalping Intro", "Strategy Forge", &"choppy", 10,
        _market(&"choppy", 100.0, 0.22, 1701),
        [_cash(), _option("long", "call", 100.0, 21, 0.22), _option("long", "put", 100.0, 21, 0.22)],
        "Re-center Delta and learn why realized volatility pays the scalper.",
        "Long Gamma plus disciplined hedging is a realized-volatility trade.",
        "The book owned Gamma but was not actively steered.",
        "Inspect hedge timing and transaction cost, not only ending stock quantity.",
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -3.", &"total_pnl", Objectives.OP_AT_LEAST, -3.0),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 60.", &"abs_delta", Objectives.OP_AT_MOST, 60.0),
            Objectives.action_count(&"delta_hedges", "Use Delta hedge at least twice.", &"delta_hedge", 2, 1.2),
        ], 3
    ))

    levels.append(_level(
        "vol-crush-event", "Vol Crush Event", "Market Weather Campaign", &"earnings_event", 8,
        _market(&"earnings_event", 100.0, 0.82, 1801),
        [_cash(), _option("short", "call", 112.0, 12, 0.82), _option("short", "put", 88.0, 12, 0.84)],
        "Sell rich event volatility while respecting the jump distribution.",
        "Short event volatility works only when jump risk is sized.",
        "The IV crush arrived, but the jump was too large for inventory.",
        "Assess whether premium and tail loss were proportionate.",
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -5.", &"total_pnl", Objectives.OP_AT_LEAST, -5.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 30.", &"max_drawdown", Objectives.OP_AT_MOST, 30.0),
        ], 3
    ))

    levels.append(_level(
        "build-call-spread", "Build a Call Spread", "Strategy Forge", &"trending_up", 7,
        _market(&"trending_up", 100.0, 0.22, 1901), [_cash()],
        "Create capped upside with lower premium than a naked long call.",
        "A call spread turns a direction view into a bounded payoff shape.",
        "The structure was empty, mismatched, or left the upside undefined.",
        "Inspect how the upper strike changes premium, Delta, and maximum gain.",
        [
            Objectives.call_spread(1.0, 1.0, 0.08, 1.6),
            Objectives.metric(&"loss_floor", "Keep P&L above -3.", &"total_pnl", Objectives.OP_AT_LEAST, -3.0),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 95.", &"abs_delta", Objectives.OP_AT_MOST, 95.0),
        ], 3
    ))

    levels.append(_level(
        "build-butterfly", "Build a Butterfly", "Strategy Forge", &"calm", 9,
        _market(&"calm", 100.0, 0.20, 2001), [_cash()],
        "Build a narrow target-zone payoff around 100 with defined wing losses.",
        "A butterfly is cheap, convex, and intensely location-sensitive.",
        "Three labels were present, but the quantities did not form a butterfly.",
        "Verify non-zero 1:-2:1 quantities and equally spaced strikes.",
        [
            Objectives.butterfly(1.0, 0.08, 1.7),
            Objectives.metric(&"loss_floor", "Keep P&L above -4.", &"total_pnl", Objectives.OP_AT_LEAST, -4.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
        ], 4
    ))

    levels.append(_level(
        "iron-condor-survival", "Iron Condor Survival", "Market Weather Campaign", &"calm", 14,
        _market(&"calm", 100.0, 0.26, 2101),
        [
            _cash(),
            _option("short", "call", 110.0, 28, 0.26),
            _option("long", "call", 118.0, 28, 0.26),
            _option("short", "put", 90.0, 28, 0.28),
            _option("long", "put", 82.0, 28, 0.30),
        ],
        "Survive a short-volatility income run with wings that cap disaster.",
        "Defined-risk short volatility is still a risk-budget decision.",
        "The income engine was not balanced against wing risk.",
        "Decide whether the wings were protection or decoration.",
        [
            Objectives.metric(&"minimum_pnl", "Earn at least 1 P&L.", &"total_pnl", Objectives.OP_AT_LEAST, 1.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 18.", &"max_drawdown", Objectives.OP_AT_MOST, 18.0),
        ], 4
    ))

    levels.append(_level(
        "market-maker-intro", "Market Maker Intro", "Market Maker Arena", &"choppy", 8,
        _market(&"choppy", 100.0, 0.25, 2201), [_cash(), _stock(0.0)],
        "Quote client flow, earn fills selectively, and control inventory Greeks.",
        "Spread compensates for inventory risk and information asymmetry.",
        "Quotes were too tight for toxic flow or too wide to earn edge.",
        "Compare quote count, fill count, captured edge, and closing inventory.",
        [
            Objectives.market_making(4, 2, 0.25, 1.6),
            Objectives.metric(&"loss_floor", "Keep P&L above -6.", &"total_pnl", Objectives.OP_AT_LEAST, -6.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
        ], 4
    ))
    return levels


static func _build_final_trials() -> Array[Dictionary]:
    var levels: Array[Dictionary] = []
    levels.append(_final_trial(
        "gamma-scalper-final", "Gamma Scalper Final", &"choppy", 12, 3101,
        [_cash(), _option("long", "call", 100.0, 21, 0.28), _option("long", "put", 100.0, 21, 0.28)],
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 28.", &"max_drawdown", Objectives.OP_AT_MOST, 28.0),
            Objectives.action_count(&"delta_hedges", "Execute at least three Delta hedges.", &"delta_hedge", 3, 1.4),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 45.", &"abs_delta", Objectives.OP_AT_MOST, 45.0),
        ]
    ))
    levels.append(_final_trial(
        "vol-crush-ambush", "Vol Crush Ambush", &"earnings_event", 12, 3201,
        [_cash(), _option("long", "call", 103.0, 18, 0.78), _option("long", "put", 97.0, 18, 0.80)],
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 28.", &"max_drawdown", Objectives.OP_AT_MOST, 28.0),
            Objectives.action_count(&"vega_repairs", "Reduce long Vega before event resolution.", &"vega_hedge", 1, 1.4),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
        ]
    ))
    levels.append(_final_trial(
        "short-gamma-final", "Short Gamma Final", &"crash", 12, 3301,
        [_cash(), _option("short", "call", 110.0, 24, 0.40), _option("short", "put", 90.0, 24, 0.43)],
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 28.", &"max_drawdown", Objectives.OP_AT_MOST, 28.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
            Objectives.action_count(&"tail_repairs", "Use protection or reduce convexity before the jump.", &"tail_hedge", 1, 1.4),
        ]
    ))
    levels.append(_final_trial(
        "surface-twist-final", "Surface Twist Final", &"volatility_spike", 12, 3401,
        [_cash(), _option("long", "put", 92.0, 45, 0.34), _option("short", "call", 108.0, 30, 0.30)],
        [
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 28.", &"max_drawdown", Objectives.OP_AT_MOST, 28.0),
            Objectives.metric(&"closing_vega", "Finish with absolute Vega no greater than 0.24 per vol point.", &"abs_vega", Objectives.OP_AT_MOST, 0.24, 1.3),
            Objectives.action_count(&"surface_repairs", "Use a strike or tenor Vega hedge.", &"surface_hedge", 1, 1.3),
        ]
    ))
    levels.append(_final_trial(
        "market-making-final", "Market Making Final", &"choppy", 12, 3501,
        [_cash(), _stock(0.0)],
        [
            Objectives.market_making(6, 3, 0.75, 1.7),
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
            Objectives.metric(&"closing_delta", "Finish with absolute Delta no greater than 50.", &"abs_delta", Objectives.OP_AT_MOST, 50.0),
        ]
    ))
    levels.append(_final_trial(
        "probability-pit-final", "Probability Pit Final", &"trending_down", 12, 3601,
        [_cash(), _option("long", "put", 98.0, 30, 0.30)],
        [
            Objectives.probability(0.28, 3, 1.8),
            Objectives.metric(&"loss_floor", "Keep P&L above -8.", &"total_pnl", Objectives.OP_AT_LEAST, -8.0),
            Objectives.metric(&"drawdown_limit", "Keep drawdown at or below 28.", &"max_drawdown", Objectives.OP_AT_MOST, 28.0),
            Objectives.metric(&"risk_flags", "Use no more than two risk violations.", &"risk_violations", Objectives.OP_AT_MOST, 2.0),
        ]
    ))
    return levels


static func _final_trial(
        id: String,
        title: String,
        regime: StringName,
        horizon: int,
        seed: int,
        portfolio: Array[Dictionary],
        objectives: Array[Dictionary]
    ) -> Dictionary:
    var volatility := 0.28
    if regime == &"earnings_event":
        volatility = 0.78
    elif regime == &"crash":
        volatility = 0.38
    return _level(
        id, title, "Final Trials", regime, horizon,
        _market(regime, 100.0, volatility, seed), portfolio,
        "Pass a compact final combining pricing, path management, risk, and debrief discipline.",
        "Professional trading skill means explaining and controlling risk under pressure.",
        "The book could not explain or control its dominant risk.",
        "Compare score, attribution, action history, calibration, and inventory quality.",
        objectives, 5, &"final"
    )


static func _level(
        id: String,
        title: String,
        act: String,
        theme: StringName,
        horizon: int,
        initial_market: Dictionary,
        initial_portfolio: Array[Dictionary],
        goal: String,
        learning_point: String,
        failure: String,
        review: String,
        level_objectives: Array[Dictionary],
        difficulty: int,
        category: StringName = &"core"
    ) -> Dictionary:
    var objectives: Array[Dictionary] = [Objectives.fixed_horizon(horizon, 1.25)]
    objectives.append_array(level_objectives)
    var constraints := PackedStringArray()
    for objective in objectives:
        constraints.append(String(objective.get("label", "")))
    return {
        "schema_version": 1,
        "id": id,
        "title": title,
        "act": act,
        "category": category,
        "difficulty": difficulty,
        "formal": true,
        "seed": int(initial_market.get("seed", 0)),
        "theme": theme,
        "horizon": horizon,
        "initial_market": initial_market,
        "initial_portfolio": initial_portfolio,
        "goal": goal,
        "constraints": constraints,
        "learning_point": learning_point,
        "failure": failure,
        "review": review,
        "objectives": objectives,
    }


static func _market(
        regime: StringName,
        spot: float,
        volatility: float,
        seed: int
    ) -> Dictionary:
    var liquidity := 0.86
    var event_risk := 0.10
    var skew := -0.06
    var surface_shock := 0.0
    match regime:
        &"calm":
            liquidity = 0.94
            skew = -0.04
        &"volatility_spike":
            liquidity = 0.58
            event_risk = 0.38
            surface_shock = 0.08
        &"earnings_event":
            liquidity = 0.62
            event_risk = 0.90
            skew = -0.09
        &"crash":
            liquidity = 0.34
            event_risk = 0.72
            skew = -0.16
            surface_shock = 0.12
    return {
        "spot": spot,
        "volatility": volatility,
        "risk_free_rate": 0.025,
        "day": 0,
        "regime": regime,
        "liquidity": liquidity,
        "event_risk": event_risk,
        "skew": skew,
        "term_slope": -0.04 if regime == &"earnings_event" else 0.02,
        "surface_shock": surface_shock,
        "seed": seed,
    }


static func _option(
        side: String,
        option_type: String,
        strike: float,
        expiry_days: int,
        iv: float,
        quantity: float = 1.0
    ) -> Dictionary:
    return {
        "kind": &"option",
        "side": StringName(side),
        "option_type": StringName(option_type),
        "strike": strike,
        "expiry_days": expiry_days,
        "iv": iv,
        "quantity": quantity,
        "contract_size": 1.0,
    }


static func _stock(quantity: float) -> Dictionary:
    return {"kind": &"stock", "quantity": quantity}


static func _cash(amount: float = 0.0) -> Dictionary:
    return {"kind": &"cash", "amount": amount}
