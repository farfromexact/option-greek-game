class_name ChallengeGenerator
extends RefCounted

const Objectives = preload("res://scripts/game/objective_defs.gd")

const REGIMES: Array[StringName] = [
    &"calm",
    &"trending_up",
    &"trending_down",
    &"choppy",
    &"volatility_spike",
    &"earnings_event",
    &"crash",
]

const MISSION_FRAMES: Array[Dictionary] = [
    {
        "slug": "theta-harvest",
        "title": "Theta Harvest",
        "goal": "Collect time decay while keeping the tail loss inside the sponsor limit.",
        "learning_point": "Short premium is an insurance book, not passive income.",
    },
    {
        "slug": "gamma-taxi",
        "title": "Gamma Taxi",
        "goal": "Run long Gamma through realized movement without dying from the fuel leak.",
        "learning_point": "Gamma pays when realized movement clears implied cost and friction.",
    },
    {
        "slug": "surface-misfit",
        "title": "Surface Misfit",
        "goal": "Control the strike and tenor bucket carrying the actual volatility risk.",
        "learning_point": "A neutral total Vega can conceal a dangerous surface mismatch.",
    },
    {
        "slug": "event-airbag",
        "title": "Event Airbag",
        "goal": "Position around an event without letting IV crush erase the thesis.",
        "learning_point": "Direction and volatility are separate bets.",
    },
    {
        "slug": "inventory-run",
        "title": "Inventory Run",
        "goal": "Trade client flow, then clean up the Greeks left in inventory.",
        "learning_point": "A fill begins an inventory problem; it does not finish one.",
    },
    {
        "slug": "calibration-desk",
        "title": "Calibration Desk",
        "goal": "Commit forecasts before the path and stay calibrated under pressure.",
        "learning_point": "Probability skill is scored before hindsight can edit the forecast.",
    },
]


static func generate(seed_text: String, ordinal: int = 0) -> Dictionary:
    var challenge_seed := _hash_seed("%s:%d" % [seed_text, ordinal])
    var rng := RandomNumberGenerator.new()
    rng.seed = challenge_seed

    var regime: StringName = REGIMES[rng.randi_range(0, REGIMES.size() - 1)]
    var frame: Dictionary = MISSION_FRAMES[rng.randi_range(0, MISSION_FRAMES.size() - 1)]
    var difficulty := rng.randi_range(1, 5)
    var horizon := 8 + difficulty * 2
    var spot := float(rng.randi_range(92, 114))
    var volatility := clampf(0.16 + difficulty * 0.045 + rng.randf_range(0.0, 0.14), 0.14, 0.72)
    if regime == &"earnings_event":
        volatility = maxf(volatility, 0.55)
    elif regime == &"crash":
        volatility = maxf(volatility, 0.32)

    var initial_market := _market(regime, spot, volatility, challenge_seed, rng)
    var objectives: Array[Dictionary] = [
        Objectives.fixed_horizon(horizon, 1.25),
        Objectives.metric(
            &"minimum_pnl",
            "Finish above the desk loss floor.",
            &"total_pnl",
            Objectives.OP_AT_LEAST,
            -float(difficulty) * 2.0,
            1.0
        ),
        Objectives.metric(
            &"drawdown_limit",
            "Keep drawdown inside the sponsor limit.",
            &"max_drawdown",
            Objectives.OP_AT_MOST,
            18.0 + difficulty * 5.0,
            1.2
        ),
        Objectives.metric(
            &"risk_discipline",
            "Keep risk violations controlled.",
            &"risk_violations",
            Objectives.OP_AT_MOST,
            float(maxi(1, 4 - difficulty / 2)),
            1.0
        ),
    ]

    match String(frame["slug"]):
        "gamma-taxi":
            objectives.append(Objectives.action_count(
                &"delta_hedges", "Use at least two deliberate Delta hedges.", &"delta_hedge", 2, 1.1
            ))
        "inventory-run":
            objectives.append(Objectives.market_making(
                3 + difficulty, 2, 0.1 * difficulty, 1.4
            ))
        "calibration-desk":
            objectives.append(Objectives.probability(
                maxf(0.20, 0.31 - difficulty * 0.015), 3, 1.5
            ))
        _:
            objectives.append(Objectives.metric(
                &"closing_delta",
                "Finish with controlled directional exposure.",
                &"abs_delta",
                Objectives.OP_AT_MOST,
                100.0 - difficulty * 8.0,
                0.9
            ))

    return {
        "schema_version": 1,
        "id": "seed-%s-%d" % [_slugify(seed_text), ordinal],
        "title": "%s · Seed %d" % [frame["title"], ordinal + 1],
        "act": "Seed Challenges",
        "category": &"challenge",
        "difficulty": difficulty,
        "formal": true,
        "seed": challenge_seed,
        "theme": regime,
        "horizon": horizon,
        "initial_market": initial_market,
        "initial_portfolio": _portfolio_for_frame(initial_market, String(frame["slug"]), rng),
        "goal": frame["goal"],
        "learning_point": frame["learning_point"],
        "failure": "The generated path exposed a risk bucket that was neither priced nor controlled.",
        "review": "Replay the path and name the dominant P&L driver before trying the seed again.",
        "objectives": objectives,
    }


