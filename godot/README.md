# Volatility Forge 2D (Godot)

这是现有 React 浏览器版旁边的独立 Godot 4 版本。它保留期权风险训练的核心，但重新组织为更清楚的四段流程：

1. **Mission**：只展示推荐任务、目标和正式/练习边界。
2. **Build**：搭建组合，并在运行前看 Greeks 与 payoff。
3. **Run**：先提交概率，再逐日推进、对冲、报价或管理尾部风险。
4. **Review**：按目标逐项结算，解释 P&L、成本、回撤和风险标记。

## 主要改进

- 固定 mission horizon，到期自动暂停并结算。
- `market_steps` 与普通编辑/交易操作分开，不能靠反复操作凑步数。
- 运行中的清仓是有成本的真实交易，不会删除 replay、回撤或成本历史。
- Training override 会把 run 标为 Practice，不能进入正式 leaderboard。
- 概率必须在第一步市场运行前提交，Brier score 可成为正式目标。
- 做市成交使用玩家实际 bid/ask，而不是重新按理论价入账。
- 结构任务校验非零数量、方向、行权价顺序和比例。
- 只有完成且未使用练习覆盖的 run 才能保存；同一 run 不能重复写榜。
- 首次引导只有三步，始终可以跳过；主操作保持 48px 高度并支持键盘。

## 运行

需要 Godot 4.7 或更高版本：

```powershell
godot --path godot --editor
```

直接运行：

```powershell
godot --path godot
```

无窗口验证：

```powershell
npm run godot:verify
```

该命令会依次检查项目解析、规则防作弊、定价引擎、完整主流程和主场景启动；Windows 上也会自动查找通过 `winget` 安装的 Godot console 可执行文件。

## 键盘

- `1` / `2` / `3` / `4`：Mission / Build / Run / Review
- `Space`：Run / Pause
- `N`：推进一个市场日
- `Esc`：关闭引导或弹层

界面使用真实窗口尺寸响应式重排；窄窗口会切换为单列卡片和双列行情摘要，不会把 1440px 画布整体缩小成难以阅读的字。

## 目录

```text
godot/
  project.godot
  scenes/                 # 主场景
  scripts/engine/         # 定价、Greeks、市场、组合、归因
  scripts/game/           # 关卡、目标、评分、挑战、保存
  scripts/ui/             # 界面、主题与绘制控件
  tests/                  # headless 验证
```

进度保存在 Godot 的 `user://` 目录中，不连接真实交易账户，也不读取外部行情。
