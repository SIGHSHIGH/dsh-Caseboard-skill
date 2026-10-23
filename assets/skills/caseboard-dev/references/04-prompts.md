# 提示词库（12 个可直接套用的作业指令）

> 用法：把模板连同用户的原始描述一起交给执行者（自己或子代理）。`<>` 是占位符。
> 每条模板都写死了三件事：**先确认什么 → 按什么顺序改 → 用什么证明改对了**。这三件事缺一，改出来的东西就不算完成。

## 使用总则（贴在每条模板前面即可）

```
你在案情板 CaseBoard 仓库内工作（仓库根 = 当前工作区，含 `docs/CaseBoard-SPEC.md` 与 `src-tauri/`）。
先加载 caseboard-dev 技能（SKILL.md）并遵守其 Gate 0 红线与验收台阶。
规矩：一次只做一件事；写码前先给 3–6 条计划（涉及文件 + 验收标准）等我确认；
实现与断言同批交付；界面文案全中文；不引入新依赖；不删旧断言、不放宽阈值。
```

---

## P1 · 缺陷修复（用户口述现象）

```
现象：<用户原话，例如"在卡片上按住右键拖不动画布">
复现：<触发步骤；不确定就写"待我补充">
期望：<改完以后应该怎样>

要求：
1. 先定位到具体代码路径（贴出 file:line），用一句话解释根因——是数据错了、命令错了、还是渲染/事件错了。
2. 只改根因，不顺手重构；不改 Gate 0 相关的既有行为。
3. 若根因触碰 model/持久化，先告诉我影响面（旧档能否打开、迁移要不要动）。
4. 修复后在 scripts/smoke.cjs 新段（从 [80] 起）或 scripts/ui-smoke.cjs 加断言；
   断言要能在修复前失败、修复后通过（说明这一点）。
5. 跑：scripts\pnpm.cmd typecheck → smoke →（碰 .tsx 再 build + ui-smoke）。
6. 汇报用 SKILL.md §4 的格式，并写清"同类缺陷还有没有别处"。
```

## P2 · 新增面板 / 对话框（M 档）

```
需求：<例如"右栏加一个『案件时间轴摘要』面板">
行为：<有哪些字段、读哪些数据、有哪些操作>
位置：<右栏 / 顶栏菜单 / 底部状态栏 / 独立对话框>

要求：
1. 先读 references/01-architecture.md 第 6 节，确认挂载点与现有面板的写法（照最近的同类面板抄结构）。
2. 纯展示逻辑抽到 lib/（可被 smoke 断言）；面板自身只做 render + dispatch。
3. 所有写操作必须是既有命令工厂或新命令工厂（commands/ + index.ts 导出），不许在面板里 setState。
4. 样式只用 src/index.css 的令牌变量；新令牌要同时在 :root 与 lib/theme.ts 登记。
5. 验收：typecheck → build → ui-smoke（新面板至少 1 条源码/伪布局断言）。
```

## P3 · 模型新增字段（L 档，最容易漏的一类）

```
字段：CaseNode.<fieldName> : <类型>   （或 CaseEdge / Group / Asset / ImageNode / View）
语义：<它表示什么；缺省值是什么；旧档没有它时怎么补>
界面：<在右栏哪一组出现；还是只给导出/DSL 用>

按这个顺序改，一步都不能跳：
1. src/types/index.ts          —— 加字段（可选 ?，除非有明确缺省语义）
2. src/serializers/migrate.ts  —— normalizeDoc 里补缺省/夹取；越界值要夹，不合法要丢弃
3. src/services/db/mapping.ts  —— 落库/读库映射（如需持久化）
4. src/commands/*Commands.ts   —— update/add 工厂允许写它；涉及不变量就在这里拦
5. 右栏组件                     —— src/components/panels/RightPanel.tsx 对应分组
6. src/dsl/diff.ts             —— 若要在代码视图往返，加进 DSL_NODE_KEYS 白名单
7. src/dsl/serialize.ts + parse.ts —— 若进 DSL，还要补文本格式（并考虑改了 .grammar 就重生成）
8. scripts/smoke.cjs           —— 断言：缺省补全、越界夹取、往返一致、命令可撤销
9. scripts/ui-smoke.cjs        —— 断言：控件存在、文案中文

验收：typecheck → smoke → build → ui-smoke → bench（若碰 DSL）
额外：跑一次 snapshot 回放——用旧版 JSON 打开，字段应补默认值而不是 undefined。
```

