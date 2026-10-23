# 鸿蒙移植版（platforms/harmony）· 双平台工作手册

> 适用：2026-10 起仓库变成「一个仓库、两套前端」。写码前先确认自己在哪个分支、改哪套前端，否则会把改动写进一份落后的镜像。
> 行号以写入时为准（2026-10-23，分支 `harmony` HEAD `119d2e7`）；漂移了就用 `grep -n "<符号>"` 重新定位。

## 0. 三十秒判断

| 事实 | 值 |
| --- | --- |
| 两个前端 | 桌面 `src/`（Tauri 2 + WebView2）；鸿蒙 `platforms/harmony/web/src/`（ArkWeb 内嵌 `$rawfile`） |
| 桌面主干分支 | `main`——通常挂在独立工作树里（`git worktree list` 查；本项目用的是 `F:\DSH PROJECT\.cb-main`，没有就自己 `git worktree add` 一个） |
| 鸿蒙分支 | `harmony`——`platforms/harmony/` 全在 + 一份**较早的** `src/` 镜像 |
| 版本 | 根 `package.json` / `platforms/harmony/web/package.json` = `1.0.0-beta.1`；`AppScope/app.json5:5-6` versionCode `1000000` / versionName `1.0.0` |
| 鸿蒙进度 | H0–H5.10 已落地（H5.11 抽屉/小地图让位仍在工作区、未提交）；H6（原生画布）/ H7（真机 OCR·PDF·签名）未开始 |
| 唯一进度台账 | `platforms/harmony/docs/HARMONY-MILESTONES.md`——正式结项只写到 **H5.6.3**，之后的 H5.7–H5.10 看 `platforms/harmony/CHANGELOG.md` 与 `git log --oneline` |
| 鸿蒙验收 | `scripts/accept-h5.ps1`（现存 **45** 条 Assertion，H5-1…H5-41） |
| 桌面验收 | 四件套 + selftest，**要在 main 工作树里跑**（见 §5.1） |

**先跑这三条**，再决定改哪份代码：

```bash
git branch --show-current                                  # harmony / main
git branch -vv                                             # main → F:/DSH PROJECT/.cb-main
git log --oneline harmony..origin/main -- src | wc -l       # 主线比鸿蒙分支多出的桌面提交（2026-10-23 = 5 条）
```

改动的落点：

| 你要改的东西 | 改哪里 | 之后 |
| --- | --- | --- |
| 业务逻辑（types / lib / commands / dsl / serializers / store / 面板 / 导出） | **先落 `main` 的 `src/`** | 再同步到 `platforms/harmony/web/src/` 同名文件 |
| 触屏/平板/ArkWeb 交互（长按、手势、抽屉、触控尺寸、ArkTS 桥） | `platforms/harmony/web/src/` 或 `entry/` | 判断是否该回填桌面（§7），写在台账「桌面回填」行 |
| 桌面专属（Tauri 打包、内置 OCR、自检 exe、NSIS 签名） | `main` 的 `src/` + `src-tauri/` + `scripts/` | 无需同步 |
| 图标 | `harmony-icon/make-icon.py` / `sync-icon.py` | 桌面仍是 `src-tauri/icons/icon.png` |

> ⚠️ 在 `harmony` 分支上直接改根 `src/`，改到的是**落后主线 5 个提交**的镜像（2026-10-23：harmony 分支根 `src/` 缺集中钉子/红线/层级控件等回填）。桌面逻辑请去 main 工作树改。

## 1. 目录

```
platforms/harmony/
  AppScope/app.json5            bundleName com.caseboard.harmony、版本号
  entry/                        ArkTS 工程（stage 模型，build-profile.json5:2）
    src/main/ets/
      pages/Index.ets           Web 宿主 + 诊断探针（1852 行，最重的一支）
      bridge/CaseBoardBridge.ets  25 个桥方法（310 行）
      bridge/RawfileScheme.ets    caseboard:// 自定义 scheme（191 行）
      service/                  Db / File / Clipboard / Ocr / Image / Platform 六个服务
      entryability/EntryAbility.ets  读 `--ps caseboardSelftest <phase>`（:18-25）
    src/main/resources/rawfile/ 前端产物（build-web.ps1 生成，**不入库**）
    src/main/module.json5        EntryAbility + `orientation: landscape`
  web/                          前端工程＝桌面 src/ 的镜像（173 ts/tsx vs 桌面 163）
  scripts/                      构建与验收（_env.ps1 统一工具链定位）
  docs/                         台账 / 差分 / H0–H4 验收记录 / 仓库策略
  test-fixtures/                CASEBOARD_TEST_FIXTURES=1 时才拷进 rawfile
harmony-icon/                   桌面根目录下的图标源（make-icon.py / sync-icon.py + png）
```

