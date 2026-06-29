import type { PnlAttribution, ReplayRecord } from "../types";

export function calculatePnlAttribution(records: ReplayRecord[]): PnlAttribution {
  if (records.length === 0) {
    return {
      totalPnl: 0,
      deltaPnl: 0,
      gammaPnl: 0,
      thetaPnl: 0,
      vegaPnl: 0,
      transactionCost: 0,
      residual: 0,
      maxDrawdown: 0,
      riskViolations: 0,
      realizedVol: 0,
      impliedVol: 0,
      gammaScalpEdge: 0,
    };
  }

  let deltaPnl = 0;
  let gammaPnl = 0;
  let thetaPnl = 0;
  let vegaPnl = 0;
  let transactionCost = records[0].transactionCost;
  let highWatermark = records[0].pnl;
  let maxDrawdown = 0;
  let riskViolations = 0;

  for (let i = 1; i < records.length; i += 1) {
    const prev = records[i - 1];
    const current = records[i];
    const dSpot = current.market.spot - prev.market.spot;
    const dVol = current.market.volatility - prev.market.volatility;
    const dTimeYears = 1 / 365;
    deltaPnl += prev.portfolio.delta * dSpot;
    gammaPnl += 0.5 * prev.portfolio.gamma * dSpot * dSpot;
    thetaPnl += prev.portfolio.theta * dTimeYears;
    vegaPnl += prev.portfolio.vega * dVol;
    transactionCost += current.transactionCost;
    highWatermark = Math.max(highWatermark, current.pnl);
    maxDrawdown = Math.max(maxDrawdown, highWatermark - current.pnl);

    const riskLoad =
      Math.abs(current.portfolio.delta) / 120 +
      Math.abs(current.portfolio.gamma) / 12 +
      Math.abs(current.portfolio.vega) / 900 +
      Math.max(0, -current.pnl) / 45;
    if (riskLoad > 2.25) {
      riskViolations += 1;
    }
  }

  const totalPnl = records[records.length - 1].pnl;
  const explained = deltaPnl + gammaPnl + thetaPnl + vegaPnl - transactionCost;
  const realizedVol = estimateRealizedVol(records);
  const impliedVol = records[records.length - 1].market.volatility;

  return {
    totalPnl,
    deltaPnl,
    gammaPnl,
    thetaPnl,
    vegaPnl,
    transactionCost,
    residual: totalPnl - explained,
    maxDrawdown,
    riskViolations,
    realizedVol,
    impliedVol,
    gammaScalpEdge: realizedVol - impliedVol,
  };
}

function estimateRealizedVol(records: ReplayRecord[]): number {
  const returns: number[] = [];
  for (let i = 1; i < records.length; i += 1) {
    const prev = records[i - 1].market.spot;
    const current = records[i].market.spot;
    if (prev > 0 && current > 0) {
      returns.push(Math.log(current / prev));
    }
  }
  if (returns.length < 2) {
    return 0;
  }
  const mean = returns.reduce((total, value) => total + value, 0) / returns.length;
  const variance =
    returns.reduce((total, value) => total + Math.pow(value - mean, 2), 0) /
    Math.max(1, returns.length - 1);
  return Math.sqrt(variance) * Math.sqrt(252);
}
