import { CheckCircle2, ChevronLeft, ChevronRight, X } from "lucide-react";
import { useMemo, useState } from "react";
import { tutorialSteps } from "../game/tutorial";

type TutorialOverlayProps = {
  forced: boolean;
  onComplete: () => void;
  onClose: () => void;
};

export function TutorialOverlay({ forced, onComplete, onClose }: TutorialOverlayProps) {
  const [index, setIndex] = useState(0);
  const step = tutorialSteps[index];
  const isLast = index === tutorialSteps.length - 1;
  const progress = useMemo(
    () => Math.round(((index + 1) / tutorialSteps.length) * 100),
    [index],
  );
  const Icon = step.icon;

  function advance() {
    if (isLast) {
      onComplete();
      return;
    }
    setIndex((current) => Math.min(tutorialSteps.length - 1, current + 1));
  }

  return (
    <div className="tutorial-backdrop" role="dialog" aria-modal="true" aria-label="Pre-game tutorial">
      <section className="tutorial-shell">
        <div className="tutorial-header">
          <div className="tutorial-brand">
            <Icon size={24} />
            <div>
              <span className="eyebrow">Pre-flight tutorial</span>
              <h1>{step.title}</h1>
            </div>
          </div>
          {!forced && (
            <button className="icon-button" onClick={onClose} aria-label="Close tutorial">
              <X size={17} />
            </button>
          )}
        </div>

        <div className="tutorial-progress" aria-label={`Tutorial progress ${progress}%`}>
          <i style={{ width: `${progress}%` }} />
        </div>

        <div className="tutorial-body">
          <aside className="tutorial-rail" aria-label="Tutorial steps">
            {tutorialSteps.map((item, itemIndex) => {
              const StepIcon = item.icon;
              return (
                <button
                  key={item.id}
                  className={itemIndex === index ? "active" : ""}
                  onClick={() => setIndex(itemIndex)}
                >
                  <StepIcon size={16} />
                  <span className="tutorial-step-copy">
                    <strong>{item.title}</strong>
                    <small>{item.stage}</small>
                  </span>
                  {itemIndex < index && <CheckCircle2 size={14} />}
                </button>
              );
            })}
          </aside>

          <div className="tutorial-card">
            <div className="tutorial-meta">
              <span>{step.stage}</span>
              {step.unlock && <span>Unlock: {step.unlock}</span>}
            </div>
            <p className="tutorial-subtitle">{step.subtitle}</p>
            <div className="tutorial-lesson-grid">
              <LessonBlock label="Core idea" text={step.coreIdea} />
              <LessonBlock label="Player action" text={step.playerAction} />
              <LessonBlock label="Watch signal" text={step.watchSignal} />
              <LessonBlock label="Mental model" text={step.metaphor} />
            </div>
            {step.checkpoints && <TutorialCheckpoints items={step.checkpoints} />}

            <div className={`tutorial-visual visual-${step.id}`}>
              <span className="visual-spot" />
              <span className="visual-path" />
              <span className="visual-risk" />
              <span className="visual-greek one" />
              <span className="visual-greek two" />
              <strong>{step.metaphor}</strong>
            </div>
          </div>
        </div>

        <div className="tutorial-footer">
          <button
            className="secondary-button"
            onClick={() => setIndex((current) => Math.max(0, current - 1))}
            disabled={index === 0}
          >
            <ChevronLeft size={16} />
            Back
          </button>
          <span>{index + 1} / {tutorialSteps.length}</span>
          <button className="primary-button" onClick={advance}>
            {isLast ? "Start game" : "Next"}
            {isLast ? <CheckCircle2 size={16} /> : <ChevronRight size={16} />}
          </button>
        </div>
      </section>
    </div>
  );
}

function LessonBlock({ label, text }: { label: string; text: string }) {
  return (
    <article className="tutorial-lesson">
      <span>{label}</span>
      <p>{text}</p>
    </article>
  );
}

function TutorialCheckpoints({ items }: { items: string[] }) {
  return (
    <div className="tutorial-route">
      <span className="eyebrow">Play-through checkpoints</span>
      <ol>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ol>
    </div>
  );
}
