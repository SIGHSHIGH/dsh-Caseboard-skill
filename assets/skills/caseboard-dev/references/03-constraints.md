# Gate 0 八条硬约束：代码落点与验证

> 任何改动都要过这八条。每条给出**规则 → 落点（file:line）→ 谁在守着它 → 破坏后的症状**。
> 行号会漂移，漂了就 `grep -n "<标识符>"` 重新定位。

## G0-1 单一数据源（画布与代码视图同一份 Document Model）

- 落点：`src/store/codeStore.ts:9-17`（状态机 `idle→graphEditing→codeEditing→conflict→error`，注释写明"绝不存在第二份数据"）；`:54,:56` 的 `applyingCode`/`isApplyingCode`；`:83-114` `syncCodeText`（解析失败 → `state:'error'`，模型不动）；`:117` `flushGraphToCode`；`src/components/code/useCodeSyncBridge.ts:9-26`（订阅 doc → 200 ms 防抖 → `noteGraphChange`）；只读降级 `src/components/flow/Board.tsx:170` `graphLocked`、`:1011` `nodesDraggable={!graphLocked}`、`:1050` 横幅。
- 守着它：smoke `[23]`（`scripts/smoke.cjs:1113`；`:1119` "打开时代码是模型序列化"，`:1164` "解析失败不清空模型"，`:1168` "代码编辑只占一条撤销记录"）；smoke `[20]`（`:751` "序列化不修改模型"，`:752` "跨 JSON 往返输出不变"）；ui-smoke `:172`"已同步"徽标。
- 破坏症状：代码视图自己缓存一份 `CaseDoc`；CodeMirror 直接 dispatch 而不走 `applyDslChanges` —— 一次编辑出两条撤销记录、两个视图开始分叉。
- 要做的事：新视图一律从 `useDocStore` 派生，**不许**拷贝文档。

## G0-2 所有写操作走 Command

- 落点：`src/commands/types.ts:1-12`（`interface Command { label; apply(draft: Draft<CaseDoc>): void }`）；`src/store/docStore.ts:29-48` 的 `DocStore` 接口**没有 setter**（只有 `dispatch/undo/redo/hydrate/flush/removeWithTrash`）；`:110-119` `dispatch` = `produceWithPatches` → `patches.length===0` 丢弃 → `past.slice(-200)`（`:16`）→ `scheduleSave`（400 ms `:18`，5 分钟快照 `:20`）；`:121-137` undo/redo 走 `applyPatches(inverse/forward)`；内部 `setState` 只碰 `lastSavedAt/ready`（`:77,:199`）。命令工厂全在 `src/commands/index.ts` 汇总导出（0.1 版是 43 个；H5 回填后新增了 `pinLinkCommands` 一族与 `setNodeLayer` / `moveNodes` / `addNodesToGroup` / `setClusterOffset` 等，**确切清单以该文件为准**，模块职责见 `01-architecture.md` 第 4 节）。
- 注意："广播"没有叫这个名字的标识符，它就是 Zustand 订阅（`useCodeSyncBridge.ts:12`、各处的 `useDoc()`）。
- 守着它：smoke `[2]`（`:72-82` 加→撤→重做）、`[3]`（`:84` "撤销栈清空后不再生效"）、`:1018` "无改动时 changes 为空（不污染撤销栈）"、`:1178` "格式化不改模型、不占撤销栈"。
- 破坏症状：没有任何机制拦 `useDocStore.setState({doc})`（grep 确认 docStore 之外无人调用）。绕过 dispatch 立刻失去 undo 与持久化；在 Command 外做 Immer mutation 会静默改动 store 副本，撤销栈对不上。

## G0-3 线型即语义（实线=已证实 / 虚线=推测 / 点线=待核实，图例常驻不可关）

