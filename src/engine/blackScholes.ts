import type { GreekSet, OptionType } from "../types";

export type BlackScholesInput = {
  spot: number;
  strike: number;
  timeToExpiry: number;
  volatility: number;
  riskFreeRate: number;
  optionType: OptionType;
};

export type BlackScholesResult = GreekSet & {
  price: number;
  intrinsicValue: number;
  d1: number;
  d2: number;
};

const SQRT_TWO_PI = Math.sqrt(2 * Math.PI);

export function normalPdf(x: number): number {
  return Math.exp(-0.5 * x * x) / SQRT_TWO_PI;
}

export function normalCdf(x: number): number {
  const sign = x < 0 ? -1 : 1;
  const z = Math.abs(x) / Math.sqrt(2);
  const t = 1 / (1 + 0.3275911 * z);
  const a1 = 0.254829592;
  const a2 = -0.284496736;
  const a3 = 1.421413741;
  const a4 = -1.453152027;
  const a5 = 1.061405429;
  const erf =
    1 -
    (((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * Math.exp(-z * z));
  return 0.5 * (1 + sign * erf);
}

export function blackScholes(input: BlackScholesInput): BlackScholesResult {
  const spot = Math.max(input.spot, 0.01);
  const strike = Math.max(input.strike, 0.01);
  const timeToExpiry = Math.max(input.timeToExpiry, 1 / 3650);
  const volatility = Math.max(input.volatility, 0.01);
  const rate = input.riskFreeRate;
  const sqrtT = Math.sqrt(timeToExpiry);
  const discount = Math.exp(-rate * timeToExpiry);
  const d1 =
    (Math.log(spot / strike) + (rate + 0.5 * volatility * volatility) * timeToExpiry) /
    (volatility * sqrtT);
  const d2 = d1 - volatility * sqrtT;
  const call =
    spot * normalCdf(d1) - strike * discount * normalCdf(d2);
  const put =
    strike * discount * normalCdf(-d2) - spot * normalCdf(-d1);
  const isCall = input.optionType === "call";
  const price = isCall ? call : put;
  const delta = isCall ? normalCdf(d1) : normalCdf(d1) - 1;
  const gamma = normalPdf(d1) / (spot * volatility * sqrtT);
  const vega = spot * normalPdf(d1) * sqrtT;
  const vanna = -normalPdf(d1) * (d2 / volatility);
  const vomma = (vega * d1 * d2) / volatility;
  const callTheta =
    -(spot * normalPdf(d1) * volatility) / (2 * sqrtT) -
    rate * strike * discount * normalCdf(d2);
  const putTheta =
    -(spot * normalPdf(d1) * volatility) / (2 * sqrtT) +
    rate * strike * discount * normalCdf(-d2);
  const rho = isCall
    ? strike * timeToExpiry * discount * normalCdf(d2)
    : -strike * timeToExpiry * discount * normalCdf(-d2);
  const charm =
    -normalPdf(d1) *
    ((2 * rate * timeToExpiry - d2 * volatility * sqrtT) /
      (2 * timeToExpiry * volatility * sqrtT));
  const speed = -(gamma / spot) * (d1 / (volatility * sqrtT) + 1);
  const color =
    (-normalPdf(d1) /
      (2 * spot * timeToExpiry * volatility * sqrtT)) *
    (2 * rate * timeToExpiry +
      1 +
      (d1 * (2 * rate * timeToExpiry - d2 * volatility * sqrtT)) /
        (volatility * sqrtT));

  return {
    price,
    intrinsicValue: isCall
      ? Math.max(spot - strike, 0)
      : Math.max(strike - spot, 0),
    delta,
    gamma,
    theta: isCall ? callTheta : putTheta,
    vega,
    rho,
    vanna,
    vomma,
    charm,
    speed,
    color,
    d1,
    d2,
  };
}

export function expiryPayoff(
  optionType: OptionType,
  spotAtExpiry: number,
  strike: number,
): number {
  if (optionType === "call") {
    return Math.max(spotAtExpiry - strike, 0);
  }
  return Math.max(strike - spotAtExpiry, 0);
}
