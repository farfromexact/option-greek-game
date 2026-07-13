class_name PnlAttribution
extends RefCounted

## Replay records use `is_market_step` to distinguish elapsed market time from
## zero-time trading actions. Costs and drawdown still include every record.


static func calculate(records: Array) -> Dictionary:
    var valid_records: Array[Dictionary] = []
    for record_value: Variant in records:
        if record_value is Dictionary:
            var record: Dictionary = record_value
            valid_records.append(record)
    if valid_records.is_empty():
        return _empty_result()

    var first_record: Dictionary = valid_records[0]
    var transaction_cost: float = float(first_record.get("transaction_cost", 0.0))
    var first_pnl: float = float(first_record.get("pnl", 0.0))
    var high_watermark: float = maxf(0.0, first_pnl)
    var max_drawdown: float = maxf(0.0, -first_pnl)
    var risk_violations: int = 0
    var delta_pnl: float = 0.0
    var gamma_pnl: float = 0.0
    var theta_pnl: float = 0.0
    var vega_pnl: float = 0.0
    var market_returns: Array[float] = []

    for index: int in range(1, valid_records.size()):
        var previous: Dictionary = valid_records[index - 1]
        var current: Dictionary = valid_records[index]
        transaction_cost += float(current.get("transaction_cost", 0.0))
        var current_pnl: float = float(current.get("pnl", 0.0))
        high_watermark = maxf(high_watermark, current_pnl)
        max_drawdown = maxf(max_drawdown, high_watermark - current_pnl)

        if not bool(current.get("is_market_step", false)):
            continue
        var previous_market: Dictionary = previous.get("market", {})
        var current_market: Dictionary = current.get("market", {})
        var elapsed_day_count: int = (
            int(current_market.get("day", 0))
            - int(previous_market.get("day", 0))
        )
        if elapsed_day_count <= 0:
            continue
        var current_portfolio: Dictionary = current.get("portfolio", {})
        var risk_load: float = (
            absf(float(current_portfolio.get("delta", 0.0))) / 120.0
            + absf(float(current_portfolio.get("gamma", 0.0))) / 12.0
            + absf(float(current_portfolio.get("vega", 0.0))) / 9.0
            + maxf(0.0, -current_pnl) / 45.0
        )
        if risk_load > 2.25:
            risk_violations += 1
        var previous_portfolio: Dictionary = previous.get("portfolio", {})
        var previous_spot: float = float(previous_market.get("spot", 0.0))
        var current_spot: float = float(current_market.get("spot", previous_spot))
        var previous_volatility: float = float(previous_market.get("volatility", 0.0))
        var current_volatility: float = float(current_market.get("volatility", previous_volatility))
        var spot_move: float = current_spot - previous_spot
        var vol_point_move: float = (current_volatility - previous_volatility) / 0.01
        var elapsed_days: float = float(elapsed_day_count)
        delta_pnl += float(previous_portfolio.get("delta", 0.0)) * spot_move
        gamma_pnl += 0.5 * float(previous_portfolio.get("gamma", 0.0)) * spot_move * spot_move
        theta_pnl += float(previous_portfolio.get("theta", 0.0)) * elapsed_days
        vega_pnl += float(previous_portfolio.get("vega", 0.0)) * vol_point_move
        if previous_spot > 0.0 and current_spot > 0.0:
            market_returns.append(log(current_spot / previous_spot))

    var last_record: Dictionary = valid_records[valid_records.size() - 1]
    var total_pnl: float = float(last_record.get("pnl", 0.0))
    var explained: float = delta_pnl + gamma_pnl + theta_pnl + vega_pnl - transaction_cost
    var realized_vol: float = _estimate_realized_vol(market_returns)
    var final_market: Dictionary = last_record.get("market", {})
    var implied_vol: float = float(final_market.get("volatility", 0.0))
    return {
        "total_pnl": total_pnl,
        "delta_pnl": delta_pnl,
        "gamma_pnl": gamma_pnl,
        "theta_pnl": theta_pnl,
        "vega_pnl": vega_pnl,
        "transaction_cost": transaction_cost,
        "residual": total_pnl - explained,
        "max_drawdown": max_drawdown,
        "risk_violations": risk_violations,
        "realized_vol": realized_vol,
        "implied_vol": implied_vol,
        "gamma_scalp_edge": realized_vol - implied_vol,
    }


static func _estimate_realized_vol(returns: Array[float]) -> float:
    if returns.size() < 2:
        return 0.0
    var total: float = 0.0
    for value: float in returns:
        total += value
    var mean: float = total / float(returns.size())
    var squared_deviations: float = 0.0
    for value: float in returns:
        squared_deviations += (value - mean) * (value - mean)
    var variance: float = squared_deviations / float(returns.size() - 1)
    return sqrt(variance) * sqrt(252.0)


static func _empty_result() -> Dictionary:
    return {
        "total_pnl": 0.0,
        "delta_pnl": 0.0,
        "gamma_pnl": 0.0,
        "theta_pnl": 0.0,
        "vega_pnl": 0.0,
        "transaction_cost": 0.0,
        "residual": 0.0,
        "max_drawdown": 0.0,
        "risk_violations": 0,
        "realized_vol": 0.0,
        "implied_vol": 0.0,
        "gamma_scalp_edge": 0.0,
    }
