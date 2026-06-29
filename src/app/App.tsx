import { useCallback, useEffect, useMemo, useState } from "react";
import { BookOpen, CircleDollarSign, HelpCircle, Radar } from "lucide-react";
import { GreekDashboard } from "../components/GreekDashboard";
import { LevelBriefing } from "../components/LevelBriefing";
import { MarketMakerArena } from "../components/MarketMakerArena";
import { MarketWeatherView } from "../components/MarketWeatherView";
import { PayoffChart } from "../components/PayoffChart";
import { PortfolioBuilder, type LegTemplate } from "../components/PortfolioBuilder";
import { ProbabilityPit } from "../components/ProbabilityPit";
import { ReferenceGuideOverlay } from "../components/ReferenceGuideOverlay";
import { ReplayPanel } from "../components/ReplayPanel";
import { RiskLimitPanel } from "../components/RiskLimitPanel";
import { ScenarioChart } from "../components/ScenarioChart";
import { TutorialOverlay } from "../components/TutorialOverlay";
import { VolSurfaceMap } from "../components/VolSurfaceMap";
import { GameModesPanel } from "../components/GameModesPanel";
import { calculatePnlAttribution } from "../engine/pnlAttribution";
import {
  createCashLeg,
  createOptionLeg,
  createStockLeg,
  decayOptionExpiries,
  priceLeg,
  summarizePortfolio,
} from "../engine/portfolio";
import {
  simulateMarketStep,
  transactionCostForNotional,
} from "../engine/marketSimulator";
import { getLevel, levels } from "../game/levels";
import { generateChallengeLevel } from "../game/procedural";
import {
  loadProgress,
  recordCalibrationResult,
  recordLeaderboardEntry,
  recordLevelScore,
  saveProgress,
  type ProgressState,
} from "../game/progression";
import { evaluateLevel } from "../game/scoring";
import type {
  CalibrationResult,
  LevelConfig,
  LeaderboardEntry,
  MarketState,
  OptionLeg,
  PortfolioLeg,
  ReplayRecord,
} from "../types";

type SessionState = {
  market: MarketState;
  legs: PortfolioLeg[];
  baselineValue: number;
  totalCosts: number;
  records: ReplayRecord[];
};

function createSession(level: LevelConfig): SessionState {
  const market = clone(level.initialMarket);
  const legs = clone(level.initialPortfolio);
  const snapshot = summarizePortfolio(legs, market);
  return {
    market,
    legs,
    baselineValue: snapshot.value,
    totalCosts: 0,
    records: [
      {
        step: 0,
        market,
        portfolio: snapshot,
        pnl: 0,
        action: "Mission start",
        transactionCost: 0,
      },
    ],
  };
}

