# caseboard-dev

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）用的 **案情板 CaseBoard 编辑技能**。

「案情板 CaseBoard」是一个已经验收完成的办案应用：**桌面端** Tauri 2 + React 18（画布 / 代码双视图、时间线、素材与 OCR、导出、AI 抽取与生图），**鸿蒙端** ArkTS + ArkWeb 承载同一套前端（平板布局、触控手势、集中钉子、红线、应用内对话框），两端在同一个仓库里。这个技能要做的事只有一件：**让 AI 在这个代码库里改东西时，不破坏它已经立住的纪律，也别改错分支。**

装上它以后，agent 一碰到 CaseBoard 仓库就会自动带上：

- **纪律**：Gate 0 八条硬约束（单一数据源、写入只走 Command、线型即语义、AI 只进待确认队列、本地优先、坐标只走 `lib/coords.ts`……），每条都指到具体的代码落点与守着它的断言；外加 G0-9 **双平台镜像白名单**（哪些文件该同名不同实现、逻辑先落 `main` 再同步）。
- **地图**：六层依赖图、`CaseDoc` / `CaseNode` / `CaseEdge` 字段面（含 `pinLinks` / `clusterPin` / `clusterOffset`）、43 个命令工厂、DSL 双向同步链路、十个扩展点，以及鸿蒙侧的 ArkWeb 桥、路由与 accepts 脚本链。
- **尺子**：桌面四件套验收（typecheck / smoke / ui-smoke / bench）+ 桌面自检两轮；鸿蒙侧 `build-web` → `accept-h5`（45 条）→ `accept-h0`（H0 八项），附实测基线与失败签名。
- **话术**：28 条可直接套用的作业提示词（16 条任务型 + 12 条流程型，含 P0 上下文注入模板），含触屏手感、钉子/钉集/红线、跨端回填、鸿蒙排障四类新模板。

## 为什么需要它

这类「AI 改得动但容易改坏」的项目，坑是固定的：

| 常见翻车 | 后果 |
| --- | --- |
| 为某个功能缓存第二份文档 | 画布与代码视图立刻不一致，且很难查 |
| 组件里直接改 store | undo 栈断掉、持久化漏掉、广播错乱 |
| 把可断言的逻辑写进 `services/` 或 `.tsx` | `tsconfig.smoke.json` 不编译它们，smoke 直接 `Cannot find module` |
| 忘了先构建就打包（桌面 `build`、鸿蒙 `build-web`） | 产物里是旧前端，自检照样全绿 |
| 新行为不配断言 | 下一个里程碑把它踩掉，没人知道 |
| 在 `harmony` 分支改根 `src/` | 那是落后主线 36 个文件的镜像，改动不会出现在任何产物里 |
| 整目录覆盖做「同步」 | 镜像里有 12 个鸿蒙独有文件，一覆盖就丢 |

技能把这些坑写成了**先验知识**：开工前读哪份、改哪一层、用什么证明改对了。

## 安装

需要 dsh **≥ 0.2.0-rc.2**（插件按 profile 装载）。

```bash
# 从 npm
dsh plugin add caseboard-dev

# 从本地目录（开发时）
dsh plugin add F:\path\to\caseboard-dev

# 从 git
dsh plugin add github:SIGHSHIGH/dsh-Caseboard-skill
```

装完重启 dsh（或重新挂载该 profile）。技能会出现在技能目录里，名字是 `caseboard-dev`。

> 只想在单个仓库里用、不想装插件：把 `assets/skills/caseboard-dev/` 整个目录复制到目标仓库的 `.dsh/skills/` 下即可 —— 项目级技能（rank 100）优先级高于本插件（rank 600），两边同名时以仓库内那份为准。

## 它会怎么被触发

- **模型自动调用**：技能的 `description` 就是路由信号。任务落在 CaseBoard 仓库、或用户提到「案情板 / CaseBoard / caseboard」的改动、修复、打包、里程碑收尾时，模型会先加载技能正文。
- **手动调用**：`/caseboard-dev`（技能同时注册为可被用户调用）。
- **正文不常驻**：只有 `name` + `description` 进系统提示，`SKILL.md` 与 `references/` 在需要时才读。

## 两个平台，一句话分清

| 你要改的东西 | 改哪里 |
| --- | --- |
| 命令 / 模型 / DSL / 自检规则 / 导出序列化 | 根 `src/`（分支 `main`），纯 TS 不受平台影响 |
| 桌面窗口、Tauri 插件、SQLite、打包安装包 | 根 `src/` + `src-tauri/` |
| 同一功能的**平台接入层**（文件、数据库、选择器、打印） | 各端自己的 `services/*`（桌面 `src/services`，鸿蒙 `platforms/harmony/web/src/services`） |
| 鸿蒙 ArkTS 桥、HAP 外壳、生命周期、权限 | `platforms/harmony/entry/src/main/ets/` |
| 触控手势、命中带、抽屉布局、只横屏闸门 | `platforms/harmony/web/src/` 与其 `styles/responsive.css` |

镜像规则：`platforms/harmony/web/src/` 是 `src/` 的副本，白名单内允许不同实现，**逻辑改动先落 `main` 再手工同步**，合并方向只许 `harmony → main`。细节见技能里的 `references/06-harmony.md`。

## 包内有什么

