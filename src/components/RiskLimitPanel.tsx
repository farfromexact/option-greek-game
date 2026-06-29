import { AlertTriangle, Gauge, ShieldCheck } from "lucide-react";
import type { ReactNode } from "react";
import type { MarketState, PnlAttribution, PortfolioSnapshot } from "../types";
import { greekRiskScore } from "../engine/greeks";

type RiskLimitPanelProps = {
  market: MarketState;
  snapshot: PortfolioSnapshot;
  attribution: PnlAttribution;
};

export function RiskLimitPanel({ market, snapshot, attribution }: RiskLimitPanelProps) {
  const usage = greekRiskScore(snapshot);
  const drawdownUsage = Math.min(1, attribution.maxDrawdown / 35);
  const liquidityStress = Math.min(1, 1 - market.liquidity + market.eventRisk * 0.35);
  const totalUsage = Math.min(1, usage * 0.55 + drawdownUsage * 0.25 + liquidityStress * 0.2);

  return (
    <section className="panel risk-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Sponsor limits</span>
          <h2>Risk shield</h2>
        </div>
        <div className={`status-pill ${totalUsage > 0.75 ? "hot" : totalUsage > 0.48 ? "warn" : "ok"}`}>
          {(totalUsage * 100).toFixed(0)}%
        </div>
      </div>

      <div className="risk-bars">
        <RiskBar label="Greek load" value={usage} icon={<Gauge size={16} />} />
        <RiskBar label="Drawdown" value={drawdownUsage} icon={<AlertTriangle size={16} />} />
        <RiskBar label="Liquidity/event" value={liquidityStress} icon={<ShieldCheck size={16} />} />
      </div>

      <div className="advanced-greek-grid">
        <span>Vanna <strong>{snapshot.vanna.toFixed(2)}</strong></span>
        <span>Vomma <strong>{snapshot.vomma.toFixed(2)}</strong></span>
        <span>Charm <strong>{snapshot.charm.toFixed(2)}</strong></span>
        <span>Speed <strong>{snapshot.speed.toFixed(3)}</strong></span>
        <span>Color <strong>{snapshot.color.toFixed(3)}</strong></span>
        <span>Margin <strong>{snapshot.marginEstimate.toFixed(0)}</strong></span>
      </div>
    </section>
  );
}

function RiskBar({
  label,
  value,
  icon,
}: {
  label: string;
  value: number;
  icon: ReactNode;
}) {
  return (
    <div className="risk-bar">
      <span>{icon}{label}</span>
      <div><i style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} /></div>
    </div>
  );
}
