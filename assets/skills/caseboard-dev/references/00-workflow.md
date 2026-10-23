# 改动流程（每次编辑的固定动作）

> 下面所有命令都在**仓库根目录**执行（含 `src-tauri/`、`docs/CaseBoard-SPEC.md`、`.git` 的那个目录）。
> 本机约定：`pnpm` 命令**不能**直接调（沙箱里 spawn 会 EPERM），必须走 node 直连；见第 4 节。
>
> **第 0 步永远是「判平台」**（2026-10 起仓库是双平台单仓库）：桌面 Tauri 在根 `src/` + `src-tauri/`（分支 `main`），鸿蒙 ArkTS 在 `platforms/harmony/`（分支 `harmony`）。判错了改的就是落后镜像，白改。判断表见 `06-harmony.md` 第 1 节，落点纪律见 `03-constraints.md` 的 G0-9。

## 1. 五道闸门

| 闸门 | 什么时候 | 通过条件 | 不通过怎么办 |
| --- | --- | --- | --- |
| **G0 对齐** | 用户提需求的当下 | 能用一句话复述"要改的是哪个视图/哪个实体/哪条命令"，且知道它属于哪个里程碑能力 | 直接问用户，不要猜 |
| **G0.5 平台** | 同上 | 已确定改桌面、改鸿蒙、还是两边都要（`06-harmony.md` 第 1 节三问） | 平台相关的产品行为两边不一致时**先问**，别自己对齐 |
| **G1 契约侦察** | 动手前 | 已读权威规格里对应小节（`docs/CaseBoard-SPEC.md` 的 P0–P7 提示词库）+ `docs/MILESTONES.md` 对应里程碑三表 + 相关决策记录 D 编号；鸿蒙侧另读 `platforms/harmony/docs/HARMONY-MILESTONES.md` 与 `FEATURE-DIFF-WIN-VS-HARMONY.md` | 没找到对应条目就**先问**，不要自创产品行为 |
| **G2 计划确认** | 写第一行代码前 | 给出 3–6 条计划：涉及文件 + 验收标准，用户确认 | 用户没确认就只做只读侦察 |
| **G3 里程碑边界** | 任何功能增量 | 明确它落在哪个 M（M1–M18，桌面）或 H（H0–H5.x，鸿蒙）的范围内 | 超出范围 → 先写进计划的"待排期"再问；**一次只推进一个里程碑** |

## 2. 规模分档

先判断改动规模，再决定流程长度（不要为改一行文案跑全套五件套，也不要为改模型跳过 smoke）：

| 档位 | 判定 | 必做 |
| --- | --- | --- |
| **XS 文案/样式** | 只动 `.tsx` 的 JSX 或 CSS 变量，不动逻辑 | `pnpm typecheck` + `pnpm ui-smoke`（有源码断言）+ 视情况 `pnpm build` |
| **S 单点逻辑** | 一个 `lib/` 函数或一个命令 | 上一档 + `pnpm smoke`（必须新增断言） |
| **M 功能增量** | 加面板 / 加导出格式 / 加自检项 / 加节点字段 | 上一档 + `pnpm bench`（若碰解析链）+ `MILESTONES.md` 决策记录 + `CHANGELOG.md` |
| **L 模型/持久化变更** | 改 `CaseDoc` 形状、DSL 语法、SQLite 表 | 全套四件套 + 桌面自检两轮 + 迁移器与 `db/mapping.ts` 同步 + 旧档回放验证 |
| **H 鸿蒙侧增量** | 改 `platforms/harmony/web/src` / ArkTS / 触控与布局 | `build-web.ps1` + `accept-h5.ps1`（碰桥或 `entry/src/main` 加 `accept-h0.ps1`）+ 逻辑层同构的 main 侧 `typecheck` |

> 判 L 的补充：**钉子与红线**（`pinLinks`、`clusterPin`、`clusterOffset`）已经是 L 级面——改它们要同时动 types / migrate / commands / 渲染 / DSL 五处，缺一处旧档就会漂。

**判断依据**：只要改到 `src/types/index.ts`、`src/serializers/migrate.ts`、`src/dsl/generated/*`、`src-tauri/src/migrations.rs` 任意一处，直接按 L 走。

## 3. 动手顺序（固定）

