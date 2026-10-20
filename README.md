# caseboard-dev

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）用的 **案情板 CaseBoard 编辑技能**。

「案情板 CaseBoard」是一个已经验收完成的 Tauri 2 桌面办案应用（画布 / 代码双视图、时间线、素材与 OCR、导出、AI 抽取与生图）。这个技能要做的事只有一件：**让 AI 在这个代码库里改东西时，不破坏它已经立住的纪律**。

装上它以后，agent 一碰到 CaseBoard 仓库就会自动带上：

- **纪律**：Gate 0 八条硬约束（单一数据源、写入只走 Command、线型即语义、AI 只进待确认队列、本地优先、坐标只走 `lib/coords.ts`……），每条都指到具体的代码落点与守着它的断言；
- **地图**：六层依赖图、`CaseDoc` / `CaseNode` / `CaseEdge` 字段面、43 个命令工厂、DSL 双向同步链路、九个扩展点；
- **尺子**：四件套验收（typecheck / smoke / ui-smoke / bench）+ 桌面自检两轮，附实测基线与失败签名；
- **话术**：22 条可直接套用的作业提示词（12 条任务型 + 10 条流程型）。

## 为什么需要它

这类「AI 改得动但容易改坏」的项目，坑是固定的：

| 常见翻车 | 后果 |
| --- | --- |
| 为某个功能缓存第二份文档 | 画布与代码视图立刻不一致，且很难查 |
| 组件里直接改 store | undo 栈断掉、持久化漏掉、广播错乱 |
| 把可断言的逻辑写进 `services/` 或 `.tsx` | `tsconfig.smoke.json` 不编译它们，smoke 直接 `Cannot find module` |
| 忘了先构建就打包 | exe 里是旧前端，自检照样全绿 |
| 新行为不配断言 | 下一个里程碑把它踩掉，没人知道 |

技能把这些坑写成了**先验知识**：开工前读哪份、改哪一层、用什么证明改对了。

## 安装

需要 dsh **≥ 0.2.0-rc.2**（插件按 profile 装载）。

```bash
# 从 npm
dsh plugin add caseboard-dev

# 从本地目录（开发时）
dsh plugin add F:\path\to\caseboard-dev

# 从 git
dsh plugin add github:<your-github-name>/caseboard-dev
```

装完重启 dsh（或重新挂载该 profile）。技能会出现在技能目录里，名字是 `caseboard-dev`。

> 只想在单个仓库里用、不想装插件：把 `assets/skills/caseboard-dev/` 整个目录复制到目标仓库的 `.dsh/skills/` 下即可 —— 项目级技能（rank 100）优先级高于本插件（rank 600），两边同名时以仓库内那份为准。

## 它会怎么被触发

- **模型自动调用**：技能的 `description` 就是路由信号。任务落在 CaseBoard 仓库、或用户提到「案情板 / CaseBoard / caseboard」的改动、修复、打包、里程碑收尾时，模型会先加载技能正文。
- **手动调用**：`/caseboard-dev`（技能同时注册为可被用户调用）。
- **正文不常驻**：只有 `name` + `description` 进系统提示，`SKILL.md` 与 `references/` 在需要时才读。

## 包内有什么

```
caseboard-dev/
├── skills.js                      # 插件入口：注册一个 skill provider（零第三方依赖）
├── cordis.patch.yml               # 往 profile 里插入 caseboard-dev/skills 一行
├── assets/skills/caseboard-dev/
│   ├── SKILL.md                   # 技能正文：定位表、五条纪律、四步标准动作、八个高频坑
│   ├── references/00-workflow.md  # 四道闸门、规模分档、命令工具包、失败处置、收尾清单
│   ├── references/01-architecture.md  # 六层架构、字段面、43 个命令工厂、九个扩展点
│   ├── references/02-verification.md  # 四件套 + 桌面自检的跑法与失败签名
│   ├── references/03-constraints.md   # Gate 0 逐条：规则 → 落点 → 断言 → 破坏症状
│   ├── references/04-prompts.md   # 任务型提示词 12 条
│   ├── references/05-prompts.md   # 流程型提示词 10 条
│   └── scripts/check.ps1          # 一键自检（自动定位仓库根）
├── README.md
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

## 兼容性

| 项 | 要求 |
| --- | --- |
| dsh | ≥ `0.2.0-rc.2`（`@deepseek-ai/cordis` ≥ 4.0.4），按 `peerDependencies` 校验 |
| Node | ≥ 20（`skills.js` 只用 `node:fs/promises` 与 `node:url`） |
| 目标项目 | 案情板 CaseBoard（Tauri 2 桌面应用，主目标平台 Windows） |
| `check.ps1` | Windows PowerShell 5.1 / PowerShell 7 均可；非 Windows 上跑不了，技能正文仍然可用 |

## 合规声明

- **不联网**：插件不发起任何网络请求，不读取环境变量里的密钥，不收集遥测。
- **不落盘**：除读取自身 `assets/skills` 文本外，插件不写任何文件。
- **不起进程**：插件本身不 spawn 子进程；`check.ps1` 只有在你或 agent 显式执行时才运行仓库里的命令。
- **数据留在本机**：技能描述的应用本身是本地优先设计（SQLite + 本地素材），技能不改变这一点。

## 发布前需要替换

`package.json` 里的 `<your-github-name>` 三处（`repository` / `homepage` / `bugs`）与 README 里的安装示例换成你自己的仓库地址，然后：

```bash
npm publish --access public
```

## 许可

本技能包（`skills.js`、`cordis.patch.yml`、`SKILL.md`、`references/`、`scripts/`）以 **MIT** 发布，见 [LICENSE](LICENSE)。

它描述的 **案情板 CaseBoard 应用本体** 采用 **PolyForm Noncommercial 1.0.0**（可自由修改与分发，不得商用），两者是两套许可，详见 [NOTICE](NOTICE)。
