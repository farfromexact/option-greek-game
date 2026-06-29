import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();

function read(path) {
  return readFileSync(join(root, path), "utf8");
}

function assert(condition, label, evidence) {
  if (!condition) {
    failures.push({ label, evidence });
    return;
  }
  passes.push({ label, evidence });
}

function includes(path, needle) {
  return read(path).includes(needle);
}

function matches(path, pattern) {
  return pattern.test(read(path));
}

const failures = [];
const passes = [];

const requiredFiles = [
  "src/engine/blackScholes.ts",
  "src/engine/portfolio.ts",
  "src/engine/marketSimulator.ts",
  "src/engine/pnlAttribution.ts",
  "src/engine/volSurface.ts",
  "src/game/procedural.ts",
  "src/game/progression.ts",
  "src/components/ReplayPanel.tsx",
  "src/components/RiskLimitPanel.tsx",
  "src/components/VolSurfaceMap.tsx",
  "src/components/MarketMakerArena.tsx",
  "src/components/GameModesPanel.tsx",
  "src/components/ProbabilityPit.tsx",
  "src/components/TutorialOverlay.tsx",
  "src/components/ReferenceGuideOverlay.tsx",
  "src/app/App.tsx",
  "src/game/tutorial.ts",
  "src/game/referenceGuide.ts",
  "src/styles/main.css",
];

for (const file of requiredFiles) {
  assert(existsSync(join(root, file)), `Required file exists: ${file}`, file);
}

// v0.2
assert(
  includes("src/engine/pnlAttribution.ts", "gammaScalpEdge") &&
    includes("src/components/ReplayPanel.tsx", "RV-IV"),
  "v0.2 gamma scalping attribution is implemented",
  "pnlAttribution.ts gammaScalpEdge + ReplayPanel RV-IV",
);
assert(
  includes("src/engine/marketSimulator.ts", "transactionCostForNotional") &&
    includes("src/app/App.tsx", "transactionCostForNotional"),
  "v0.2 transaction costs are modeled and applied",
  "marketSimulator.ts + App.tsx",
);
assert(
  includes("src/components/ReplayPanel.tsx", "Replay step") &&
    includes("src/components/ReplayPanel.tsx", "type=\"range\""),
  "v0.2 market replay scrubber exists",
  "ReplayPanel.tsx",
);
assert(
  includes("src/engine/marketSimulator.ts", "earnings_event") &&
    includes("src/engine/marketSimulator.ts", "eventVolCrush"),
  "v0.2 earnings event and vol crush are simulated",
  "marketSimulator.ts",
);
assert(
  includes("src/components/RiskLimitPanel.tsx", "Risk shield") &&
    includes("src/app/App.tsx", "RiskLimitPanel"),
  "v0.2 risk limit UI is wired",
  "RiskLimitPanel.tsx + App.tsx",
);

// v0.3
assert(
  includes("src/engine/volSurface.ts", "buildVolSurface") &&
    includes("src/components/VolSurfaceMap.tsx", "surface-grid"),
  "v0.3 vol surface map is implemented",
  "volSurface.ts + VolSurfaceMap.tsx",
);
assert(
  includes("src/types.ts", "skew") &&
    includes("src/types.ts", "termSlope") &&
    includes("src/types.ts", "surfaceShock"),
  "v0.3 skew, term structure, and surface shock live in MarketState",
  "types.ts",
);
assert(
  includes("src/engine/volSurface.ts", "calculateVegaBuckets") &&
    includes("src/components/VolSurfaceMap.tsx", "bucket-list"),
  "v0.3 vega buckets are calculated and displayed",
  "volSurface.ts + VolSurfaceMap.tsx",
);

// v0.4
assert(
  includes("src/components/MarketMakerArena.tsx", "CustomerOrder") &&
    includes("src/components/MarketMakerArena.tsx", "toxicity"),
  "v0.4 market maker arena has customer flow and informed/toxic signal",
  "MarketMakerArena.tsx",
);
assert(
  includes("src/components/MarketMakerArena.tsx", "Width") &&
    includes("src/components/MarketMakerArena.tsx", "Inv Δ") &&
    includes("src/components/MarketMakerArena.tsx", "Inv V"),
  "v0.4 quote width and inventory risk are visible",
  "MarketMakerArena.tsx",
);

