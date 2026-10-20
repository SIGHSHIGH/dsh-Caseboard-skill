# 验收体系：四件套 + 桌面自检

> 基线（Beta 1.0 记录）：`typecheck` 0 error · `smoke` **871 PASS**（78 段 `[1]`–`[77]`，`[11]` 出现两次）· `ui-smoke` **430 PASS / 0 FAIL**（26 个 `[UI]` 分组）· `bench` 1000 节点解析链 **74.5 ms**（阈值 300）· `build` 成功 · 桌面自检两轮 PASS。
> 耗时参考：typecheck 2–3 s、build 5–7 s、smoke ~1 s、ui-smoke ~35 s、bench <1 s、bench:board ~9 s、verify ~45 s。

## 1. 脚本矩阵

| script | 实际跑什么 | 验什么 | 需要先 build |
| --- | --- | --- | :---: |
| `dev` | `vite`（端口 5273） | 无 | |
| `build` | `tsc --noEmit && vite build` | 全量类型 + 产出 `dist/` | |
| `typecheck` | `tsc --noEmit`（163 文件，strict） | 类型 | |
| `smoke` | `tsc -p tsconfig.smoke.json && node scripts/smoke.cjs` | 78 段逻辑断言 | |
| `ui-smoke` | `node scripts/ui-smoke.cjs` | 26 段伪布局渲染断言 | **是（`dist/`）** |
| `bench` | `tsc -p tsconfig.smoke.json && node scripts/bench-dsl.cjs` | 1000 节点形状 + 总耗时 < 300 ms | |
| `bench:board` | `node scripts/bench-board.cjs` | 300 节点回归（打印 `LIMIT_MS=8000`，**不判定**） | 是 |
| `verify` | typecheck + build + smoke + ui-smoke 串联 | 不含两个 bench，也不含桌面自检 | |
| — | `node scripts/run-selftest.cjs` | 桌面两轮自检 | 需 Tauri 重建 |

CI（`.github/workflows/ci.yml`，ubuntu）只跑 `install --frozen-lockfile && typecheck && smoke && bench` —— **CI 不覆盖 ui-smoke 与桌面自检**，所以不要以为 CI 绿就没事。

## 2. smoke 的内部约定

- **编译集**：`tsconfig.smoke.json` 只编 `src/{types,lib,commands,serializers,dsl,data,store,services/exif.ts}` → `dist-smoke/`；排除 `src/**/*.tsx`、`src/store/importStore.ts`、`src/services/image.ts`、`src/services/imageStore.ts`。
  → **能断言的逻辑只能放这几层**。放 `services/` 或 `.tsx` 里 smoke 会 `require` 失败（M8 就这么坏过）。
- `scripts/smoke.cjs:12` 会写 `dist-smoke/package.json` 为 `{"type":"commonjs"}`（根 `package.json` 是 `type:module`）；目录不存在 → exit 1。
- `[1]`–`[24]` 在文件上半部；`void main()`（`scripts/smoke.cjs:1271`）拥有 `[25]`–`[79]`。末两段：`[78]` M17 线宽/锚点避障/关系气泡（`:3826`）、`[79]` M18 关系线自动梳理（`:3944`）。
- 任意断言失败 → `process.exit(1)`。
- **段号纪律**：现有最大段号是 `[79]`（`[78]` M17 线宽/锚点/关系气泡 `scripts/smoke.cjs:3826`、`[79]` M18 关系线自动梳理 `:3944`），新段从 **`[80]`** 起，段首写中文标题注释；每个 `check(...)` 都会计入 PASS 数。

