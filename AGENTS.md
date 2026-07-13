# Repository Guidelines

## Project Structure & Module Organization

This repository is a Vite + React + TypeScript browser game named Volatility Forge. Application wiring lives in `src/app/App.tsx`; reusable UI panels live in `src/components/`; pricing, portfolio, market simulation, volatility surface, and attribution logic live in `src/engine/`; game content, scoring, tutorial, progress, and procedural level generation live in `src/game/`. Shared types are in `src/types.ts`, global styles are in `src/styles/main.css`, and README screenshots are stored in `docs/screenshots/`. Build output goes to `dist/` and must not be committed.

## Build, Test, and Development Commands

- `npm install`: install dependencies from `package-lock.json`.
- `npm run dev`: start Vite on `127.0.0.1` for local development.
- `npm run build`: run TypeScript checking with `tsc --noEmit`, then build with Vite.
- `npm run preview`: preview the production build locally.
- `npm run goal-audit`: run `scripts/goal-audit.mjs` to verify core feature wiring.
- `npm run verify`: run the full project check (`build` + `goal-audit`).

## Coding Style & Naming Conventions

Use TypeScript and React function components. Keep component files in PascalCase, for example `GreekDashboard.tsx`; keep engine and game modules in camelCase, for example `marketSimulator.ts` and `pnlAttribution.ts`. Prefer explicit types for shared interfaces in `src/types.ts`. Keep comments short and only where they clarify non-obvious pricing, simulation, or scoring behavior. Follow the existing two-space indentation and CSS class naming patterns.

## Testing Guidelines

There is no separate unit test framework configured yet. Treat `npm run verify` as the required pre-commit check. When changing gameplay systems, update `scripts/goal-audit.mjs` if the feature contract changes. For UI changes, manually inspect the local app and refresh screenshots in `docs/screenshots/` only when the README visuals need to change.

## Commit & Pull Request Guidelines

The current history uses concise imperative commit messages, such as `Initial option greeks game`. Keep future messages short and action-oriented, for example `Add volatility surface drill`. Pull requests should include a short summary, verification commands run, screenshots for visible UI changes, and any notes about changed scoring, persistence, or generated level behavior.

## Security & Configuration Tips

Do not commit credentials, real trading data, API keys, logs, `node_modules/`, or `dist/`. This project uses simulated market data and stores player progress in browser `localStorage`.
