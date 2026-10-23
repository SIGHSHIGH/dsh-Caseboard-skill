# 提示词库 · 直接粘贴使用

每条提示词都是**一整段可粘贴的文本**。`{大括号}` 是占位符，粘贴前替换。
每条包含：**何时用 → 正文 → 期望产出 → 验收判据**。

> 原则：一次只让 AI 做一件事。改代码的提示词**不要**夹带发版；发版的提示词**不要**夹带改功能。

---

## P0 · 上下文注入（每个新会话第一条）

**何时用**：新会话、或压缩后失忆时。贴完再贴具体任务。
**作用**：让 AI 在 30 秒内进入「不越线」的工作状态，不必重读整个仓库。

```
你是案情板 CaseBoard 的开发 agent。仓库根 = 当前工作区（含 docs/CaseBoard-SPEC.md 与 src-tauri/）。
唯一权威规格 docs/CaseBoard-SPEC.md，执行契约 docs/MILESTONES.md（§6 决策记录 D1–D101），
项目约定 AGENTS.md（含 8 条 Gate 0 硬约束，逐条遵守，不许绕过）。
技术栈锁定：Tauri 2 + Rust · React 18 + TS strict + Vite · @xyflow/react · CodeMirror 6 + Lezer ·
Zustand + Immer · SQLite · graphology/dagre/d3-force。要偏离先说明理由并等我确认。

工作方式（每次都必须）：
1. 先给 3–6 条计划：涉及文件 + 验收标准，等我确认后再写代码。
2. 改大文件只用 edit 定点替换，禁止整份 read→write 回写（read 默认上限约 924 行，会静默截断）。
3. 所有写操作走 Command；图形/代码是同一条 Document Model；坐标只走 src/lib/coords.ts。
4. 完成后跑验收四件套（沙箱内 build 需 danger-full-access）：
   pnpm typecheck · pnpm smoke · pnpm ui-smoke · pnpm bench；涉及 UI/桌面再加 node scripts/run-selftest.cjs。
5. 报告口径：给出实际 PASS 数、毫秒数、error 数，不要写「应该没问题」。

现在开始：{任务描述}
```

---

## P1 · 开工计划（只出计划，不写代码）

**何时用**：任何非一行改动之上的任务。AGENTS.md 要求「开工先给 3–6 条计划，确认后再写代码」。

```
任务：{一句话目标}
背景：{为什么要改 / 用户看到的问题 / 期望效果}

请只输出计划，不要改任何文件。格式：

1) 现状判定 —— 用 file:line 说明现在这段逻辑在哪、为什么产生这个结果。不许猜，先 read。
2) 改动方案 —— 3–6 条，每条写：涉及文件（精确路径）· 改什么 · 为什么这样改而不是另一种做法。
3) 波及面清单 —— 这次改动会不会牵连：迁移 migrate.ts / DSL serialize+parse / 命令层 / 导出 SVG·PNG·PDF /
   图例 / 自检 selfCheck / smoke 段号。牵连到的必须列进来。
4) 新增断言 —— 打算往 pnpm smoke 的哪一段加几条、断言什么；ui-smoke 加几条源码/样式断言。
5) 验收判据 —— 可机器判定的成功条件（数字），以及只能人工确认的部分。
6) 风险与回退 —— 最坏情况是什么，怎么一步退回。

等我确认后再开始写代码。
```

---

## P2 · 定点实现（默认实现提示词）

**何时用**：计划已确认，开始改代码。**这是使用频率最高的一条。**

```
按已确认的计划实施。约束：

- 只改计划里列出的文件；发现必须新增文件时先停下来说明原因。
- 改大文件用 edit 定点替换（锚点取足够长的唯一上下文）；不要 write 覆盖整份。
- 严格 TS：禁止 any 逃逸；边界用 unknown + 类型守卫。
- 组件层不直接调平台 API，走 src/services；不引新依赖（要引先问我）。
- 注释与 UI 文案用简体中文。
- 逻辑必须放在可被 smoke 覆盖的层：src/lib/ 或 src/serializers/；
  src/services/ 与 .tsx 不在 tsconfig.smoke.json 里，别把可断言逻辑写进去。
- 每处行为变更补断言：新命令 → smoke；新面板/新样式 → ui-smoke。

完成后依次跑并在报告里给出原文数字：
pnpm typecheck → pnpm smoke → pnpm ui-smoke → pnpm bench →（涉及构建时）pnpm build
任一步失败：先修到全绿再报告，不要跳过或注释掉断言。
```

---

## P3 · 数据模型 / 字段变更（五处同步）