```
caseboard-dev/
├── skills.js                      # 插件入口：注册一个 skill provider（零第三方依赖）
├── cordis.patch.yml               # 往 profile 里插入 caseboard-dev/skills 一行
├── assets/skills/caseboard-dev/
│   ├── SKILL.md                   # 技能正文：平台判断表、五条纪律、标准动作、高频坑
│   ├── references/00-workflow.md  # 五道闸门、规模分档（含鸿蒙 H 档）、命令工具包、失败处置、收尾清单
│   ├── references/01-architecture.md  # 六层架构、字段面（含钉子/红线）、命令工厂、扩展点
│   ├── references/02-verification.md  # 桌面四件套 + 自检两轮 + 鸿蒙 accept 链与失败签名
│   ├── references/03-constraints.md   # Gate 0 逐条 + 双平台镜像纪律 + 架构约束
│   ├── references/04-prompts.md   # 任务型提示词 16 条
│   ├── references/05-prompts.md   # 流程型提示词 12 条（含 P0 上下文注入）
│   ├── references/06-harmony.md   # 鸿蒙侧：落点地图、ArkWeb 桥语义、DDL、accepts 脚本、已知限制
│   └── scripts/check.ps1          # 一键自检（自动定位仓库根）
├── README.md
├── CHANGELOG.md
├── LICENSE                        # MIT
└── NOTICE                         # 被描述的 CaseBoard 本体是另一套许可
```

## 一键自检

技能自带一个脚本，按「改了哪一层」选择台阶跑验证：

```powershell
# 改 lib/ 或 commands/：typecheck + smoke
powershell -ExecutionPolicy Bypass -File <技能目录>\scripts\check.ps1 -Quick

# 全套五道：typecheck → smoke → build → ui-smoke → bench
powershell -ExecutionPolicy Bypass -File <技能目录>\scripts\check.ps1
```

脚本会从自身位置向上找「含 `scripts/pnpm.cmd` + `src-tauri/tauri.conf.json`」的目录作为仓库根，找不到就用 `-Root <仓库根>` 显式指定。它会把 `TMP` / `TEMP` 指到仓库内的 `.tmp-esbuild`（否则 esbuild 处理大产物时在系统临时目录删不掉文件）。退出码 = 失败步骤数。

鸿蒙侧不归 `check.ps1` 管，在 `platforms/harmony/` 下跑自己的链：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-web.ps1   # 产物进 rawfile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\accept-h5.ps1   # 装 HAP + 上机断言
```

## 兼容性

| 项 | 要求 |
| --- | --- |
| dsh | ≥ `0.2.0-rc.2`（`@deepseek-ai/cordis` ≥ 4.0.4），按 `peerDependencies` 校验 |
| Node | ≥ 20（`skills.js` 只用 `node:fs/promises` 与 `node:url`） |
| 目标项目 | 案情板 CaseBoard 双平台单仓库（桌面 Tauri 2 主目标 Windows；鸿蒙 HarmonyOS 6.0 / API 20，ArkTS + ArkWeb） |
| `check.ps1` | Windows PowerShell 5.1 / PowerShell 7 均可；非 Windows 上跑不了技能里的桌面命令，技能正文仍然可用 |
| 鸿蒙 accept 链 | 需要 DevEco Studio（含签名站点）、hdc、一台平板模拟器或真机；缺任一项脚本会明确报出来 |

## 合规声明

- **不联网**：插件不发起任何网络请求，不读取环境变量里的密钥，不收集遥测。
- **不落盘**：除读取自身 `assets/skills` 文本外，插件不写任何文件。
- **不起进程**：插件本身不 spawn 子进程；`check.ps1` 只有在你或 agent 显式执行时才运行仓库里的命令。
- **数据留在本机**：技能描述的应用本身是本地优先设计（SQLite + 本地素材），技能不改变这一点。

## 仓库与发版

源代码在 <https://github.com/SIGHSHIGH/dsh-Caseboard-skill>。

```bash
git clone https://github.com/SIGHSHIGH/dsh-Caseboard-skill.git
```

改完技能内容后按语义化版本发版：

```bash
# 1) 改 package.json 的 version，并在 CHANGELOG.md 写清楚
# 2) 提交并打 tag
git commit -am "chore: bump x.y.z"
git tag -a vx.y.z -m "caseboard-dev x.y.z"
git push origin main --tags

# 3) 发布到 npm（可选：不发布也能用 dsh plugin add github:... 安装）
npm publish --access public
```

版本对应关系：

| 版本 | 对齐的项目状态 |
| --- | --- |
| `v0.1.0` | 案情板 CaseBoard Beta 1.0（M1–M18 全部验收通过，仅桌面） |
| `v0.2.0` | 双平台单仓库：桌面 M18 + 鸿蒙 H0–H5.11，桌面侧已回填集中钉子/钉集/红线/层级控件/节点挑选/组框挑人，鸿蒙侧已实现应用内对话框、触屏命中、响应式抽屉 |

## 许可

本技能包（`skills.js`、`cordis.patch.yml`、`SKILL.md`、`references/`、`scripts/`）以 **MIT** 发布，见 [LICENSE](LICENSE)。

它描述的 **案情板 CaseBoard 应用本体** 采用 **PolyForm Noncommercial 1.0.0**（可自由修改与分发，不得商用），两者是两套许可，详见 [NOTICE](NOTICE)。
