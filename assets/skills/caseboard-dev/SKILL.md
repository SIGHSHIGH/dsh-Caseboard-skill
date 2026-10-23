---
name: caseboard-dev
description: 案情板 CaseBoard 的编辑技能，覆盖双平台：Windows 桌面版（Tauri 2 + React 18 + TS strict + React Flow + SQLite）与 HarmonyOS 移植版（ArkWeb 内嵌同一套 React 前端 + ArkTS 桥）。当用户要求修改、修复、扩展、调整这个办案应用——画布/节点/关系线/集中钉子/钉集/红线、代码视图 DSL、右栏属性、时间线/演示/地图、素材与 OCR、导出 PNG/SVG/PDF/Word、AI 抽取与生图、自动布局、触屏与平板适配、鸿蒙桥与 HAP 打包、双平台回填、桌面打包发布——先加载本技能，按 Gate 0 八条硬约束与对应平台的验收流程动手。用户口述现象、或说"帮我改一下这个 app"时也适用。
whenToUse: 任务落在案情板 CaseBoard 仓库（含 docs/MILESTONES.md、src-tauri/、platforms/harmony/）内，或用户提到 CaseBoard/案情板/caseboard、鸿蒙/ArkWeb/平板/集中钉/红线/钉集 的任何功能改动、缺陷修复、里程碑收尾、发布打包、双平台同步。
---

# 案情板 CaseBoard · 编辑技能

你是这个应用的**共同开发者**，不是旁观者。用户可以要你做任何事：改一个按钮文案、加一种导出、修一条关系线的走位、给平板加长按手势、把鸿蒙版的交互回填到桌面、出安装包或 HAP。本技能给你五样东西：**纪律**（Gate 0 + 双平台同步）、**地图**（架构）、**尺子**（验收）、**话术**（提示词库）、**鸿蒙手册**（`references/06-harmony.md`）。

## 0. 三十秒定位

| 事实 | 值 |
| --- | --- |
| 仓库根 | 当前工作区（含 `src-tauri/`、`docs/CaseBoard-SPEC.md`、`platforms/harmony/`、`.git`）——命令在这里跑 |
| 两个前端 | 桌面 `src/`（Tauri + WebView2）；鸿蒙 `platforms/harmony/web/src/`（ArkWeb 内嵌 `$rawfile`）——**同源镜像，不是共用代码** |
| 分支 | 桌面主干 `main`（本地可在任意目录另开 worktree 检出一份干净的 main）；鸿蒙线 `harmony`（含一份较早的根 `src/` 镜像）——**动手前先 `git branch --show-current`** |
| 版本 | `1.0.0-beta.1`（Beta 1.0，桌面 M1–M18 全部验收通过）；鸿蒙 `AppScope/app.json5` versionName `1.0.0` |
| 权威规格 | `docs/CaseBoard-SPEC.md`（产品 + P0–P7 提示词库） |
| 执行契约 | `docs/MILESTONES.md`（M1–M18 / Gate 0 / 决策记录 D1–D101） |
| 鸿蒙台账 | `platforms/harmony/docs/HARMONY-MILESTONES.md`（H0–H5.6.3 有正式结项；更新的 H5.7–H5.10 只在 `platforms/harmony/CHANGELOG.md` 与 git log 里）＋差分 `platforms/harmony/docs/FEATURE-DIFF-WIN-VS-HARMONY.md` |
| 桌面基线（Beta 1.0 记录） | typecheck 0 error · smoke **871 PASS** · ui-smoke **430 PASS** · bench **≈74.5 ms**（阈值 300）· build 通过 —— 但**必须自己实跑**，且要在 main 工作树里跑 |
| 鸿蒙基线 | `scripts/accept-h5.ps1` 现存 **45** 条上机断言全 PASS（模拟器 `127.0.0.1:5555`）；H5.11（抽屉/小地图让位）目前是**未提交的工作区改动** |
| 没有 npm/pnpm | 必须 `scripts\pnpm.cmd <script>` 或 node 直连 pnpm.cjs |

**一键自检**（推荐每次动手前后各跑一次；`$SKILL` = 本技能所在目录，插件安装后是 `<插件目录>\assets\skills\caseboard-dev`，仓库内开发副本是 `.dsh\skills\caseboard-dev`）：

```powershell
powershell -ExecutionPolicy Bypass -File $SKILL\scripts\check.ps1 -Quick   # 改 lib/commands
powershell -ExecutionPolicy Bypass -File $SKILL\scripts\check.ps1         # 全套五道
```

## 1. 六条不可协商的编辑纪律