- 落点：`src/lib/theme.ts:48-52` `LINE_STYLE_META`——`solid`{实线, meaning '已证实'}、`dashed`{虚线, dash `'9 6'`, 推测}、`dotted`{点线, dash `'2 5'`, 待核实}；渲染 `src/components/flow/BezierEdge.tsx:145,147`（`strokeDasharray = meta.dash`）；图例 `src/components/panels/CanvasLegend.tsx:5`（三种线型固定数组）、`:43` 标题"线型即语义，固定不可关闭"、`:79` FAB"图示"；其它选择器 `ConnectDialog.tsx:82`、`RightPanel.tsx:639,:1394`、`PresentationView.tsx:199-200`。
- 守着它：smoke `:1413` "三种线型图例齐全"、`:1429` 空档导出仍写"已证实"、`:185` 导出设置里的图例文案；自检规则 `lines`（`src/lib/selfCheck.ts:235-253`，solid 且 confidence<60 → warn）；ui-smoke `:73-76`（顶栏图例已移走，`.cb-legend-fab` 必须存在）。
- 破坏症状：加"隐藏图例/隐藏虚线"开关；用置信度反推虚线。导出（`serializers/svg.ts`）与 DSL 读的是同一套三个值，改一处就会不一致。

## G0-4 AI 产出只进「待确认」队列，永不直接改 Model

- 落点：`src/store/aiStore.ts:72-88`（`toEntries` → `status:'pending'`）、`:133-150`（抽取只写 drafts，**不 dispatch**）、`:175-215`（`acceptOne` 先判 `status==='pending'` 才 `dispatch(acceptAiDrafts)`）、`:213-214` 驳回、`:220-233` 全采纳（一次 dispatch，只收 pending）；`src/commands/aiCommands.ts:29-31` 采纳命令（合并同名实体、新建一律 `status:'todo'`、新点排到右侧空白区）；`src/lib/extract.ts:287,:297-298`（陈述 → `dotted`/45；书证 → `solid`/88）；置信度夹取 `aiCommands.ts:64,84,106,118`；界面红线提示 `src/components/panels/AiPanel.tsx:4`。
- 守着它：smoke `:2055` "抽取不改动 Model"、`:2077` 点线 45、`:2119` 新实体待核实；ui-smoke `:411,:417-423,:434-437`。
- 破坏症状：抽取时顺手写进 `doc`；新增第二条"直接 append 节点"的采纳通道。采纳必须保持**一条命令、一次撤销**。

## G0-5 AI 生成图合规

- 落点：`src/lib/aiImage.ts:6` `AI_WATERMARK_TEXT = 'AI 生成 · 模拟图'`；**像素级**写入 `src/services/aiImage.ts:129-161`（`AI 生成 · 模拟图 · 非真实照片`，`:208,:223` 调用，无 UI 开关）；`buildAiMeta` `aiImage.ts:130-148`；资产落库 `services/aiImage.ts:398-409`（`zone:'ai'`、`aiGenerated:true`、`aiMeta`）；红线 `aiImage.ts:54-62,:71-87`（换脸 / 伪现场直接拒绝）；`blocksConfirmed` `:280-282`；**命令层地板** `src/commands/nodeCommands.ts:88-93`（`if (hasAi) delete next.status`）；自检规则 `ai`（`selfCheck.ts:255-283`，fail）；审计 `src/lib/aiAudit.ts:52-59,:113`。
- 守着它：smoke `:2624` "AI 素材永远不能算已证实"、`:2649-2660` 命令层拦截/解绑后放行、`:3733` 自检 ai=fail；桌面自检 `src/services/selftest.ts:439`（像素角标 + `blocksConfirmed` `:449`）；ui-smoke `:110,:119,:532`。
- 破坏症状：任何绕过 `stampWatermark` 直接插 data URL 的路径；把 zone 写成 'ai' 以外；绕过 `updateNode` 把节点改成已证实（地板在命令里，不在 UI 里）。

## G0-6 全中文界面 + 中性深灰/证据红（不用 UI 库默认紫蓝）

