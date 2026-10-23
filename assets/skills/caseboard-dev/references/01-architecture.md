# CaseBoard 架构地图（改代码前必读）

> 适用版本：桌面 Beta 1.0（M1–M18 全部验收通过，`package.json` = `1.0.0-beta.1`）＋鸿蒙移植线 H0–H5.10。
> 所有行号以写入时为准；若已漂移，用 `grep -n "<符号名>"` 重新定位，不要盲信行号。
> 本文件的行号取自主干 `main` 的 `src/`；鸿蒙副本 `platforms/harmony/web/src/` 同构，行号会平移几行。**动手前先 `git branch --show-current`**（见 `06-harmony.md` §0）。

## 0. 一句话结构

**一份 `CaseDoc` 是唯一数据源**；UI 只 `dispatch(Command)`，Command 用 Immer patch 改它，patch 进 undo 栈 → 防抖存 SQLite → Zustand 通知订阅者（画布重渲染 / 代码视图重新序列化）。画布与代码视图**都不是**第二份数据。

```
类型层 types/  ← 零依赖，只有声明
   ↑
纯逻辑 lib/    ← 只 import types：coords / theme / nodeTemplates / groups / filter / graph / selfCheck / edgeCurve / edgeOptimize / layout …
   ↑
命令层 commands/ ← 只 import types + lib，导出 Command 工厂，纯函数式改 Draft<CaseDoc>
   ↑
DSL dsl/ + 序列化 serializers/ ← types + lib（dsl 也含 grammar 产物）
   ↑
服务层 services/ ← 副作用（文件 / 图片 / SQLite / AI / 自检），不 import store
   ↑
状态层 store/   ← 持有唯一 CaseDoc + undo 栈 + 持久化订阅，import services
   ↑
组件层 components/ ← render + dispatch，绝不直接改 doc，绝不自己算坐标
```

依赖方向是**靠约定**维持的（没有 lint 拦截），所以越界写入一定会被人工评审打回。

### 0.1 两套前端（2026-10 起的仓库形态）

| | Windows 桌面 | HarmonyOS |
| --- | --- | --- |
| 前端代码 | `src/`（`main` 分支，唯一主干） | `platforms/harmony/web/src/`（`harmony` 分支，镜像副本） |
| 宿主 | Tauri 2 + WebView2，页面 `http://tauri.localhost` | ArkWeb + ArkTS 桥，页面 `caseboard://rawfile/index.html`（自定义 scheme，不能用 `resource://`） |
| 平台缝 | `services/platform.ts`、`db/tauri.ts`、Tauri 文件/对话框插件 | `services/{platform,file,ocr,storage,harmony}.ts`、`db/harmony.ts`、ArkTS 桥 25 方法 |
| 数据 | SQLite（tauri-plugin-sql），`%APPDATA%/app.caseboard.desktop/` | relationalStore，沙盒 `el2/base/haps/entry/files/` |
| 验收 | 四件套 + `caseboard.exe --selftest` 两轮 | `platforms/harmony/scripts/accept-h{0,1,4,5}.ps1` 上机断言 |

同一份 `CaseDoc` 语义、同一套 Gate 0、同一套 `lib/commands/dsl`；**差异只允许落在白名单文件里**（清单与纪律见 `06-harmony.md` 第 2 节）。逻辑改动先在 `main` 落地，再同步鸿蒙副本；鸿蒙侧新功能要判断是否回填桌面。

## 1. 各层职责与红线

