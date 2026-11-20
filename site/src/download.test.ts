// What the page offers, from the two reads (landing-page::REQ-001), and what each state's buttons say and where
// they lead (landing-page::REQ-002). The wording is the spec's and the confirmed prototype's. Every link is written
// out as a literal, not rebuilt with the module's helpers.
import { describe, expect, test } from 'vitest'
import { decide, view, type DownloadState } from './download'
import { LOCALES } from './i18n/ui'
import type { GitHubRead, PointerRead } from './releases'

const REPO = 'https://github.com/aloong-planet/justsnap'
const RELEASE_LIST = `${REPO}/releases`
const R2_DMG = 'https://dl.justsnap.aloongplanet.com/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg'

describe('deciding what to offer', () => {
  const formalR2: PointerRead = { kind: 'formal', version: '0.2.0', url: R2_DMG }
  const pointers: [string, PointerRead][] = [
    ['no pointer', { kind: 'absent' }],
    ['an unreadable pointer', { kind: 'unreadable' }]
  ]
  const githubs: [string, GitHubRead | undefined, DownloadState][] = [
    ['a release', { kind: 'formal', version: '0.2.0', dmg: true }, { kind: 'formal-github', version: '0.2.0', dmg: true }],
    ['a release without its DMG', { kind: 'formal', version: '0.2.0', dmg: false }, { kind: 'formal-github', version: '0.2.0', dmg: false }],
    ['no release', { kind: 'none' }, { kind: 'list' }],
    ['GitHub unreadable', { kind: 'unreadable' }, { kind: 'list' }],
    ['GitHub not read', undefined, { kind: 'list' }]
  ]

  test.each(githubs)('a readable pointer wins, whatever GitHub says (%s)', (_, github) => {
    expect(decide(formalR2, github)).toEqual({ kind: 'formal-r2', version: '0.2.0', url: R2_DMG })
  })

  test('a readable pointer wins over a newer release on GitHub: the mirror may lag (failure A4)', () => {
    expect(decide(formalR2, { kind: 'formal', version: '0.3.0', dmg: true })).toEqual({ kind: 'formal-r2', version: '0.2.0', url: R2_DMG })
  })

  for (const [p, pointer] of pointers) {
    test.each(githubs)(`${p}, and GitHub has %s`, (_, github, expected) => {
      expect(decide(pointer, github)).toEqual(expected)
    })
  }
})

describe('the list state', () => {
  test.each(LOCALES)('%s: both buttons lead to the release list, in a new tab', (locale) => {
    const v = view({ kind: 'list' }, locale)
    expect(v.hero).toMatchObject({ href: RELEASE_LIST, newTab: true })
    expect(v.section.buttons).toHaveLength(1)
    expect(v.section.buttons[0]).toMatchObject({ href: RELEASE_LIST, newTab: true, kind: 'primary' })
    expect(v.every).toBeNull()
  })

  test('copy, English', () => {
    const v = view({ kind: 'list' }, 'en')
    expect(v.hero.label).toBe('Download JustSnap from GitHub')
    expect(v.section.line).toBe("Version details can't be loaded right now — download from GitHub")
    expect(v.section.buttons[0]?.label).toBe('Download from GitHub')
  })

  test('copy, Chinese', () => {
    const v = view({ kind: 'list' }, 'zh')
    expect(v.hero.label).toBe('从 GitHub 下载随译')
    expect(v.section.line).toBe('暂时无法读取版本信息，请前往 GitHub 下载')
    expect(v.section.buttons[0]?.label).toBe('前往 GitHub 下载')
  })

  test.each(LOCALES)('%s: no version anywhere in the buttons, and every label is there', (locale) => {
    const v = view({ kind: 'list' }, locale)
    for (const label of [v.hero.label, v.section.line, ...v.section.buttons.map((b) => b.label)]) {
      expect(label.trim()).not.toBe('')
      expect(label).not.toMatch(/\d+\.\d+/)
    }
  })
})

