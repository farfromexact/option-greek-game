import { CheckCircle2, X } from "lucide-react";
import { useMemo, useState } from "react";
import { guideSections, type GuideEntry } from "../game/referenceGuide";

type ReferenceGuideOverlayProps = {
  onClose: () => void;
};

export function ReferenceGuideOverlay({ onClose }: ReferenceGuideOverlayProps) {
  const [activeId, setActiveId] = useState(guideSections[0].id);
  const active = useMemo(
    () => guideSections.find((section) => section.id === activeId) ?? guideSections[0],
    [activeId],
  );

  return (
    <div className="guide-backdrop" role="dialog" aria-modal="true" aria-label="Reference guide">
      <section className="guide-shell">
        <div className="guide-header">
          <div>
            <span className="eyebrow">Reference guide</span>
            <h1>Icons, visuals, operations</h1>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="Close guide">
            <X size={17} />
          </button>
        </div>

        <div className="guide-body">
          <aside className="guide-nav" aria-label="Guide sections">
            {guideSections.map((section) => (
              <button
                key={section.id}
                className={section.id === active.id ? "active" : ""}
                onClick={() => setActiveId(section.id)}
              >
                <span>{section.title}</span>
                <small>{section.entries.length} items</small>
              </button>
            ))}
          </aside>

          <div className="guide-content">
            <div className="guide-section-intro">
              <span className="eyebrow">{active.title}</span>
              <p>{active.summary}</p>
            </div>

            <div className="guide-entry-grid">
              {active.entries.map((entry) => (
                <GuideEntryCard key={`${active.id}-${entry.label}`} entry={entry} />
              ))}
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function GuideEntryCard({ entry }: { entry: GuideEntry }) {
  const Icon = entry.icon;
  return (
    <article className="guide-entry">
      <div className="guide-entry-mark">
        {Icon ? <Icon size={20} /> : entry.visual ? <VisualSwatch kind={entry.visual} /> : <CheckCircle2 size={18} />}
      </div>
      <div>
        <strong>{entry.label}</strong>
        <p>{entry.detail}</p>
        {entry.read && <small>{entry.read}</small>}
      </div>
    </article>
  );
}

function VisualSwatch({ kind }: { kind: string }) {
  if (kind === "pill") {
    return (
      <span className="guide-swatch guide-pill-swatch">
        <i />
        <i />
        <i />
      </span>
    );
  }
  if (kind === "force") {
    return (
      <span className="guide-swatch guide-force-swatch">
        <i />
      </span>
    );
  }
  if (kind === "arrow") {
    return <span className="guide-swatch guide-arrow-swatch" />;
  }
  if (kind === "spring") {
    return (
      <span className="guide-swatch guide-spring-swatch">
        {Array.from({ length: 5 }).map((_, index) => <i key={index} />)}
      </span>
    );
  }
  if (kind === "energy") {
    return <span className="guide-swatch guide-energy-swatch" />;
  }
  if (kind === "shield") {
    return <span className="guide-swatch guide-shield-swatch" />;
  }
  if (kind === "weather") {
    return (
      <span className="guide-swatch guide-weather-swatch">
        <i />
        <b />
      </span>
    );
  }
  if (kind === "meters") {
    return (
      <span className="guide-swatch guide-meter-swatch">
        <i />
        <i />
        <i />
      </span>
    );
  }
  if (kind === "payoff") {
    return <span className="guide-swatch guide-payoff-swatch" />;
  }
  if (kind === "dashed") {
    return <span className="guide-swatch guide-dashed-swatch" />;
  }
  if (kind === "heat") {
    return (
      <span className="guide-swatch guide-heat-swatch">
        {Array.from({ length: 9 }).map((_, index) => <i key={index} />)}
      </span>
    );
  }
  if (kind === "surface") {
    return (
      <span className="guide-swatch guide-surface-swatch">
        {Array.from({ length: 9 }).map((_, index) => <i key={index} />)}
      </span>
    );
  }
  if (kind === "bucket") {
    return (
      <span className="guide-swatch guide-bucket-swatch">
        <i />
        <i />
      </span>
    );
  }
  if (kind === "timeline") {
    return (
      <span className="guide-swatch guide-timeline-swatch">
        {Array.from({ length: 6 }).map((_, index) => <i key={index} />)}
      </span>
    );
  }
  if (kind === "chips") {
    return (
      <span className="guide-swatch guide-chip-swatch">
        <i />
        <i />
      </span>
    );
  }
  return <span className="guide-swatch" />;
}