export function App() {
  const [progress, setProgress] = useState<ProgressState>(() => loadProgress());
  const [selectedLevelId, setSelectedLevelId] = useState(() => loadProgress().lastLevelId);
  const [session, setSession] = useState<SessionState>(() => createSession(getLevel(loadProgress().lastLevelId)));
  const [running, setRunning] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [showTutorial, setShowTutorial] = useState(() => !loadProgress().tutorialCompleted);
  const [showGuide, setShowGuide] = useState(false);
  const [customLevel, setCustomLevel] = useState<LevelConfig | null>(null);
  const availableLevels = useMemo(
    () => (customLevel ? [customLevel, ...levels] : levels),
    [customLevel],
  );
  const selectedLevel = useMemo(
    () => availableLevels.find((level) => level.id === selectedLevelId) ?? getLevel(selectedLevelId),
    [availableLevels, selectedLevelId],
  );

  const snapshot = useMemo(
    () => summarizePortfolio(session.legs, session.market),
    [session.legs, session.market],
  );
  const livePnl = snapshot.value - session.baselineValue - session.totalCosts;
  const attribution = useMemo(
    () => calculatePnlAttribution(session.records),
    [session.records],
  );
  const result = useMemo(
    () => evaluateLevel(selectedLevel, attribution, snapshot, session.legs, Math.max(0, session.records.length - 1)),
    [selectedLevel, attribution, snapshot, session.legs, session.records.length],
  );

  const commit = useCallback(
    (
      updater: (previous: SessionState) => {
        market?: MarketState;
        legs?: PortfolioLeg[];
        action: string;
        cost?: number;
        resetBaseline?: boolean;
      },
    ) => {
      setSession((previous) => {
        const patch = updater(previous);
        const market = patch.market ?? previous.market;
        const legs = patch.legs ?? previous.legs;
        const cost = patch.cost ?? 0;
        const snapshotNow = summarizePortfolio(legs, market);

        if (patch.resetBaseline) {
          return {
            market,
            legs,
            baselineValue: snapshotNow.value,
            totalCosts: 0,
            records: [
              {
                step: 0,
                market,
                portfolio: snapshotNow,
                pnl: 0,
                action: patch.action,
                transactionCost: 0,
              },
            ],
          };
        }

        const totalCosts = previous.totalCosts + cost;
        const pnl = snapshotNow.value - previous.baselineValue - totalCosts;
        return {
          market,
          legs,
          baselineValue: previous.baselineValue,
          totalCosts,
          records: [
            ...previous.records,
            {
              step: previous.records.length,
              market,
              portfolio: snapshotNow,
              pnl,
              action: patch.action,
              transactionCost: cost,
            },
          ],
        };
      });
    },
    [],
  );

  const stepMarket = useCallback(() => {
    commit((previous) => {
      const nextMarket = simulateMarketStep(previous.market);
      const decayed = decayOptionExpiries(previous.legs, 1).map((leg) => {
        if (leg.kind !== "option") {
          return leg;
        }
        const volMove = nextMarket.volatility - previous.market.volatility;
        return {
          ...leg,
          iv: Math.max(0.03, Math.min(1.4, leg.iv + volMove * 0.85)),
        };
      });
      return {
        market: nextMarket,
        legs: decayed,
        action: `Market step: ${nextMarket.regime}`,
      };
    });
  }, [commit]);

  useEffect(() => {
    if (!running) {
      return undefined;
    }
    const delay = Math.max(120, 900 / speed);
    const timer = window.setInterval(stepMarket, delay);
    return () => window.clearInterval(timer);
  }, [running, speed, stepMarket]);

  function selectLevel(id: string) {
    const level = availableLevels.find((item) => item.id === id) ?? getLevel(id);
    setRunning(false);
    setSelectedLevelId(id);
    setSession(createSession(level));
    const nextProgress = { ...progress, lastLevelId: id };
    setProgress(nextProgress);
    saveProgress(nextProgress);
  }

  function restartLevel() {
    setRunning(false);
    setSession(createSession(selectedLevel));
  }

  function addTemplate(template: LegTemplate) {
    commit((previous) => {
      const leg = createLegFromTemplate(template, previous.market);
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      if (buildMode) {
        return {
          legs: [...previous.legs, leg],
          action: `Added ${template}`,
          resetBaseline: true,
        };
      }
      const priced = priceLeg(leg, previous.market).value;
      const cost = transactionCostForNotional(Math.abs(priced), previous.market);
      return {
        legs: [...previous.legs, leg, createCashLeg(-priced)],
        action: `Traded ${template}`,
        cost,
      };
    });
  }

  function updateLeg(updated: PortfolioLeg) {
    commit((previous) => {
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      return {
        legs: previous.legs.map((leg) => (leg.id === updated.id ? updated : leg)),
        action: `Adjusted ${updated.kind}`,
        resetBaseline: buildMode,
      };
    });
  }

  function removeLeg(id: string) {
    commit((previous) => {
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      return {
        legs: previous.legs.filter((leg) => leg.id !== id),
        action: "Removed leg",
        resetBaseline: buildMode,
      };
    });
  }

  function deltaHedge() {
    const hedgeQuantity = -snapshot.delta;
    if (Math.abs(hedgeQuantity) < 0.05) {
      return;
    }
    commit((previous) => {
      const leg = createStockLeg(Number(hedgeQuantity.toFixed(2)));
      const notional = Math.abs(hedgeQuantity * previous.market.spot);
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      return {
        legs: buildMode
          ? [...previous.legs, leg]
          : [...previous.legs, leg, createCashLeg(-hedgeQuantity * previous.market.spot)],
        action: "Delta hedge",
        cost: buildMode ? 0 : transactionCostForNotional(notional, previous.market),
        resetBaseline: buildMode,
      };
    });
  }

  function protectTail() {
    commit((previous) => {
      const leg = createOptionLeg("long", "put", previous.market, {
        strike: Math.round(previous.market.spot * 0.88),
        expiryDays: 35,
        iv: previous.market.volatility + 0.05,
        quantity: 1,
      });
      const priced = priceLeg(leg, previous.market).value;
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      return {
        legs: buildMode
          ? [...previous.legs, leg]
          : [...previous.legs, leg, createCashLeg(-priced)],
        action: "Bought tail wing",
        cost: buildMode ? 0 : transactionCostForNotional(Math.abs(priced), previous.market),
        resetBaseline: buildMode,
      };
    });
  }

  function clearPortfolio() {
    commit(() => ({
      legs: [createCashLeg(0)],
      action: "Cleared portfolio",
      resetBaseline: true,
    }));
  }

  function changeRegime(regime: MarketState["regime"]) {
    commit((previous) => {
      const nextMarket = { ...previous.market, regime };
      const buildMode = previous.records.length <= 1 && previous.market.day === 0;
      return {
        market: nextMarket,
        action: `Regime set: ${regime}`,
        resetBaseline: buildMode,
      };
    });
  }

  function fastForward() {
    setSpeed((current) => (current >= 4 ? 1 : current * 2));
  }

  function saveCurrentProgress() {
    const scored = recordLevelScore(progress, selectedLevel.id, result.score, result.completed);
    const entry: LeaderboardEntry = {
      id: `run-${Date.now()}`,
      levelId: selectedLevel.id,
      levelTitle: selectedLevel.title,
      score: result.score,
      pnl: attribution.totalPnl,
      drawdown: attribution.maxDrawdown,
      riskViolations: attribution.riskViolations,
      seed: selectedLevel.seed ?? session.market.seed,
      createdAt: new Date().toISOString(),
    };
    setProgress(recordLeaderboardEntry(scored, entry));
  }

  function completeTutorial() {
    const next = { ...progress, tutorialCompleted: true };
    setProgress(next);
    saveProgress(next);
    setShowTutorial(false);
  }

  function fillCustomerOrder(leg: OptionLeg, description: string) {
    commit((previous) => {
      const priced = priceLeg(leg, previous.market).value;
      const cost = transactionCostForNotional(Math.abs(priced), previous.market);
      return {
        legs: [...previous.legs, leg, createCashLeg(-priced)],
        action: description,
        cost,
      };
    });
  }

  function startChallenge(seed: string) {
    const level = generateChallengeLevel(seed, availableLevels.length);
    setCustomLevel(level);
    setRunning(false);
    setSelectedLevelId(level.id);
    setSession(createSession(level));
  }

  function recordCalibration(result: CalibrationResult) {
    setProgress((current) => recordCalibrationResult(current, result));
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand-block">
          <Radar size={24} />
          <div>
            <span>Risk intuition simulator</span>
            <strong>Volatility Forge</strong>
          </div>
        </div>
        <div className="top-stats">
          <button className="secondary-button topbar-button" onClick={() => setShowGuide(true)}>
            <HelpCircle size={16} />
            Guide
          </button>
          <button className="secondary-button topbar-button" onClick={() => setShowTutorial(true)}>
            <BookOpen size={16} />
            Tutorial
          </button>
          <span>
            <CircleDollarSign size={16} />
            {formatMoney(livePnl)}
          </span>
          <span>Completed {progress.completedLevels.length}/{levels.length}</span>
          <span>Day {session.market.day}</span>
        </div>
      </header>

      <main className="game-grid">
        <div className="left-column">
          <LevelBriefing
            levels={availableLevels}
            selectedLevel={selectedLevel}
            progress={progress}
            result={result}
            onSelectLevel={selectLevel}
            onSaveProgress={saveCurrentProgress}
          />
          <GameModesPanel
            levels={availableLevels}
            progress={progress}
            onSelectLevel={selectLevel}
            onStartChallenge={startChallenge}
          />
          <MarketWeatherView
            market={session.market}
            records={session.records}
            scriptedRegime={selectedLevel.initialMarket.regime}
            running={running}
            speed={speed}
            onRegimeChange={changeRegime}
            onToggleRun={() => setRunning((value) => !value)}
            onStep={stepMarket}
            onFast={fastForward}
            onRestart={restartLevel}
          />
        </div>

        <div className="center-column">
          <GreekDashboard market={session.market} snapshot={snapshot} pnl={livePnl} />
          <RiskLimitPanel market={session.market} snapshot={snapshot} attribution={attribution} />
          <div className="chart-grid">
            <PayoffChart legs={session.legs} market={session.market} />
            <ScenarioChart legs={session.legs} market={session.market} />
          </div>
          <VolSurfaceMap market={session.market} legs={session.legs} />
          <ReplayPanel
            attribution={attribution}
            records={session.records}
            level={selectedLevel}
            result={result}
          />
        </div>

        <div className="right-column">
          <PortfolioBuilder
            legs={session.legs}
            market={session.market}
            snapshot={snapshot}
            onAddTemplate={addTemplate}
            onUpdateLeg={updateLeg}
            onRemoveLeg={removeLeg}
            onDeltaHedge={deltaHedge}
            onProtectTail={protectTail}
            onClear={clearPortfolio}
          />
          <MarketMakerArena market={session.market} snapshot={snapshot} onFill={fillCustomerOrder} />
          <ProbabilityPit
            level={selectedLevel}
            records={session.records}
            attribution={attribution}
            onSubmit={recordCalibration}
          />
        </div>
      </main>

      {showTutorial && (
        <TutorialOverlay
          forced={!progress.tutorialCompleted}
          onComplete={completeTutorial}
          onClose={() => setShowTutorial(false)}
        />
      )}
      {showGuide && <ReferenceGuideOverlay onClose={() => setShowGuide(false)} />}
    </div>
  );
}

function createLegFromTemplate(template: LegTemplate, market: MarketState): PortfolioLeg {
  if (template === "stock") {
    return createStockLeg(-10);
  }
  if (template === "cash") {
    return createCashLeg(250);
  }
  if (template === "long-call") {
    return createOptionLeg("long", "call", market);
  }
  if (template === "short-call") {
    return createOptionLeg("short", "call", market, { strike: Math.round(market.spot * 1.08) });
  }
  if (template === "long-put") {
    return createOptionLeg("long", "put", market);
  }
  return createOptionLeg("short", "put", market, { strike: Math.round(market.spot * 0.92) });
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function formatMoney(value: number): string {
  return `${value < 0 ? "-" : ""}$${Math.abs(value).toFixed(2)}`;
}
