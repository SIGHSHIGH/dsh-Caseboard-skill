---
name: caseboard-dev
description: 案情板 CaseBoard（Tauri 2 + React 18 + TS strict + React Flow + SQLite）的编辑技能。当用户要求修改、修复、扩展、调整这个桌面办案应用——画布/节点/关系线、代码视图 DSL、右栏属性、时间线/演示/地图、素材与 OCR、导出 PNG/SVG/PDF/Word、AI 抽取与生图、自动布局、打包发布——先加载本技能，按 Gate 0 八条硬约束与四件套验收流程动手。用户口述现象、或说"帮我改一下这个 app"时也适用。
whenToUse: 任务落在案情板 CaseBoard 仓库（含 docs/MILESTONES.md、src-tauri/ 的目录）内，或用户提到 CaseBoard/案情板/caseboard 的任何功能改动、缺陷修复、发布打包、里程碑收尾。
---

# 案情板 CaseBoard · 编辑技能

你是这个应用的**共同开发者**，不是旁观者。用户可以要你做任何事：改一个按钮文案、加一种导出、修一条关系线的走位、扩一个模型字段、出安装包。本技能给你四样东西：**纪律**（Gate 0）、**地图**（架构）、**尺子**（验收）、**话术**（提示词库）。

## 0. 三十秒定位

| 事实 | 值 |
| --- | --- |
| 仓库根 | 当前工作区（含 `src-tauri/`、`docs/CaseBoard-SPEC.md`、`.git`）——一切命令在这里跑 |
| 版本 | `1.0.0-beta.1`（Beta 1.0，M1–M18 全部验收通过） |
| 权威规格 | `docs/CaseBoard-SPEC.md`（产品 + P0–P7 提示词库） |
| 执行契约 | `docs/MILESTONES.md`（M1–M18 / Gate 0 / 决策记录 D1–D101） |
| 基线（本轮实测） | typecheck 0 error · smoke **871 PASS** · ui-smoke **430 PASS** · bench **75.6 ms**（阈值 300） · build 通过 |
| 没有 npm/pnpm | 必须 `scripts\pnpm.cmd <script>` 或 node 直连 pnpm.cjs |

**一键自检**（推荐每次动手前后各跑一次；`$SKILL` = 本技能所在目录，插件安装后是 `<插件目录>\assets\skills\caseboard-dev`，仓库内开发副本是 `.dsh\skills\caseboard-dev`）：

```powershell
powershell -ExecutionPolicy Bypass -File $SKILL\scripts\check.ps1 -Quick   # 改 lib/commands
powershell -ExecutionPolicy Bypass -File $SKILL\scripts\check.ps1         # 全套五道
```

## 1. 五条不可协商的编辑纪律

1. **一份数据**：`CaseDoc` 只有一个，在 `src/store/docStore.ts`。画布、代码视图、导出、分析全部从它派生；绝不为某个功能缓存第二份文档。
2. **写入只走 Command**：`dispatch(command)` → Immer patch → undo 栈 → 400 ms 防抖落库 → Zustand 广播。组件里不许 `setState({doc})`，不许在 Command 外改 doc。
3. **八条 Gate 0 逐条守**：线型即语义 / AI 只进待确认 / AI 图角标写进像素 / 全中文 + 证据红 `#C0392B` / 本地优先 / 坐标只走 `lib/coords.ts`。全文与代码落点见 `references/03-constraints.md`。
4. **能断言的逻辑不放 services/ 与 .tsx**：`tsconfig.smoke.json` 不编译它们，放错位置 smoke 直接 `require` 失败。业务逻辑进 `lib/`、`serializers/`、`commands/`。
5. **实现与断言同批交付**：新行为必须在 `scripts/smoke.cjs` 开新段（现最大 `[79]`，从 `[80]` 起）或在 `scripts/ui-smoke.cjs` 加断言。只写实现 = 未完成。

## 2. 我要改 X → 读哪份

| 你的情况 | 先读 | 顺手确认 |
| --- | --- | --- |
| 不知道从哪下手 / 用户描述很模糊 | `references/00-workflow.md` 第 1、2 节（四道闸门 + 规模分档） | 先问清"哪个视图、什么行为算改对了" |
| 要碰 model / store / 命令 / 新面板 | `references/01-architecture.md` | 命令工厂怎么写、扩展点排序 |
| 动 `.tsx`、样式、打包、Rust | `references/02-verification.md` | ui-smoke 必须先 build；Tauri 前必须先 build |
| 怕踩 Gate 0 / 加了新颜色 / AI 相关 | `references/03-constraints.md` | 落点行号 + 守着它的断言 |
| 要一份能直接用的作业指令 | `references/04-prompts.md` | 任务型 12 条：缺陷/新面板/新字段/新节点类型/新导出/自检项/DSL/发布… |
| 要按“流程阶段”下指令 | `references/05-prompts.md` | 流程型 10 条：上下文注入→开工计划→定点实现→验收报批→自审→收尾→回退 |

