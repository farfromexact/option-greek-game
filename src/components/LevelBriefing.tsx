import { Save, Target } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { LevelConfig } from "../types";
import type { ProgressState } from "../game/progression";
import type { LevelResult } from "../game/scoring";

type LevelBriefingProps = {
  levels: LevelConfig[];
  selectedLevel: LevelConfig;
  progress: ProgressState;
  result: LevelResult;
  onSelectLevel: (id: string) => void;
  onSaveProgress: () => void;
};

export function LevelBriefing({
  levels,
  selectedLevel,
  progress,
  result,
  onSelectLevel,
  onSaveProgress,
}: LevelBriefingProps) {
  const [selectedGroup, setSelectedGroup] = useState<LevelGroup>(() => groupForLevel(selectedLevel));
  const groups = useMemo(
    () =>
      levelGroups
        .map((group) => ({
          ...group,
          count: levels.filter((level) => groupForLevel(level) === group.id).length,
        }))
        .filter((group) => group.count > 0),
    [levels],
  );
  const visibleLevels = useMemo(
    () => levels.filter((level) => groupForLevel(level) === selectedGroup),
    [levels, selectedGroup],
  );
  const groupCompleted = visibleLevels.filter((level) => progress.completedLevels.includes(level.id)).length;

  useEffect(() => {
    setSelectedGroup(groupForLevel(selectedLevel));
  }, [selectedLevel.id]);

  return (
    <section className="panel level-panel">
      <div className="panel-heading">
        <div>
          <span className="eyebrow">Volatility Forge</span>
          <h1>{selectedLevel.title}</h1>
        </div>
        <button
          className="secondary-button save-progress-button"
          onClick={onSaveProgress}
          aria-label="Save progress locally"
          title="Saved in this browser with localStorage."
        >
          <Save size={16} />
          Save local run
        </button>
      </div>

      <div className="local-save-note">
        Local browser save: best scores, completed levels, leaderboard, and tutorial state stay in this browser.
      </div>

      <div className="level-group-tabs" aria-label="Level groups">
        {groups.map((group) => (
          <button
            key={group.id}
            className={group.id === selectedGroup ? "active" : ""}
            onClick={() => setSelectedGroup(group.id)}
            title={group.detail}
          >
            <span>{group.label}</span>
            <strong>{group.count}</strong>
          </button>
        ))}
      </div>

      <div className="level-group-summary">
        <span>{groupCompleted}/{visibleLevels.length} complete</span>
        <small>{groups.find((group) => group.id === selectedGroup)?.detail}</small>
      </div>

      <div className="level-picker">
        {visibleLevels.map((level) => (
          <button
            key={level.id}
            className={level.id === selectedLevel.id ? "active" : ""}
            onClick={() => onSelectLevel(level.id)}
            title={level.title}
          >
            <span className="level-title">{level.title}</span>
            <small>{level.act}</small>
            <strong>{levelBadge(level, progress)}</strong>
          </button>
        ))}
      </div>

      <div className="mission-brief">
        <div className="brief-goal">
          <Target size={18} />
          <p>{selectedLevel.goal}</p>
        </div>
        <div className="constraint-list">
          {selectedLevel.constraints.map((constraint) => (
            <span key={constraint}>{constraint}</span>
          ))}
        </div>
        <p className="learning-point">{selectedLevel.learningPoint}</p>
      </div>

      <div className={`result-band ${result.completed ? "complete" : "open"}`}>
        <strong>Score {result.score.toFixed(0)}</strong>
        <span>{result.reasons[0] ?? "Build, run, and review the book."}</span>
      </div>
    </section>
  );
}

type LevelGroup = "core" | "trial" | "procedural" | "challenge";

const levelGroups: Array<{ id: LevelGroup; label: string; detail: string }> = [
  {
    id: "core",
    label: "Core path",
    detail: "Hand-built onboarding and strategy missions.",
  },
  {
    id: "trial",
    label: "Jane Street",
    detail: "Capstone trials that combine Greeks, surface, probability, and market making.",
  },
  {
    id: "procedural",
    label: "Generated",
    detail: "Daily procedural missions. Use the seed launcher for repeatable drills.",
  },
  {
    id: "challenge",
    label: "Challenge",
    detail: "Custom seed missions created during this session.",
  },
];

function groupForLevel(level: LevelConfig): LevelGroup {
  return level.category ?? "core";
}

function levelBadge(level: LevelConfig, progress: ProgressState): string {
  if (progress.completedLevels.includes(level.id)) {
    return "done";
  }
  const best = progress.bestScores[level.id];
  if (best !== undefined) {
    return `${best}`;
  }
  return `D${level.difficulty ?? 1}`;
}
