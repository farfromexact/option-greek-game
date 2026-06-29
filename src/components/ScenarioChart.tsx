import type { MarketState, PortfolioLeg } from "../types";
import { scenarioPnl } from "../engine/portfolio";

type ScenarioChartProps = {
  legs: PortfolioLeg[];
  market: MarketState;
};

const spotShifts = [-18, -12, -6, 0, 6, 12, 18];
const volShifts = [0.12, 0.06, 0, -0.06, -0.12];

export function ScenarioChart({ legs, market }: ScenarioChartProps) {
  const cells = volShifts.flatMap((volShift, row) =>
    spotShifts.map((spotShift, col) => {
      const pnl = scenarioPnl(legs, market, spotShift, volShift, 7);
      return { row, col, pnl, spotShift, volShift };
    }),
  );
  const absMax = Math.max(1, ...cells.map((cell) => Math.abs(cell.pnl)));
  const linePoints = spotShifts.map((spotShift, index) => {
    const pnl = scenarioPnl(legs, market, spotShift, 0, 7);
    const x = 8 + index * 14;
    const y = 74 - ((pnl + absMax) / (absMax * 2)) * 58;
    return `${x},${y}`;
  });

  return (
    <section className="panel chart-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Seven-day stress</span>
          <h2>Scenario P&L</h2>
        </div>
      </div>
      <div className="scenario-wrap">
        <svg viewBox="0 0 108 84" role="img" aria-label="Scenario P&L chart">
          <line className="chart-axis" x1="4" y1="45" x2="104" y2="45" />
          <polyline className="scenario-line" points={linePoints.join(" ")} fill="none" />
          {spotShifts.map((shift, index) => (
            <text key={shift} x={8 + index * 14} y="82" className="chart-label" textAnchor="middle">
              {shift > 0 ? "+" : ""}{shift}
            </text>
          ))}
        </svg>
        <div className="heat-grid">
          {cells.map((cell) => (
            <span
              key={`${cell.row}-${cell.col}`}
              className={cell.pnl >= 0 ? "heat gain" : "heat loss"}
              style={{ opacity: 0.25 + Math.min(0.75, Math.abs(cell.pnl) / absMax) }}
              title={`Spot ${cell.spotShift}, IV ${Math.round(cell.volShift * 100)}: ${cell.pnl.toFixed(2)}`}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