## 3. 五分钟定位配方（grep 速查）

```bash
grep -rn "用户看到的那句话" src/components          # 文案 → 组件
grep -n  "RightPanel\|TopBar\|LeftPanel" src/App.tsx # 面板挂载点
grep -rn "dispatch(" src/components | grep -i 关键词  # 谁在写这份数据
grep -rn "thickness" src --include=*.ts --include=*.tsx # 字段的读写面
grep -n  "\[79\]" scripts/smoke.cjs                 # 现有断言怎么写的
grep -n  "cb-" scripts/ui-smoke.cjs                 # 现有 UI 断言选择器
grep -n  "^| D10" docs/MILESTONES.md          # 决策记录（表格行 `| D101 | …`）
grep -n  "^## P" docs/CaseBoard-SPEC.md             # 产品规格分节
```

## 4. 标准动作（四步，别跳）

1. **侦察**（只读）：`grep -n "<符号>"` 定位 → `read` 相关段落 → 找到对应里程碑与 D 决策编号。**没找到规格依据就先问用户**，不要自创产品行为。
2. **计划**（3–6 条）：涉及文件 + 验收标准 + 属于哪一档（XS/S/M/L）。涉及模型或语法时，把迁移与断言一起列进去。**用户确认后再写码**。
3. **实现**：`edit` 定点替换（超过 500 行的既有文件禁止整份 `write` 回去，`read` 有约 924 行截断上限，会静默丢内容）。
4. **验证 + 记录**：按 §2 的台阶跑 → `CHANGELOG.md` 追加条目 → 涉决策写 `docs/MILESTONES.md` §6 → 汇报。

## 5. 汇报格式（照抄）

```
改了什么：<一句话>
涉及文件：src/xxx.ts:12-40 …
验收：typecheck 0 error · smoke 873 PASS · ui-smoke 432 PASS · bench 76 ms · build ok
回归风险：<受影响行为 + 守着它的断言/段号>
未自动验证：<拖拽手感、真实渲染、安装包等，逐条点名>
未做/待办：<明确列出没碰的部分>
```

## 6. 八个高频坑（每条都真实踩过）

| 坑 | 症状 | 处置 |
| --- | --- | --- |
| 逻辑写进 `services/` 或 `.tsx` | smoke `Cannot find module` | 下沉到 `lib/`/`serializers/` |
| 整份 `read` 再整份 `write` | 文件静默少几百行 | 只用 `edit`，改完 `git diff` 看行数 |
| 忘了 `TMP` 指到 `.tmp-esbuild` | esbuild `Access is denied` | 见 `references/00-workflow.md` 第 4 节 |
| 用 `pnpm` / `pnpm tauri` | `spawn EPERM` / `unrecognized subcommand` | `scripts\pnpm.cmd`、`node scripts/tauri-cli.cjs` |
| 忘了 `build` 就 `ui-smoke` | 找不到 `dist/assets` | 先 `scripts\pnpm.cmd build` |
| 忘了 `build` 就 `tauri build` | exe 里是旧前端，自检照样绿 | `beforeBuildCommand` 是空的，必须手动 build |
| 改了 `.grammar` 没重生成 | 旧解析器全绿但新语法被拒 | `node scripts/build-grammar.mjs` |
| 残留 `caseboard.exe` | 链接失败 / 文件占用 | `Get-Process caseboard \| Stop-Process -Force` |

## 7. 交付前最后一眼

- [ ] 四件套数字是**这一轮实际跑出来的**，不是抄 CHANGELOG
- [ ] 新行为有对应断言（smoke 段号或 ui-smoke 断言）
- [ ] 旧断言一条没删、阈值一个没放宽
- [ ] 界面文案全中文；没有新增十六进制色值（令牌在 `src/index.css` + `lib/theme.ts`）
- [ ] 版本号三处同步（`package.json` / `src-tauri/tauri.conf.json` / `src-tauri/Cargo.toml`）——只有发布才动
- [ ] `CHANGELOG.md` 有条目；决策有 D 编号；里程碑收尾打了 `ms/M<n>`
