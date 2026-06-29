import { Dices, Trophy } from "lucide-react";
import { useMemo, useState } from "react";
import type { LeaderboardEntry, LevelConfig } from "../types";
import type { ProgressState } from "../game/progression";
import { regimeLabels } from "../engine/marketSimulator";

type GameModesPanelProps = {
  levels: LevelConfig[];
  progress: ProgressState;
  onSelectLevel: (id: string) => void;
  onStartChallenge: (seed: string) => void;
};

const seedPresets = ["market-open-001", "vol-crush-drill", "crash-wing-2026"];

export function GameModesPanel({
  levels,
  progress,
  onSelectLevel,
  onStartChallenge,
}: GameModesPanelProps) {
  const [seed, setSeed] = useState("market-open-001");
  const trials = useMemo(() => levels.filter((level) => level.category === "trial"), [levels]);
  const topEntries = progress.leaderboard.slice(0, 5);

  return (
    <section className="panel modes-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">v1.0 systems</span>
          <h2>Jane Street Trials</h2>
        </div>
        <Trophy size={18} />
      </div>

      <p className="mode-copy">
        Seeds are player-chosen text codes. The same text rebuilds the same generated market, so you can replay or share a drill.
      </p>

      <div className="seed-row">
        <label>
          Challenge seed
          <input value={seed} onChange={(event) => setSeed(event.target.value)} />
        </label>
        <button className="primary-button" onClick={() => onStartChallenge(seed)}>
          <Dices size={16} />
          Launch
        </button>
      </div>

      <div className="seed-presets" aria-label="Seed presets">
        {seedPresets.map((preset) => (
          <button key={preset} onClick={() => setSeed(preset)}>
            {preset}
          </button>
        ))}
      </div>

      <div className="mode-section-heading">
        <span>Jane Street Trials</span>
        <small>{trials.length} finals</small>
      </div>

      <div className="trial-list">
        {trials.map((trial) => (
          <button key={trial.id} onClick={() => onSelectLevel(trial.id)}>
            <span>
              <strong>{trial.title}</strong>
              <small>Jane Street Trial | {regimeLabels[trial.theme]}</small>
            </span>
            <strong>D{trial.difficulty ?? 5}</strong>
          </button>
        ))}
      </div>

      <div className="mode-section-heading">
        <span>Local leaderboard</span>
        <small>saved in browser</small>
      </div>

      <div className="leaderboard-list">
        {topEntries.length === 0 ? (
          <p>No scored runs yet. Save a completed run to seed the board.</p>
        ) : (
          topEntries.map((entry) => <LeaderboardRow key={entry.id} entry={entry} />)
        )}
      </div>
    </section>
  );
}

function LeaderboardRow({ entry }: { entry: LeaderboardEntry }) {
  return (
    <div className="leaderboard-row">
      <span>{entry.levelTitle}</span>
      <strong>{entry.score.toFixed(0)}</strong>
      <small>P&L {entry.pnl.toFixed(1)} | DD {entry.drawdown.toFixed(1)}</small>
    </div>
  );
}
