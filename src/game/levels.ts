import type { LevelConfig, MarketState, PortfolioLeg, RegimeId } from "../types";
import { createMarket } from "../engine/marketSimulator";
import { createCashLeg, createOptionLeg, createStockLeg } from "../engine/portfolio";
import { generateProceduralLevels, janeStreetTrials } from "./procedural";

function market(regime: RegimeId, overrides: Partial<MarketState> = {}): MarketState {
  return {
    ...createMarket(regime, overrides.spot ?? 100),
    ...overrides,
  };
}

function emptyPortfolio(): PortfolioLeg[] {
  return [createCashLeg(0)];
}

function longCallLevel(marketState: MarketState): PortfolioLeg[] {
  return [
    createCashLeg(0),
    createOptionLeg("long", "call", marketState, {
      strike: 103,
      expiryDays: 28,
      iv: marketState.volatility,
    }),
  ];
}

function shortStrangle(marketState: MarketState): PortfolioLeg[] {
  return [
    createCashLeg(0),
    createOptionLeg("short", "call", marketState, {
      strike: 112,
      expiryDays: 24,
      iv: marketState.volatility + 0.02,
    }),
    createOptionLeg("short", "put", marketState, {
      strike: 88,
      expiryDays: 24,
      iv: marketState.volatility + 0.04,
    }),
  ];
}