| 层 | 目录 | 职责 | 红线 |
| --- | --- | --- | --- |
| 类型 | `src/types/index.ts` | 全部接口/联合类型，388 行，零 import | 不引任何模块 |
| 纯逻辑 | `src/lib/` | 坐标换算、主题与令牌、节点模板、分组渲染模型、筛选、图算法、自检、边几何、布局 | 不 import store / services / React |
| 命令 | `src/commands/` | `Command{label, apply(draft)}` 工厂 | 不 import store / services / React；**不调用任何 `set`** |
| DSL | `src/dsl/`（含 `generated/`） | 文本 ↔ 模型：序列化、解析、diff、合并 | 不 import store / components |
| 序列化 | `src/serializers/` | JSON / `.caseboard` 包 / 清单 / SVG / PNG / PDF / Word | 不 import store / React（`migrate.ts` 在 smoke 编译集内） |
| 服务 | `src/services/` | 全部副作用：平台（`platform.ts` 的 `isTauri()`）、SQLite（`db/repo.ts`、`db/mapping.ts`）、存储（`storage.ts`）、自检（`selftest.ts`）、OCR（`ocr.ts`） | **不 import store**（store 反过来 import 它们）；**不在 `tsconfig.smoke.json` 编译集内** |
| 状态 | `src/store/` | `docStore`（唯一文档 + undo）、`persist`、`codeStore`、`uiStore`、`viewStore`、`viewModeStore` | 只暴露 `dispatch/undo/redo/hydrate/flush/removeWithTrash`，**没有裸 set** |
| 组件 | `src/components/` | `flow/`（Board 1098 行、各 Node、BezierEdge）、`panels/`、`views/`、`code/` | 只 dispatch；坐标一律走 `lib/coords.ts` |

## 2. 文档模型（`src/types/index.ts`）

`CaseDoc`（`:364-388`）：

```ts
meta{ id, title, caseNo?, createdAt, updatedAt }
nodes: CaseNode[]
edges: CaseEdge[]
pinLinks?: PinLink[]        // 集中钉子之间的红线（H5.6 起；不是 CaseEdge，见下）
groups: Group[]
assets: Asset[]
imageNodes: ImageNode[]
assetFolders?: AssetFolder[]
timeline?: TimelineConfig
views: View[]
hypotheses: Hypothesis[]
chains?: ChainDef[]
settings: Settings
```

没有 `schemaVersion` 字段。**唯一合法入口是迁移器**：`normalizeDoc(input: unknown): CaseDoc`（`src/serializers/migrate.ts:549`）——
缺 `meta/nodes/edges` 抛 `DocMigrateError`（`:551-554`），端点缺失的边被丢弃（`:576`），id 去重。
`CASEBOARD_VERSION = 1`（`src/serializers/caseboard.ts:22`）只版本化 `.caseboard` 压缩包清单，不是文档版本。

关键实体字段：

- `CaseNode`（`:33-60`）：`id, type, title, x, y, w, h, zIndex?, groupId?, photo?, fields: Record<string,string|number|boolean>, aliases?, tags, status, confidence, time?, attachments, notes?, collapsed?, comments?`
  - `NodeType`（`:6`）= `'person'|'org'|'place'|'item'|'event'|'evidence'|'time'|'note'|'relation'`
  - `Status` = `todo | checking | confirmed | ruledout`
- `CaseEdge`（`:62-94`）：`id, source, target, sourceHandle?, targetHandle?, sourceAnchor?, targetAnchor?, controlPoints?, path: EdgePath, relType: string, label?, directed, style, color?, weight?, thickness?, autoAnchor?, curvature?, time?, confidence, evidenceIds, notes?, scenario?`
  - `LineStyle` = `solid | dashed | dotted`（**语义**：已证实 / 推测 / 待核实，不是样式偏好）
- `Group`（`:96-105`）：`id, title, bounds{x,y,w,h}, color, parentId?, collapsed, opacity?`
- `Asset`（`:150-184`）：`id, path, kind, hash, ocrText?, thumbnails, source?, zone?, width?, height?, …, annotations: Annotation[], aiGenerated?, aiMeta?`
- `ImageNode`（`:197-219`）：`id, kind:'freeImage', assetId, x, y, w, h, rotation, zIndex, borderStyle?, linkedNodeId?, dockCorner?, dockOffset?, pinned?, dotMode?`
- `View`（`:227-234`）：`id, kind('board'|'timeline'|'map'|'chain'|'presentation'|'scenario'), name, filters, camera?, steps?`
- `PinLink`（`main` 的 `src/types/index.ts:424-431`；鸿蒙 `web/src/types/index.ts:424`）：`id, source, target`——**只连两颗集中钉子**（`CaseNode.type === 'clusterPin'`），渲染成直线（`PinLinkLayer.tsx`，`stroke-width = settings.pinLinkWidth ?? 4`），**不进 `CaseDoc.edges`**，所以它没有线型语义、不参与关系梳理/证据链/DSL 边白名单。
- `Settings.pinLinkWidth?`：红线全局粗细（`lib/clusterPin.ts` 的 `PIN_LINK_WIDTH_MIN/MAX/DEFAULT = 1/12/4` 归一化），案件级、缺省 4。
- 集中钉子与钉集（H5.3–H5.6 引入，桌面已由 `cd6f9e1` 回填）：`NodeType` 多一个 `'clusterPin'`；`ImageNode` 多 `pinPos?`（图钉在图片内的相对落点）、`pinColor?`、`clusterId?`（所属集中钉子）、`clusterOffset?: XY`（成员相对钉子中心的偏移，入集后图片坐标**由钉子位置 + 偏移推导**，不再自由）。层级常量在 `lib/clusterPin.ts:17-23`：`CLUSTER_Z_BASE = 1000`、`CLUSTER_PIN_Z = 1600`、`CLUSTER_PIN_W/H = 30`。