## P4 · 新增节点类型

```
类型标识：<英文小写，例如 supplier>
中文名：<例如"涉案单位下属部门">
默认字段：<字段名+类型+是否必填，3–8 个>
颜色：<从既有 9 类的色板里取，或说明为何要新色>

改动清单（按 references/01-architecture.md §6.1 的顺序）：
1. src/types/index.ts:6          —— NodeType 联合加值
2. src/lib/nodeTemplates.ts      —— NODE_TEMPLATES 加模板（字段定义）+ NODE_TYPE_ORDER 排位
3. src/lib/theme.ts              —— NODE_TYPE_META（中文名/色/图标）
4. src/serializers/migrate.ts    —— 旧档里非法 type 的处理（当前回落到 note，确认这个回落仍成立）
5. src/serializers/svg.ts / png  —— 导出时角标与配色
6. src/lib/selfCheck.ts          —— 若该类型有必填字段，考虑加一条体检
7. smoke：模板字段、类型回落、导出文案；ui-smoke：左栏出现新类型按钮

禁止：直接复用 relation/note 的语义侥幸通过；新增类型不得让"已证实/推测/待核实"的线型语义变形。
```

## P5 · 新增导出格式

```
格式：<例如 Markdown 案件摘要 / Excel 清单>
用途：<给谁看、要不要脱敏、要不要含图片>
入口：<顶栏导出对话框 / 右栏按钮>

要求：
1. 纯函数写在 src/serializers/<fmt>.ts：输入 CaseDoc（+ 选项），输出 string 或 Uint8Array；不碰 DOM、不碰 store。
2. 需要二进制/打包时走 src/services 落盘（bytesToBase64 过 IPC，D26）。
3. 图片要转成内嵌还是引用外链，先问清；含 AI 素材必须带"AI 生成·模拟图"标注（Gate 0-5）。
4. 接线：src/components/panels/ExportDialog.tsx + TopBar 菜单项；文件名沿用 <案件名>_<格式>_<时间> 约定。
5. 断言：smoke 新段（结构/转义/中文不乱码/空文档不崩）；桌面自检若涉及真实落盘，追加一条 record。
```

## P6 · 新增自检项（13 → 14）

```
要体检什么：<例如"孤立图片节点（没有宿主卡片）">
级别：<pass 条件 / warn 条件 / fail 条件>
指引文案：<告诉用户去哪修，例如"右栏 → 图片 → 吸附到卡片">

步骤：
1. src/lib/selfCheck.ts 写 function checkXxx(doc: CaseDoc): SelfCheckItem
   返回 { id, title, level, detail, nodeIds }，中文，纯函数，绝不 dispatch。
2. push 进 runSelfCheck 的数组（:424-438 附近），位置按"结构类在前、统计类在后"。
3. 同步改两处计数断言：scripts/smoke.cjs:3692（items.length）与 scripts/ui-smoke.cjs:944（.cb-check__item）。
4. smoke 用例至少覆盖：干净档 pass、脏档 warn/fail、nodeIds 指得准。
5. 需要时补 docs/MANUAL-ACCEPTANCE.md 的 R 节。
```

## P7 · DSL 语法扩展