const coreLevels: LevelConfig[] = [
  {
    id: "delta-wind",
    title: "Delta Wind",
    act: "Greek Sense Lab",
    theme: "trending_up",
    initialMarket: market("trending_up", { spot: 100, volatility: 0.2 }),
    initialPortfolio: emptyPortfolio(),
    goal: "Shape directional exposure, then survive a slow rightward price wind.",
    constraints: ["Keep absolute delta under 80 after the fifth step.", "Finish with positive P&L."],
    learningPoint: "Delta is the first push from spot movement.",
    success: { minPnl: 1, maxAbsDelta: 80, minSteps: 8 },
    failure: "The portfolio drifted with the wind instead of being driven deliberately.",
    review: "Review whether the final P&L came from intended Delta or accidental exposure.",
  },
  {
    id: "gamma-spring",
    title: "Gamma Spring",
    act: "Greek Sense Lab",
    theme: "choppy",
    initialMarket: market("choppy", { spot: 100, volatility: 0.24 }),
    initialPortfolio: [
      createCashLeg(0),
      createOptionLeg("long", "call", createMarket("choppy"), { strike: 100, expiryDays: 18, iv: 0.24 }),
      createOptionLeg("long", "put", createMarket("choppy"), { strike: 100, expiryDays: 18, iv: 0.24 }),
    ],
    goal: "Use long Gamma to absorb a pinball market without letting time decay dominate.",
    constraints: ["Run at least 10 steps.", "Avoid more than 2 risk violations."],
    learningPoint: "Gamma changes Delta; movement helps long Gamma, but Theta is the fuel leak.",
    success: { minPnl: -2, maxRiskViolations: 2, minSteps: 10 },
    failure: "The spring was too expensive or hedged too late.",
    review: "Separate realized movement gains from Theta cost.",
  },
  {
    id: "theta-desert",
    title: "Theta Desert",
    act: "Greek Sense Lab",
    theme: "calm",
    initialMarket: market("calm", { spot: 100, volatility: 0.2 }),
    initialPortfolio: shortStrangle(market("calm", { spot: 100, volatility: 0.2 })),
    goal: "Harvest quiet-market Theta while keeping the tail shield alive.",
    constraints: ["Positive P&L after 12 steps.", "No more than 1 risk violation."],
    learningPoint: "Short premium earns rent while selling jump insurance.",
    success: { minPnl: 2, maxRiskViolations: 1, minSteps: 12 },
    failure: "Theta income looked stable, but unbounded convexity created hidden risk.",
    review: "Check whether the strategy was paid enough for the tail exposure.",
  },
  {
    id: "vega-storm",
    title: "Vega Storm",
    act: "Greek Sense Lab",
    theme: "volatility_spike",
    initialMarket: market("volatility_spike", { spot: 100, volatility: 0.24 }),
    initialPortfolio: [
      createCashLeg(0),
      createOptionLeg("long", "call", createMarket("volatility_spike"), { strike: 102, expiryDays: 35, iv: 0.24 }),
      createOptionLeg("long", "put", createMarket("volatility_spike"), { strike: 98, expiryDays: 35, iv: 0.24 }),
    ],
    goal: "Ride a rising-volatility weather system without confusing Vega with direction.",
    constraints: ["Run 8 steps.", "Do not finish with absolute delta above 90."],
    learningPoint: "Vega is storm sensitivity. The portfolio can win or lose before spot picks a side.",
    success: { minPnl: 1, maxAbsDelta: 90, minSteps: 8 },
    failure: "The storm was visible, but the portfolio had the wrong weather sensitivity.",
    review: "Attribute how much came from IV expansion versus Delta.",
  },
  {
    id: "direction-right-lost",
    title: "Direction Right But Still Lost",
    act: "Strategy Forge",
    theme: "earnings_event",
    initialMarket: market("earnings_event", { spot: 100, volatility: 0.78, eventRisk: 0.9 }),
    initialPortfolio: longCallLevel(market("earnings_event", { spot: 100, volatility: 0.78 })),
    goal: "Experience an earnings IV crush and repair a naive long-call thesis.",
    constraints: ["Run at least 7 steps.", "Reduce Vega or hedge before the event resolves."],
    learningPoint: "A correct direction call can lose when implied volatility collapses.",
    success: { minPnl: -6, maxRiskViolations: 2, minSteps: 7 },
    failure: "The spot move helped, but the collapsing airbag erased the thesis.",
    review: "Compare Delta P&L with Vega P&L after the event.",
  },
  {
    id: "short-gamma-nightmare",
    title: "Short Gamma Nightmare",
    act: "Jane Street Trials",
    theme: "crash",
    initialMarket: market("crash", { spot: 100, volatility: 0.28 }),
    initialPortfolio: shortStrangle(market("crash", { spot: 100, volatility: 0.28 })),
    goal: "Manage a high-win-rate short premium book through a jump.",
    constraints: ["Cut risk before drawdown exceeds 20.", "Run 6 steps."],
    learningPoint: "Short Gamma looks calm until path dependence becomes the whole game.",
    success: { minPnl: -18, maxDrawdown: 22, minSteps: 6 },
    failure: "Small daily income was not enough compensation for the jump.",
    review: "Identify when position sizing or protection would have changed the outcome.",
  },
  {
    id: "gamma-scalping-intro",
    title: "Gamma Scalping Intro",
    act: "Strategy Forge",
    theme: "choppy",
    initialMarket: market("choppy", { spot: 100, volatility: 0.22 }),
    initialPortfolio: [
      createCashLeg(0),
      createOptionLeg("long", "call", createMarket("choppy"), { strike: 100, expiryDays: 21, iv: 0.22 }),
      createOptionLeg("long", "put", createMarket("choppy"), { strike: 100, expiryDays: 21, iv: 0.22 }),
    ],
    goal: "Keep re-centering Delta and learn why realized volatility pays the scalper.",
    constraints: ["Use Delta hedge at least once.", "Run 10 steps."],
    learningPoint: "Long Gamma plus disciplined hedge is a realized-volatility trade.",
    success: { minPnl: -3, maxAbsDelta: 60, minSteps: 10 },
    failure: "The book had Gamma, but it was not actively steered.",
    review: "Find the hedge that reduced drift without over-trading.",
  },
  {
    id: "vol-crush-event",
    title: "Vol Crush Event",
    act: "Market Weather Campaign",
    theme: "earnings_event",
    initialMarket: market("earnings_event", { spot: 100, volatility: 0.82 }),
    initialPortfolio: [
      createCashLeg(0),
      createOptionLeg("short", "call", createMarket("earnings_event"), { strike: 112, expiryDays: 12, iv: 0.82 }),
      createOptionLeg("short", "put", createMarket("earnings_event"), { strike: 88, expiryDays: 12, iv: 0.84 }),
    ],
    goal: "Sell rich event volatility while respecting the jump distribution.",
    constraints: ["Keep drawdown below 30.", "Run 8 steps."],
    learningPoint: "Short event vol can work, but only if the jump risk is sized.",
    success: { minPnl: -5, maxDrawdown: 30, minSteps: 8 },
    failure: "The IV crush was real, but the jump was too large for the inventory.",
    review: "Assess whether the premium was worth the jump tail.",
  },
  {
    id: "build-call-spread",
    title: "Build a Call Spread",
    act: "Strategy Forge",
    theme: "trending_up",
    initialMarket: market("trending_up", { spot: 100, volatility: 0.22 }),
    initialPortfolio: emptyPortfolio(),
    goal: "Create capped upside with lower premium than a naked long call.",
    constraints: ["Use at least one long call and one short higher-strike call.", "Run 7 steps."],
    learningPoint: "A call spread turns a direction view into a bounded payoff shape.",
    success: { minPnl: -3, maxAbsDelta: 95, minSteps: 7 },
    failure: "The structure was either too expensive or left the upside undefined.",
    review: "Inspect how selling the upper strike changed premium, Delta, and max gain.",
  },
  {
    id: "build-butterfly",
    title: "Build a Butterfly",
    act: "Strategy Forge",
    theme: "calm",
    initialMarket: market("calm", { spot: 100, volatility: 0.2 }),
    initialPortfolio: emptyPortfolio(),
    goal: "Build a narrow target-zone payoff around 100 with defined loss on both wings.",
    constraints: ["Use at least three strikes.", "Run 9 steps."],
    learningPoint: "A butterfly is a price trap: cheap, convex, and very location-sensitive.",
    success: { minPnl: -4, maxRiskViolations: 2, minSteps: 9 },
    failure: "The payoff did not concentrate risk around the target zone.",
    review: "Look at why the body strike matters more than the name of the structure.",
  },
  {
    id: "iron-condor-survival",
    title: "Iron Condor Survival",
    act: "Market Weather Campaign",
    theme: "calm",
    initialMarket: market("calm", { spot: 100, volatility: 0.26 }),
    initialPortfolio: [
      createCashLeg(0),
      createOptionLeg("short", "call", createMarket("calm"), { strike: 110, expiryDays: 28, iv: 0.26 }),
      createOptionLeg("long", "call", createMarket("calm"), { strike: 118, expiryDays: 28, iv: 0.26 }),
      createOptionLeg("short", "put", createMarket("calm"), { strike: 90, expiryDays: 28, iv: 0.28 }),
      createOptionLeg("long", "put", createMarket("calm"), { strike: 82, expiryDays: 28, iv: 0.3 }),
    ],
    goal: "Survive a short-vol income run with wings that cap the disaster.",
    constraints: ["Run 14 steps.", "Keep drawdown under 18."],
    learningPoint: "Defined-risk short volatility is still a risk budget decision.",
    success: { minPnl: 1, maxDrawdown: 18, minSteps: 14 },
    failure: "The income engine was not balanced against the wing risk.",
    review: "Check whether the wings were protection or just decoration.",
  },
  {
    id: "market-maker-intro",
    title: "Market Maker Intro",
    act: "Market Maker Arena",
    theme: "choppy",
    initialMarket: market("choppy", { spot: 100, volatility: 0.25 }),
    initialPortfolio: [createCashLeg(0), createStockLeg(0)],
    goal: "Quote client flow, get filled selectively, and keep inventory Greeks manageable.",
    constraints: ["Complete at least three quotes.", "Avoid more than two risk violations."],
    learningPoint: "The spread is compensation for inventory risk and information asymmetry.",
    success: { minPnl: -6, maxRiskViolations: 2, minSteps: 6 },
    failure: "Quotes were either too tight for toxic flow or too wide to earn edge.",
    review: "Compare quote width, fill quality, and the risk left after each trade.",
  },
];

export const levels: LevelConfig[] = [
  ...coreLevels,
  ...janeStreetTrials,
  ...generateProceduralLevels(108),
].map((level) => ({
  category: "core" as const,
  difficulty: 1,
  ...level,
}));

export function getLevel(id: string): LevelConfig {
  return levels.find((level) => level.id === id) ?? levels[0];
}