- **真正的主色源**是 CSS 变量，不是 `theme.ts`：`src/index.css:1-26` `:root` —— `--cb-bg #f5f3ef`、`--cb-panel #fbfaf7`、`--cb-border #e2ded5`、`--cb-text #2b2b2b`、`--cb-muted #6e6862`、`--cb-accent #c0392b`、`--cb-accent-strong #a93226`、`--cb-accent-soft rgba(192,57,43,0.08)`、`--cb-surface #ffffff`、`--cb-surface-2 #efece6`、`--cb-on-accent #ffffff`、`--cb-ok/-warn/-danger/-info`、`--cb-radius 8px`；深色 `:32-53`（`--cb-accent #ce4a3d`）、高对比 `:56-77`（`--cb-accent #b02a1e`）。
- 镜像与语义：`src/lib/theme.ts:4-16` `COLORS`、`:28-38` `NODE_TYPE_META`、`:40-45` `STATUS_META`；主题模式 `src/lib/themeMode.ts:12-35`；应用点 `src/store/themeStore.ts:18-24`（写 `data-theme`）+ `:48` 启动主题。
- 守着它：smoke `[48]`（`:2796`、`:2810` "默认主题仍有暖白表面变量（主色不变）"）；ui-smoke `:612`（`data-theme=board`）、`:615`（dark + localStorage `caseboard-theme`）、`:623`（"样式表组件层不再写死白底"）、`:893`（中文 aria-label）。
- 依赖里没有 UI 组件库（React / @xyflow / CodeMirror / zustand / immer / tauri），所以紫蓝主题不可能从库漏进来；`index.html` 是 `lang="zh-CN"`。
- **必须保持英文的**：provider id（`builtin`/`ollama`/`openai`）、存储键（`caseboard-theme`/`caseboard-ai-settings`）、ComfyUI 的 `class_type`、自检脚本里的 ASCII 前缀（`APP 桌面环境`、`ASSET 素材落盘`、`FTS 全文检索`）。
- 新增颜色：只在 `:root` 与 `theme.ts` 同时加 token，组件读变量/常量，**不许**在组件里写新的十六进制。

## G0-7 本地优先，云端能力需显式配置 + 二次确认

- 落点：`src/services/ai/settings.ts:2,7,9-15`（键 `caseboard-ai-settings`，`allowRemote:false`，baseUrl `127.0.0.1:11434`）、`:67-71` `isLocalProvider`（builtin 恒真、ollama 只认回环、openai 恒假）、`:82-87` `requireRemotePermission`（抛"当前是纯本地模式…"）；`src/services/ai/provider.ts:69-` 远程闸 + 90 s 超时；生图云端 `src/services/aiImage.ts:32,:44-46,:55,:71,:265-266`（需 `allowCloud` **且** `confirmCloud`）。
- 边界：`src-tauri/tauri.conf.json:27` 的 `"csp"` 为 null；`src-tauri/capabilities/default.json` 只授 fs/sql/dialog，没有 HTTP 插件；fetch 只出现在 `services/ai/provider.ts:74`、`services/aiImage.ts:235-291`、`serializers/png.ts:366`（本地资源 URL）。
- 守着它：桌面自检 `src/services/selftest.ts:483` "零外呼"（包装 `window.fetch`，只放行 `blob:/data:/tauri:/asset:/asset.localhost/ipc.localhost`）；smoke `:2334-2355`（中文 provider 名、隐私提示、ollama 非回环拒绝、未授权远程拒绝）、`[41]` `:2393`。
- 破坏症状：在这些文件之外新增 `fetch()` —— typecheck/build **抓不到**，只有桌面自检的"零外呼"会红。

## G0-8 坐标只走 `src/lib/coords.ts`

