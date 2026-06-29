import type { LevelConfig, MarketState, PortfolioLeg, RegimeId } from "../types";
import { createMarket, seededNoise } from "../engine/marketSimulator";
import { createCashLeg, createOptionLeg, createStockLeg } from "../engine/portfolio";

const regimes: RegimeId[] = [
  "calm",
  "trending_up",
  "trending_down",
  "choppy",
  "volatility_spike",
  "earnings_event",
  "crash",
];

const missionFrames = [
  {
    title: "Theta Harvest",
    goal: "Collect time decay while keeping the tail loss inside the sponsor limit.",
    point: "Short premium is an insurance book, not passive income.",
  },
  {
    title: "Gamma Taxi",
    goal: "Run a long-Gamma book through realized movement and avoid death by fuel leak.",
    point: "Gamma pays only when realized movement beats the implied cost.",
  },
  {
    title: "Surface Misfit",
    goal: "Identify whether wing Vega or ATM Vega is carrying the real risk.",
    point: "Total Vega can hide the strike and tenor bucket that matters.",
  },
  {
    title: "Event Airbag",
    goal: "Position around an event without letting IV crush erase the whole thesis.",
    point: "Direction and volatility are separate bets.",
  },
  {
    title: "Inventory Run",
    goal: "Trade client flow, then clean up the Greeks left in inventory.",
    point: "The fill is the start of the problem, not the end.",
  },
  {
    title: "Crash Wing",
    goal: "Stay alive through a left-tail surface shock and poor liquidity.",
    point: "Skew, liquidity, and tail convexity arrive together.",
  },
];

export function generateProceduralLevels(count = 108): LevelConfig[] {
  return Array.from({ length: count }, (_, index) => {
    const seed = 1000 + index * 37;
    return generateChallengeLevel(`daily-${seed}`, index);
  });
}

export function generateChallengeLevel(seedText: string, ordinal = 0): LevelConfig {
  const seed = hashSeed(seedText);
  const regime = regimes[Math.abs(seed) % regimes.length];
  const frame = missionFrames[Math.abs(Math.floor(seededNoise(seed) * 1000)) % missionFrames.length];
  const difficulty = 1 + (Math.abs(seed) % 5);
  const spot = 92 + Math.abs(seed % 23);
  const initialMarket: MarketState = {
    ...createMarket(regime, spot),
    volatility: Math.max(0.14, Math.min(0.72, 0.18 + difficulty * 0.045 + Math.abs(seededNoise(seed + 5)) * 0.18)),
    skew: -0.03 - difficulty * 0.016 - Math.max(0, seededNoise(seed + 2)) * 0.05,
    termSlope: regime === "earnings_event" ? -0.18 : -0.04 + seededNoise(seed + 9) * 0.12,
    surfaceShock: seededNoise(seed + 13) * 0.12,
    eventRisk: Math.max(0.05, Math.min(0.95, difficulty * 0.12 + Math.abs(seededNoise(seed + 17)) * 0.4)),
    seed,
  };
  const initialPortfolio = buildSeedPortfolio(initialMarket, seed, frame.title);

  return {
    id: `seed-${seedText.replace(/[^a-zA-Z0-9-]/g, "-").slice(0, 32)}-${ordinal}`,
    title: `${frame.title} #${ordinal + 1}`,
    act: "Daily Seeds / Challenge Runs",
    theme: regime,
    initialMarket,
    initialPortfolio,
    goal: frame.goal,
    constraints: [
      `Run at least ${8 + difficulty * 2} steps.`,
      `Keep drawdown below ${(18 + difficulty * 5).toFixed(0)}.`,
      "Use debrief attribution to explain the result.",
    ],
    learningPoint: frame.point,
    success: {
      minPnl: -difficulty * 2,
      maxDrawdown: 18 + difficulty * 5,
      maxRiskViolations: Math.max(1, 4 - Math.floor(difficulty / 2)),
      minSteps: 8 + difficulty * 2,
    },
    failure: "The generated market exposed a risk bucket that was not priced or hedged.",
    review: "Replay the path and identify whether Delta, Gamma, Vega bucket, or transaction cost drove the score.",
    seed,
    difficulty,
    category: "procedural",
  };
}