- `masaike board hamonyos/`（工作区同级）是**空壳**，只剩 `.dsh-hdc/` 截图与 `.tmp-esbuild/` 产物，不是工程，别去那里改代码。
- `harmony/` 工程内**没有** hvigorw / ohpm 包，全部用 DevEco Studio 自带的（`_env.ps1` 负责找到它们）。

## 2. 镜像关系与白名单

`platforms/harmony/web/src/` 是根 `src/` 的镜像副本，**只有这些文件允许两边不同**：

| 类别 | 文件 |
| --- | --- |
| 平台缝（同名不同实现） | `services/platform.ts`、`services/file.ts`、`services/ocr.ts`、`services/storage.ts`、`services/db/harmony.ts` |
| 鸿蒙新增 | `services/harmony.ts`（桥封装）、`styles/responsive.css`（`pointer: coarse` 44px 命中区、平板/窄档）、`components/OrientationGate.tsx`、`components/flow/AssetDragGhost.tsx`、`lib/viewport.ts` |
| 桌面独有（鸿蒙没有） | `services/ocrBuiltin.ts`（Tesseract WASM 内核，鸿蒙切系统 OCR） |

`web/vite.config.ts` 三处差异：`base: './'`（`caseboard://rawfile/` 下必须是相对路径）、`build.outDir` 直指 `entry/src/main/resources/rawfile`、`target` 抬到 es2022。
`docs/REPO-STRATEGY.md:44-56` 的纪律：合并方向**只许** `harmony → main`；逻辑层先在 main 落地再往回同步。计划中的 `scripts/sync-web.ps1` **尚未实现**（2026-10-23 根 `scripts/` 内没有此文件），同步是手工的。

模型也**不是共用代码**，而是镜像超集：鸿蒙 `web/src/types/index.ts:6-17` 多 `clusterPin` 节点类型、`:228-244` 多 `pinPos/pinColor/clusterId`，桌面 `src/types/index.ts:6` 没有对应成员。

## 3. ArkWeb 五条硬结论（别再试一遍）

1. **不能用 `resource://rawfile/`**：`resource:` 是 opaque origin，ArkWeb 对 `<script type="module">` 做 CORS 校验直接拒（`Access to script at 'resource://rawfile/assets/index-*.js' from origin 'null' has been blocked by CORS policy`），Vite 产物必然是 ESM → 白屏。正解：自定义 scheme `caseboard://rawfile/`（`customizeSchemes(isSupportCORS:true)` + `WebSchemeHandler` 从 rawfile 供货，响应头带 `Access-Control-Allow-Origin: *`）。
2. **`asyncMethodList` 不回传返回值**：页面调用桥方法只拿到受理码 `0`，ArkTS 侧的 Promise 结果被丢弃。唯一回传通道是「页面在参数表末尾多传一个回调函数」，所以 25 个方法全是 `(args…, cb: (result: string) => void): void`，返回值统一包 `{"ok":true,"value":…}` 信封。
3. **`setMimeType` 只吃裸 MIME**：写 `text/html; charset=utf-8` 会让 ArkWeb 把整页当纯文本源码显示；字符集走 `setEncoding('utf-8')`。
4. **只做横屏**：竖屏/小窗由前端 `OrientationGate.tsx` 拦（文案 `_(:3」∠)_`），不实现竖屏布局；`module.json5` 也锁了 `landscape`。
5. **能力随 HMS 走**：OCR 用 `@kit.CoreVisionKit`（`canIUse('SystemCapability.AI.OCR.TextRecognition')` 守卫，不支持就退手工录入）；PDF 用 `@kit.PDFKit`（非 HMS 设备不可用）；`ohos.permission.READ_PASTEBOARD` 是 system_basic 级，普通应用声明不了，读剪贴板失败只记警告返回空。

## 4. 桥与平台缝

```
Index.ets（Web 组件） ── caseboard://rawfile/index.html ──► web/src（React）
        ▲                                                      │
        │ registerJavaScriptProxy（25 方法，回调信封）           ▼
CaseBoardBridge.ets ──► service/{Db,File,Clipboard,Ocr,Image,Platform}Service.ets
        │                                                      │
        └──────────── RawfileScheme.ets（供货 rawfile）          └──► relationalStore / 沙箱 files
```

