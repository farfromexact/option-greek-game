export type OptionType = "call" | "put";
export type Side = "long" | "short";
export type RegimeId =
  | "calm"
  | "trending_up"
  | "trending_down"
  | "choppy"
  | "volatility_spike"
  | "earnings_event"
  | "crash";

export type CustomerType =
  | "retail"
  | "hedge_fund"
  | "vol_arb"
  | "corporate"
  | "event_trader"
  | "panic";

export type OptionLeg = {
  id: string;
  kind: "option";
  side: Side;
  optionType: OptionType;
  strike: number;
  expiryDays: number;
  iv: number;
  quantity: number;
};

export type StockLeg = {
  id: string;
  kind: "stock";
  quantity: number;
};

export type CashLeg = {
  id: string;
  kind: "cash";
  amount: number;
};

export type PortfolioLeg = OptionLeg | StockLeg | CashLeg;

export type MarketState = {
  spot: number;
  volatility: number;
  riskFreeRate: number;
  day: number;
  regime: RegimeId;
  liquidity: number;
  eventRisk: number;
  skew: number;
  termSlope: number;
  surfaceShock: number;
  seed: number;
};

export type GreekSet = {
  delta: number;
  gamma: number;
  theta: number;
  vega: number;
  rho: number;
  vanna: number;
  vomma: number;
  charm: number;
  speed: number;
  color: number;
};

export type PortfolioSnapshot = GreekSet & {
  value: number;
  intrinsicValue: number;
  maxLossEstimate: number;
  marginEstimate: number;
};

export type ReplayRecord = {
  step: number;
  market: MarketState;
  portfolio: PortfolioSnapshot;
  pnl: number;
  action: string;
  transactionCost: number;
};

export type LeaderboardEntry = {
  id: string;
  levelId: string;
  levelTitle: string;
  score: number;
  pnl: number;
  drawdown: number;
  riskViolations: number;
  seed: number;
  createdAt: string;
};

export type CalibrationQuestion = {
  id: string;
  label: string;
  probability: number;
  outcome: boolean;
  brier: number;
};

export type CalibrationResult = {
  id: string;
  levelId: string;
  createdAt: string;
  averageBrier: number;
  questions: CalibrationQuestion[];
};

export type LevelConfig = {
  id: string;
  title: string;
  act: string;
  theme: RegimeId;
  initialMarket: MarketState;
  initialPortfolio: PortfolioLeg[];
  goal: string;
  constraints: string[];
  learningPoint: string;
  success: {
    minPnl?: number;
    maxAbsDelta?: number;
    maxDrawdown?: number;
    maxRiskViolations?: number;
    minSteps?: number;
  };
  failure: string;
  review: string;
  seed?: number;
  difficulty?: number;
  category?: "core" | "procedural" | "trial" | "challenge";
};

export type PnlAttribution = {
  totalPnl: number;
  deltaPnl: number;
  gammaPnl: number;
  thetaPnl: number;
  vegaPnl: number;
  transactionCost: number;
  residual: number;
  maxDrawdown: number;
  riskViolations: number;
  realizedVol: number;
  impliedVol: number;
  gammaScalpEdge: number;
};
