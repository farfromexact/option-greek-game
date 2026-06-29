import type {
  CashLeg,
  GreekSet,
  MarketState,
  OptionLeg,
  PortfolioLeg,
  PortfolioSnapshot,
  StockLeg,
} from "../types";
import { blackScholes, expiryPayoff } from "./blackScholes";
import { addGreeks, scaleGreeks, zeroGreeks } from "./greeks";

export const CONTRACT_SIZE = 1;

export function makeId(prefix: string): string {
  return `${prefix}-${Math.random().toString(36).slice(2, 9)}`;
}

export function optionSign(leg: OptionLeg): number {
  return leg.side === "long" ? 1 : -1;
}

export function yearsFromDays(days: number): number {
  return Math.max(days, 0.25) / 365;
}

export function priceOptionLeg(leg: OptionLeg, market: MarketState) {
  const result = blackScholes({
    spot: market.spot,
    strike: leg.strike,
    timeToExpiry: yearsFromDays(leg.expiryDays),
    volatility: optionSurfaceVolatility(leg, market),
    riskFreeRate: market.riskFreeRate,
    optionType: leg.optionType,
  });
  const scale = optionSign(leg) * leg.quantity * CONTRACT_SIZE;
  return {
    value: result.price * scale,
    intrinsicValue: result.intrinsicValue * scale,
    greeks: scaleGreeks(result, scale),
    unitPrice: result.price,
  };
}

export function priceStockLeg(leg: StockLeg, market: MarketState) {
  const greeks: GreekSet = {
    ...zeroGreeks,
    delta: leg.quantity,
  };
  return {
    value: leg.quantity * market.spot,
    intrinsicValue: leg.quantity * market.spot,
    greeks,
  };
}

export function priceCashLeg(leg: CashLeg) {
  return {
    value: leg.amount,
    intrinsicValue: leg.amount,
    greeks: zeroGreeks,
  };
}

export function priceLeg(leg: PortfolioLeg, market: MarketState) {
  if (leg.kind === "option") {
    return priceOptionLeg(leg, market);
  }
  if (leg.kind === "stock") {
    return priceStockLeg(leg, market);
  }
  return priceCashLeg(leg);
}

export function optionSurfaceVolatility(leg: OptionLeg, market: MarketState): number {
  const moneyness = leg.strike / Math.max(1, market.spot);
  const expiryYears = yearsFromDays(leg.expiryDays);
  const termBend = market.termSlope * (expiryYears - 30 / 365);
  const wingShock = market.surfaceShock * Math.pow(Math.abs(moneyness - 1), 0.7);
  const skewShock = market.skew * (moneyness - 1);
  return Math.max(0.03, Math.min(1.6, leg.iv + termBend + skewShock + wingShock));
}

export function summarizePortfolio(
  legs: PortfolioLeg[],
  market: MarketState,
): PortfolioSnapshot {
  return legs.reduce<PortfolioSnapshot>(
    (snapshot, leg) => {
      const priced = priceLeg(leg, market);
      const nextGreeks = addGreeks(snapshot, priced.greeks);
      return {
        value: snapshot.value + priced.value,
        intrinsicValue: snapshot.intrinsicValue + priced.intrinsicValue,
        maxLossEstimate: snapshot.maxLossEstimate,
        marginEstimate: snapshot.marginEstimate + estimateLegMargin(leg, market),
        ...nextGreeks,
      };
    },
    {
      value: 0,
      intrinsicValue: 0,
      maxLossEstimate: 0,
      marginEstimate: 0,
      ...zeroGreeks,
    },
  );
}

export function estimateLegMargin(leg: PortfolioLeg, market: MarketState): number {
  if (leg.kind === "cash") {
    return 0;
  }
  if (leg.kind === "stock") {
    return Math.abs(leg.quantity * market.spot) * 0.25;
  }
  const notional = Math.abs(leg.quantity * leg.strike * CONTRACT_SIZE);
  if (leg.side === "short") {
    return notional * 0.18 + market.spot * Math.abs(leg.quantity) * 0.05;
  }
  return notional * 0.04;
}

export function payoffAtExpiry(
  legs: PortfolioLeg[],
  market: MarketState,
  spotAtExpiry: number,
): number {
  const currentValue = summarizePortfolio(legs, market).value;
  const expiryValue = legs.reduce((total, leg) => {
    if (leg.kind === "option") {
      return (
        total +
        expiryPayoff(leg.optionType, spotAtExpiry, leg.strike) *
          optionSign(leg) *
          leg.quantity *
          CONTRACT_SIZE
      );
    }
    if (leg.kind === "stock") {
      return total + leg.quantity * spotAtExpiry;
    }
    return total + leg.amount;
  }, 0);
  return expiryValue - currentValue;
}

export function scenarioPnl(
  legs: PortfolioLeg[],
  market: MarketState,
  spotShift: number,
  volShift: number,
  daysForward: number,
): number {
  const currentValue = summarizePortfolio(legs, market).value;
  const shiftedMarket: MarketState = {
    ...market,
    spot: Math.max(1, market.spot + spotShift),
    volatility: Math.max(0.03, market.volatility + volShift),
    day: market.day + daysForward,
  };
  const shiftedLegs = decayOptionExpiries(legs, daysForward).map((leg) =>
    leg.kind === "option"
      ? { ...leg, iv: Math.max(0.03, leg.iv + volShift) }
      : leg,
  );
  return summarizePortfolio(shiftedLegs, shiftedMarket).value - currentValue;
}

export function decayOptionExpiries(
  legs: PortfolioLeg[],
  days: number,
): PortfolioLeg[] {
  return legs.map((leg) =>
    leg.kind === "option"
      ? { ...leg, expiryDays: Math.max(0.25, leg.expiryDays - days) }
      : leg,
  );
}

export function createOptionLeg(
  side: "long" | "short",
  optionType: "call" | "put",
  market: MarketState,
  overrides: Partial<OptionLeg> = {},
): OptionLeg {
  const strikeBias = optionType === "call" ? 1.04 : 0.96;
  return {
    id: makeId(`${side}-${optionType}`),
    kind: "option",
    side,
    optionType,
    strike: Math.round(market.spot * strikeBias),
    expiryDays: 30,
    iv: market.volatility,
    quantity: 1,
    ...overrides,
  };
}

export function createStockLeg(quantity: number): StockLeg {
  return {
    id: makeId("stock"),
    kind: "stock",
    quantity,
  };
}

export function createCashLeg(amount: number): CashLeg {
  return {
    id: makeId("cash"),
    kind: "cash",
    amount,
  };
}