- 前端只见 `services/platform.ts` 的 `isHarmony()` 与 `services/harmony.ts` 的桥封装；组件层不许直接碰桥。
- 数据层：`db/repo.ts` 的 `SqlDriver` 是缝（`repo.ts:12`），`db/mapping.ts` 两边同构；`src-tauri/src/migrations.rs` 的 `V1_SQL` 可整段复用（relationalStore 与 tauri-plugin-sql 一一对应）。
- 存档位置：桌面 `%APPDATA%/app.caseboard.desktop/`；鸿蒙 `el2/base/haps/entry/files/`（沙盒）。

## 5. 验收链

```powershell
cd platforms\harmony
# 1) 前端产物 → entry/src/main/resources/rawfile（tsc --noEmit → vite build → postbuild-rawfile.mjs）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-web.ps1
# 2) 只构建 HAP（hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-hap.ps1
# 3) 全量上机验收：前端产物 → HAP → 安装 → 断言（H5 现存 45 条）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\accept-h5.ps1
# 其它里程碑：accept-h0（H0 八项）/ accept-h1（22 条）/ accept-h4（8 条）
```

- 报告落 `platforms/harmony/.tmp-esbuild/accept-h{0,1,4,5}.json`；全通过才 exit 0。
- 设备：默认模拟器 `127.0.0.1:5555`（HarmonyOS 26.0.0 平板模拟器，MatePad Pro 13，1440×893 CSS px @ dpr 2）；`-Target` 可指定真机。
- **签名坑**：模拟器上已装的是 DevEco 签名站点构建的包，未签名包装不进去（`code:9568332 install sign info inconsistent`）。`-Hap` 可直接指定已签名包。
- 工具链：`scripts/_env.ps1` 优先级 = 显式参数 > 环境变量（`DEVECO_HOME` / `NODE_HOME` / `HDC` / `PNPM_CLI`）> 常见安装位置（`D:\DevEco Studio`、`C:\Program Files\Huawei\DevEco Studio`、`C:\DevEco Studio`）> `PATH`。
- 探针：`EntryAbility.ets:18-25` 读 `--ps caseboardSelftest <phase>`，`pages/Index.ets:78-83` 的 `runBridgeProbe()` 把结果打 hilog，脚本再抓 hilog 断言。新增 phase 的辅助脚本：`check-probe.mjs`（只编译校验探针源码）、`extract-probe.mjs`、`diag-probe.mjs`、`splice-phase*.mjs`、`fix-bom.mjs`。

### 5.1 桌面版验收要在 main 工作树跑

```powershell
cd "<main 工作树>"   # 桌面主干单独检出的 worktree
scripts\pnpm.cmd typecheck; scripts\pnpm.cmd smoke; scripts\pnpm.cmd ui-smoke; scripts\pnpm.cmd bench
```

在 `harmony` 分支的根目录跑四件套，验证的是那份落后镜像，数字不具备代表性。`platforms/harmony/web/` 自己只有 `typecheck` / `build` / `dev` 三个脚本（`web/package.json`），逻辑断言仍靠桌面 smoke + 鸿蒙 accept 脚本。

## 6. 鸿蒙独有功能（回填候选）与回填现状

差分文档：`platforms/harmony/docs/FEATURE-DIFF-WIN-VS-HARMONY.md`（73 行，全表格）。桌面**没有**任何功能是鸿蒙缺失的，只有方向相反的这条清单：

| # | 功能 | 关键文件 | 桌面前状态 | 回填情况（main，2026-10-23） |
| --- | --- | --- | --- | --- |
| A1 | 集中钉子 + 钉集（整集移动 / 绕钉旋转 / 相对位置） | `lib/clusterPin.ts`、`commands/imageNodeCommands.ts`、`BaseNode.tsx`、`FreeImageNode.tsx`、`RightPanel.tsx` | 无 | ✅ `cd6f9e1` |
| A2 | 红线（长按钉子→点另一颗钉子，4px 直线，**不算关系线**） | `types/index.ts`(`PinLink`)、`commands/pinLinkCommands.ts`、`components/flow/PinLinkLayer.tsx`、`Board.tsx` | 无 | ✅ `cd6f9e1` + `828a7b8` + `bbf11db`（粗细滑块） |
| A3 | 长按多选 + 「加入组框…」 | `store/uiStore.ts`(`multiSelect`)、`BaseNode.tsx`、`RightPanel.tsx`、`groupCommands.addNodesToGroup` | 无 | ✅ `cd6f9e1`（桌面切成右键多选） |
| A4 | 组框挑节点对话框 | `panels/NodePickerDialog.tsx`、`GroupPickDialog.tsx` | 无 | ✅ `cd6f9e1` |
| A5 | 应用内确认框 + Toast（替 `window.confirm/alert`） | `panels/SystemDialogs.tsx`、`uiStore.askConfirm/pushNotice` | 机制已在（`uiStore.ts:120-126,:234,:257`），但仍有 **12 处**调用点未迁移（TopBar 4 · AiPanel 3 · useCanvasImage 2 · DemoDialog/HistoryDialog/AiImagePanel 各 1） | 🟡 机制已回填，调用点待迁 |
| A6 | 所有节点右栏层级控件（置顶/上移/下移/置底） | `commands/nodeCommands.ts`(`setNodeLayer`)、`RightPanel.tsx` | 无 | ✅ `cd6f9e1` |
| A7 | 触摸长按拖素材 + 跟手影 | `panels/AssetLibrary.tsx`、`flow/AssetDragGhost.tsx`、`uiStore.assetDrag` | 只有 HTML5 拖放 | ❌ 未回填 |
| A8 | 触控分档 CSS（44px 命中区/平板档） | `styles/responsive.css` | 无 `styles/` | ❌ 未回填 |
| A9 | 横竖屏闸门 | `components/OrientationGate.tsx` | 无 | ❌ 桌面无意义 |
| A10 | viewport 工具与惯性参数化 | `lib/viewport.ts`、`Board.tsx` | 惯性阈值写死 | ❌ 未回填 |
| B1 | 内置 OCR 内核（Tesseract WASM） | `services/ocrBuiltin.ts` + `public/ocr` 16MB | 有 | 反向缺口，不在回填范围 |

