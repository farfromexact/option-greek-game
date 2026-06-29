import { Trash2 } from "lucide-react";
import type { ChangeEvent } from "react";
import type { MarketState, PortfolioLeg } from "../types";
import { priceLeg } from "../engine/portfolio";

type OptionLegEditorProps = {
  leg: PortfolioLeg;
  market: MarketState;
  onChange: (leg: PortfolioLeg) => void;
  onRemove: (id: string) => void;
};

const numberValue = (event: ChangeEvent<HTMLInputElement>) =>
  Number.parseFloat(event.target.value || "0");

export function OptionLegEditor({
  leg,
  market,
  onChange,
  onRemove,
}: OptionLegEditorProps) {
  const priced = priceLeg(leg, market);

  if (leg.kind === "cash") {
    return (
      <article className="leg-row">
        <div className="leg-title">
          <span className="leg-chip cash">Cash</span>
          <strong>Cash reserve</strong>
        </div>
        <label>
          Amount
          <input
            type="number"
            value={roundInput(leg.amount)}
            onChange={(event) => onChange({ ...leg, amount: numberValue(event) })}
          />
        </label>
        <span className="leg-value">{formatMoney(priced.value)}</span>
        <button className="icon-button danger" onClick={() => onRemove(leg.id)} aria-label="Remove cash">
          <Trash2 size={16} />
        </button>
      </article>
    );
  }

  if (leg.kind === "stock") {
    return (
      <article className="leg-row">
        <div className="leg-title">
          <span className="leg-chip stock">Stock</span>
          <strong>Stock hedge</strong>
        </div>
        <label>
          Qty
          <input
            type="number"
            value={roundInput(leg.quantity)}
            step="1"
            onChange={(event) => onChange({ ...leg, quantity: numberValue(event) })}
          />
        </label>
        <span className="leg-value">{formatMoney(priced.value)}</span>
        <button className="icon-button danger" onClick={() => onRemove(leg.id)} aria-label="Remove stock">
          <Trash2 size={16} />
        </button>
      </article>
    );
  }

  return (
    <article className="leg-row option-leg">
      <div className="leg-title">
        <span className={`leg-chip ${leg.side}`}>
          {leg.side} {leg.optionType}
        </span>
        <strong>{leg.strike.toFixed(0)}K / {leg.expiryDays.toFixed(0)}D</strong>
      </div>
      <label>
        Side
        <select
          value={leg.side}
          onChange={(event) => onChange({ ...leg, side: event.target.value as typeof leg.side })}
        >
          <option value="long">long</option>
          <option value="short">short</option>
        </select>
      </label>
      <label>
        Type
        <select
          value={leg.optionType}
          onChange={(event) => onChange({ ...leg, optionType: event.target.value as typeof leg.optionType })}
        >
          <option value="call">call</option>
          <option value="put">put</option>
        </select>
      </label>
      <label>
        Strike
        <input
          type="number"
          value={roundInput(leg.strike)}
          step="1"
          onChange={(event) => onChange({ ...leg, strike: numberValue(event) })}
        />
      </label>
      <label>
        Expiry
        <input
          type="number"
          value={roundInput(leg.expiryDays)}
          step="1"
          min="1"
          onChange={(event) => onChange({ ...leg, expiryDays: Math.max(1, numberValue(event)) })}
        />
      </label>
      <label>
        IV
        <input
          type="number"
          value={roundInput(leg.iv * 100)}
          step="1"
          min="1"
          onChange={(event) => onChange({ ...leg, iv: Math.max(0.01, numberValue(event) / 100) })}
        />
      </label>
      <label>
        Qty
        <input
          type="number"
          value={roundInput(leg.quantity)}
          step="1"
          min="0"
          onChange={(event) => onChange({ ...leg, quantity: Math.max(0, numberValue(event)) })}
        />
      </label>
      <span className="leg-value">{formatMoney(priced.value)}</span>
      <button className="icon-button danger" onClick={() => onRemove(leg.id)} aria-label="Remove option leg">
        <Trash2 size={16} />
      </button>
    </article>
  );
}

function roundInput(value: number): string {
  return Number.isFinite(value) ? String(Math.round(value * 100) / 100) : "0";
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(2)}`;
}