1. **一份数据**：`CaseDoc` 只有一个，在 `src/store/docStore.ts`（鸿蒙镜像同位置）。画布、代码视图、导出、分析全部从它派生；绝不为某个功能缓存第二份文档。
2. **写入只走 Command**：`dispatch(command)` → Immer patch → undo 栈 → 400 ms 防抖落库 → Zustand 广播。组件里不许 `setState({doc})`，不许在 Command 外改 doc。
3. **八条 Gate 0 逐条守**：线型即语义 / AI 只进待确认 / AI 图角标写进像素 / 全中文 + 证据红 `#C0392B` / 本地优先 / 坐标只走 `lib/coords.ts`。全文与代码落点见 `references/03-constraints.md`。
4. **能断言的逻辑不放 services/ 与 .tsx**：`tsconfig.smoke.json` 不编译它们，放错位置 smoke 直接 `require` 失败。业务逻辑进 `lib/`、`serializers/`、`commands/`。
5. **实现与断言同批交付**：新行为必须在 `scripts/smoke.cjs` 开新段（现最大 `[79]`，从 `[80]` 起）或在 `scripts/ui-smoke.cjs` 加断言；碰鸿蒙就在 `platforms/harmony/scripts/accept-h*.ps1` 加一条 Assertion。只写实现 = 未完成。
6. **双平台先定落点**：业务逻辑一律**先在 `main` 的 `src/` 落地**，再逐文件同步到 `platforms/harmony/web/src/`（白名单差异见 `references/06-harmony.md` 第 2 节）；鸿蒙侧改动都要回答「该不该回填桌面」，回填要记台账 `docs/HARMONY-MILESTONES.md` 的「桌面回填（main）」行。在 `harmony` 分支直接改根 `src/` 是最常见的白干。

## 2. 我要改 X → 读哪份

| 你的情况 | 先读 | 顺手确认 |
| --- | --- | --- |
| 不知道从哪下手 / 用户描述很模糊 | `references/00-workflow.md` 第 1、2 节（五道闸门 + 规模分档） | 先问清"哪个视图、什么行为算改对了" |
| 要碰 model / store / 命令 / 新面板 | `references/01-architecture.md` | 命令工厂怎么写、扩展点排序 |
| 动 `.tsx`、样式、打包、Rust | `references/02-verification.md` | ui-smoke 必须先 build；Tauri 前必须先 build |
| 怕踩 Gate 0 / 加了新颜色 / AI 相关 | `references/03-constraints.md` | 落点行号 + 守着它的断言 |
| 要一份能直接用的作业指令 | `references/04-prompts.md` | 任务型 16 条：缺陷/新面板/新字段/新节点类型/新导出/自检项/DSL/发布/触屏/钉集/回填… |
| 要按"流程阶段"下指令 | `references/05-prompts.md` | 流程型 10 条：上下文注入→开工计划→定点实现→验收报批→自审→收尾→回退 |
| 碰 `platforms/harmony/`、ArkTS 桥、HAP、平板/触屏、双平台同步 | `references/06-harmony.md` | 分支与落点、镜像白名单、ArkWeb 硬结论、accept 链、回填现状 |

## 3. 五分钟定位配方（grep 速查）

```bash
grep -rn "用户看到的那句话" src/components          # 文案 → 组件（鸿蒙侧换 platforms/harmony/web/src）
grep -n  "RightPanel\|TopBar\|LeftPanel" src/App.tsx # 面板挂载点
grep -rn "dispatch(" src/components | grep -i 关键词  # 谁在写这份数据
grep -rn "thickness" src --include=*.ts --include=*.tsx # 字段的读写面
grep -n  "\[79\]" scripts/smoke.cjs                 # 现有断言怎么写的
grep -n  "cb-" scripts/ui-smoke.cjs                 # 现有 UI 断言选择器
grep -n  "^| D10" docs/MILESTONES.md          # 决策记录（表格行 `| D101 | …`）
grep -n  "^## P" docs/CaseBoard-SPEC.md             # 产品规格分节
git branch --show-current; git branch -vv            # 我在哪条线、main 挂在哪
grep -n "Add-Result\|Add-Check" platforms/harmony/scripts/accept-h5.ps1   # 鸿蒙断言怎么写
grep -n "A[0-9]\|B[0-9]" platforms/harmony/docs/FEATURE-DIFF-WIN-VS-HARMONY.md # 回填候选清单
```

## 4. 标准动作（四步，别跳）

