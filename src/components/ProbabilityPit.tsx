import { Target } from "lucide-react";
import { useState } from "react";
import type { CalibrationQuestion, CalibrationResult, LevelConfig, PnlAttribution, ReplayRecord } from "../types";

type ProbabilityPitProps = {
  level: LevelConfig;
  records: ReplayRecord[];
  attribution: PnlAttribution;
  onSubmit: (result: CalibrationResult) => void;
};

const questionDefs = [
  { id: "spot-up", label: "Final spot above start" },
  { id: "realized-over-implied", label: "Realized vol beats implied" },
  { id: "vol-crush", label: "IV crush over 5 vol points" },
  { id: "risk-flag", label: "At least one risk violation" },
];

export function ProbabilityPit({
  level,
  records,
  attribution,
  onSubmit,
}: ProbabilityPitProps) {
  const [probabilities, setProbabilities] = useState<Record<string, number>>({
    "spot-up": 55,
    "realized-over-implied": 50,
    "vol-crush": 45,
    "risk-flag": 35,
  });
  const [lastScore, setLastScore] = useState<number | null>(null);

  function submit() {
    const first = records[0];
    const latest = records[records.length - 1] ?? first;
    const outcomes: Record<string, boolean> = {
      "spot-up": latest.market.spot > first.market.spot,
      "realized-over-implied": attribution.gammaScalpEdge > 0,
      "vol-crush": latest.market.volatility < first.market.volatility - 0.05,
      "risk-flag": attribution.riskViolations > 0,
    };
    const questions: CalibrationQuestion[] = questionDefs.map((question) => {
      const probability = (probabilities[question.id] ?? 50) / 100;
      const outcome = outcomes[question.id];
      const brier = Math.pow(probability - (outcome ? 1 : 0), 2);
      return {
        id: question.id,
        label: question.label,
        probability,
        outcome,
        brier,
      };
    });
    const averageBrier =
      questions.reduce((total, question) => total + question.brier, 0) / questions.length;
    setLastScore(averageBrier);
    onSubmit({
      id: `cal-${Date.now()}`,
      levelId: level.id,
      createdAt: new Date().toISOString(),
      averageBrier,
      questions,
    });
  }

  return (
    <section className="panel probability-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Prediction Pit</span>
          <h2>Probability calibration</h2>
        </div>
        <Target size={18} />
      </div>

      <div className="probability-list">
        {questionDefs.map((question) => (
          <label key={question.id}>
            <span>{question.label}</span>
            <input
              type="range"
              min="1"
              max="99"
              value={probabilities[question.id]}
              onChange={(event) =>
                setProbabilities((current) => ({
                  ...current,
                  [question.id]: Number(event.target.value),
                }))
              }
            />
            <strong>{probabilities[question.id]}%</strong>
          </label>
        ))}
      </div>

      <button className="primary-button calibration-button" onClick={submit}>
        Score forecast
      </button>
      <p className="calibration-copy">
        {lastScore === null
          ? "Submit after a path develops. Lower Brier score means better calibration."
          : `Average Brier ${lastScore.toFixed(3)}. ${lastScore < 0.25 ? "Well calibrated." : "Forecasts need sharper odds."}`}
      </p>
    </section>
  );
}