1. **读**：先 `grep -n` 定位，再 `read` 目标文件的相关段落（大文件禁止整份读后整份写回）。
2. **改**：`edit` 定点替换 / `ops_edit_file` 多处 patch；新文件用 `write`。
3. **验**：按第 5 节选最少够用的一组。
4. **记**：`CHANGELOG.md` 追加条目；涉及决策的写 `docs/MILESTONES.md` §6（D 编号递增）。
5. **交**：git commit（信息中文、`feat/fix/chore(范围): 描述`），里程碑收尾再打 tag —— 桌面 `ms/M<n>`、鸿蒙 `hs/H<n>`（两个命名空间不混用）。

## 4. 命令工具包

```powershell
# ── 常量 ──────────────────────────────────────────────
# <DSH安装目录> = DSH Desktop 的安装目录（`resources\` 的上一级；右击快捷方式 →
# 打开文件所在位置）。仓库自带的 scripts\pnpm.cmd 已封装这条路径，优先用它。
$DSH_ROOT = "<DSH安装目录>"
$PNPM = Join-Path $DSH_ROOT 'resources\app.asar.unpacked\node_modules\pnpm\bin\pnpm.cjs'
# 临时目录必须落在工作区，否则 esbuild 处理大产物时在系统 Temp 删除失败
$env:TMP = "$PWD\.tmp-esbuild"; $env:TEMP = $env:TMP
```

| 目的 | 命令 | 备注 |
| --- | --- | --- |
| 装依赖 | `node $PNPM install` 或 `scripts\pnpm.cmd install` | 极少需要 |
| 类型检查 | `node $PNPM typecheck` | 必须 0 error |
| 逻辑自测 | `node $PNPM smoke` | node CJS，跑 `scripts/smoke.cjs` |
| UI 自测 | `node $PNPM ui-smoke` | **先 `build`**，否则没有 `dist/` |
| 性能基线 | `node $PNPM bench` | 1000 节点 DSL 解析链 < 300 ms |
| 打包前端 | `node $PNPM build` | = `tsc --noEmit && vite build`；沙箱内需 `danger-full-access` |
| 桌面可执行 | `node scripts/tauri-cli.cjs build --no-bundle` | 见第 6 节前置 |
| 安装包 | `node scripts/tauri-cli.cjs build --bundles nsis` | 产物 `src-tauri/target/release/bundle/nsis/` |
| 桌面自检 | `node scripts/run-selftest.cjs` | 默认两轮 `CB_PHASES=1,2` |
| 签名 | `powershell -ExecutionPolicy Bypass -File scripts/sign-installer.ps1` | `-SelfSignedTest` 可演练 |

鸿蒙侧命令**全部在 `platforms\harmony\` 下执行**（脚本自己会定位 DevEco / node / hdc）：

| 目的 | 命令 | 备注 |
| --- | --- | --- |
| 构建前端产物 | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-web.ps1` | tsc → vite → `postbuild-rawfile.mjs` → `entry/src/main/resources/rawfile` |
| 打 HAP | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-hap.ps1` | `hvigorw assembleHap --mode module -p product=default -p buildMode=debug` |
| 上机前端验收 | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\accept-h5.ps1` | 现 45 条断言（H5-1…H5-41；H5.11 的 H5-42/43 尚未提交）；`-Target <serial>` 换设备、`-Hap <path>` 用已签名包 |
| 桥 / 存储验收 | `scripts\accept-h0.ps1` | H0 八项（`docs/H0-ACCEPTANCE.md`） |
| 平板布局 / 手势验收 | `scripts\accept-h1.ps1` / `scripts\accept-h4.ps1` | 22 条 / 8 条 |
| 探针源码校验 | `node scripts\check-probe.mjs <Index.ets> <phase>` | 改探针后先跑它，别直接上机 |
| 环境定位 | `scripts\_env.ps1` | `DEVECO_HOME`/`NODE_HOME`/`HDC`/`PNPM_CLI` 或常见安装路径；**别用 `$home` 当变量名** |

`scripts/pnpm.cmd` 是上面 node 直连的包装，批次里用它更短：`scripts\pnpm.cmd smoke`。
**注意 shell**：在 bash 里裸 `node` 不可解析，要写 `node.cmd`；PowerShell / `pwsh` 里 `node` 正常。

## 5. 验证矩阵

