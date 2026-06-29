import type { GreekSet } from "../types";

export const zeroGreeks: GreekSet = {
  delta: 0,
  gamma: 0,
  theta: 0,
  vega: 0,
  rho: 0,
  vanna: 0,
  vomma: 0,
  charm: 0,
  speed: 0,
  color: 0,
};

export function scaleGreeks(greeks: GreekSet, scale: number): GreekSet {
  return {
    delta: greeks.delta * scale,
    gamma: greeks.gamma * scale,
    theta: greeks.theta * scale,
    vega: greeks.vega * scale,
    rho: greeks.rho * scale,
    vanna: greeks.vanna * scale,
    vomma: greeks.vomma * scale,
    charm: greeks.charm * scale,
    speed: greeks.speed * scale,
    color: greeks.color * scale,
  };
}

export function addGreeks(a: GreekSet, b: GreekSet): GreekSet {
  return {
    delta: a.delta + b.delta,
    gamma: a.gamma + b.gamma,
    theta: a.theta + b.theta,
    vega: a.vega + b.vega,
    rho: a.rho + b.rho,
    vanna: a.vanna + b.vanna,
    vomma: a.vomma + b.vomma,
    charm: a.charm + b.charm,
    speed: a.speed + b.speed,
    color: a.color + b.color,
  };
}

export function normalizeGreek(value: number, softLimit: number): number {
  if (!Number.isFinite(value) || softLimit <= 0) {
    return 0;
  }
  return Math.max(-1, Math.min(1, value / softLimit));
}

export function greekRiskScore(greeks: GreekSet): number {
  const delta = Math.abs(greeks.delta) / 120;
  const gamma = Math.abs(greeks.gamma) / 12;
  const theta = Math.abs(greeks.theta) / 450;
  const vega = Math.abs(greeks.vega) / 850;
  return Math.min(1, delta * 0.25 + gamma * 0.25 + theta * 0.2 + vega * 0.3);
}