段清单（改动前先找对应段，改完确认它还绿）：
`[1]` 脱敏演示案 · `[2]` 加→撤→重做 · `[3]` 空撤销栈 · `[4]` 删节点级联边 · `[5]` 更新/移动 · `[6]` 边 CRUD · `[7]` JSON 往返 · `[8]` 节点模板 · `[9]` 旧档迁移 · `[10]` 评论/折叠 · `[11]` 分组 · `[11]`(重号) 素材 id/缩略图 · `[12]` SHA-256 去重 · `[13]` EXIF · `[14]` 导入命令 · `[15]` 图片纯函数 · `[16]` 图片命令 · `[17]` 标注几何 · `[18]` 标注命令 · `[19]` PDF/视频抽帧计划 · `[20]` DSL 序列化 · `[21]` DSL 解析 · `[22]` 三方合并 · `[23]` 代码视图同步 · `[24]` 错误矩阵 + 50 操作 + 1000 节点压测 · `[25]` 脱敏马赛克 · `[26]` `.caseboard` 容器 · `[27]` 整板 SVG · `[28]` 回收站恢复 · `[29]` 批量恢复 · `[30]` 曲率手柄 · `[31]` 分析内核 · `[32]` 筛选聚焦 · `[33]` 路径/中心度 · `[34]` 布局写回+撤销 · `[35]` 演示 · `[36]` 抽取建图 · `[37]` 矛盾审查 · `[38]` 自然语言编辑 diff · `[39]` 报告/Word · `[40]` AI 通道 · `[41]` 零外呼 · `[42]` 假设 · `[43]` OCR + 生图红线 · `[44]` 地图坐标 · `[45]` 搜索/命令面板 · `[46]` 文本脱敏 · `[47]` 生图审计 · `[48]` 主题 · `[49]` 日期时间控件 · `[50]` 时间线字段 · `[51]` 反投影 · `[52]` 标签关系 · `[53]` 素材分组 · `[54]` 锚点/标签避让 · `[55]` 保险库已移除 · `[56]` 图片分带/吸附 · `[57]` 八端口 · `[58]` 时间线轨道 · `[59]` 地图拖动 · `[60]` 素材文件夹 · `[61]` 内置 OCR · `[62]` 迁移 v9 · `[63]` 卡片+图片 · `[64]` 圆点 · `[65]` 轨道选取 · `[66]` 证据链分类 · `[67]` 导入进文件夹 · `[68]` 时间切片行 · `[69]` 假设草稿 · `[70]` 自定义证据链 · `[71]` 地点自动连接 · `[72]` 地点解绑 · `[73]` 画布底衬/背景/溢出 · `[74]` 网格+标尺 · `[75]` 自动检验 · `[76]` ABC 演示案 · `[77]` 布局带动图片。

## 3. ui-smoke 的内部约定

- **必须先 `build`**（它没有 build 步骤，直接读 `dist/`）。`verify` 已经把顺序排好。
- jsdom + `scripts/jsdom-harness.cjs`：桩掉 `ResizeObserver`、`getBoundingClientRect`/`offsetWidth`（伪布局，`NODE_W=208`、`NODE_H=108`）、`DOMMatrix`。
- 退出码：`2` = mount 失败，`3` = 未捕获异常，`4` = 未处理 rejection；断言失败也会非 0。
- `CB_DEBUG=1` 会 dump DOM，排查选择器时用。
- **陷阱**：harness 按 readdir 顺序取 **第一个** `dist/assets/index-*.js`，不是 `dist/index.html` 里那个入口。所以残留的旧 chunk 会让覆盖率悄悄变化 —— 出现"改了没生效/莫名失败"先 `rm -rf dist` 重 build。
- 分组按里程碑命名（M2-3、M4×3、…、M18），新增断言放对应里程碑组里，别另起一组。

## 4. bench

- `scripts/bench-dsl.cjs`：1000 节点、999 边，先断言形状（1000/999/0 诊断），再断言整链耗时 `< LIMIT_MS`（`bench-dsl.cjs:40`，300 ms）；实时值 74–77 ms。
- 门禁口径（D24）：**纯逻辑链** `serializeDoc + parseDsl + locateDeclarations + diffDocs`；DOM 渲染只做 `bench:board` 回归，**不设阈值**。

## 5. DSL 语法（改动时会忘的一步）

