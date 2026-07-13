class_name MarketSimulator
extends RefCounted

## A deterministic, seed-carrying market path. Calling `step` twice with the
## same dictionary returns the same next state; the returned seed advances by 1.

const PROFILES: Dictionary = {
    &"calm": {"drift": 0.0002, "shock": 0.004, "vol_drift": -0.002, "vol_shock": 0.006, "liquidity": 0.86, "event_risk": 0.08, "skew": -0.05},
    &"trending_up": {"drift": 0.006, "shock": 0.011, "vol_drift": -0.001, "vol_shock": 0.008, "liquidity": 0.76, "event_risk": 0.18, "skew": -0.04},
    &"trending_down": {"drift": -0.005, "shock": 0.012, "vol_drift": 0.002, "vol_shock": 0.010, "liquidity": 0.72, "event_risk": 0.24, "skew": -0.09},
    &"choppy": {"drift": 0.0, "shock": 0.018, "vol_drift": 0.0005, "vol_shock": 0.011, "liquidity": 0.68, "event_risk": 0.20, "skew": -0.06},
    &"volatility_spike": {"drift": -0.001, "shock": 0.016, "vol_drift": 0.018, "vol_shock": 0.025, "liquidity": 0.55, "event_risk": 0.42, "skew": -0.11},
    &"earnings_event": {"drift": 0.001, "shock": 0.026, "vol_drift": -0.012, "vol_shock": 0.035, "liquidity": 0.60, "event_risk": 0.75, "skew": -0.03},
    &"crash": {"drift": -0.017, "shock": 0.032, "vol_drift": 0.026, "vol_shock": 0.032, "liquidity": 0.35, "event_risk": 0.88, "skew": -0.18},
}


static func create_market(
        regime: StringName,
        spot: float = 100.0,
        seed: int = 1
    ) -> Dictionary:
    var regime_id: StringName = regime if PROFILES.has(regime) else &"calm"
    var profile: Dictionary = PROFILES[regime_id]
    var volatility: float = 0.28
    if regime_id == &"calm":
        volatility = 0.18
    elif regime_id == &"crash":
        volatility = 0.42
    return {
        "spot": maxf(spot, 1.0),
        "volatility": volatility,
        "risk_free_rate": 0.04,
        "day": 0,
        "regime": regime_id,
        "liquidity": float(profile["liquidity"]),
        "event_risk": float(profile["event_risk"]),
        "skew": float(profile["skew"]),
        "term_slope": -0.16 if regime_id == &"earnings_event" else (0.03 if regime_id == &"calm" else 0.08),
        "surface_shock": 0.0,
        "seed": seed,
    }


static func step(market: Dictionary) -> Dictionary:
    var requested_regime: StringName = StringName(market.get("regime", &"calm"))
    var regime: StringName = requested_regime if PROFILES.has(requested_regime) else &"calm"
    var profile: Dictionary = PROFILES[regime]
    var day: int = int(market.get("day", 0))
    var spot: float = maxf(float(market.get("spot", 100.0)), 1.0)
    var current_volatility: float = float(market.get("volatility", 0.20))
    var seed: int = int(market.get("seed", 1))
    var wave: float = sin(float(day + 1) * 0.83)
    var noise: float = _seeded_noise(
        float(seed) * 1.000003 + float(day + 1) * 104729.0 + spot * 17.0
    )
    var jump: float = 0.0
    if regime == &"earnings_event" and day == 4:
        jump = _seeded_noise(float(seed) * 31.0 + spot) * 0.075
    elif regime == &"crash" and day == 2:
        jump = -0.08
    var mean_reversion: float = 0.0
    if regime == &"choppy":
        if spot > 100.0:
            mean_reversion = -0.006
        elif spot < 100.0:
            mean_reversion = 0.006
    var return_pct: float = (
        float(profile["drift"])
        + wave * float(profile["shock"]) * 0.35
        + noise * float(profile["shock"])
        + jump
        + mean_reversion
    )
    var next_spot: float = maxf(1.0, spot * (1.0 + return_pct))
    var event_vol_crush: float = -0.035 if regime == &"earnings_event" and day >= 5 else 0.0
    var vol_move: float = (
        float(profile["vol_drift"])
        + absf(noise) * float(profile["vol_shock"])
        - (0.004 if regime == &"calm" else 0.0)
        + event_vol_crush
    )
    var next_volatility: float = clampf(current_volatility + vol_move, 0.06, 1.20)
    var current_surface_shock: float = float(market.get("surface_shock", 0.0))
    var next_surface_shock: float = 0.0
    if regime == &"earnings_event" and day == 5:
        next_surface_shock = -0.20
    elif regime == &"crash":
        next_surface_shock = minf(0.45, current_surface_shock + 0.06 + absf(return_pct))
    else:
        next_surface_shock = maxf(-0.25, current_surface_shock * 0.72 + vol_move * 0.55)
    var current_term_slope: float = float(market.get("term_slope", 0.0))
    var next_term_slope: float = 0.0
    if regime == &"earnings_event":
        next_term_slope = maxf(-0.35, current_term_slope - 0.025)
    elif regime == &"crash":
        next_term_slope = minf(0.28, current_term_slope + 0.035)
    else:
        next_term_slope = current_term_slope * 0.92 + float(profile["vol_drift"]) * 0.35
    var liquidity_noise: float = _seeded_noise(float(seed) * 7.0 + float(day + 5))
    var next_liquidity: float = clampf(
        float(profile["liquidity"]) - absf(return_pct) * 2.4 + liquidity_noise * 0.04,
        0.15,
        0.95
    )
    var next_market: Dictionary = market.duplicate(true)
    next_market.merge({
        "spot": next_spot,
        "volatility": next_volatility,
        "risk_free_rate": float(market.get("risk_free_rate", 0.04)),
        "day": day + 1,
        "regime": regime,
        "liquidity": next_liquidity,
        "event_risk": clampf(float(profile["event_risk"]) + absf(return_pct) * 3.0, 0.0, 1.0),
        "skew": float(profile["skew"]) - maxf(0.0, 100.0 - next_spot) * 0.002,
        "term_slope": next_term_slope,
        "surface_shock": next_surface_shock,
        "seed": seed + 1,
    }, true)
    return next_market


static func transaction_cost(notional: float, market: Dictionary) -> float:
    var liquidity: float = clampf(float(market.get("liquidity", 0.50)), 0.0, 1.0)
    var friction: float = 0.002 + (1.0 - liquidity) * 0.012
    return absf(notional) * friction


static func _seeded_noise(value: float) -> float:
    var raw_value: float = sin(value * 12.9898) * 43758.5453
    return (raw_value - floor(raw_value)) * 2.0 - 1.0