| 改了什么 | typecheck | smoke | ui-smoke | bench | build | 桌面自检 |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| 文案 / 样式 / 布局 | ● | | ● | | ▲ | |
| `lib/` 纯函数 | ● | ● | | ▲ | | |
| `commands/` 新命令 | ● | ● | | | | |
| store 写路径 / undo | ● | ● | ● | | | |
| 新面板 / 新视图 | ● | | ● | | ● | |
| DSL / 语法 / 序列化 | ● | ● | ● | ● | ● | |
| 模型 / 迁移 / SQLite | ● | ● | ● | ● | ● | ● |
| 打包 / 安装包 / 签名 | ● | ● | ● | | ● | ● |

● = 必做；▲ = 相关时做（例如 bench 只在碰解析链时）。

鸿蒙侧（`platforms/harmony/`）另算一张：

| 改了什么 | build-web | accept-h5 | accept-h0 | accept-h1/h4 | main 侧 typecheck |
| --- | :---: | :---: | :---: | :---: | :---: |
| 纯 TS 逻辑（与桌面同构） | ● | ● | | | ● |
| 组件 / 样式 / 响应式 | ● | ● | | ▲（动布局档位时） | ● |
| 触控手势 / 命中带 | ● | ● | | ● | |
| ArkTS 桥 / 平台缝 / SQLite | ● | ● | ● | | ● |
| 原生弹窗替换 / 新面板 | ● | ● | | ▲ | ● |

**两条硬规则**：

1. 新增可机器断言的行为 → **必须在 `scripts/smoke.cjs` 新开段或追加断言**（段号接着写，例如现有末段 [79] 之后是 `[80]`）。只写实现不写断言，视为未完成。
2. 触碰 `lib/` 或 `components/` 的可见行为 → `scripts/ui-smoke.cjs` 至少加一条源码/伪布局断言（它跑的是打包产物 + jsdom，能抓到"代码里还有没有图例/角标/中文文案"）。

## 6. 桌面链路前置（缺一条就失败）

```powershell
Get-Process caseboard -ErrorAction SilentlyContinue | Stop-Process -Force   # 残留 exe 会锁文件
$env:TMP = "$PWD\.tmp-esbuild"; $env:TEMP = $env:TMP
$env:CARGO_HOME = "$PWD\.rust\cargo"; $env:RUSTUP_HOME = "$PWD\.rust\rustup"
$env:PATH = "$PWD\.rust\cargo\bin;" + $env:PATH
node $PNPM build   # ★ 必做，见下（$PNPM 见第 4 节；也可用 scripts\pnpm.cmd build）
node scripts/tauri-cli.cjs build --no-bundle
```

- ★ **必须先 `build`**：`src-tauri/tauri.conf.json` 的 `beforeBuildCommand` 是空字符串，Tauri 不会替你构建前端。忘了这一步会把旧 `dist/` 打进 exe，而自检仍可能全绿（前端还是上一版）。
- Rust 工具链装在仓库内 `.rust\`（用户目录不可写，决策 D25）。
- **不要**跑 `pnpm tauri`：本机没有独立 node，`argv[0]` 是 Electron，会报 `unrecognized subcommand`。
- Tauri 构建与 `build`/`dev`/`preview` 在沙箱内都需要 `danger-full-access`（esbuild / rustc 子进程）。
- 自检脚本每轮换 `WEBVIEW2_USER_DATA_FOLDER`，数据目录 `.tmp-esbuild/appdata/app.caseboard.desktop`；报告落 `.tmp-esbuild/selftest-phase*.json`。

## 7. 失败处置表

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| `[vite:esbuild-transpile] remove …: Access is denied` | 系统 Temp 被占用/权限 | 把 `TMP`/`TEMP` 指到 `$PWD\.tmp-esbuild`（第 4 节） |
| `spawn EPERM`（pnpm/vite 子进程） | 沙箱 | 用 `node $PNPM …`；`build`/`dev` 加 `danger-full-access` |
| `Cannot find module '../src/services/...'`（smoke） | 逻辑放进了 `services/` 或 `.tsx` | 下沉到 `lib/`/`serializers/`/`commands/` |
| `ui-smoke` 报找不到 `dist/assets` | 没先 build | 先 `node $PNPM build` |
| exe 文件被占用 / 链接失败 | 残留进程 | `Get-Process caseboard | Stop-Process -Force` |
| 文件突然少了几百行 | 整份读 + 整份写（read 上限截断） | 用 `git diff` 找回，之后只 `edit` |
| `unrecognized subcommand` | 走了 `pnpm tauri` | 改 `node scripts/tauri-cli.cjs …` |
| 断言数突然变少 | 新断言段号撞车 / 段被覆盖 | 检查 `smoke.cjs` 尾部段号与 `exit code` |
| `install sign info inconsistent`（鸿蒙） | 装了未签名 HAP | 用 DevEco 签名站点出的包；模拟器只认签名包 |
| 鸿蒙页面白屏 / ESM 加载失败 | `resource://` 的 CORS | 必须走 `caseboard://rawfile/` 自定义 scheme |
| 桥调用拿不到返回值 | 参数表末尾没传回调 | `asyncMethodList` 不回传；值走回调 |
| 页面显示成源码文本 | `setMimeType` 混了 charset | 只吃裸 MIME（`text/html`） |
| 改了 `web/src` 但真机没变 | 没重跑 `build-web.ps1` | rawfile 是产物，`/MIR` 覆盖后再装 |