```powershell
node scripts/build-grammar.mjs
```
`@lezer/generator` 的 `buildParserFile` 读 `grammar/caseboard.grammar`，产出 `src/dsl/generated/caseboard.parser.ts`（`typeScript:true`，已入库，文件头写"请勿手改"）。
**构建和测试都不会自动重生成** —— 改了 `.grammar` 不跑这一步，会出现"旧解析器照样全绿，新语法却被静默拒绝"的假绿。package.json 里没有对应 script，也没有 lezer CLI。

## 6. 桌面链路（顺序不能换）

```powershell
Get-Process caseboard -ErrorAction SilentlyContinue | Stop-Process -Force
$env:TMP = "$PWD\.tmp-esbuild"; $env:TEMP = $env:TMP
$env:CARGO_HOME = "$PWD\.rust\cargo"; $env:RUSTUP_HOME = "$PWD\.rust\rustup"
$env:PATH = "$PWD\.rust\cargo\bin;" + $env:PATH
node $PNPM build   # ★ 必做（$PNPM 见 00-workflow 第 4 节；也可用 scripts\pnpm.cmd build）
node scripts/tauri-cli.cjs build --no-bundle        # → src-tauri\target\release\caseboard.exe
node scripts/run-selftest.cjs                       # 两轮，每轮上限 120 s
node scripts/tauri-cli.cjs build --bundles nsis     # → ...\bundle\nsis\CaseBoard_<ver>_x64-setup.exe
powershell -ExecutionPolicy Bypass -File scripts/sign-installer.ps1
```

- ★ **`src-tauri/tauri.conf.json` 的 `beforeBuildCommand` 是空字符串**：Tauri 不会替你跑前端构建，忘了 `pnpm build` 就会把一个旧 `dist/` 打进 exe（而自检可能照样绿，因为前端是上一版）。
- `tauri build` 需要 `danger-full-access`；`run-selftest.cjs` 需要 exe 存在。
- 自检数据目录 `.tmp-esbuild/appdata/app.caseboard.desktop`；报告 `selftest.json`，归档 `.tmp-esbuild/selftest-phase{1,2}.json` + `.log`；**任一失败 exit 3**。
- 环境变量：`CB_PHASES`（默认 `1,2`）、`CB_SELFTEST_TIMEOUT`（120000）。
- 签名：证书要在 `Cert:\CurrentUser\My` 里（当前机器没有 → 会打印 "No code signing certificate…"，属预期）；`signtool` 只在 Windows Kits 目录下被找到。演练用 `-SelfSignedTest`。
- 产物归档：把 `caseboard.exe` 与安装包拷进 `release\`（该目录**不在版本控制内**），字节数与 SHA-256 记到 `docs/RELEASES.md` / `CHANGELOG.md`。

## 7. 最快的验证台阶（照这个顺序，不要跳）

- **(a) 只改 `lib/`**：`typecheck` → `smoke` →（动了导出就再 `verify`）
- **(b) 改 `.tsx` / UI**：`typecheck` → `build` → `ui-smoke` → `verify`
- **(c) 改 DSL / 语法**：`node scripts/build-grammar.mjs`（若 `.grammar` 变了）→ `typecheck` → `smoke`（`[20]`–`[24]` 会立刻暴露解析错误）→ `bench` → `build && ui-smoke`
- **(d) 改 Rust / 打包**：`build` → `tauri-cli build --no-bundle` → `run-selftest` → `--bundles nsis` → 手工安装 C1–C5

## 8. 自动化覆盖不到的（只能人工）

真实 WebView2 渲染与排版、拖拽/缩放/旋转手感、HMR 时延、原生保存对话框与外部查看器里的导出保真、系统级拖放与文件选择器、打包后 App 里的 OCR WASM、局域网/离线复验、NSIS 向导与卸载与 SmartScreen、签名链、多实例与 SQLite 文件锁。
对应清单：`docs/MANUAL-ACCEPTANCE.md` 的 A1–A10、B1–B4、C1–C5、R1–R6。交付时**明确说出哪几项没被自动验证**。