```
要支持：<例如"边的 evidenceIds 用 [e1,e2] 内联标注">
先确认：能不能不改语法实现？（relType 是自由文本、标签与时间已有槽位——很多时候不需要动 grammar）

必须改时：
1. grammar/caseboard.grammar
2. node scripts/build-grammar.mjs   ← 不跑这步，旧解析器会"全绿但拒绝新语法"
3. 提交 src/dsl/generated/caseboard.parser.ts（已入库，勿手改）
4. src/dsl/serialize.ts（固定字段顺序、名字表）+ parse.ts（parseDsl 永不抛异常，错误进 diagnostics）
5. src/dsl/diff.ts（新字段要加进 DSL_*_KEYS 白名单，否则不往返）
6. scripts/smoke.cjs [20][21][22] 段附近加断言：序列化幂等、解析容错、三方合并保留画布值
7. scripts/bench-dsl.cjs 跑一遍：1000 节点整链必须 < 300 ms

验收：typecheck → smoke → bench → build → ui-smoke；DSL 改动不许让旧文档解析失败。
```

## P8 · 新增纯 UI 状态 / 视图模式

```
需求：<例如"新增『对照视图』：左右并排两块画布">
持久化：<需要落进 CaseDoc 吗？只有"打开文件还要看到"的东西才需要；否则走 uiStore/viewStore>

规则：
- 临时状态（展开、拖拽中、悬浮）→ src/store/uiStore.ts，不许进 doc。
- 视图枚举 → src/store/viewModeStore.ts + App.tsx 渲染分支 + View.kind（若要随文档保存）。
- 画布渲染永远从 useDocStore 派生；两块画布也只能共享同一份 doc（Gate 0-1）。
- 键盘快捷键在 src/lib 里集中定义，别散在组件里。
```

## P9 · 打包发布

```
版本：<x.y.z>（三处同步：package.json / src-tauri/tauri.conf.json / src-tauri/Cargo.toml）

顺序执行（顺序错就要重来）：
1. Get-Process caseboard -ErrorAction SilentlyContinue | Stop-Process -Force
2. $env:TMP="$PWD\.tmp-esbuild"; $env:TEMP=$env:TMP
   $env:CARGO_HOME="$PWD\.rust\cargo"; $env:RUSTUP_HOME="$PWD\.rust\rustup"
   $env:PATH="$PWD\.rust\cargo\bin;"+$env:PATH
3. scripts\pnpm.cmd typecheck && smoke && bench && build && ui-smoke
4. scripts\pnpm.cmd build                          ← ★ beforeBuildCommand 是空的
5. node scripts/tauri-cli.cjs build --no-bundle
6. node scripts/run-selftest.cjs                   ← 两轮，任一失败 exit 3
7. node scripts/tauri-cli.cjs build --bundles nsis
8. powershell -ExecutionPolicy Bypass -File scripts/sign-installer.ps1（无证书会打印提示，属预期）

记录：exe 字节数、安装包字节数 + SHA-256、四件套数字 → CHANGELOG.md 与 docs/RELEASES.md；
产物拷进 release\（不入库）。发布说明写 docs/RELEASE-NOTES-<版本>.md。
```

## P10 · 里程碑收尾

```
里程碑：<Mn>，tag：<ms/Mn>

交付前自检：
- [ ] 三表在 docs/MILESTONES.md（范围/交付物/验收）已写，验收标准逐条对应断言
- [ ] 新决策进 §6，D 编号递增（当前末号 D101）
- [ ] CHANGELOG.md 条目：用户反馈原文 → 改了什么（带 file:line）→ 验收数字 → 产物摘要
- [ ] AGENTS.md 的范围行同步（M1–M18 / D1–Dxxx）
- [ ] 手工验收项补 docs/MANUAL-ACCEPTANCE.md
- [ ] git commit + tag；工作区干净
```

## P11 · 提交前自查（贴给评审者）

```
请只读审查以下改动，按 Gate 0 八条逐条给结论（命中/未命中/不适用），不要改代码：
- 是否出现第二份文档拷贝或第二条写入口？
- 是否有绕过 Command 的 doc 变更（含在 Command 外做 Immer mutation）？
- 新增/修改是否让"实线=已证实"语义变模糊，或给了关闭图例的口子？
- AI 相关：产出是否只进待确认？生图是否仍写像素角标、zone:'ai'、永不已证实？
- 是否新增非中文界面文案、非令牌颜色、非本地请求？
- 是否有组件自己算 world↔screen？
- 新逻辑是否落在 smoke 编译集内？断言是否真能在修复前失败？
- 是否删/放宽了既有断言？（这一条命中即驳回）
输出：file:line + 一句话风险 + 建议动作。最后给"可提交/需修改"。
```

