/**
 * 案情板 CaseBoard 编辑技能 —— DSH 插件入口。
 *
 * 注册一个 skill provider：技能正文（SKILL.md）与参考手册（references/）随包分发，
 * 模型按需通过 `skill` 工具加载，不占用常驻上下文。
 *
 * 只依赖 Node 内置模块，不引入任何第三方运行时依赖。
 * @module caseboard-dev/skills
 */

import { readFile, readdir } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

/** Provider 名称（出现在技能来源里）。 */
const PROVIDER_NAME = 'caseboard-dev'

/** 技能根目录：<包>/assets/skills/<技能名>/SKILL.md */
const SKILLS_DIR = fileURLToPath(new URL('./assets/skills/', import.meta.url))

/**
 * 排序权重：与内置技能同级（600）。项目级 `.dsh/skills`（100）与 `.agents/skills`（200）
 * 的同名技能会盖过它 —— 想让某个仓库用改过的版本时，把技能放进该仓库即可。
 */
const SKILL_RANK = 600

/**
 * 解析 SKILL.md 的 YAML frontmatter（只认本仓库用到的标量键，够用且无依赖）。
 * @param {string} text 文件全文
 * @returns {Record<string, string>} 键值表（值已去掉包裹引号）
 */
function parseFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)
  if (!match) return {}
  /** @type {Record<string, string>} */
  const meta = {}
  for (const raw of match[1].split(/\r?\n/)) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const at = line.indexOf(':')
    if (at <= 0) continue
    const key = line.slice(0, at).trim()
    let value = line.slice(at + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    meta[key] = value
  }
  return meta
}

/**
 * 把 frontmatter 里的布尔写法归一化（与 dsh 技能加载器一致）。
 * @param {string | undefined} value 原始值
 * @param {boolean} fallback 缺省值
 */
function readFlag(value, fallback) {
  if (value === undefined || value === '') return fallback
  const lowered = value.toLowerCase()
  if (['true', 'yes', 'on', '1'].includes(lowered)) return true
  if (['false', 'no', 'off', '0'].includes(lowered)) return false
  return fallback
}

/**
 * 读取一个技能目录，生成 provider 候选条目。
 * @param {string} dirName 技能目录名
 */
async function describeSkill(dirName) {
  const locator = new URL(`./assets/skills/${dirName}/SKILL.md`, import.meta.url)
  const content = await readFile(locator, 'utf8')
  const meta = parseFrontmatter(content)
  return {
    name: meta.name || dirName,
    description: meta.description || '',
    invocation: {
      modelInvocable: !readFlag(meta['disable-model-invocation'], false),
      userInvocable: readFlag(meta['user-invocable'], true),
    },
    provider: PROVIDER_NAME,
    source: 'bundled',
    resourceBase: { kind: 'directory', path: fileURLToPath(new URL(`./assets/skills/${dirName}/`, import.meta.url)) },
    rank: SKILL_RANK,
    locator,
  }
}

/** @type {import('@deepseek-ai/dsh-skill').SkillProvider} */
const provider = {
  name: PROVIDER_NAME,
  async list() {
    let entries
    try {
      entries = await readdir(SKILLS_DIR, { withFileTypes: true })
    } catch {
      return []
    }
    const dirs = entries.filter(entry => entry.isDirectory()).map(entry => entry.name).sort()
    const candidates = []
    for (const dir of dirs) {
      try {
        candidates.push(await describeSkill(dir))
      } catch {
        // 目录里没有 SKILL.md（或读不出来）：跳过，而不是让整个 provider 失效。
      }
    }
    return candidates
  },
  async get(candidate) {
    const content = await readFile(candidate.locator, 'utf8')
    return {
      name: candidate.name,
      description: candidate.description,
      invocation: candidate.invocation,
      provider: candidate.provider,
      source: candidate.source,
      resourceBase: candidate.resourceBase,
      content,
    }
  },
}

/** Cordis 插件名。 */
export const name = 'caseboard-skills'

/** 需要 skills 服务。 */
export const inject = ['skills']

/**
 * 注册本包自带的技能。
 * @param {{ skills: { registerProvider: (factory: () => unknown) => void } }} ctx Cordis 上下文
 */
export function apply(ctx) {
  ctx.skills.registerProvider(() => provider)
}