// v1.0
assert(
  matches("src/game/procedural.ts", /generateProceduralLevels\(count = 108\)/) &&
    includes("src/game/levels.ts", "generateProceduralLevels(108)"),
  "v1.0 has 100+ procedural missions",
  "procedural.ts + levels.ts",
);
assert(
  includes("src/game/procedural.ts", "janeStreetTrials") &&
    (read("src/game/procedural.ts").match(/makeTrial\(/g) ?? []).length >= 6,
  "v1.0 Jane Street Trials are configured",
  "procedural.ts",
);
assert(
  includes("src/game/progression.ts", "leaderboard") &&
    includes("src/components/GameModesPanel.tsx", "leaderboard-row"),
  "v1.0 leaderboard is persisted and displayed",
  "progression.ts + GameModesPanel.tsx",
);
assert(
  includes("src/components/GameModesPanel.tsx", "Challenge seed") &&
    includes("src/app/App.tsx", "generateChallengeLevel"),
  "v1.0 challenge seeds launch generated missions",
  "GameModesPanel.tsx + App.tsx",
);
assert(
  includes("src/types.ts", "vanna") &&
    includes("src/types.ts", "vomma") &&
    includes("src/types.ts", "charm") &&
    includes("src/types.ts", "speed") &&
    includes("src/types.ts", "color") &&
    includes("src/engine/blackScholes.ts", "vanna"),
  "v1.0 advanced Greeks are calculated",
  "types.ts + blackScholes.ts",
);
assert(
  includes("src/components/ProbabilityPit.tsx", "Average Brier") &&
    includes("src/game/progression.ts", "calibrationHistory"),
  "v1.0 probability calibration mode is implemented and persisted",
  "ProbabilityPit.tsx + progression.ts",
);
assert(
  includes("src/game/tutorial.ts", "Tutorial completion route") &&
    includes("src/game/tutorial.ts", "1.0 play-through route") &&
    includes("src/game/tutorial.ts", "Vol Surface Cartographer") &&
    includes("src/game/tutorial.ts", "Market Maker Arena") &&
    includes("src/game/tutorial.ts", "Probability Pit") &&
    includes("src/game/tutorial.ts", "Challenge seed") &&
    includes("src/game/tutorial.ts", "Jane Street Trials") &&
    includes("src/game/tutorial.ts", "leaderboard"),
  "v1.0 tutorial teaches the full play-through route",
  "tutorial.ts",
);
assert(
  includes("src/components/TutorialOverlay.tsx", "Play-through checkpoints") &&
    includes("src/components/TutorialOverlay.tsx", "Unlock:") &&
    includes("src/styles/main.css", ".tutorial-route"),
  "Tutorial UI displays route checkpoints and unlocked systems",
  "TutorialOverlay.tsx + main.css",
);
assert(
  includes("src/components/LevelBriefing.tsx", "Save local run") &&
    includes("src/components/LevelBriefing.tsx", "Local browser save") &&
    includes("src/components/LevelBriefing.tsx", "level-group-tabs") &&
    includes("src/styles/main.css", ".level-group-tabs"),
  "Level picker is grouped and local save is explicit",
  "LevelBriefing.tsx + main.css",
);
assert(
  includes("src/components/GameModesPanel.tsx", "Jane Street Trials") &&
    includes("src/components/GameModesPanel.tsx", "same generated market") &&
    includes("src/components/GameModesPanel.tsx", "seedPresets") &&
    includes("src/styles/main.css", ".seed-presets"),
  "v1.0 systems panel labels trials and explains challenge seeds",
  "GameModesPanel.tsx + main.css",
);
assert(
  includes("src/components/MarketWeatherView.tsx", "Training override") &&
    includes("src/components/MarketWeatherView.tsx", "Scripted:") &&
    includes("src/components/MarketWeatherView.tsx", "weather-map-legend") &&
    includes("src/styles/main.css", ".vol-pressure") &&
    includes("src/app/App.tsx", "scriptedRegime"),
  "Market weather distinguishes scripted level weather from sandbox override",
  "MarketWeatherView.tsx + main.css + App.tsx",
);
assert(
  includes("src/app/App.tsx", "Guide") &&
    includes("src/app/App.tsx", "ReferenceGuideOverlay") &&
    includes("src/game/referenceGuide.ts", "Icons") &&
    includes("src/game/referenceGuide.ts", "Visual Patterns") &&
    includes("src/game/referenceGuide.ts", "Operations") &&
    includes("src/game/referenceGuide.ts", "Panels"),
  "Standalone guide is available outside the tutorial",
  "App.tsx + referenceGuide.ts",
);
assert(
  includes("src/game/referenceGuide.ts", "Save local run") &&
    includes("src/game/referenceGuide.ts", "Training override weather") &&
    includes("src/game/referenceGuide.ts", "Market weather map") &&
    includes("src/game/referenceGuide.ts", "Scenario heat grid") &&
    includes("src/game/referenceGuide.ts", "Quote customer") &&
    includes("src/components/ReferenceGuideOverlay.tsx", "GuideEntryCard") &&
    includes("src/styles/main.css", ".guide-entry-grid"),
  "Guide explains icons, visual patterns, and operations",
  "referenceGuide.ts + ReferenceGuideOverlay.tsx + main.css",
);

// Responsive coverage for the newly added tool surfaces.
assert(
  includes("src/styles/main.css", "@media (max-width: 820px)") &&
    includes("src/styles/main.css", ".surface-meta") &&
    includes("src/styles/main.css", ".probability-list label") &&
    includes("src/styles/main.css", ".replay-scrubber") &&
    includes("src/styles/main.css", ".tutorial-body") &&
    includes("src/styles/main.css", ".level-group-tabs") &&
    includes("src/styles/main.css", ".weather-map-legend") &&
    includes("src/styles/main.css", ".guide-body"),
  "Responsive CSS includes new v1.0 panels",
  "main.css",
);

const report = {
  passed: passes.length,
  failed: failures.length,
  failures,
};

if (failures.length > 0) {
  console.error(JSON.stringify(report, null, 2));
  process.exit(1);
}

console.log(JSON.stringify(report, null, 2));