## P12 · 交互手感调整（拖拽 / 吸附 / 锚点 / 曲率）

```
要调什么：<例如"卡片拖动时的对齐辅助线太黏">
当前实现：<先 grep 出 file:line，别凭印象>

规则：
- 拖动过程只写 uiStore（预览），松手才 dispatch（D15）；任何把预览写进 doc 的做法都会把 undo 栈刷爆。
- 坐标数学先进 lib/coords.ts 或 lib/ 对应模块，组件只调函数（D6）。
- 涉及锚点/曲率必须走 pickAnchorPair / bestGeometry（D95/D100/D101），不要在组件里另写一套代价模型。
- 阈值一律提常量并写在 lib/ 顶部（如 CHIP_MIN_GAP、DOCK_TOLERANCE、EDGE_JUDGE_PAD），禁止裸数字。
- 手感类改动必须给"改前/改后"的量化对比（例如压卡数、交叉数、吸附触发距离），并补 smoke 断言。
```

## P13 · 触屏 / 平板交互（长按、命中带、抽屉、触控尺寸）

```
要改的触控行为：<例如"长按卡片 100ms 进多选"、"连线命中带加宽到 34px"、"窄档右栏改浮层抽屉">
设备：<平板模拟器 MatePad Pro 13（1440×893 CSS px @ dpr 2）/ 真机 / 桌面触屏>

要求：
1. 先判断落点：这套改造是「鸿蒙独有」还是「两边都该有」——前者改 platforms/harmony/web/src（及 styles/responsive.css），
   后者先落 main 的 src/ 再同步（见 references/06-harmony.md 第 2 节）。改错分支 = 白干。
2. 触控尺寸走 lib/viewport.ts 的分档（1180 / 900）与 pointer: coarse 变量，不要另起一套断点。
3. 长按/拖拽阈值一律提常量（现有：长按 100ms、拖动跟手 480ms 档已废弃）并写进 lib/，禁止裸数字。
4. ArkWeb 会把真机长按抢成 contextmenu：必须同时给一条右键菜单通道，别只押长按。
5. 验收：platforms/harmony/scripts/accept-h5.ps1 加一条 Assertion（照 Add-Result 的写法，抓 hilog 探针）；
   桌面侧若同步了，main 工作树跑 typecheck + build + ui-smoke。
6. 手感必须给量化对比（帧间隔 p50/p95、drop 帧数、命中带宽度），照 H5-2 / H5-19 / H5-21 的格式。
```

## P14 · 集中钉子 / 钉集 / 红线（模型 + 命令 + 渲染 + DSL）

```
要加/改的钉子行为：<例如"钉集成员可绕钉旋转 15° 步进"、"红线支持箭头"、"钉集内层级可调">

按这个顺序改，一处都不能漏：
1. src/types/index.ts        —— CaseNode.type 加 'clusterPin' 相关字段 / ImageNode 加 pinPos·pinColor·clusterId·clusterOffset / PinLink 加属性
2. src/serializers/migrate.ts —— normalizeDoc 里补缺省与夹取（clusterOffset 一律走 clamp；pinLinkWidth 夹 1–12）
3. src/commands/             —— pinLinkCommands（红线）或 imageNodeCommands 的集内命令；一次操作 = 一条 Command = 一次撤销
4. src/lib/clusterPin.ts     —— 几何与常量（CLUSTER_Z_BASE 1000 / CLUSTER_PIN_Z 1600 / 钉子 30×30 / PIN_LINK_WIDTH 1–12 缺省 4）
5. 渲染                      —— Board.tsx 的拖拽分支（渲染优先级 dockPreview ?? dragPos ?? 派生坐标，松手清预览）
                               + PinLinkLayer.tsx（红线，ViewportPortal 内直线层）
6. 右栏                      —— RightPanel.tsx 对应分组；集中钉右栏不出现别名/地图坐标/评论
7. DSL                      —— 要进代码视图就同步 dsl/{serialize,parse,diff}.ts（白名单见 dsl/diff.ts）
8. 断言                      —— 桌面 scripts/smoke.cjs 新段（从 [80] 起）；鸿蒙 accept-h5.ps1 加 Assertion
9. 红线纪律                  —— 永不写进 CaseDoc.edges（G0-3 补注）

验收：typecheck → smoke → build → ui-smoke →（碰鸿蒙）build-web.ps1 + accept-h5.ps1
```