**何时用**：新增或修改 `CaseDoc` 里的任何字段（节点字段、边字段、settings、timeline…）。
**为什么用这条**：模型字段最容易「typecheck 过了但 DSL 往返丢字段 / 旧案卷打不开」。

```
需求：为 {实体} 增加字段 {字段名}: {类型}，语义是 {一句话}，缺省值 {值}。

这是模型字段变更，必须按五处同步顺序做完并逐一说明：
1. src/types/index.ts —— 类型声明（含注释里的中文语义）。
2. src/serializers/migrate.ts —— 迁移到新版本号：旧文档补默认值、脏数据夹取/白名单，
   并保证「已经是新版本」的文档不重复迁移。
3. src/commands/ —— 命令层写入路径（哪个命令写这个字段、有没有校验/拦截）。
4. src/dsl/serialize.ts + src/dsl/parse.ts —— DSL 是否表达该字段？
   若表达：序列化 + 解析双向都要改，并在 parse 里做容错；
   若不表达（如素材/自由图片/视觉态）：显式在 serialize.ts 的白名单里注明「不进 DSL」，
   并确认三方合并 diff.ts 不会把它当成差异抹掉。
5. scripts/smoke.cjs —— 新增一段断言：迁移补值、往返不丢、脏数据夹取、命令写入。

另外检查是否需要同步：导出（svg.ts / png.ts / pdfExport.ts）、右栏属性面板、selfCheck、
脚手架模板（nodeTemplates.ts）。不需要的也要一句话说明「为什么不涉及」。
```

---

## P4 · 新增节点类型 / 新关系语义

**何时用**：要加「第 10 类实体」或新的线型/关系语义。
**注意**：Gate 0-3 规定线型语义固定（实线=已证实 / 虚线=推测 / 点线=待核实），**不许新增线型**；
新语义只能落在字段、标签或节点类型上。

```
需求：新增节点类型 {type}（中文名 {中文名}），用途 {一句话}；字段 {字段清单}。

按「类型即注册表」的顺序做，每步说明改动：
1. src/types/index.ts —— 加进 NodeType 联合类型 + 类型中文名映射。
2. src/lib/nodeTemplates.ts —— 字段模板（这是字段唯一来源，只存在于代码，不做数据迁移）。
3. 画布呈现 —— src/components/flow/BaseNode.tsx 与 src/index.css 的样式（若需要不同外观，
   沿用现有卡片结构；关系气泡是用圆角胶囊 + 隐藏字段区的先例，见 D94）。
4. 类型库面板 —— 左栏类型库的入口与图标；右键新建菜单；新建对话框。
5. 右栏属性面板 —— 表单渲染（模板字段 + 自定义字段）。
6. 图例 / 语义不变 —— 确认没有引入新的线型语义；如需新的视觉区分，用字段不用线型。
7. 导出 —— svg.ts / png.ts / pdfExport.ts 的绘制分支（三种导出共用排版常量，别各写一份）。
8. 自检 selfCheck —— 是否需要一条结构一致性规则。
9. DSL —— 类型名在语法层不是关键字（D21），确认 parse.ts 能识别新首词；serialize 的排序键要覆盖新类型。
10. 断言 —— smoke 加序列化/解析/命令/迁移；ui-smoke 加类型库入口与卡片结构断言。
```

---

## P5 · UI / 交互改动

**何时用**：面板、布局、交互手感、样式。

```
需求（UI）：{具体交互描述，含触发方式与期望结果}

约束与做法：
- 先 read 目标组件的当前实现，报告它现在的交互链路（事件从哪进、状态存哪、命令在哪发）。
- 临时视觉态（拖拽预览、参考线、悬停高亮）放 src/store/uiStore.ts 等轻量 store，
  绝不写进 CaseDoc（D15）；落库只发生在松手后的那一条命令。
- 多对象一起变必须用 src/commands/compose.ts 的 composeCommands 合成一条命令（D54），
  否则一次 Ctrl+Z 只回退一半。
- 样式用既有令牌：--cb-control-h / --cb-control-h-sm / --cb-control-r / --cb-control-pad（D81）；
  新控件不要各写尺寸。主色中性深灰 + 证据红 #C0392B，禁止紫蓝默认主题。
- 全中文界面；文案不用「AI 已确认」这类暗示已证实的措辞。
- 弹出层若父级有 overflow 裁剪，必须走 createPortal + position: fixed（D86）。
- 涉及测量的组件（顶栏折叠、时间线刻度）在宽度未知（jsdom 恒 0）时必须「不折叠/不裁剪」降级（D83/D88）。
- 补 ui-smoke 断言（它做的是打包产物 + jsdom 伪布局 + 源码正则，能抓结构不能抓手感）。
```

