class_name PortfolioEngine
extends RefCounted

const BlackScholes = preload("res://scripts/engine/black_scholes_engine.gd")
const GREEK_KEYS: Array[StringName] = [
    &"delta", &"gamma", &"theta", &"vega", &"rho",
    &"vanna", &"vomma", &"charm", &"speed", &"color",
]


static func summarize(legs: Array, market: Dictionary) -> Dictionary:
    var snapshot: Dictionary = _empty_snapshot()
    for leg_value: Variant in legs:
        if not leg_value is Dictionary:
            continue
        var leg: Dictionary = leg_value
        var priced: Dictionary = price_leg(leg, market)
        snapshot["value"] = float(snapshot["value"]) + float(priced.get("value", 0.0))
        snapshot["intrinsic_value"] = float(snapshot["intrinsic_value"]) + float(priced.get("intrinsic_value", 0.0))
        snapshot["margin_estimate"] = float(snapshot["margin_estimate"]) + _estimate_margin(leg, market)
        var greeks: Dictionary = priced.get("greeks", {})
        for greek_key: StringName in GREEK_KEYS:
            snapshot[greek_key] = float(snapshot[greek_key]) + float(greeks.get(greek_key, 0.0))
    return snapshot


static func price_leg(leg: Dictionary, market: Dictionary) -> Dictionary:
    var kind: StringName = StringName(leg.get("kind", &"cash"))
    if kind == &"option":
        return _price_option(leg, market)
    if kind == &"stock":
        var stock_greeks: Dictionary = _zero_greeks()
        var stock_quantity: float = float(leg.get("quantity", 0.0))
        var spot: float = float(market.get("spot", 0.0))
        stock_greeks["delta"] = stock_quantity
        return {
            "value": stock_quantity * spot,
            "intrinsic_value": stock_quantity * spot,
            "greeks": stock_greeks,
            "unit_price": spot,
        }
    if kind == &"cash":
        var cash_amount: float = float(leg.get("amount", 0.0))
        return {
            "value": cash_amount,
            "intrinsic_value": cash_amount,
            "greeks": _zero_greeks(),
            "unit_price": 1.0,
        }
    return {"value": 0.0, "intrinsic_value": 0.0, "greeks": _zero_greeks(), "unit_price": 0.0}


static func payoff_at_expiry(
        legs: Array,
        market: Dictionary,
        spot_at_expiry: float
    ) -> float:
    var current_snapshot: Dictionary = summarize(legs, market)
    var expiry_value: float = 0.0
    for leg_value: Variant in legs:
        if not leg_value is Dictionary:
            continue
        var leg: Dictionary = leg_value
        var kind: StringName = StringName(leg.get("kind", &"cash"))
        if kind == &"option":
            var option_type: StringName = StringName(leg.get("option_type", &"call"))
            var strike: float = float(leg.get("strike", 0.0))
            var scale: float = _option_scale(leg)
            expiry_value += BlackScholes.expiry_payoff(option_type, spot_at_expiry, strike) * scale
        elif kind == &"stock":
            expiry_value += float(leg.get("quantity", 0.0)) * spot_at_expiry
        elif kind == &"cash":
            expiry_value += float(leg.get("amount", 0.0))
    return expiry_value - float(current_snapshot["value"])


static func decay_expiries(legs: Array, days: float) -> Array:
    var decayed: Array = []
    for leg_value: Variant in legs:
        if not leg_value is Dictionary:
            decayed.append(leg_value)
            continue
        var leg: Dictionary = Dictionary(leg_value).duplicate(true)
        if StringName(leg.get("kind", &"cash")) == &"option":
            leg["expiry_days"] = maxf(0.25, float(leg.get("expiry_days", 0.25)) - days)
        decayed.append(leg)
    return decayed


static func create_option(
        side: StringName,
        option_type: StringName,
        market: Dictionary,
        overrides: Dictionary = {}
    ) -> Dictionary:
    var spot: float = float(market.get("spot", 100.0))
    var strike_bias: float = 1.04 if option_type == &"call" else 0.96
    var leg: Dictionary = {
        "kind": &"option",
        "side": side,
        "option_type": option_type,
        "strike": roundf(spot * strike_bias),
        "expiry_days": 30.0,
        "iv": float(market.get("volatility", 0.20)),
        "quantity": 1.0,
        "contract_size": 1.0,
    }
    leg.merge(overrides, true)
    return leg