## 8. 收尾清单（每个里程碑）

- [ ] 四件套（+ 桌面两轮）全绿，数字记下来（PASS 数 / bench ms / 产物字节数）
- [ ] `CHANGELOG.md` 新条目：用户反馈原文（如有）→ 改了什么（带文件路径）→ 验收数字 → 打包产物与 SHA-256
- [ ] `docs/MILESTONES.md`：三表 + 新增决策 D 编号（§6 递增，当前末号 D101）
- [ ] 版本号三处统一：`package.json` / `src-tauri/tauri.conf.json` / `src-tauri/Cargo.toml`
- [ ] git commit + tag `ms/M<n>`（里程碑）
- [ ] 涉及手工验收的补 `docs/MANUAL-ACCEPTANCE.md` 的 R 节

**鸿蒙侧（`hs/H<n>`）另有四条**：

- [ ] `platforms/harmony/docs/HARMONY-MILESTONES.md` 的交付表 + `:23` 的「桌面回填（main）」一行（两列都要填）
- [ ] `platforms/harmony/CHANGELOG.md` 追加条目（**UTF-8**，别沿用历史 GBK 乱码）
- [ ] `platforms/harmony/README.md` 的验收数字（H5 断言条数）
- [ ] 差分文档：`FEATURE-DIFF-WIN-VS-HARMONY.md` 里对应条目的"鸿蒙现状"/"差异"要不要改

## 9. 反模式（出现任何一条就停下重想）

- ❌ 为了让测试变绿去改断言数字 / 删断言 / 放宽阈值
- ❌ 绕过 `dispatch` 直接改 `doc`，或在组件里 `useDocStore.setState`
- ❌ 新开一个"临时"数据副本让画布/代码视图各读一半
- ❌ 在 `.tsx` 或 `services/` 里写需要断言的业务逻辑
- ❌ 用 `write` 整份重写超过 500 行的既有文件
- ❌ 引入新依赖（技术栈锁定）、引入 UI 库主题、把界面文案写成英文
- ❌ 让 AI 产出跳过「待确认」直达 Model，或让 AI 图摘掉角标/进「已证实」
- ❌ 在组件里自己算 world↔screen（必须走 `lib/coords.ts`）
- ❌ 一次提交里混进两个里程碑的功能
- ❌ 在 `harmony` 分支名下改根 `src/`（那是落后镜像），或整目录覆盖同步镜像（会带进 12 个鸿蒙独有文件或删掉它们）
- ❌ 新代码里用 `window.confirm/alert`（鸿蒙已换成 `askConfirm`/`pushNotice`，桌面 A5 待回填）
- ❌ 把红线（`pinLinks`）塞进 `CaseDoc.edges`，或给红线编一个 `LineStyle`
- ❌ 在 `platforms/harmony/scripts/*.ps1` 里硬编码机器路径或用 `$home` 当变量（环境差异走 `_env.ps1`）

## 10. 交付报告格式

```
改了什么：<一句话>
平台：<桌面 main / 鸿蒙 harmony / 双平台 —— 两侧文件是否都改了>
涉及文件：<path:line> …
验收：typecheck 0 error · smoke N PASS · ui-smoke N PASS · bench N ms · build ok
      （鸿蒙）build-web ok · accept-h5 45/45 · accept-h0 8/8
回归风险：<说清受影响的既有行为，以及哪条断言守着它>
未做/待办：<明确列出没碰的部分，尤其是"主线还没回填"的那几条>
```
