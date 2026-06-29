import type { CalibrationResult, LeaderboardEntry } from "../types";

export type ProgressState = {
  completedLevels: string[];
  bestScores: Record<string, number>;
  lastLevelId: string;
  tutorialCompleted: boolean;
  leaderboard: LeaderboardEntry[];
  calibrationHistory: CalibrationResult[];
};

const STORAGE_KEY = "volatility-forge-progress-v1";

const defaultProgress: ProgressState = {
  completedLevels: [],
  bestScores: {},
  lastLevelId: "delta-wind",
  tutorialCompleted: false,
  leaderboard: [],
  calibrationHistory: [],
};

export function loadProgress(): ProgressState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return defaultProgress;
    }
    return {
      ...defaultProgress,
      ...(JSON.parse(raw) as Partial<ProgressState>),
    };
  } catch {
    return defaultProgress;
  }
}

export function saveProgress(progress: ProgressState): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
}

export function recordLevelScore(
  progress: ProgressState,
  levelId: string,
  score: number,
  completed: boolean,
): ProgressState {
  const completedLevels = completed
    ? Array.from(new Set([...progress.completedLevels, levelId]))
    : progress.completedLevels;
  const bestScores = {
    ...progress.bestScores,
    [levelId]: Math.max(progress.bestScores[levelId] ?? 0, Math.round(score)),
  };
  const next = {
    completedLevels,
    bestScores,
    lastLevelId: levelId,
    tutorialCompleted: progress.tutorialCompleted,
    leaderboard: progress.leaderboard,
    calibrationHistory: progress.calibrationHistory,
  };
  saveProgress(next);
  return next;
}

export function recordLeaderboardEntry(
  progress: ProgressState,
  entry: LeaderboardEntry,
): ProgressState {
  const next = {
    ...progress,
    leaderboard: [...progress.leaderboard, entry]
      .sort((a, b) => b.score - a.score)
      .slice(0, 25),
  };
  saveProgress(next);
  return next;
}

export function recordCalibrationResult(
  progress: ProgressState,
  result: CalibrationResult,
): ProgressState {
  const next = {
    ...progress,
    calibrationHistory: [result, ...progress.calibrationHistory].slice(0, 30),
  };
  saveProgress(next);
  return next;
}