static func generate_many(seed_text: String, count: int) -> Array[Dictionary]:
    var generated: Array[Dictionary] = []
    for ordinal in range(maxi(count, 0)):
        generated.append(generate(seed_text, ordinal))
    return generated


static func daily(date_key: String = "") -> Dictionary:
    var key := date_key
    if key.is_empty():
        var date := Time.get_date_dict_from_system()
        key = "%04d-%02d-%02d" % [date.year, date.month, date.day]
    return generate("daily-%s" % key, 0)


static func _market(
        regime: StringName,
        spot: float,
        volatility: float,
        challenge_seed: int,
        rng: RandomNumberGenerator
    ) -> Dictionary:
    return {
        "spot": spot,
        "volatility": volatility,
        "risk_free_rate": 0.025,
        "day": 0,
        "regime": regime,
        "liquidity": clampf(0.92 - volatility * 0.55, 0.28, 0.92),
        "event_risk": clampf(rng.randf_range(0.05, 0.45) + (0.35 if regime == &"earnings_event" else 0.0), 0.05, 0.95),
        "skew": -0.04 - rng.randf_range(0.0, 0.08),
        "term_slope": rng.randf_range(-0.12, 0.08),
        "surface_shock": rng.randf_range(-0.08, 0.12),
        "seed": challenge_seed,
    }


static func _portfolio_for_frame(
        market: Dictionary,
        frame_slug: String,
        rng: RandomNumberGenerator
    ) -> Array[Dictionary]:
    var portfolio: Array[Dictionary] = [_cash(0.0)]
    var spot := float(market["spot"])
    var iv := float(market["volatility"])
    match frame_slug:
        "theta-harvest":
            portfolio.append(_option("short", "call", roundf(spot * 1.10), 28, iv + 0.02))
            portfolio.append(_option("short", "put", roundf(spot * 0.90), 28, iv + 0.04))
        "gamma-taxi":
            portfolio.append(_option("long", "call", roundf(spot), 21, iv))
            portfolio.append(_option("long", "put", roundf(spot), 21, iv))
        "inventory-run":
            portfolio.append(_stock(float(rng.randi_range(-20, 20))))
        _:
            portfolio.append(_option("long", "put", roundf(spot * 0.92), 45, iv + 0.03))
            portfolio.append(_option("short", "call", roundf(spot * 1.08), 30, iv))
    return portfolio


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


static func _cash(amount: float) -> Dictionary:
    return {"kind": &"cash", "amount": amount}


static func _hash_seed(text: String) -> int:
    # Deterministic across platforms and Godot sessions; never uses global RNG.
    var hash_value: int = 2166136261
    for index in text.length():
        hash_value = (hash_value ^ text.unicode_at(index)) & 0x7fffffff
        hash_value = (hash_value * 16777619) & 0x7fffffff
    return maxi(hash_value, 1)


static func _slugify(text: String) -> String:
    var output := ""
    for index in text.length():
        var character := text.substr(index, 1).to_lower()
        if character in "abcdefghijklmnopqrstuvwxyz0123456789-":
            output += character
        elif not output.ends_with("-"):
            output += "-"
    output = output.trim_prefix("-").trim_suffix("-")
    if output.is_empty():
        return "challenge"
    return output.left(32)
