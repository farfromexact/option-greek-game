import { Radio } from "lucide-react";
import { useMemo, useState } from "react";
import type { LevelConfig, PnlAttribution, ReplayRecord } from "../types";
import type { LevelResult } from "../game/scoring";

type ReplayPanelProps = {
  attribution: PnlAttribution;
  records: ReplayRecord[];
  level: LevelConfig;
  result: LevelResult;
};

export function ReplayPanel({ attribution, records, level, result }: ReplayPanelProps) {
  const [selectedStep, setSelectedStep] = useState(records.length - 1);
  const clampedStep = Math.min(records.length - 1, selectedStep);
  const selected = records[clampedStep] ?? records[records.length - 1];
  const latest = records[records.length - 1];
  const volRead = useMemo(
    () => ({
      realized: (attribution.realizedVol * 100).toFixed(1),
      implied: (attribution.impliedVol * 100).toFixed(1),
      edge: (attribution.gammaScalpEdge * 100).toFixed(1),
    }),
    [attribution.gammaScalpEdge, attribution.impliedVol, attribution.realizedVol],
  );
  return (
    <section className="panel replay-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Debrief</span>
          <h2>P&L attribution</h2>
        </div>
        <div className={`status-pill ${result.completed ? "ok" : "warn"}`}>
          {result.completed ? "Cleared" : "Open"}
        </div>
      </div>

      <div className="attribution-grid">
        <Metric label="Total" value={attribution.totalPnl} />
        <Metric label="Delta" value={attribution.deltaPnl} />
        <Metric label="Gamma" value={attribution.gammaPnl} />
        <Metric label="Theta" value={attribution.thetaPnl} />
        <Metric label="Vega" value={attribution.vegaPnl} />
        <Metric label="Costs" value={-attribution.transactionCost} />
      </div>

      <div className="timeline">
        {records.map((record, index) => (
          <span
            key={`${record.step}-${record.action}`}
            className={`${record.pnl >= 0 ? "gain" : "loss"} ${index === clampedStep ? "selected" : ""}`}
            style={{
              height: `${Math.max(8, Math.min(44, Math.abs(record.pnl) + 8))}px`,
            }}
            title={`${record.step}: ${record.action} ${record.pnl.toFixed(2)}`}
          />
        ))}
      </div>

      <div className="replay-scrubber">
        <label>
          Replay step
          <input
            type="range"
            min="0"
            max={Math.max(0, records.length - 1)}
            value={clampedStep}
            onChange={(event) => setSelectedStep(Number(event.target.value))}
          />
        </label>
        {selected && (
          <div>
            <strong>#{selected.step} {selected.action}</strong>
            <span>S {selected.market.spot.toFixed(2)} | IV {(selected.market.volatility * 100).toFixed(1)}% | P&L {selected.pnl.toFixed(2)}</span>
          </div>
        )}
      </div>

      <div className="replay-copy">
        <Radio size={17} />
        <p>{result.completed ? level.review : level.failure}</p>
      </div>

      {latest && (
        <div className="latest-action">
          <span>Last action</span>
          <strong>{latest.action}</strong>
        </div>
      )}

      <div className="risk-summary">
        <span>Max DD {attribution.maxDrawdown.toFixed(2)}</span>
        <span>Risk flags {attribution.riskViolations}</span>
        <span>Residual {attribution.residual.toFixed(2)}</span>
        <span>RV {volRead.realized}%</span>
        <span>IV {volRead.implied}%</span>
        <span>RV-IV {volRead.edge}%</span>
      </div>
    </section>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className={value >= 0 ? "metric gain" : "metric loss"}>
      <span>{label}</span>
      <strong>{formatMoney(value)}</strong>
    </div>
  );
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(2)}`;
}