- 落点：`src/lib/coords.ts:14` `screenToWorld(point, viewport)`、`:21` `worldToScreen`、`:28` `snap(value, grid=8)`、`:32` `snapPoint`。唯一引入者 `src/components/flow/Board.tsx:31`（用于对齐辅助线 `:117-128`）。
- **已知例外（D 记录在案）**：`src/components/flow/GroupRectNode.tsx:59-60` 自己 `(event.clientX - start.x) / zoom`（`:40` 用 `useViewport()`），是历史遗留，改这块时顺手评估是否回收。
- 守着它：没有自动断言（人工评审项）；smoke `[44]` `:2663` 与 `[51]` `:2855` 只覆盖 `lib/map.ts` 的纯投影。
- 要做的事：新交互先在 `coords.ts` 加纯函数并写 smoke 断言，再让组件调用。

**补注（H5.6.3 起，2026-10）——红线不是关系线**：集中钉子之间的「红线」存在 `CaseDoc.pinLinks`（`PinLink{id,source,target}`，写入口 `commands/pinLinkCommands.ts`），由 `components/flow/PinLinkLayer.tsx` 直接画直线（`settings.pinLinkWidth ?? 4`），**不进 `CaseDoc.edges`、没有 `LineStyle`、不参与关系梳理 / 证据链 / DSL 边白名单**。线型语义只管 `edges`。
守着它：鸿蒙 `scripts/accept-h5.ps1` 的 H5-35（`red=1 redW=4`）、H5-36（`redLen=317`）、H5-39（`straight=1 edgesDelta=0`——红线没有多出一条边）；桌面 `scripts/smoke.cjs` 的「DSL 往返（H5.6.4：集中钉子与红线不再被代码视图丢掉）」段（`origin/main` 从 `:4252` 起，含「红线进入文本并解析回 `pinLinks`（id 稳定）」）。

## G0-9 双平台同构（镜像白名单）

- 落点：`platforms/harmony/web/src/` 是 `src/` 的**镜像副本**，白名单清单见 `06-harmony.md` 第 2 节（5 个平台缝同名不同实现 + 5 个鸿蒙新增 + 桌面独有的 `services/ocrBuiltin.ts`）。
- 纪律：逻辑改动**先落 `main` 再同步**；合并方向只许 `harmony → main`（`platforms/harmony/docs/REPO-STRATEGY.md:44-56`）；计划中的 `scripts/sync-web.ps1` **未实现**，同步是手工的。
- 守着它：没有自动断言（人工评审项）。能机械查的是 `diff -rq src platforms/harmony/web/src`——差异必须**只有白名单**那几项。
- 破坏症状：在 `harmony` 分支直接改根 `src/`（改到落后主线的镜像，白干）；两侧同一逻辑各写一份、慢慢分叉。

## 架构约束（不在 Gate 0 八条里，但一样会被打回）

1. **不用 `window.confirm/alert`**：桌面 WebView2 与 ArkWeb 都会吞掉或行为不一致。鸿蒙已全替为 `uiStore.askConfirm` / `pushNotice` + `components/panels/SystemDialogs.tsx`（TopBar 4 / AiPanel 3 / AiImagePanel 1 / HistoryDialog 1，共 9 处；云端授权两处带 `danger`）。桌面 A5 尚未回填——**新代码别再引入原生弹窗**。
2. **钉集坐标只认一条渲染链**：`dockPreview ?? dragPos ?? 派生坐标`（`lib/clusterPin.ts` 的 `memberPosition`），松手必须清预览、只 dispatch 一次；否则钉子与成员图片的相对位置会漂（H5.6）。
3. **钉集强制置顶**：成员 `z ≥ CLUSTER_Z_BASE(1000)`、钉子 `CLUSTER_PIN_Z(1600)`、钉子 30×30（`lib/clusterPin.ts:17-23`）。层级控件（`setNodeLayer`）要在这套地板之上工作，别把钉子压到卡片下面。

## 设计令牌速查