static func create_stock(quantity: float) -> Dictionary:
    return {"kind": &"stock", "quantity": quantity}


static func create_cash(amount: float) -> Dictionary:
    return {"kind": &"cash", "amount": amount}


static func option_surface_volatility(leg: Dictionary, market: Dictionary) -> float:
    var spot: float = maxf(float(market.get("spot", 100.0)), 1.0)
    var moneyness: float = float(leg.get("strike", spot)) / spot
    var expiry_years: float = _years_from_days(float(leg.get("expiry_days", 30.0)))
    var term_bend: float = float(market.get("term_slope", 0.0)) * (expiry_years - 30.0 / 365.0)
    var wing_shock: float = float(market.get("surface_shock", 0.0)) * float(pow(absf(moneyness - 1.0), 0.7))
    var skew_shock: float = float(market.get("skew", 0.0)) * (moneyness - 1.0)
    return clampf(float(leg.get("iv", market.get("volatility", 0.20))) + term_bend + skew_shock + wing_shock, 0.03, 1.60)


static func _price_option(leg: Dictionary, market: Dictionary) -> Dictionary:
    var result: Dictionary = BlackScholes.evaluate({
        "spot": float(market.get("spot", 100.0)),
        "strike": float(leg.get("strike", 100.0)),
        "time_to_expiry": _years_from_days(float(leg.get("expiry_days", 30.0))),
        "volatility": option_surface_volatility(leg, market),
        "risk_free_rate": float(market.get("risk_free_rate", 0.0)),
        "option_type": StringName(leg.get("option_type", &"call")),
    })
    var scale: float = _option_scale(leg)
    var scaled_greeks: Dictionary = _zero_greeks()
    for greek_key: StringName in GREEK_KEYS:
        scaled_greeks[greek_key] = float(result.get(greek_key, 0.0)) * scale
    return {
        "value": float(result["price"]) * scale,
        "intrinsic_value": float(result["intrinsic_value"]) * scale,
        "greeks": scaled_greeks,
        "unit_price": float(result["price"]),
    }


static func _option_scale(leg: Dictionary) -> float:
    var side: StringName = StringName(leg.get("side", &"long"))
    var sign_value: float = 1.0 if side == &"long" else -1.0
    return sign_value * float(leg.get("quantity", 0.0)) * float(leg.get("contract_size", 1.0))


static func _years_from_days(days: float) -> float:
    return maxf(days, 0.25) / 365.0


static func _estimate_margin(leg: Dictionary, market: Dictionary) -> float:
    var kind: StringName = StringName(leg.get("kind", &"cash"))
    if kind == &"cash":
        return 0.0
    if kind == &"stock":
        return absf(float(leg.get("quantity", 0.0)) * float(market.get("spot", 0.0))) * 0.25
    var notional: float = absf(
        float(leg.get("quantity", 0.0))
        * float(leg.get("strike", 0.0))
        * float(leg.get("contract_size", 1.0))
    )
    if StringName(leg.get("side", &"long")) == &"short":
        return notional * 0.18 + float(market.get("spot", 0.0)) * absf(float(leg.get("quantity", 0.0))) * float(leg.get("contract_size", 1.0)) * 0.05
    return notional * 0.04


static func _zero_greeks() -> Dictionary:
    return {
        "delta": 0.0, "gamma": 0.0, "theta": 0.0, "vega": 0.0,
        "rho": 0.0, "vanna": 0.0, "vomma": 0.0, "charm": 0.0,
        "speed": 0.0, "color": 0.0,
    }


static func _empty_snapshot() -> Dictionary:
    var snapshot: Dictionary = _zero_greeks()
    snapshot.merge({
        "value": 0.0,
        "intrinsic_value": 0.0,
        "max_loss_estimate": 0.0,
        "margin_estimate": 0.0,
    })
    return snapshot
