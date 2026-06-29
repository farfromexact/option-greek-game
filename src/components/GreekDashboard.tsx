import { Activity, CloudLightning, Fuel, Gauge, Shield, Wind } from "lucide-react";
import type { ReactNode } from "react";
import type { MarketState, PortfolioSnapshot } from "../types";
import { greekRiskScore, normalizeGreek } from "../engine/greeks";

type GreekDashboardProps = {
  market: MarketState;
  snapshot: PortfolioSnapshot;
  pnl: number;
};

export function GreekDashboard({ market, snapshot, pnl }: GreekDashboardProps) {
  const riskScore = greekRiskScore(snapshot);
  const shield = Math.max(0, 1 - riskScore);
  const deltaForce = normalizeGreek(snapshot.delta, 120);
  return (
    <section className="panel greek-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Cockpit</span>
          <h2>Greek forces</h2>
        </div>
        <div className={`status-pill ${riskScore > 0.7 ? "hot" : riskScore > 0.42 ? "warn" : "ok"}`}>
          Risk {(riskScore * 100).toFixed(0)}%
        </div>
      </div>

      <div className="force-grid">
        <ForceMeter
          icon={<Wind size={19} />}
          label="Delta wind"
          value={snapshot.delta}
          normalized={normalizeGreek(snapshot.delta, 120)}
          unit=""
          mode="signed"
        />
        <ForceMeter
          icon={<Activity size={19} />}
          label="Gamma spring"
          value={snapshot.gamma}
          normalized={normalizeGreek(snapshot.gamma, 12)}
          unit=""
          mode="signed"
        />
        <ForceMeter
          icon={<Fuel size={19} />}
          label="Theta fuel"
          value={snapshot.theta / 365}
          normalized={normalizeGreek(snapshot.theta, 420)}
          unit="/day"
          mode="inverse"
        />
        <ForceMeter
          icon={<CloudLightning size={19} />}
          label="Vega storm"
          value={snapshot.vega / 100}
          normalized={normalizeGreek(snapshot.vega, 850)}
          unit="/vol pt"
          mode="signed"
        />
      </div>

      <div className="cockpit-visuals">
        <div
          className={`delta-arrow ${deltaForce < 0 ? "left" : "right"}`}
          style={{ ["--delta-width" as string]: `${Math.abs(deltaForce) * 42}%` }}
        >
          <span />
        </div>
        <div className="spring-visual" style={{ ["--gamma" as string]: Math.abs(normalizeGreek(snapshot.gamma, 10)) }}>
          {Array.from({ length: 9 }).map((_, index) => (
            <i key={index} />
          ))}
        </div>
        <div className="energy-row">
          <Gauge size={18} />
          <div className="energy-track">
            <div className={`energy-fill ${pnl < 0 ? "loss" : "gain"}`} style={{ width: `${Math.min(100, Math.max(0, 50 + pnl * 2))}%` }} />
          </div>
          <strong>{formatMoney(pnl)}</strong>
        </div>
        <div className="energy-row">
          <Shield size={18} />
          <div className="energy-track">
            <div className="shield-fill" style={{ width: `${shield * 100}%` }} />
          </div>
          <strong>{(shield * 100).toFixed(0)}%</strong>
        </div>
      </div>

      <div className="market-strip">
        <span>S {market.spot.toFixed(2)}</span>
        <span>IV {(market.volatility * 100).toFixed(1)}%</span>
        <span>T+{market.day}</span>
        <span>Liq {(market.liquidity * 100).toFixed(0)}%</span>
      </div>
    </section>
  );
}

function ForceMeter({
  icon,
  label,
  value,
  normalized,
  unit,
  mode,
}: {
  icon: ReactNode;
  label: string;
  value: number;
  normalized: number;
  unit: string;
  mode: "signed" | "inverse";
}) {
  const magnitude = Math.min(1, Math.abs(normalized));
  const className = normalized < -0.08 ? "negative" : normalized > 0.08 ? "positive" : "neutral";
  return (
    <div className={`force-meter ${className} ${mode}`}>
      <div className="force-label">
        {icon}
        <span>{label}</span>
      </div>
      <div className="force-track">
        <span className="zero-line" />
        <span
          className="force-fill"
          style={{
            width: `${magnitude * 50}%`,
            left: normalized < 0 ? `${50 - magnitude * 50}%` : "50%",
          }}
        />
      </div>
      <strong>{value.toFixed(2)}{unit}</strong>
    </div>
  );
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(2)}`;
}
