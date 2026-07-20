# Volatility Forge

Volatility Forge 是一个使用 Godot 4.7 制作的 2D 期权风险训练游戏。玩家通过 `Mission → Build → Run → Review` 四段流程，练习组合构建、Greeks 管理、市场路径判断和 P&L 归因。

> 本项目只使用模拟市场数据，不连接真实交易账户，也不构成投资建议。

## 当前版本

仓库现在只保留 Godot 2D 版本。原先的 Vite + React 浏览器原型已经移除；历史代码仍可从 Git 提交 `a8c8cb1` 或合并前的仓库历史中找回。

Godot 项目位于 [`godot/`](godot/README.md)。

## 启动

需要 Godot 4.7 或更高版本。

直接运行游戏：

```powershell
godot --path godot
```

在编辑器中打开：

```powershell
godot --editor --path godot
```

也可以在 Godot Project Manager 中导入 [`godot/project.godot`](godot/project.godot)，然后按 `F6` 或右上角运行按钮。

## 验证

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/godot-verify.ps1
```

验证脚本会自动寻找本机 Godot console，并依次执行项目解析、规则、定价引擎、集成流程和主场景冒烟测试。

## 操作

- `1` / `2` / `3` / `4`：切换 Mission / Build / Run / Review
- `Space`：运行或暂停
- `N`：推进一个市场日
- `Esc`：关闭引导或弹层

## 核心内容

- Black-Scholes 定价与组合 Greeks
- 确定性市场模拟、流动性和事件冲击
- 固定任务周期与正式/练习模式隔离
- Delta 对冲、尾部保护和真实交易成本
- P&L 归因、回撤、风险违规与操作历史
- 12 个核心任务、6 个最终试炼和可复现挑战
- 本地进度、成绩和排行榜记录
- 面向桌面和紧凑窗口的原生 Godot 2D 界面

## OpenAI Build Week: Codex and GPT-5.6

Volatility Forge was developed with Codex as an active engineering collaborator running GPT-5.6. The human author set the product direction, options-risk rules, learning goals, and final design decisions; Codex helped turn those decisions into a tested native Godot project.

- **Architecture and implementation:** Codex inspected the original browser prototype, planned the Godot 4.7 port, and implemented modular GDScript systems for pricing, market simulation, portfolio state, mission rules, scoring, persistence, and UI.
- **Gameplay reasoning:** GPT-5.6 helped define fixed mission horizons, forecast-before-reveal rules, official versus practice runs, transaction-cost handling, deterministic seeds, immutable replay records, and explainable P&L attribution.
- **Godot workflow:** Codex configured Godot and Godot MCP, launched the editor and project, inspected debug output, and used the running desktop game as a feedback loop while refining the interface.
- **Visual iteration:** Codex translated supplied visual references into a quieter high-contrast design, then checked typography, spacing, responsive layouts, and interaction states in the native app.
- **Verification:** Codex added and ran headless rules, pricing-engine, integration, and main-flow smoke tests, and reviewed the Git diff before the changes were merged through pull requests.

The result is not a generated mockup: it is a playable Godot application whose simulations, risk limits, scoring, replay, and persistence are exercised by automated tests.

## 目录

```text
godot/
  project.godot
  scenes/                 # 主场景
  scripts/engine/         # 定价、市场、组合和归因
  scripts/game/           # 任务、规则、评分和进度
  scripts/ui/             # 主界面、主题和绘制控件
  tests/                  # Headless 集成测试
scripts/
  godot-verify.ps1        # 完整验证入口
```

Godot 导入缓存、导出文件、构建产物和日志均不会提交到 Git。游戏进度保存在 Godot 的 `user://` 目录。
