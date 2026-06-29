import type { LevelConfig, PnlAttribution, PortfolioLeg, PortfolioSnapshot } from "../types";

export type LevelResult = {
  completed: boolean;
  score: number;
  reasons: string[];
};

export function evaluateLevel(
  level: LevelConfig,
  attribution: PnlAttribution,
  snapshot: PortfolioSnapshot,
  legs: PortfolioLeg[],
  steps: number,
): LevelResult {
  const reasons: string[] = [];
  let completed = true;

  if (level.success.minSteps !== undefined && steps < level.success.minSteps) {
    completed = false;
    reasons.push(`Run ${level.success.minSteps - steps} more steps.`);
  }
  if (level.success.minPnl !== undefined && attribution.totalPnl < level.success.minPnl) {
    completed = false;
    reasons.push(`Need P&L above ${level.success.minPnl.toFixed(1)}.`);
  }
  if (
    level.success.maxAbsDelta !== undefined &&
    Math.abs(snapshot.delta) > level.success.maxAbsDelta
  ) {
    completed = false;
    reasons.push(`Delta is outside the ${level.success.maxAbsDelta} limit.`);
  }
  if (
    level.success.maxDrawdown !== undefined &&
    attribution.maxDrawdown > level.success.maxDrawdown
  ) {
    completed = false;
    reasons.push(`Drawdown exceeded ${level.success.maxDrawdown}.`);
  }
  if (
    level.success.maxRiskViolations !== undefined &&
    attribution.riskViolations > level.success.maxRiskViolations
  ) {
    completed = false;
    reasons.push(`Risk violations exceeded ${level.success.maxRiskViolations}.`);
  }

  if (level.id === "build-call-spread" && !hasCallSpread(legs)) {
    completed = false;
    reasons.push("Build one long call and one higher-strike short call.");
  }
  if (level.id === "build-butterfly" && countUniqueOptionStrikes(legs) < 3) {
    completed = false;
    reasons.push("Use at least three option strikes.");
  }
  if (level.id === "gamma-scalping-intro" && !legs.some((leg) => leg.kind === "stock" && Math.abs(leg.quantity) > 0)) {
    completed = false;
    reasons.push("Use a stock hedge at least once.");
  }

  const riskPenalty = attribution.maxDrawdown * 1.6 + attribution.riskViolations * 18;
  const pnlScore = Math.max(0, 50 + attribution.totalPnl * 4);
  const greekBalance = Math.max(0, 25 - Math.abs(snapshot.delta) * 0.08 - Math.abs(snapshot.gamma) * 0.7);
  const structureBonus =
    (level.id === "build-call-spread" && hasCallSpread(legs) ? 15 : 0) +
    (level.id === "build-butterfly" && countUniqueOptionStrikes(legs) >= 3 ? 15 : 0);
  const score = Math.max(0, Math.min(100, pnlScore + greekBalance + structureBonus - riskPenalty));

  if (completed && reasons.length === 0) {
    reasons.push("Objective met. Replay attribution is ready.");
  }

  return {
    completed,
    score,
    reasons,
  };
}

function hasCallSpread(legs: PortfolioLeg[]): boolean {
  const longCalls = legs.filter(
    (leg) => leg.kind === "option" && leg.optionType === "call" && leg.side === "long",
  );
  const shortCalls = legs.filter(
    (leg) => leg.kind === "option" && leg.optionType === "call" && leg.side === "short",
  );
  return longCalls.some((longLeg) =>
    shortCalls.some((shortLeg) => shortLeg.kind === "option" && longLeg.kind === "option" && shortLeg.strike > longLeg.strike),
  );
}

function countUniqueOptionStrikes(legs: PortfolioLeg[]): number {
  return new Set(
    legs
      .filter((leg) => leg.kind === "option")
      .map((leg) => (leg.kind === "option" ? leg.strike : 0)),
  ).size;
}