| 令牌 | 值 | 用途 |
| --- | --- | --- |
| `--cb-bg` | `#f5f3ef` | 画布底 |
| `--cb-panel` / `--cb-surface` | `#fbfaf7` / `#ffffff` | 面板 / 卡片 |
| `--cb-border` | `#e2ded5` | 常规描边 |
| `--cb-text` / `--cb-muted` | `#2b2b2b` / `#6e6862` | 正文 / 次要 |
| `--cb-accent` | `#c0392b`（证据红） | 选中、强调、主操作 |
| `--cb-accent-strong` | `#a93226` | 悬停/按下 |
| `--cb-radius` | `8px` | 统一圆角 |

`#C0392B` 的字面量散布在 `commands/groupCommands.ts:7,48`、`components/code/CodeEditor.tsx:75`、`components/flow/Board.tsx:1017`、`components/flow/FreeImageNode.tsx:254`、`data/demo.ts:208,239`、`data/demoAbc.ts:712,780`、`dsl/language.ts:54`、`lib/annotation.ts:30-31`、`lib/hypothesis.ts:14`、`lib/timelineTracks.ts:23`、`services/annotate.ts:41`、`services/selftest.ts:96`、`types/index.ts:128` —— 这些是导出/画布需要的常量镜像，不是随手写的色值。

## 自检系统（read-only 结构体检，13 项）

- 文件：`src/lib/selfCheck.ts`（459 行，纯函数，在 `lib/` 所以 smoke 能 require）。类型 `:19-37`；阈值 `SOLID_MIN_CONFIDENCE = 60`（`:40`）；**登记方式=普通数组**，`runSelfCheck` `:424-438`。
- 13 项顺序（id → 行号 → 标题）：`edges` `:75` 关系两端都存在(fail) · `groups` `:96` 分组引用有效 · `images` `:121` 图片节点引用有效 · `titles` `:147` 标题完整且不重复 · `time` `:179` 时间字段可解析 · `geo` `:214` 经纬度可解析 · `lines` `:235` 线型与置信度一致 · **`geometry` `:371` 关系线交叉与压卡（M18 新增，排在数组第 8 位、不是最后）** · `ai` `:255` AI 生成图合规(fail) · `hypotheses` `:285` 假设引用有效 · `chains` `:319` 自定义证据链完整 · `coverage` `:397` 时间线覆盖 · `tags` `:350` 标签可扩展关系。
- **加一项自检**：写 `function checkXxx(doc: CaseDoc): SelfCheckItem`（返回中文 `{id,title,level,detail,nodeIds}`，纯函数、不 dispatch）→ push 进 `:424-438` → 同步改两处计数断言 `scripts/smoke.cjs:3692`（`items.length===13`）与 `scripts/ui-smoke.cjs:944`（`.cb-check__item===13`）→ 需要时补 `docs/MANUAL-ACCEPTANCE.md:337` 的 R8 节。
- 面板：`src/components/panels/AiPanel.tsx:31,:115,:481`。

## 桌面自检（`src/services/selftest.ts`）

- 登记方式：`await record(name, fn)`（`:163-175`，fn 返回详情字符串，抛异常=fail，自动记录耗时）。
- 顺序（名称 → 行号）：`APP 桌面环境` `:178` → **[phase≥2] 重启后数据完整** `:186`（必须早于 ASSET，因为 ASSET 会覆盖原件）→ `ASSET 素材落盘` `:202` → `DB 保存并重开` `:229` → `FTS 全文检索` `:244` → `版本快照` `:250` → `回收站` `:262` → `.caseboard 打包` `:279` → `拷到另一目录可打开` `:289` → `整板 PNG 与模型一致` `:305` → `整板 SVG` `:332` → `多页 PDF` `:344` → `案件图片包 manifest.csv` `:371` → `脱敏马赛克不可逆` `:391` → `AI 文本能力` `:421` → `AI 模拟图` `:439` → `OCR 字段抽取` `:471` → `零外呼` `:483`（**永远放最后**，它证明整轮没有出网）。
- 加一项：插一条 `await record('中文名', async () => { ...; return '详情'; })`，保持"phase-2 在前、ASSET 之前""零外呼在最后"这两条顺序不变量。