## 3. 写路径（六步，少一步就是 bug）

1. 组件调用命令工厂：`dispatch(addNode({...}))`
2. `useDocStore.getState().dispatch(cmd)` —— **唯一写入口**（`src/store/docStore.ts:110`）
3. `produceWithPatches(doc, d => cmd.apply(d as Draft<CaseDoc>))`（`:112-114`）；patch 为空数组 = 无操作（`:115`，不会污染 undo 栈）
4. push `{label, patches, inverse}` 进 `past`，上限 `MAX_HISTORY = 200`（`:16`），清空 `future`
5. `scheduleSave(next)` → 400 ms 防抖 `SAVE_DEBOUNCE_MS`（`:18`）→ `flushPending` → `saveDocToStorage`（`src/services/storage.ts:46`）→ 更新 `lastSavedAt`；另有 5 分钟自动快照
6. 撤销 = `applyPatches(doc, entry.inverse)`（`:125`），重做 = `entry.patches`（`:134`），两者都会重新 `scheduleSave`

广播 = 普通 Zustand 订阅。代码视图桥 `src/components/code/useCodeSyncBridge.ts:12` 订阅 doc，用 `isApplyingCode()` 跳过自引起的变化，200 ms 防抖后重新序列化。

**注意**：`enablePatches()` 必须在任何 dispatch 前执行（`docStore.ts:25`），删了它第一个命令就会让 undo 崩。
`dispatch` 之外**不要**新增任何改变 `doc` 的入口——包括"临时预览"也必须留在 `uiStore.dragPos`（`:32-33`）这类 UI 状态里，等拖拽结束才 dispatch（`Board.tsx:534,581` 的 `onNodeDragStop`）。

## 4. 命令面（`src/commands/index.ts`，全量导出）

| 模块 | 覆盖 |
| --- | --- |
| `nodeCommands` | add / update / move / moveNodes / delete / restore / addComment / deleteComment / **setNodeLayer**（卡片层级，与自由图片共用同一 zIndex 空间） |
| `edgeCommands` | add / update / delete / restore |
| `pinLinkCommands` | **addPinLink / removePinLink / removePinLinksOf**（红线，写 `doc.pinLinks`，不碰 edges） |
| `docCommands` | 整档、settings、画布、地图底图 |
| `groupCommands` | add / update / rename / toggle / delete / move / resize / assignNodesToGroup / **addNodesToGroup**（组框「挑节点加入」：pad 24 / 组头 40 / 间距 16 / 卡片高度下限 96，只放大组框、不收窄卡片） |
| `assetCommands` | add / addAssets / update / delete / importAssets |
| `assetFolderCommands` | 素材文件夹 + `asset.folderId` |
| `imageNodeCommands` | add / update / move / resize / rotate / layer / delete / attach / layout ＋ 钉集一族：**attachImageToCluster / detachImageFromCluster / rotateClusterMember / nudgeClusterOffset / setClusterOffset / moveClusterBy / syncClusterMembers** |
| `annotationCommands` | `asset.annotations` |
| `hypothesisCommands` | 假设 + 立场 |
| `chainCommands` | 证据链 / 条目 |
| `timelineCommands` | `doc.timeline` |
| `layoutCommands` | 节点/分组坐标（走 `lib/layout`） |
| `edgeGeometryCommands` | 边的 `controlPoints` / `curvature` |
| `restoreCommands` | 回收站实体重插 |
| `dslCommands` | 应用代码视图的 `DocChange[]`（`:28` `applyDslChanges`） |
| `aiCommands` | 接受 AI 草稿（`:29` 的守卫在里面）——**AI 永远不能直接改 Model** |