1. **侦察**（只读）：先 `git branch --show-current` 确认平台与落点 → `grep -n "<符号>"` 定位 → `read` 相关段落 → 找到对应里程碑与 D 决策编号。**没找到规格依据就先问用户**，不要自创产品行为。
2. **计划**（3–6 条）：涉及文件 + 验收标准 + 属于哪一档（XS/S/M/L）+ 是否需要同步鸿蒙副本。涉及模型或语法时，把迁移与断言一起列进去。**用户确认后再写码**。
3. **实现**：`edit` 定点替换（超过 500 行的既有文件禁止整份 `write` 回去，`read` 有约 924 行截断上限，会静默丢内容）。
4. **验证 + 记录**：按对应平台的台阶跑（桌面四件套 / 鸿蒙 `accept-h*.ps1`）→ `CHANGELOG.md` 追加条目（回填要两侧都记）→ 涉决策写 `docs/MILESTONES.md` §6 → 汇报。

## 5. 汇报格式（照抄）

```
改了什么：<一句话>
涉及文件：src/xxx.ts:12-40 …（鸿蒙侧另列 platforms/harmony/web/src/…）
平台落点：<桌面 main / 鸿蒙 harmony / 两者同步>
验收：typecheck 0 error · smoke 873 PASS · ui-smoke 432 PASS · bench 76 ms · build ok
回归风险：<受影响行为 + 守着它的断言/段号>
未自动验证：<拖拽手感、真实渲染、安装包、真机触屏等，逐条点名>
未做/待办：<明确列出没碰的部分，例如"鸿蒙副本未同步">
```

## 6. 十二个高频坑（每条都真实踩过）

| 坑 | 症状 | 处置 |
| --- | --- | --- |
| 在 `harmony` 分支改根 `src/` 当成桌面版 | 改到一份落后主线若干个提交的镜像，白干 | 桌面改动去 main 工作树 `F:\DSH PROJECT\.cb-main` |
| 把 `platforms/harmony/web/src` 当随手镜像改 | 两套前端越走越远 | 先改 main `src/`，再按白名单逐文件同步 |
| 逻辑写进 `services/` 或 `.tsx` | smoke `Cannot find module` | 下沉到 `lib/`/`serializers/` |
| 整份 `read` 再整份 `write` | 文件静默少几百行 | 只用 `edit`，改完 `git diff` 看行数 |
| 忘了 `TMP` 指到 `.tmp-esbuild` | esbuild `Access is denied` | 见 `references/00-workflow.md` 第 4 节 |
| 用 `pnpm` / `pnpm tauri` | `spawn EPERM` / `unrecognized subcommand` | `scripts\pnpm.cmd`、`node scripts/tauri-cli.cjs` |
| 忘了 `build` 就 `ui-smoke` | 找不到 `dist/assets` | 先 `scripts\pnpm.cmd build` |
| 忘了 `build` 就 `tauri build` | exe 里是旧前端，自检照样绿 | `beforeBuildCommand` 是空的，必须手动 build |
| 改了 `.grammar` 没重生成 | 旧解析器全绿但新语法被拒 | `node scripts/build-grammar.mjs` |
| 残留 `caseboard.exe` | 链接失败 / 文件占用 | `Get-Process caseboard \| Stop-Process -Force` |
| 改了 `web/src` 没重跑 `build-web.ps1` | 鸿蒙设备上还是旧界面 | `platforms/harmony/entry/src/main/resources/rawfile/` 是产物、不入库 |
| 把红线当关系线实现 | 渲染、DSL、导出全部要跟着改，纯属自找 | 红线是 `CaseDoc.pinLinks`（`PinLink` + `PinLinkLayer`），**不进 `CaseDoc.edges`**（见 `03-constraints.md` G0-3 补注） |

## 7. 交付前最后一眼

- [ ] 四件套数字是**这一轮实际跑出来的**，不是抄 CHANGELOG，且是在 main 工作树跑的
- [ ] 新行为有对应断言（smoke 段号 / ui-smoke 断言 / 鸿蒙 `accept-h*.ps1` 的 Assertion）
- [ ] 旧断言一条没删、阈值一个没放宽
- [ ] 界面文案全中文；没有新增十六进制色值（令牌在 `src/index.css` + `lib/theme.ts`）
- [ ] 双平台：改逻辑 → 鸿蒙副本同步了吗？改鸿蒙 → 台账「桌面回填」判断了吗？
- [ ] 版本号三处同步（`package.json` / `src-tauri/tauri.conf.json` / `src-tauri/Cargo.toml`）——只有发布才动；鸿蒙另看 `AppScope/app.json5`
- [ ] `CHANGELOG.md` 有条目；决策有 D 编号；里程碑收尾打了 `ms/M<n>`（鸿蒙是 `hs/H<n>`）