---

## P6 · 缺陷定位与修复

**何时用**：用户报「不对 / 不生效 / 错位 / 没反应」。

```
缺陷：{现象}
复现：{步骤}
期望：{应该怎样}
实际：{现在怎样，含截图或数值}

分三步，不要跳步：
1. 定位 —— 给出根因的 file:line 与机制解释（哪一行导致这个现象）。
   贴出能证明的最小证据（代码行 / 断言 / 数据）。
   如果现象无法在自动化里复现，说明为什么，并给出可信的旁证
   （桌面端可用 WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9333 经 CDP 查页面态；
    日志走 hilog / debug.log）。
2. 影响面 —— 这个根因还影响哪些同类操作（列出文件与场景）。
3. 修复 —— 最小改动，不顺手重构；补一条能在改回后失败的回归断言（smoke 或 ui-smoke）。

报告里必须写明：改前什么行为、改后什么行为、哪条断言守住它。
```

---

## P7 · 验收报批（机器 + 桌面）

**何时用**：一轮改动做完，要写验收记录。

```
对本次改动做完整验收，输出一张表，每行给「命令 / 结果原文 / 判定」：

1. pnpm typecheck                → 期望 0 error
2. pnpm smoke                    → 给出 PASS 条数与新增/改动的段号
3. pnpm ui-smoke                 → 给出 PASS/FAIL 数
4. pnpm bench                    → 1000 节点解析链毫秒数（阈值 300ms）
5. pnpm build                    → 是否成功、产物大小、是否新增分包
6. 桌面（改动涉及 UI/桌面/持久化时必做）：
   先 Get-Process caseboard | Stop-Process -Force，
   设 TMP/TEMP/CARGO_HOME/RUSTUP_HOME/PATH，
   node scripts/tauri-cli.cjs build --no-bundle，
   再 node scripts/run-selftest.cjs（两轮：第 1 轮建数据与导出，第 2 轮复跑验证持久化）
   → 期望 phase1=PASS phase2=PASS

任何一项没跑，明确写「未跑 + 原因」，不要用「应该通过」代替。
最后给一份可粘贴进 docs/MILESTONES.md 的验收记录（表格 + 结论）。
```

---

## P8 · Gate 0 自审（只审不改）

**何时用**：合并前、发版前，或怀疑自己越界时。

```
对当前工作区做 Gate 0 自审，逐条给证据（file:line 或命令输出），发现违规只报告不擅自修：

1 单一数据源：图形视图与代码视图是否仍渲染同一份 Document Model（有无影子副本）。
2 写入口唯一：是否有绕过 Command 直接改 Model 的路径；store 是否暴露了裸 set。
3 线型语义：实线/虚线/点线 === 已证实/推测/待核实，图例是否常驻可查、有无「关闭语义」的开关。
4 AI 产出：是否只进「待确认」队列；采纳是否只有一条写入口；推断关系是否 dotted/dashed + 低置信度。
5 AI 生图：角标是否写入像素、有无移除开关、aiGenerated + aiMeta 是否完整、zone:'ai' 是否生效、
  是否拦住了换脸类提示词、是否可能出现「已证实」。
6 主题与语言：有无紫蓝主题残留、证据红 #C0392B 是否仍是强调色、界面是否有英文残留。
7 本地优先：有无新增外呼/遥测/云依赖；远程能力是否要显式授权 + 二次确认。
8 坐标：所有世界↔屏幕换算是否只经 src/lib/coords.ts。

报告格式：一条一行 —— 结论（符合/存疑/违规）· 证据 · 若不修的理由或建议。
最后一句回答：这批改动能不能发。
```

---

## P9 · 里程碑收尾与发版

**何时用**：功能与验收都过了，要留痕、要出安装包、要打 tag。

```
按仓库既有格式做收尾，五件事，顺序不要乱：

1. CHANGELOG.md —— 在最上方「[未发布]」区追加条目，沿用现有写法：
   用户原话（如有）→ 「改了什么」逐条（带 file 与机制）→ 「验收」给四件套原文数字
   + 桌面自检 phase1/phase2 + 产物字节数与 SHA-256。
2. 版本号三处同步（必须一致）：package.json · src-tauri/tauri.conf.json · src-tauri/Cargo.toml。
3. 文档 —— docs/MILESTONES.md 的 §7 变更记录追加一行；
   若有新的取舍，§6 决策记录追加 D{下一个编号}（决策 / 理由 / 影响 / 里程碑）；
   docs/MANUAL-ACCEPTANCE.md 若有人工验收项，追加一节。
4. 打包 —— 先杀残留进程；node scripts/tauri-cli.cjs build --no-bundle 出 caseboard.exe，
   跑 node scripts/run-selftest.cjs 两轮 PASS；再 --bundles nsis 出安装包；
   记录字节数与 SHA-256，归档到 release\（该目录不入库），并把记录写进 docs/RELEASES.md。
   签名：powershell -ExecutionPolicy Bypass -File scripts/sign-installer.ps1（无证书时说明「未签名」）。
5. git —— 一次性提交，message 沿用 [里程碑] 主题格式；打 tag（里程碑用 ms/M<n>，版本用 v<version>）。
   不要 --force、不要重写已推送历史。
```

