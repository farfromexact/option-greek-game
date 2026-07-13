class_name BlackScholesEngine
extends RefCounted

## Black-Scholes pricing for non-dividend-paying European options.
## `theta` is returned per calendar day and `vega` per one volatility point
## (a 0.01 absolute change in implied volatility).

const MIN_SPOT: float = 0.01
const MIN_STRIKE: float = 0.01
const MIN_TIME_YEARS: float = 1.0 / 3650.0
const MIN_VOLATILITY: float = 0.01
const SQRT_TWO: float = 1.4142135623730951
const SQRT_TWO_PI: float = 2.5066282746310002


static func evaluate(input: Dictionary) -> Dictionary:
    var spot: float = maxf(float(input.get("spot", 0.0)), MIN_SPOT)
    var strike: float = maxf(float(input.get("strike", 0.0)), MIN_STRIKE)
    var time_to_expiry: float = maxf(
        float(input.get("time_to_expiry", 0.0)),
        MIN_TIME_YEARS
    )
    var volatility: float = maxf(
        float(input.get("volatility", 0.0)),
        MIN_VOLATILITY
    )
    var risk_free_rate: float = float(input.get("risk_free_rate", 0.0))
    var option_type: StringName = StringName(input.get("option_type", &"call"))
    var sqrt_time: float = sqrt(time_to_expiry)
    var discount: float = exp(-risk_free_rate * time_to_expiry)
    var d1: float = (
        log(spot / strike)
        + (risk_free_rate + 0.5 * volatility * volatility) * time_to_expiry
    ) / (volatility * sqrt_time)
    var d2: float = d1 - volatility * sqrt_time
    var call_price: float = (
        spot * normal_cdf(d1)
        - strike * discount * normal_cdf(d2)
    )
    var put_price: float = (
        strike * discount * normal_cdf(-d2)
        - spot * normal_cdf(-d1)
    )
    var is_call: bool = option_type == &"call"
    var density: float = normal_pdf(d1)
    var delta: float = normal_cdf(d1) if is_call else normal_cdf(d1) - 1.0
    var gamma: float = density / (spot * volatility * sqrt_time)
    var raw_vega: float = spot * density * sqrt_time
    var annual_call_theta: float = (
        -(spot * density * volatility) / (2.0 * sqrt_time)
        - risk_free_rate * strike * discount * normal_cdf(d2)
    )
    var annual_put_theta: float = (
        -(spot * density * volatility) / (2.0 * sqrt_time)
        + risk_free_rate * strike * discount * normal_cdf(-d2)
    )
    var rho: float = (
        strike * time_to_expiry * discount * normal_cdf(d2)
        if is_call
        else -strike * time_to_expiry * discount * normal_cdf(-d2)
    )
    var vanna: float = -density * (d2 / volatility)
    var vomma: float = (raw_vega * d1 * d2) / volatility
    var charm: float = -density * (
        (2.0 * risk_free_rate * time_to_expiry - d2 * volatility * sqrt_time)
        / (2.0 * time_to_expiry * volatility * sqrt_time)
    )
    var speed: float = -(gamma / spot) * (
        d1 / (volatility * sqrt_time) + 1.0
    )
    var color: float = (
        -density / (2.0 * spot * time_to_expiry * volatility * sqrt_time)
    ) * (
        2.0 * risk_free_rate * time_to_expiry
        + 1.0
        + d1 * (
            2.0 * risk_free_rate * time_to_expiry - d2 * volatility * sqrt_time
        ) / (volatility * sqrt_time)
    )

    return {
        "price": call_price if is_call else put_price,
        "intrinsic_value": maxf(spot - strike, 0.0) if is_call else maxf(strike - spot, 0.0),
        "delta": delta,
        "gamma": gamma,
        "theta": (annual_call_theta if is_call else annual_put_theta) / 365.0,
        "vega": raw_vega * 0.01,
        "rho": rho,
        "vanna": vanna,
        "vomma": vomma,
        "charm": charm,
        "speed": speed,
        "color": color,
        "d1": d1,
        "d2": d2,
    }


static func normal_pdf(value: float) -> float:
    return exp(-0.5 * value * value) / SQRT_TWO_PI


static func normal_cdf(value: float) -> float:
    var sign_value: float = -1.0 if value < 0.0 else 1.0
    var z: float = absf(value) / SQRT_TWO
    var t: float = 1.0 / (1.0 + 0.3275911 * z)
    var polynomial: float = (
        ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592)
        * t
    )
    var erf_value: float = 1.0 - polynomial * exp(-z * z)
    return 0.5 * (1.0 + sign_value * erf_value)


static func expiry_payoff(
        option_type: StringName,
        spot_at_expiry: float,
        strike: float
    ) -> float:
    if option_type == &"call":
        return maxf(spot_at_expiry - strike, 0.0)
    return maxf(strike - spot_at_expiry, 0.0)
