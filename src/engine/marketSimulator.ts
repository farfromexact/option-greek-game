import type { MarketState, RegimeId } from "../types";

export const regimeLabels: Record<RegimeId, string> = {
  calm: "Calm Lake",
  trending_up: "Slow Trend Up",
  trending_down: "Slow Trend Down",
  choppy: "Pinball Market",
  volatility_spike: "Vega Storm",
  earnings_event: "Volcano Event",
  crash: "Crash Storm",
};

type RegimeProfile = {
  drift: number;
  shock: number;
  volDrift: number;
  volShock: number;
  liquidity: number;
  eventRisk: number;
  skew: number;
};

const profiles: Record<RegimeId, RegimeProfile> = {
  calm: {
    drift: 0.0002,
    shock: 0.004,
    volDrift: -0.002,
    volShock: 0.006,
    liquidity: 0.86,
    eventRisk: 0.08,
    skew: -0.05,
  },
  trending_up: {
    drift: 0.006,
    shock: 0.011,
    volDrift: -0.001,
    volShock: 0.008,
    liquidity: 0.76,
    eventRisk: 0.18,
    skew: -0.04,
  },
  trending_down: {
    drift: -0.005,
    shock: 0.012,
    volDrift: 0.002,
    volShock: 0.01,
    liquidity: 0.72,
    eventRisk: 0.24,
    skew: -0.09,
  },
  choppy: {
    drift: 0,
    shock: 0.018,
    volDrift: 0.0005,
    volShock: 0.011,
    liquidity: 0.68,
    eventRisk: 0.2,
    skew: -0.06,
  },
  volatility_spike: {
    drift: -0.001,
    shock: 0.016,
    volDrift: 0.018,
    volShock: 0.025,
    liquidity: 0.55,
    eventRisk: 0.42,
    skew: -0.11,
  },
  earnings_event: {
    drift: 0.001,
    shock: 0.026,
    volDrift: -0.012,
    volShock: 0.035,
    liquidity: 0.6,
    eventRisk: 0.75,
    skew: -0.03,
  },
  crash: {
    drift: -0.017,
    shock: 0.032,
    volDrift: 0.026,
    volShock: 0.032,
    liquidity: 0.35,
    eventRisk: 0.88,
    skew: -0.18,
  },
};

export function seededNoise(seed: number): number {
  const x = Math.sin(seed * 12.9898) * 43758.5453;
  return (x - Math.floor(x)) * 2 - 1;
}

export function createMarket(regime: RegimeId, spot = 100): MarketState {
  const profile = profiles[regime];
  return {
    spot,
    volatility: regime === "calm" ? 0.18 : regime === "crash" ? 0.42 : 0.28,
    riskFreeRate: 0.04,
    day: 0,
    regime,
    liquidity: profile.liquidity,
    eventRisk: profile.eventRisk,
    skew: profile.skew,
    termSlope: regime === "earnings_event" ? -0.16 : regime === "calm" ? 0.03 : 0.08,
    surfaceShock: 0,
    seed: Math.round(spot * 100 + regime.length * 17),
  };
}

export function simulateMarketStep(
  market: MarketState,
  forcedRegime?: RegimeId,
): MarketState {
  const regime = forcedRegime ?? market.regime;
  const profile = profiles[regime];
  const wave = Math.sin((market.day + 1) * 0.83);
  const noise = seededNoise((market.day + 1) * (market.spot + 17));
  const jump =
    regime === "earnings_event" && market.day === 4
      ? seededNoise(market.spot) * 0.075
      : regime === "crash" && market.day === 2
        ? -0.08
        : 0;
  const choppyMeanRevert =
    regime === "choppy" ? -Math.sign(market.spot - 100) * 0.006 : 0;
  const returnPct =
    profile.drift + wave * profile.shock * 0.35 + noise * profile.shock + jump + choppyMeanRevert;
  const nextSpot = Math.max(1, market.spot * (1 + returnPct));
  const eventVolCrush =
    regime === "earnings_event" && market.day >= 5 ? -0.035 : 0;
  const volMove =
    profile.volDrift +
    Math.abs(noise) * profile.volShock -
    (regime === "calm" ? 0.004 : 0) +
    eventVolCrush;
  const volatility = Math.max(0.06, Math.min(1.2, market.volatility + volMove));
  const surfaceShock =
    regime === "earnings_event" && market.day === 5
      ? -0.2
      : regime === "crash"
        ? Math.min(0.45, market.surfaceShock + 0.06 + Math.abs(returnPct))
        : Math.max(-0.25, market.surfaceShock * 0.72 + volMove * 0.55);
  const termSlope =
    regime === "earnings_event"
      ? Math.max(-0.35, market.termSlope - 0.025)
      : regime === "crash"
        ? Math.min(0.28, market.termSlope + 0.035)
        : market.termSlope * 0.92 + profile.volDrift * 0.35;
  const liquidity = Math.max(
    0.15,
    Math.min(0.95, profile.liquidity - Math.abs(returnPct) * 2.4 + seededNoise(market.day + 5) * 0.04),
  );

  return {
    ...market,
    day: market.day + 1,
    spot: nextSpot,
    volatility,
    regime,
    liquidity,
    eventRisk: Math.max(0, Math.min(1, profile.eventRisk + Math.abs(returnPct) * 3)),
    skew: profile.skew - Math.max(0, 100 - nextSpot) * 0.002,
    termSlope,
    surfaceShock,
    seed: market.seed + 1,
  };
}

export function transactionCostForNotional(
  notional: number,
  market: MarketState,
): number {
  const friction = 0.002 + (1 - market.liquidity) * 0.012;
  return Math.abs(notional) * friction;
}