export const janeStreetTrials: LevelConfig[] = [
  makeTrial("gamma-scalper-final", "Gamma Scalper Final", "choppy", [
    "Estimate whether realized volatility is beating implied volatility.",
    "Keep Delta near flat after each large spot move.",
  ]),
  makeTrial("vol-crush-ambush", "Vol Crush Ambush", "earnings_event", [
    "Show that direction can be right while Vega loses.",
    "Reduce long Vega before the event resolves.",
  ]),
  makeTrial("short-gamma-final", "Short Gamma Final", "crash", [
    "Survive jump risk with sizing or protection.",
    "Avoid more than two risk flags.",
  ]),
  makeTrial("surface-twist-final", "Surface Twist Final", "volatility_spike", [
    "Manage Vanna/Vomma and bucket Vega under a surface shock.",
    "Do not rely on total Vega neutrality.",
  ]),
  makeTrial("market-making-final", "Market Making Final", "choppy", [
    "Quote at least three customer flows.",
    "Keep inventory risk below the shield limit.",
  ]),
  makeTrial("probability-pit-final", "Probability Pit Final", "trending_down", [
    "Submit calibrated probabilities before running the path.",
    "Keep average Brier score below 0.28.",
  ]),
];

function makeTrial(
  id: string,
  title: string,
  regime: RegimeId,
  constraints: string[],
): LevelConfig {
  const initialMarket = {
    ...createMarket(regime, 100),
    volatility: regime === "earnings_event" ? 0.78 : regime === "crash" ? 0.38 : 0.28,
    seed: hashSeed(id),
  };
  return {
    id,
    title,
    act: "Jane Street Trials",
    theme: regime,
    initialMarket,
    initialPortfolio: buildSeedPortfolio(initialMarket, initialMarket.seed, title),
    goal: "Pass a compact final exam that combines pricing, path management, surface risk, and debrief discipline.",
    constraints,
    learningPoint: "Professional trading skill is risk explanation under pressure.",
    success: { minPnl: -8, maxDrawdown: 28, maxRiskViolations: 2, minSteps: 12 },
    failure: "The trial failed because the book could not explain or control the dominant risk.",
    review: "Compare the score, replay attribution, Vega buckets, calibration score, and inventory risk.",
    seed: initialMarket.seed,
    difficulty: 5,
    category: "trial",
  };
}

function buildSeedPortfolio(
  market: MarketState,
  seed: number,
  frameTitle: string,
): PortfolioLeg[] {
  const base: PortfolioLeg[] = [createCashLeg(0)];
  if (frameTitle.includes("Theta") || frameTitle.includes("Crash")) {
    base.push(
      createOptionLeg("short", "call", market, { strike: Math.round(market.spot * 1.1), expiryDays: 28, iv: market.volatility + 0.02 }),
      createOptionLeg("short", "put", market, { strike: Math.round(market.spot * 0.9), expiryDays: 28, iv: market.volatility + 0.04 }),
    );
  } else if (frameTitle.includes("Gamma")) {
    base.push(
      createOptionLeg("long", "call", market, { strike: Math.round(market.spot), expiryDays: 21, iv: market.volatility }),
      createOptionLeg("long", "put", market, { strike: Math.round(market.spot), expiryDays: 21, iv: market.volatility }),
    );
  } else if (frameTitle.includes("Inventory") || frameTitle.includes("Market Making")) {
    base.push(createStockLeg(Math.round(seededNoise(seed + 4) * 20)));
  } else {
    base.push(
      createOptionLeg("long", "put", market, { strike: Math.round(market.spot * 0.92), expiryDays: 45, iv: market.volatility + 0.03 }),
      createOptionLeg("short", "call", market, { strike: Math.round(market.spot * 1.08), expiryDays: 30, iv: market.volatility }),
    );
  }
  return base;
}

function hashSeed(seedText: string): number {
  let hash = 2166136261;
  for (const char of seedText) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return Math.abs(hash >>> 0);
}
