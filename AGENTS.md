# Repository Guidelines

## Project Structure & Module Organization

This repository contains the Godot 4.7 2D game Volatility Forge. The project root is `godot/`; `godot/scenes/` contains scenes, `godot/scripts/engine/` contains pricing and simulation logic, `godot/scripts/game/` contains missions, rules, scoring, and persistence, and `godot/scripts/ui/` contains interface code and custom controls. Headless tests live in `godot/tests/`, while the repository-level verification entrypoint is `scripts/godot-verify.ps1`.

## Build, Test, and Development Commands

- `godot --editor --path godot`: open the project in the Godot editor.
- `godot --path godot`: run the game directly.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/godot-verify.ps1`: run project parsing, rules, engine, integration, main-flow, and startup checks.

## Coding Style & Naming Conventions

Use typed GDScript where values cross module boundaries. Keep scripts and methods in snake_case, classes and node types in PascalCase, and constants in UPPER_SNAKE_CASE. Follow the indentation already used by the surrounding GDScript file. Keep comments short and reserve them for non-obvious pricing units, simulation invariants, scoring rules, and persistence constraints.

## Testing Guidelines

Treat `scripts/godot-verify.ps1` as the required pre-commit check. Gameplay rule changes must update or extend the relevant smoke test under `godot/tests/` or `godot/scripts/engine/`. UI changes should be inspected in the Godot runtime at both the normal desktop size and a compact window. Do not treat successful parsing alone as proof that the main flow works.

## Commit & Pull Request Guidelines

Use short imperative commit messages, for example `Remove legacy web prototype` or `Tune volatility mission`. Pull requests should summarize player-visible impact, list verification performed, include screenshots for visual changes, and call out changes to scoring, persistence, pricing units, or generated content.

## Security & Generated Files

Do not commit credentials, real trading data, API keys, logs, Godot import caches, exports, or builds. The game uses simulated market data and stores progress under Godot `user://`.
