import { FastForward, Pause, Play, RotateCcw, StepForward } from "lucide-react";
import type { MarketState, RegimeId, ReplayRecord } from "../types";
import { regimeLabels } from "../engine/marketSimulator";

type MarketWeatherViewProps = {
  market: MarketState;
  records: ReplayRecord[];
  scriptedRegime: RegimeId;
  running: boolean;
  speed: number;
  onRegimeChange: (regime: RegimeId) => void;
  onToggleRun: () => void;
  onStep: () => void;
  onFast: () => void;
  onRestart: () => void;
};

const regimes = Object.keys(regimeLabels) as RegimeId[];

export function MarketWeatherView({
  market,
  records,
  scriptedRegime,
  running,
  speed,
  onRegimeChange,
  onToggleRun,
  onStep,
  onFast,
  onRestart,
}: MarketWeatherViewProps) {
  const path = records.length > 1 ? records : [{ market, step: 0 } as ReplayRecord];
  const minSpot = Math.min(...path.map((record) => record.market.spot), market.spot * 0.9);
  const maxSpot = Math.max(...path.map((record) => record.market.spot), market.spot * 1.1);
  const pathPoints = path.map((record, index) => {
    const x = 5 + (index / Math.max(1, path.length - 1)) * 90;
    const y = 72 - ((record.market.spot - minSpot) / Math.max(1, maxSpot - minSpot)) * 52;
    return { x, y };
  });
  const pointString = pathPoints.map((point) => `${point.x.toFixed(2)},${point.y.toFixed(2)}`).join(" ");
  const areaPath =
    pathPoints.length > 1
      ? `M ${pointString} L ${pathPoints[pathPoints.length - 1].x.toFixed(2)},78 L ${pathPoints[0].x.toFixed(2)},78 Z`
      : "";
  const spotX = clamp(50 + (market.spot - 100) * 1.15, 14, 86);
  const spotY = clamp(pathPoints[pathPoints.length - 1]?.y ?? 42, 18, 72);
  const volRadius = 10 + market.volatility * 18;
  const eventRadius = 5 + market.eventRisk * 12;
  const windOffset = clamp((market.spot - 100) * 1.2, -19, 19);
  const skewX = clamp(50 - market.skew * 140, 28, 74);
  const overrideActive = market.regime !== scriptedRegime;

  return (
    <section className={`panel weather-panel regime-${market.regime}`}>
      <div className="panel-heading">
        <div className="weather-title">
          <span className="eyebrow">Mission weather</span>
          <h2>{regimeLabels[market.regime]}</h2>
          <small>Scripted: {regimeLabels[scriptedRegime]}</small>
        </div>
        <label className="weather-override">
          Training override
          <select value={market.regime} onChange={(event) => onRegimeChange(event.target.value as RegimeId)}>
            {regimes.map((regime) => (
              <option key={regime} value={regime}>{regimeLabels[regime]}</option>
            ))}
          </select>
        </label>
      </div>
      <p className={`weather-note ${overrideActive ? "warn" : ""}`}>
        {overrideActive
          ? "Override active for sandbox practice. Restart restores the level's scripted weather."
          : "Each level starts with scripted weather; the dropdown is a sandbox override for practice."}
      </p>

      <svg className="weather-map" viewBox="0 0 100 84" role="img" aria-label="Market weather field">
        <defs>
          <linearGradient id="weatherSkyGradient" x1="0" x2="1" y1="0" y2="1">
            <stop offset="0%" stopColor="#253142" />
            <stop offset="52%" stopColor="#1e2421" />
            <stop offset="100%" stopColor="#151615" />
          </linearGradient>
          <radialGradient id="volPressureGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="rgba(22, 199, 174, 0.34)" />
            <stop offset="100%" stopColor="rgba(22, 199, 174, 0.03)" />
          </radialGradient>
        </defs>
        <rect className="weather-sky" x="0" y="0" width="100" height="84" rx="6" />
        <g className="weather-grid-lines">
          {[18, 34, 50, 66].map((y) => (
            <line key={`h-${y}`} x1="0" y1={y} x2="100" y2={y} />
          ))}
          {[20, 40, 60, 80].map((x) => (
            <line key={`v-${x}`} x1={x} y1="0" x2={x} y2="84" />
          ))}
        </g>
        <path className="terrain-band back" d="M0,62 C16,55 27,67 43,58 C62,47 76,59 100,44 L100,84 L0,84 Z" />
        <path className="terrain-band" d="M0,70 C18,60 30,76 48,63 C64,51 78,65 100,52 L100,84 L0,84 Z" />
        {areaPath && <path className="spot-area" d={areaPath} />}
        <polyline className="spot-path shadow" points={pointString} fill="none" />
        <polyline className="spot-path" points={pointString} fill="none" />
        <path
          className="skew-front"
          d={`M8,${64 + market.skew * 90} C28,${58 + market.skew * 55} ${skewX},${58 - market.skew * 40} 94,${50 - market.skew * 70}`}
        />
        <g className="wind-stack">
          {[-6, 0, 6].map((offset) => (
            <line
              key={offset}
              className="wind-line"
              x1="11"
              y1={22 + offset}
              x2={30 + windOffset}
              y2={22 + offset}
            />
          ))}
        </g>
        <circle className="vol-pressure" cx={spotX} cy={spotY} r={volRadius} />
        <circle className="spot-node" cx={spotX} cy={spotY} r={5 + market.volatility * 6} />
        <circle className="event-ring" cx="82" cy="22" r={eventRadius + 5} />
        <circle className="event-core" cx="82" cy="22" r={eventRadius} />
        <text x="6" y="12" className="weather-label">S {market.spot.toFixed(2)}</text>
        <text x="6" y="80" className="weather-label">IV {(market.volatility * 100).toFixed(1)}%</text>
        <text x="70" y="11" className="weather-label">Event {(market.eventRisk * 100).toFixed(0)}%</text>
      </svg>

      <div className="weather-map-legend">
        <span><i className="legend-spot" /> Spot path</span>
        <span><i className="legend-vol" /> IV pressure</span>
        <span><i className="legend-event" /> Event risk</span>
      </div>

      <div className="weather-meters">
        <Meter label="Liquidity" value={market.liquidity} />
        <Meter label="Event" value={market.eventRisk} />
        <Meter label="Skew" value={Math.min(1, Math.abs(market.skew) * 5)} />
      </div>

      <div className="sim-controls">
        <button className="primary-button" onClick={onToggleRun}>
          {running ? <Pause size={16} /> : <Play size={16} />}
          {running ? "Pause" : "Run"}
        </button>
        <button className="secondary-button" onClick={onStep}>
          <StepForward size={16} />
          Step
        </button>
        <button className="secondary-button" onClick={onFast}>
          <FastForward size={16} />
          {speed}x
        </button>
        <button className="secondary-button" onClick={onRestart}>
          <RotateCcw size={16} />
          Restart
        </button>
      </div>
    </section>
  );
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function Meter({ label, value }: { label: string; value: number }) {
  return (
    <div className="weather-meter">
      <span>{label}</span>
      <div>
        <i style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} />
      </div>
    </div>
  );
}
