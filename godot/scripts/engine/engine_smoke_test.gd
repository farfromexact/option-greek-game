extends SceneTree

const BlackScholes = preload("res://scripts/engine/black_scholes_engine.gd")
const Market = preload("res://scripts/engine/market_simulator.gd")
const Portfolio = preload("res://scripts/engine/portfolio_engine.gd")
const Attribution = preload("res://scripts/engine/pnl_attribution.gd")

var failures: Array[String] = []


func _init() -> void:
    _test_black_scholes_units()
    _test_deterministic_market()
    _test_portfolio_contracts()
    _test_market_step_attribution()
    if failures.is_empty():
        print("ENGINE_SMOKE_OK")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)


func _test_black_scholes_units() -> void:
    var call: Dictionary = BlackScholes.evaluate({
        "spot": 100.0,
        "strike": 100.0,
        "time_to_expiry": 1.0,
        "volatility": 0.20,
        "risk_free_rate": 0.05,
        "option_type": &"call",
    })
    _expect_close(float(call["price"]), 10.4506, 0.001, "Black-Scholes call price")
    _expect_close(float(call["theta"]), -6.4140 / 365.0, 0.0001, "Theta calendar-day units")
    _expect_close(float(call["vega"]), 0.3752, 0.0002, "Vega one-point units")


func _test_deterministic_market() -> void:
    var initial: Dictionary = Market.create_market(&"choppy", 100.0, 77)
    var first: Dictionary = Market.step(initial)
    var replay: Dictionary = Market.step(initial)
    var other_seed: Dictionary = Market.step(Market.create_market(&"choppy", 100.0, 78))
    _expect(first == replay, "Market path is not deterministic for the same state.")
    _expect(not is_equal_approx(float(first["spot"]), float(other_seed["spot"])), "Different seeds produced the same first spot.")
    _expect(int(first["day"]) == 1 and int(first["seed"]) == 78, "Market clock or seed did not advance once.")
    _expect_close(Market.transaction_cost(-1000.0, initial), 5.84, 0.00001, "Absolute-notional transaction cost")


func _test_portfolio_contracts() -> void:
    var market: Dictionary = Market.create_market(&"calm", 100.0, 4)
    var option: Dictionary = Portfolio.create_option(&"long", &"call", market, {
        "strike": 100.0,
        "expiry_days": 30.0,
        "quantity": 2.0,
        "contract_size": 10.0,
    })
    var stock: Dictionary = Portfolio.create_stock(-3.0)
    var cash: Dictionary = Portfolio.create_cash(50.0)
    var legs: Array = [option, stock, cash]
    var snapshot: Dictionary = Portfolio.summarize(legs, market)
    var priced_option: Dictionary = Portfolio.price_leg(option, market)
    var option_greeks: Dictionary = priced_option["greeks"]
    _expect_close(float(snapshot["delta"]), float(option_greeks["delta"]) - 3.0, 0.000001, "Portfolio Delta aggregation")
    _expect(absf(float(snapshot["theta"])) < 2.0, "Portfolio theta is not in daily units.")
    _expect(absf(float(snapshot["vega"])) < 20.0, "Portfolio vega is not in one-point units.")
    var decayed: Array = Portfolio.decay_expiries(legs, 5.0)
    var decayed_option: Dictionary = decayed[0]
    _expect_close(float(decayed_option["expiry_days"]), 25.0, 0.000001, "Expiry decay")
    _expect_close(float(option["expiry_days"]), 30.0, 0.000001, "Expiry decay mutated the source leg")
    var payoff: float = Portfolio.payoff_at_expiry([option], market, 110.0)
    _expect_close(payoff, 200.0 - float(priced_option["value"]), 0.000001, "Expiry payoff respects contract size")


func _test_market_step_attribution() -> void:
    var portfolio: Dictionary = {
        "delta": 2.0, "gamma": 0.1, "theta": -1.0, "vega": 3.0,
    }
    var records: Array = [
        _record(100.0, 0.20, 0, portfolio, 0.0, 0.0, false),
        _record(100.0, 0.20, 0, portfolio, -2.0, 2.0, false),
        _record(102.0, 0.21, 1, portfolio, 5.0, 0.0, true),
        _record(102.0, 0.21, 1, portfolio, 4.0, 1.0, false),
        _record(101.0, 0.205, 2, portfolio, 3.0, 0.0, true),
    ]
    var report: Dictionary = Attribution.calculate(records)
    _expect_close(float(report["delta_pnl"]), 2.0, 0.000001, "Delta attribution")
    _expect_close(float(report["gamma_pnl"]), 0.25, 0.000001, "Gamma attribution")
    _expect_close(float(report["theta_pnl"]), -2.0, 0.000001, "Actions created fake theta time")
    _expect_close(float(report["vega_pnl"]), 1.5, 0.000001, "Vega point attribution")
    _expect_close(float(report["transaction_cost"]), 3.0, 0.000001, "Action transaction costs")
    var oversized: Dictionary = {
        "delta": 1000.0, "gamma": 0.0, "theta": 0.0, "vega": 0.0,
    }
    var risk_report: Dictionary = Attribution.calculate([
        _record(100.0, 0.20, 0, oversized, 0.0, 0.0, false),
        _record(100.0, 0.20, 0, oversized, 0.0, 0.0, false),
        _record(101.0, 0.20, 1, oversized, 0.0, 0.0, true),
    ])
    _expect(int(risk_report["risk_violations"]) == 1, "A zero-time action created an extra risk violation.")
    var first_return: float = log(102.0 / 100.0)
    var second_return: float = log(101.0 / 102.0)
    var mean_return: float = (first_return + second_return) / 2.0
    var expected_realized: float = sqrt(
        ((first_return - mean_return) * (first_return - mean_return)
        + (second_return - mean_return) * (second_return - mean_return))
    ) * sqrt(252.0)
    _expect_close(float(report["realized_vol"]), expected_realized, 0.000001, "Actions polluted realized volatility")


func _record(
        spot: float,
        volatility: float,
        day: int,
        portfolio: Dictionary,
        pnl: float,
        cost: float,
        is_market_step: bool
    ) -> Dictionary:
    return {
        "market": {"spot": spot, "volatility": volatility, "day": day},
        "portfolio": portfolio.duplicate(true),
        "pnl": pnl,
        "transaction_cost": cost,
        "is_market_step": is_market_step,
    }


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _expect_close(actual: float, expected: float, tolerance: float, label: String) -> void:
    if absf(actual - expected) > tolerance:
        failures.append("%s: expected %.8f, got %.8f" % [label, expected, actual])
