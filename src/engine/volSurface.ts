import type { MarketState, PortfolioLeg } from "../types";
import { optionSurfaceVolatility, priceOptionLeg } from "./portfolio";

export type SurfacePoint = {
  strike: number;
  expiryDays: number;
  moneyness: number;
  volatility: number;
  relativeValue: number;
};

export type VegaBucket = {
  id: string;
  label: string;
  vega: number;
  exposure: number;
};

export const surfaceMoneyness = [0.8, 0.9, 0.97, 1, 1.03, 1.1, 1.2];
export const surfaceExpiries = [7, 14, 30, 60, 90, 180];

export function buildVolSurface(market: MarketState): SurfacePoint[] {
  return surfaceExpiries.flatMap((expiryDays) =>
    surfaceMoneyness.map((moneyness) => {
      const strike = Math.round(market.spot * moneyness);
      const dummyLeg = {
        id: "surface",
        kind: "option" as const,
        side: "long" as const,
        optionType: moneyness >= 1 ? "call" as const : "put" as const,
        strike,
        expiryDays,
        iv: market.volatility,
        quantity: 1,
      };
      const volatility = optionSurfaceVolatility(dummyLeg, market);
      const termAnchor = market.volatility + market.termSlope * (expiryDays / 365 - 30 / 365);
      return {
        strike,
        expiryDays,
        moneyness,
        volatility,
        relativeValue: volatility - termAnchor,
      };
    }),
  );
}

export function calculateVegaBuckets(
  legs: PortfolioLeg[],
  market: MarketState,
): VegaBucket[] {
  const buckets: VegaBucket[] = [
    { id: "front-left", label: "Front left wing", vega: 0, exposure: 0 },
    { id: "front-atm", label: "Front ATM", vega: 0, exposure: 0 },
    { id: "front-right", label: "Front right wing", vega: 0, exposure: 0 },
    { id: "back-left", label: "Back left wing", vega: 0, exposure: 0 },
    { id: "back-atm", label: "Back ATM", vega: 0, exposure: 0 },
    { id: "back-right", label: "Back right wing", vega: 0, exposure: 0 },
  ];

  for (const leg of legs) {
    if (leg.kind !== "option") {
      continue;
    }
    const moneyness = leg.strike / Math.max(1, market.spot);
    const tenor = leg.expiryDays <= 45 ? "front" : "back";
    const wing = moneyness < 0.95 ? "left" : moneyness > 1.05 ? "right" : "atm";
    const id = `${tenor}-${wing}`;
    const bucket = buckets.find((item) => item.id === id);
    if (!bucket) {
      continue;
    }
    const priced = priceOptionLeg(leg, market);
    bucket.vega += priced.greeks.vega;
    bucket.exposure += priced.value;
  }

  return buckets;
}

export function surfaceRiskNarrative(buckets: VegaBucket[], market: MarketState): string {
  const dominant = [...buckets].sort((a, b) => Math.abs(b.vega) - Math.abs(a.vega))[0];
  if (!dominant || Math.abs(dominant.vega) < 1) {
    return "Vega is broadly flat. The next surface move matters less than Delta and Gamma.";
  }
  const direction = dominant.vega > 0 ? "long" : "short";
  const surface = market.surfaceShock > 0.08 ? "a wing-rich shock" : market.surfaceShock < -0.08 ? "a vol-crush shock" : "a parallel surface drift";
  return `Largest bucket is ${direction} ${dominant.label}; ${surface} will dominate the debrief.`;
}