新增命令的最小写法：

```ts
// src/commands/<entity>Commands.ts
import type { Command } from './types';   // { label: string; apply(draft: Draft<CaseDoc>): void }

export function doSomething(id: string, patch: Partial<CaseNode>): Command {
  return {
    label: '做某件事',                      // 中文，进撤销栈后显示在历史里
    apply(draft) {
      const node = draft.nodes.find((n) => n.id === id);
      if (!node) return;                   // 找不到就返回，patch 为空 = 无操作
      Object.assign(node, patch);          // Immer draft 内允许 mutating 风格
    },
  };
}
```

然后 `src/commands/index.ts` 里 `export * from './<entity>Commands';`，组件里 `useDocStore.getState().dispatch(doSomething(...))`。
复合操作（一次撤销 = 一个语义动作）用 `composeCommands(label, commands)`（`src/commands/compose.ts:7`）。

## 5. DSL 链路（代码视图）

```
CaseDoc ──serializeDoc(doc):string──► 文本（dsl/serialize.ts:239，名字表 :49）
文本 ──parseDsl(text):{doc,diagnostics}──► CaseDoc（dsl/parse.ts:952）
用户编辑 ──mergeDslEdit(baseline, codeNext, current) + diffDocs(before, after)──► DocChange[]（dsl/diff.ts:120）
DocChange[] ──applyDslChanges(changes)──► dispatch（commands/dslCommands.ts:28），外面套 applyingCode
```

- diff 的字段白名单：`DSL_NODE_KEYS`（`:45`）、`DSL_EDGE_KEYS`（`:65`）、`DSL_GROUP_KEYS`（`:83`）、`DSL_VIEW_KEYS`（`:84`）。**不在白名单里的字段不会往返**（assets / imageNodes / hypotheses / 画布设置按设计不可见），改白名单要同步改 smoke 的 DSL 段。
- 语法：`grammar/caseboard.grammar` → **手动**跑 `node scripts/build-grammar.mjs` → 产物 `src/dsl/generated/caseboard.parser.ts` **入库**（构建期不生成，文件头写着"请勿手改"）。改语法必须重跑脚本并提交两份文件。
- `codeStore` 只存 `text + baseline` 快照，**不存第二份文档**；画布每次从 `useDocStore.doc` 重新派生（`Board.tsx:205` 的 `buildRenderModel(doc)`）。

## 6. 扩展点（按改动量从少到多排序）