---

## P10 · 回退 / 热修

**何时用**：改坏了，或用户只要回退。

```
回退请求：{要退回到什么状态}

先做三件事再动 git：
1. git status + git log --oneline -5 报告当前状态（有无未提交改动、HEAD 是什么）。
2. 判断最小回退单元：单个文件 / 单次提交 / 整条里程碑。
3. 给出回退方案与它的副作用（会不会丢别人的改动、要不要补验）。

回退后必须重跑：pnpm typecheck · pnpm smoke · pnpm ui-smoke（+ 涉及构建时 pnpm build）。
禁止：--force 推送、git reset --hard 前不确认未提交内容、删除历史提交。
```

---

## P11 · 双平台定位（任何跨端需求的第一条）

**何时用**：需求可能同时涉及桌面与鸿蒙，或用户只说「改一下手感 / 加个功能」而没说哪端。

```
需求原文：{用户的话}

先别写代码，回答这四件事：
1. 这个能力在两端现在是什么状态？（对照 platforms/harmony/docs/FEATURE-DIFF-WIN-VS-HARMONY.md
   的 A1–A10 / B1–B4，尤其 A 表里"桌面现状"那一列——能不能用 ≥ H5.x 之后主线是否已回填，
   去 main 工作树 grep 判定，例如 SystemDialogs.tsx / setNodeLayer / askConfirm 是否存在）
2. 它该落哪一侧：平台缝（原生 API / 渲染容器 / 生命周期 / 导出后端 / 存储后端）→ 各端各写；
   其余逻辑 → 先落 main 的 src/，再手工同步到 platforms/harmony/web/src。
3. 需不需要回填：如果落点是鸿蒙独有（例如触控手势、抽屉布局、钉集相对位置控件），
   按 04-prompts.md 的 P15 记账（CHANGELOG + HARMONY-MILESTONES:23 两列 + 差分文档）。
4. 验收各跑什么：桌面四件套 / 鸿蒙 build-web + accept-h5（+ 碰桥时 accept-h0）。

输出：一张三列表（能力 · 桌面现状 · 鸿蒙现状）+ 本次要改的文件白名单 + 验收命令。
不确定产品要不要两端一致时，把选择摆给用户，不要自己对齐。
```

---

## 反模式清单（贴在哪都适用）

| 别做 | 因为 |
|---|---|
| read 整份大文件再 write 回写 | read 有约 924 行上限，回写会静默截断（本项目真实踩过：smoke.cjs 丢段） |
| 把可断言逻辑写进 `src/services/` 或 `.tsx` | 不在 `tsconfig.smoke.json` 编译范围，smoke require 直接失败 |
| 为省事连发两条命令表达一次用户操作 | 撤销栈变成两步，Ctrl+Z 只回退一半（D54） |
| 逐帧 dispatch 改 Model 做拖拽 | 撤销栈被逐像素撑爆（D15：只留本地预览，松手落一条） |
| 在组件里自算 `screenToFlowPosition` 之外的换算 | 坐标必须单点走 `src/lib/coords.ts`（Gate 0-8） |
| 给 AI 产出加「已确认/已证实」直写 | Gate 0-4：AI 只进待确认队列 |
| 让线型表达新语义 | Gate 0-3：线型语义固定，不许扩展 |
| 直接改 `weight` 表达视觉粗细 | `weight` 参与统计/筛选语义，视觉粗细用 `thickness`（D96） |
| 改 DSL 相关逻辑不跑 bench | 1000 节点 <300ms 是硬门禁 |
| 用 `pnpm tauri` | 本机 argv[0] 是 Electron，会报 unrecognized subcommand，必须 `node scripts/tauri-cli.cjs` |
| 在 `harmony` 分支改根 `src/` | 那是落后主线 36 个文件的镜像，改动不会出现在任何产物里 |
| 用 `write` 整份覆盖镜像目录做「同步」 | 镜像有 12 个鸿蒙独有文件；要逐文件 port |
| 忘记 `build-web.ps1` 就直接装 HAP | rawfile 是产物，界面不会变 |