回填的完整纪律（三段式）：① 在 main 工作树改桌面 `src/` 并跑四件套；② 台账 `docs/HARMONY-MILESTONES.md:23` 的「桌面回填（main）」行记提交号；③ 根 `CHANGELOG.md` 用四段式（症状 / 根因 / 改了什么 / 验收）记一条，鸿蒙侧 `platforms/harmony/CHANGELOG.md` 也记反向一条。

## 7. 这一侧的高频坑

| 坑 | 症状 | 处置 |
| --- | --- | --- |
| 在 `harmony` 分支改根 `src/` 当桌面版 | 改完发现主线早就没有这段代码 | 桌面改动去 main 工作树（单独 worktree 检出 `main`） |
| 把 `platforms/harmony/web/src` 当桌面镜像改 | 两边越走越远 | 先改 main `src/`，再逐文件同步（白名单之外必须同构） |
| `$home` / `$host` / `$input` 当变量名 | `Cannot overwrite variable HOME because it is read-only`，dot-source 不中断但后面路径全 `$null`，报一串 `BadExpression` | 用 `$devEcoRoot` / `$nodeDir` 之类名字（`_env.ps1:8-12` 有注释） |
| 忘了 `rawfile` 是产物 | 改了 `web/src` 却看不到变化 | 必须重跑 `build-web.ps1`；`entry/src/main/resources/rawfile/{index.html,assets}` 不入库 |
| 装未签名 HAP 到模拟器 | `install sign info inconsistent`（code 9568332） | 用 DevEco 签名站点构建的包，或 `-Hap` 指定 |
| 手改 `platforms/harmony/CHANGELOG.md` 尾部 | 文件被编辑成 GBK，出现乱码 | 该文件 H3 之后已有历史乱码，改动请只追加并用 UTF-8 写回 |
| 旧文档当权威 | 按 `docs/HARMONYOS-PORT.md`（321 行）决策 | 该文档 `:3` 已标「已作废（2026-10-21）」，正确结论在 `platforms/harmony/README.md`；上面两条硬错是「只搜 openharmony kits 没搜 hms kits」「以为 vite base 是拦路虎，实际是 resource:// 的 CORS」 |
| 只跑 `accept-h5` 不跑 `accept-h0` | 桥/SQLite 回归漏检 | 碰 `entry/` 或平台缝就跑 h0 + h1 + h5 全链 |
| 期望有真实单测 | `entry/src/test/LocalUnit.test.ets:32-39` 只有一个模板用例 | 断言靠 `accept-h*.ps1` 的上机结果，不是单测 |

## 8. 写这份手册时的仓库状态（供对照）

- `harmony` 分支 HEAD `119d2e7 hs(H5.10): 换用新图标`，`origin/harmony` 落后 1 个提交。
- 工作树有**未提交**改动：`web/src/App.tsx`、`web/src/index.css`（H5.11：小地图/「›」开关按可见画布宽度让位）——动这两个文件前先确认是不是别人正在做的事。
- 未跟踪：`CaseBoard-win-test3.exe`、`docs/AI-ASSET-PROMPTS.json`、`docs/ai-assets/`。
- `docs/HARMONY-MILESTONES.md` 记 H5-7「桌面/鸿蒙双版本同步」仍是「未开始」，所以上面的回填表随时会变——以 `git log --oneline origin/main -- src` 为准。