1. **新增节点类型**：`types/index.ts:6` `NodeType` → `lib/nodeTemplates.ts:33` `NODE_TEMPLATES` + `:158` `NODE_TYPE_ORDER`（同时驱动 `migrate.ts:44` 的类型校验和左栏清单）→ `lib/theme.ts:28` `NODE_TYPE_META`（标签/颜色/图标）→ 必要时 `components/flow/BaseNode.tsx`。
2. **新增关系类型**：`lib/theme.ts:73` `REL_PRESETS` + `:54` `REL_COLORS`（`relLabel` 在 `:85`）。`relType` 是自由文本（`grammar:29`），不需要改语法。
3. **新增面板**：`components/panels/*.tsx`，挂到 `App.tsx` 或左右栏；左栏页签枚举在 `uiStore.ts:7`。
4. **新增顶层视图**：`store/viewModeStore.ts:3` `ViewMode` → `App.tsx:154-156` 的渲染分支 → `components/views/*`；要持久化就同步 `View.kind`（`types:229`）与 `migrate.ts` 的 `normalizeView`。
5. **新增导出格式**：`src/serializers/<fmt>.ts`（纯函数、不碰 DOM），接线 `panels/ExportDialog.tsx` + `panels/TopBar.tsx`。
6. **新增纯 UI store**：`src/store/<x>Store.ts`（照 `viewStore.ts` / `uiStore.ts`）。只有需要持久化的东西才进 `CaseDoc`。
7. **新增服务**：`src/services/<x>.ts`，用 `isTauri()`（`platform.ts:12`）区分浏览器/桌面；记住它**不在 smoke 编译集**，可测逻辑要下沉到 `lib/`。
8. **新增自检项**：`lib/selfCheck.ts` 的 `runSelfCheck`（`:423`）里登记 `checkXxx(doc)`；`SelfCheckItem`（`:21`）= `{id,title,level:'pass'|'warn'|'fail',detail,nodeIds}`；阈值照 `SOLID_MIN_CONFIDENCE = 60`（`:40`）的写法提常量。**当前 13 项**，ui-smoke 里有断言"自检 13 项"，加一项必须同步改。
9. **改持久化形状**：`migrate.ts` 加归一化 + `db/mapping.ts` 加行字段 + `src-tauri/src/migrations.rs`（`V1_SQL`）三处一起改（`repo.ts:8`）。
10. **加一种集中钉子 / 钉集行为**：`lib/clusterPin.ts`（几何、`CLUSTER_Z_BASE=1000` / `CLUSTER_PIN_Z=1600` / 钉子 30×30、`memberPosition`/`rotateOffset`/`clusterMemberZ`）→ `commands/imageNodeCommands.ts` 的集内命令 → `components/flow/Board.tsx` 拖拽分支（渲染优先级 `dockPreview ?? dragPos ?? 派生坐标`，松手才 dispatch 并清预览）→ `panels/RightPanel.tsx` 对应分组 → 要进代码视图就同步 `dsl/{serialize,parse,diff}.ts`（H5.9 已打通，见提交 `83a396f`）。
11. **加一种红线语义**：红线**永远不进 `CaseDoc.edges`**。扩 `PinLink`（`types/index.ts`）+ `commands/pinLinkCommands.ts` + `components/flow/PinLinkLayer.tsx`（`ViewportPortal` 里画的直线层）+ `migrate.ts` 归一化，两侧 smoke 各加一条。

## 7. 已踩过的坑（照抄即可避坑）

- `enablePatches()` 早于 dispatch；空 patch 不算一次撤销。
- 拖拽预览在 `uiStore.dragPos`，只在 `onNodeDragStop` dispatch —— 否则 200 格 undo 栈会被拖动刷爆。
- `deleteNode` 会连带删关联边（`docStore.ts:165-170`）；`removeWithTrash` 同样处理，**恢复节点必须恢复它的边**（`restoreCommands.ts`）。
- DSL 白名单外的字段静默不往返（`dsl/diff.ts:44` 注释 D20）。
- `migrate.ts` 是唯一入口；`fromJson`（`serializers/json.ts:14`）先校验再归一化，并给 `meta.updatedAt` 打时间戳。
- `lib/coords.ts` 是唯一世界↔屏幕换算（D6）；React Flow 的 `onDrop` 已经给世界坐标，只有相对 DOM 的数学才需要 `screenToWorld`。
- 需要机器断言的逻辑只能放 `lib/` `serializers/` `commands/`；放 `services/` 或 `.tsx` 里 smoke 会 `require` 失败（M8 踩过）。
- 大文件只用 `edit` 定点替换：`read` 默认约 924 行上限，整份读出来再整份 `write` 回去会**静默截断**（M4 的 `scripts/smoke.cjs` 就这样丢过 [25][26][27] 段）。
- 红线别塞进 `CaseDoc.edges`：会被线型语义（Gate 0-3）、关系梳理、证据链、DSL 边白名单、导出关系清单一起吃掉，还会凭空多出一条「关系」。红线只活在 `pinLinks` + `PinLinkLayer`。
- 钉集有两套坐标：拖动中读 `dockPreview ?? dragPos ?? 派生坐标`，松手必须清预览、只 dispatch 一次；忘了清预览，钉子与成员图片的相对位置就会漂（H5.6 修的就是这个）。
- `window.confirm/alert` 在 WebView2 与 ArkWeb 里行为都不稳（鸿蒙已 9 处全替换成 `uiStore.askConfirm/pushNotice` + `panels/SystemDialogs.tsx`）。桌面还没回填，新增代码不要再引入原生弹窗。
