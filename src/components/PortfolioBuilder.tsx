import { Crosshair, Eraser, Plus, Shield } from "lucide-react";
import type { MarketState, PortfolioLeg, PortfolioSnapshot } from "../types";
import { OptionLegEditor } from "./OptionLegEditor";

export type LegTemplate = "long-call" | "short-call" | "long-put" | "short-put" | "stock" | "cash";

type PortfolioBuilderProps = {
  legs: PortfolioLeg[];
  market: MarketState;
  snapshot: PortfolioSnapshot;
  onAddTemplate: (template: LegTemplate) => void;
  onUpdateLeg: (leg: PortfolioLeg) => void;
  onRemoveLeg: (id: string) => void;
  onDeltaHedge: () => void;
  onProtectTail: () => void;
  onClear: () => void;
};

const templates: { id: LegTemplate; label: string; detail: string }[] = [
  { id: "long-call", label: "Long Call", detail: "Delta + Vega" },
  { id: "short-call", label: "Short Call", detail: "Theta + ceiling" },
  { id: "long-put", label: "Long Put", detail: "Crash wing" },
  { id: "short-put", label: "Short Put", detail: "Theta + floor risk" },
  { id: "stock", label: "Stock Hedge", detail: "Pure Delta" },
  { id: "cash", label: "Cash", detail: "Dry powder" },
];

export function PortfolioBuilder({
  legs,
  market,
  snapshot,
  onAddTemplate,
  onUpdateLeg,
  onRemoveLeg,
  onDeltaHedge,
  onProtectTail,
  onClear,
}: PortfolioBuilderProps) {
  return (
    <section className="panel builder-panel" onDragOver={(event) => event.preventDefault()} onDrop={(event) => {
      const template = event.dataTransfer.getData("text/plain") as LegTemplate;
      if (template) {
        onAddTemplate(template);
      }
    }}>
      <div className="panel-heading">
        <div>
          <span className="eyebrow">Options workshop</span>
          <h2>Risk machine</h2>
        </div>
        <div className="mini-stat">
          <span>Value</span>
          <strong>{formatMoney(snapshot.value)}</strong>
        </div>
      </div>

      <div className="workshop-palette">
        {templates.map((template) => (
          <button
            key={template.id}
            className="tool-tile"
            draggable
            onDragStart={(event) => event.dataTransfer.setData("text/plain", template.id)}
            onClick={() => onAddTemplate(template.id)}
          >
            <Plus size={16} />
            <span>{template.label}</span>
            <small>{template.detail}</small>
          </button>
        ))}
      </div>

      <div className="builder-actions">
        <button className="secondary-button" onClick={onDeltaHedge}>
          <Crosshair size={16} />
          Delta hedge
        </button>
        <button className="secondary-button" onClick={onProtectTail}>
          <Shield size={16} />
          Buy wing
        </button>
        <button className="secondary-button" onClick={onClear}>
          <Eraser size={16} />
          Clear
        </button>
      </div>

      <div className="leg-list">
        {legs.length === 0 ? (
          <div className="empty-drop-zone">Drop option parts here</div>
        ) : (
          legs.map((leg) => (
            <OptionLegEditor
              key={leg.id}
              leg={leg}
              market={market}
              onChange={onUpdateLeg}
              onRemove={onRemoveLeg}
            />
          ))
        )}
      </div>
    </section>
  );
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(2)}`;
}
