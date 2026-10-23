# CHANGELOG

本插件（技能内容）的变更记录。版本号跟随 `package.json`，语义化版本。

## [0.2.0] · 2026-10-23

对齐案情板 CaseBoard 从「单一 Tauri 桌面应用」升级为「双平台单仓库」之后的状态（桌面 M1–M18 + 鸿蒙 H0–H5.11）。技能正文与全部参考手册按新事实重写，不只是加一段说明。

### 新增

- **`references/06-harmony.md`（新文件）**：鸿蒙侧操作手册 —— 双平台三十秒判断表（改哪里 / 不许改哪里）、ArkWeb 桥的五种调用语义（同步直取、延时取、回调回传、零参方法、异步块）、12 个鸿蒙独有文件白名单、SQLite DDL（15 张表）、import 语法陷阱、accepts 脚本链、六个已知限制。
- **`04-prompts.md` 新增 4 条任务型提示词**：P13 触屏/平板交互、P14 集中钉子/钉集/红线（模型→命令→渲染→DSL 九步）、P15 桌面↔鸿蒙回填（先判方向再记账）、P16 鸿蒙侧构建/验收排障。
- **`05-prompts.md` 新增 P11 双平台定位**：任何跨端需求的第一条，要求先答「两端现状 / 该落哪侧 / 要不要回填 / 各自验收什么」。
- **`03-constraints.md` 新增 G0-9 双平台同构（镜像白名单）**，以及三条不在 Gate 0 但同样会被打回的架构约束（不用原生 `confirm/alert`、钉集坐标只认一条渲染链、钉集强制置顶）。

### 变更

- **`SKILL.md`**：开头加「双平台三十秒判断」表；纪律从五条扩到六条（新增镜像纪律）；标准动作补「先判平台」第 0 步；高频坑从八个扩到十二个（含「在 harmony 分支改根 src」「整目录覆盖镜像」「忘了 build-web 就装 HAP」「红线塞进 edges」）。
- **`01-architecture.md`**：补双平台目录角色与分支模型；模型面补 `CaseDoc.pinLinks` / `PinLink` / `settings.pinLinkWidth` / `NODE_TYPE_ORDER` 第 10 类 `clusterPin` / `ImageNode.pinPos·pinColor·clusterId·clusterOffset`；命令面补 `pinLinkCommands` 与 H5 期间新增的 image/group 命令；扩展点从九个扩到十个（新增「关系线自动梳理」与「触控/响应式」）；高频坑补两条鸿蒙侧。
- **`02-verification.md`**：新增 §6.1 鸿蒙链路（build-web / build-hap / accept-h0·h1·h4·h5 的用途与条数、签名与设备前提、探针机制）；§7 最快验证台阶加第 (e) 级；§8 人工确认清单补鸿蒙侧只能上机看的六项。
- **`03-constraints.md`**：G0-3 加「红线不是关系线」补注（`pinLinks` 不进 `edges`、不参与梳理与 DSL 边白名单）；GL-8 保留既有已知例外。
- **`00-workflow.md`**：闸门从四道扩到五道（新增 G0.5 平台判断），G1/G3 补鸿蒙读本；规模分档新增「H 鸿蒙侧增量」；命令工具包新增鸿蒙侧 7 条命令；验证矩阵新增鸿蒙侧独立一张表；失败处置表补 5 条鸿蒙签名/白屏/桥/产物类症状；收尾清单补鸿蒙四条（`HARMONY-MILESTONES.md:23` 两列、`platforms/harmony/CHANGELOG.md`、README 数字、差分文档）；反模式补 4 条。
- **`04-prompts.md` / `05-prompts.md`**：既有提示词里指向「`src/` 是唯一源码」的表述改成双平台口径（逻辑先落 `main` 的 `src/`，再同步镜像）。

### 数字与事实校准（相对 0.1.0）

- 桌面基线：`smoke` 871 PASS、`ui-smoke` 430 PASS、`bench` 74.5 ms（Beta 1.0 实测）。
- 鸿蒙基线：`accept-h5` 45 条（H5-1…H5-41）、`accept-h1` 22 条、`accept-h4` 8 条；`accept-h0` 是 H0 八项（见 `platforms/harmony/docs/H0-ACCEPTANCE.md`）。
- 镜像差异：5 个平台缝同名不同实现 + 5 个鸿蒙新增 + 桌面独有 `services/ocrBuiltin.ts` + `vite.config.ts` 3 处。
- 提示词总数 22 → 28（任务型 12 → 16，流程型 10 → 12）。

### 已知未覆盖

- 桌面侧 A6（层级控件）、A3/A4（多选与挑选对话框）在主线 `main` 已回填（`cd6f9e1`）；A5 只回填了机制（`uiStore.askConfirm/pushNotice`，`uiStore.ts:120-126,:234,:257`），仍有 12 处调用点用原生 `window.confirm/alert`；**触屏/响应式那一层（A7–A10）仍只在鸿蒙侧**，技能里按「未回填」标注。
- `platforms/harmony/docs/HARMONYOS-PORT.md` 是 H2 迁移前的历史文档，技能明确要求以 `HARMONY-MILESTONES.md` / `REPO-STRATEGY.md` / `FEATURE-DIFF-WIN-VS-HARMONY.md` 为准。

## [0.1.0] · 2026-10-22

首个开源版本：`SKILL.md` + 6 份参考手册（`00-workflow` / `01-architecture` / `02-verification` / `03-constraints` / `04-prompts` / `05-prompts`）+ 一键自检 `check.ps1`，对齐案情板 CaseBoard Beta 1.0（M1–M18 全部验收通过的桌面应用）。