## P15 · 桌面 ↔ 鸿蒙回填（先判方向，再记账）

```
要回填的功能：<例如"鸿蒙的应用内确认框（A5）"、"钉集相对位置控件"、"触屏命中带">
来源：<harmony 分支的哪个文件/提交；还是主线 src/ 的哪次改动>

规则：
1. 先读 platforms/harmony/docs/FEATURE-DIFF-WIN-VS-HARMONY.md，确认这条在 A1–A10 / B1–B4 里的编号与"桌面现状"。
2. 方向只能是 harmony → main；落点在 main 工作树 F:\DSH PROJECT\.cb-main 的 src/。
3. 逐文件 port，不要整目录覆盖（镜像里有 12 个鸿蒙独有文件，桌面不该有）。
4. 桌面侧要补断言：scripts/smoke.cjs 新段 + scripts/ui-smoke.cjs（若动 UI）；平台特有代码不许进 smoke 编译集。
5. 记账三处：main 的 CHANGELOG.md（四段式：症状/根因/改了什么/验收）、
   platforms/harmony/docs/HARMONY-MILESTONES.md:23 的「桌面回填（main）」行、platforms/harmony/CHANGELOG.md 反向一条。
6. 若需要鸿蒙侧也同步，cherry-pick 回 harmony 并在台账写提交号（对照 774fa62 → 4a6315c 的做法）。
7. 验收：main 工作树四件套 + （碰 .tsx 时）build + ui-smoke；鸿蒙侧无改动就不必跑 accept 链。
```

## P16 · 鸿蒙侧构建 / 验收排障

```
症状：<例如"accept-h5 报 H5-35 red=0"、"模拟器装不上包"、"页面白屏"、"改了 web/src 没变化">

先按这个顺序排查（每步只改一件事并记录结果）：
1. 产物真的更新了吗：build-web.ps1 跑过没？entry/src/main/resources/rawfile/{index.html,assets} 的时间戳。
2. 装进去的是新包吗：accept-h5 的 -Hap 指向哪个 HAP；模拟器只认 DevEco 签名包（否则 code:9568332）。
3. 白屏 → 看是否 resource:// 与 ESM 的 CORS 问题（必须走 caseboard://rawfile/）。
4. 桥调用拿不到值 → 是不是没在参数表末尾传回调（asyncMethodList 不回传返回值）。
5. 页面源码显示成文本 → setMimeType 是否混进了 charset（只吃裸 MIME）。
6. 断言失败 → 报告 platforms/harmony/.tmp-esbuild/accept-h5.json 里那条的 detail；探针 phase 用
   node scripts/check-probe.mjs <Index.ets> <phase> 先校验源码能编译。
输出：根因（file:line）+ 修复 + 重跑的命令 + 前后对比数字。
```

---

## 组合用法

- **用户一句话需求** → 总则 + 对应 P 模板 + 用户原话。
- **大改动** → 先 P11 的审查口径写自己的计划，再逐个 P 模板执行；每完成一个子项跑一次 `check.ps1 -Quick`。
- **交接给子代理** → 总则 + 单一 P 模板 + 明确的文件白名单（"只许改这三个文件"），并要求它返回 file:line 与验证输出。
