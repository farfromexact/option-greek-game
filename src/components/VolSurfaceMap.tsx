import { Layers3 } from "lucide-react";
import type { MarketState, PortfolioLeg } from "../types";
import { buildVolSurface, calculateVegaBuckets, surfaceRiskNarrative } from "../engine/volSurface";

type VolSurfaceMapProps = {
  market: MarketState;
  legs: PortfolioLeg[];
};

export function VolSurfaceMap({ market, legs }: VolSurfaceMapProps) {
  const surface = buildVolSurface(market);
  const buckets = calculateVegaBuckets(legs, market);
  const maxVol = Math.max(...surface.map((point) => point.volatility));
  const minVol = Math.min(...surface.map((point) => point.volatility));
  const maxBucket = Math.max(1, ...buckets.map((bucket) => Math.abs(bucket.vega)));

  return (
    <section className="panel surface-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Vol surface cartographer</span>
          <h2>Skew, term, buckets</h2>
        </div>
        <Layers3 size={19} />
      </div>

      <div className="surface-grid" aria-label="Volatility surface map">
        {surface.map((point) => {
          const richness = (point.volatility - minVol) / Math.max(0.01, maxVol - minVol);
          return (
            <span
              key={`${point.expiryDays}-${point.strike}`}
              style={{
                opacity: 0.35 + richness * 0.65,
                transform: `translateY(${(1 - richness) * 4}px)`,
              }}
              title={`${point.expiryDays}D ${point.strike}: ${(point.volatility * 100).toFixed(1)}%`}
            >
              {(point.volatility * 100).toFixed(0)}
            </span>
          );
        })}
      </div>

      <div className="surface-meta">
        <span>Skew {market.skew.toFixed(3)}</span>
        <span>Term {market.termSlope.toFixed(3)}</span>
        <span>Shock {market.surfaceShock.toFixed(3)}</span>
      </div>

      <div className="bucket-list">
        {buckets.map((bucket) => (
          <div key={bucket.id} className={bucket.vega >= 0 ? "bucket long" : "bucket short"}>
            <span>{bucket.label}</span>
            <div><i style={{ width: `${Math.abs(bucket.vega) / maxBucket * 100}%` }} /></div>
            <strong>{bucket.vega.toFixed(1)}</strong>
          </div>
        ))}
      </div>

      <p className="surface-narrative">{surfaceRiskNarrative(buckets, market)}</p>
    </section>
  );
}