describe('the state from R2', () => {
  const state: DownloadState = { kind: 'formal-r2', version: '0.2.0', url: R2_DMG }

  test('English: the versioned button downloads the DMG from the download host, in place', () => {
    const v = view(state, 'en')
    expect(v.hero).toEqual({ label: 'Download JustSnap 0.2.0', href: R2_DMG, newTab: false, kind: 'primary' })
    expect(v.every).toEqual({ label: 'See every version on GitHub', href: RELEASE_LIST, newTab: true, kind: 'primary' })
    expect(v.section.line).toBe('Current version 0.2.0')
    expect(v.section.buttons).toEqual([
      { label: 'Download', href: R2_DMG, newTab: false, kind: 'primary' },
      { label: 'GitHub', href: `${REPO}/releases/download/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg`, newTab: true, kind: 'ghost' }
    ])
  })

  test('Chinese: the same links, the spec’s wording', () => {
    const v = view(state, 'zh')
    expect(v.hero.label).toBe('下载随译 0.2.0')
    expect(v.every?.label).toBe('在 GitHub 查看所有版本')
    expect(v.section.line).toBe('当前版本 0.2.0')
    expect(v.section.buttons.map((b) => b.label)).toEqual(['下载', 'GitHub'])
  })
})

describe('the state from GitHub', () => {
  test('English: every link on GitHub, the download row with one button', () => {
    const v = view({ kind: 'formal-github', version: '0.2.0', dmg: true }, 'en')
    const dmg = `${REPO}/releases/download/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg`
    expect(v.hero).toEqual({ label: 'Download JustSnap 0.2.0', href: dmg, newTab: true, kind: 'primary' })
    expect(v.every).toEqual({ label: 'See every version on GitHub', href: RELEASE_LIST, newTab: true, kind: 'primary' })
    expect(v.section.line).toBe('Current version 0.2.0')
    expect(v.section.buttons).toEqual([{ label: 'Download', href: dmg, newTab: true, kind: 'primary' }])
  })

  test('a release without its DMG: the buttons lead to its release page (failure A6)', () => {
    const v = view({ kind: 'formal-github', version: '0.2.0', dmg: false }, 'en')
    const page = `${REPO}/releases/tag/v0.2.0`
    expect(v.hero.href).toBe(page)
    expect(v.section.buttons.map((b) => b.href)).toEqual([page])
  })
})

describe('every state in both languages', () => {
  const states: DownloadState[] = [
    { kind: 'formal-r2', version: '0.2.0', url: R2_DMG },
    { kind: 'formal-github', version: '0.2.0', dmg: true },
    { kind: 'list' }
  ]

  test('Chinese has the same shape in each state as English', () => {
    expect(LOCALES.filter((l) => l !== 'en')).toEqual(['zh'])
    const shape = (v: ReturnType<typeof view>) => ({
      hero: [v.hero.href, v.hero.newTab, v.hero.kind],
      every: v.every && [v.every.href, v.every.newTab],
      buttons: v.section.buttons.map((b) => [b.href, b.newTab, b.kind])
    })
    for (const state of states) {
      expect(shape(view(state, 'zh')), state.kind).toEqual(shape(view(state, 'en')))
      expect(view(state, 'zh').hero.label.trim(), state.kind).not.toBe('')
    }
  })

  test('the version comes from the state, so another release needs no change (REQ-001/AC-05)', () => {
    const a = view({ kind: 'formal-github', version: '0.2.0', dmg: true }, 'zh')
    const b = view({ kind: 'formal-github', version: '1.4.2', dmg: true }, 'zh')
    expect(a.hero.label).toContain('0.2.0')
    expect(b.hero.label).toContain('1.4.2')
    expect(b.hero.label).not.toContain('0.2.0')
    expect(b.hero.href).toBe(`${REPO}/releases/download/v1.4.2/JustSnap-1.4.2-mac-arm64.dmg`)
    expect(b.section.line).toContain('1.4.2')
  })
})
