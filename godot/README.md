# Volatility Forge 2D

这是 Volatility Forge 当前唯一维护的版本，面向 Godot 4.7。游戏把期权风险训练组织为四段清晰流程：

1. **Mission**：选择任务并查看目标与正式/练习边界。
2. **Build**：搭建组合，观察 Greeks 和到期收益。
3. **Run**：预提交概率，推进市场并管理风险。
4. **Review**：复盘 P&L、成本、回撤和违规记录。

## 主要规则

- 固定 mission horizon，到期自动暂停并结算。
- `market_steps` 与编辑、交易操作分开，不能靠无效操作凑时间。
- 运行中的清仓是有成本的真实交易，不会删除回放和历史。
- Training override 会把 run 标记为 Practice，不能进入正式排行榜。
- 概率必须在第一步市场运行前提交。
- 做市成交使用玩家输入的真实 bid/ask。
- 结构任务检查非零数量、方向、行权价顺序和比例。
- 只有合格且未使用练习覆盖的 run 才会保存。

## 启动

从仓库根目录直接运行：

```powershell
godot --path godot
```

打开编辑器：

```powershell
godot --editor --path godot
```

也可以直接在 Godot Project Manager 中导入 `godot/project.godot`。

## 验证

从仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/godot-verify.ps1
```

## 键盘

- `1` / `2` / `3` / `4`：Mission / Build / Run / Review
- `Space`：Run / Pause
- `N`：推进一个市场日
- `Esc`：关闭引导或弹层

## 项目结构

```text
godot/
  project.godot
  scenes/
  scripts/engine/
  scripts/game/
  scripts/ui/
  tests/
```

游戏使用模拟数据，进度保存在 Godot 的 `user://` 目录。
