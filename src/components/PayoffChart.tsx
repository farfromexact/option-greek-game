import type { MarketState, PortfolioLeg } from "../types";
import { payoffAtExpiry } from "../engine/portfolio";

type PayoffChartProps = {
  legs: PortfolioLeg[];
  market: MarketState;
};

export function PayoffChart({ legs, market }: PayoffChartProps) {
  const spots = Array.from({ length: 45 }, (_, index) => market.spot * (0.65 + index * 0.016));
  const values = spots.map((spot) => payoffAtExpiry(legs, market, spot));
  const min = Math.min(...values, -1);
  const max = Math.max(...values, 1);
  const points = values.map((value, index) => {
    const x = (index / (values.length - 1)) * 100;
    const y = 78 - ((value - min) / (max - min)) * 66;
    return `${x.toFixed(2)},${y.toFixed(2)}`;
  });
  const zeroY = 78 - ((0 - min) / (max - min)) * 66;
  const spotX = ((market.spot - spots[0]) / (spots[spots.length - 1] - spots[0])) * 100;

  return (
    <section className="panel chart-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Expiry shape</span>
          <h2>Payoff</h2>
        </div>
        <div className="mini-stat">
          <span>Range</span>
          <strong>{formatMoney(min)} / {formatMoney(max)}</strong>
        </div>
      </div>
      <svg viewBox="0 0 100 84" role="img" aria-label="Payoff at expiry chart">
        <line className="chart-axis" x1="0" y1={zeroY} x2="100" y2={zeroY} />
        <line className="spot-line" x1={spotX} x2={spotX} y1="8" y2="78" />
        <polyline className="payoff-line" points={points.join(" ")} fill="none" />
        <text x="2" y="10" className="chart-label">{formatMoney(max)}</text>
        <text x="2" y="82" className="chart-label">{formatMoney(min)}</text>
      </svg>
    </section>
  );
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(0)}`;
}
