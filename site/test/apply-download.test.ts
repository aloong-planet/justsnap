// A state's view applied to the page as served (landing-page::REQ-002, US-001/AC-02, AC-03, failures A7, E1): the
// pages come from the run's fresh build, and each case gets its own DOM, since applying a view writes to it.
//
// Not covered here: whether the page keeps the visitor's place when a state lands while they are scrolled down
// (jsdom has no layout); test/init-download.test.ts checks that with stubbed rectangles.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { JSDOM } from 'jsdom'
import { beforeAll, describe, expect, inject, test } from 'vitest'
import { view, type DownloadState } from '../src/download'
import { ui } from '../src/i18n/ui'
import { applyView } from '../src/scripts/apply-download'

const REPO = 'https://github.com/aloong-planet/justsnap'
const R2 = 'https://dl.justsnap.aloongplanet.com/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg'
const html: Record<'zh' | 'en', string> = { zh: '', en: '' }

beforeAll(() => {
  const outDir = inject('builtSite')
  html.zh = readFileSync(join(outDir, 'index.html'), 'utf8')
  html.en = readFileSync(join(outDir, 'en/index.html'), 'utf8')
})

const page = (locale: 'zh' | 'en'): Document => new JSDOM(html[locale]).window.document
const text = (el: Element | null | undefined): string => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()

/** What a visitor gets from the hero and the download area */
function read(doc: Document) {
  const dl = doc.querySelector('.hero .dl')!
  const link = (a: Element | null) => a && { text: text(a), href: a.getAttribute('href'), target: a.getAttribute('target'), rel: a.getAttribute('rel') }
  return {
    hero: link(dl.querySelector('a.btn')),
    heroIcon: dl.querySelectorAll('a.btn svg').length,
    platform: text(dl.querySelector('.meta span')),
    every: link(dl.querySelector('.meta a.more')),
    line: text(doc.querySelector('.dlbox .ver')),
    buttons: [...doc.querySelectorAll('.dlbox .row a')].map((a) => ({
      ...link(a)!,
      kind: a.classList.contains('primary') ? 'primary' : 'ghost',
      icon: a.querySelectorAll('svg').length
    }))
  }
}

/** The markup a state changes: the hero's download block and the download area */
const markup = (doc: Document): string[] =>
  ['.hero .dl', '.dlbox'].map((s) => doc.querySelector(s)!.outerHTML.replace(/>\s+</g, '><').replace(/\s+/g, ' ').trim())

describe('a state applied to the served page', () => {
  test('the state from R2: the DMG from the download host in place, GitHub in a new tab', () => {
    const doc = page('en')
    applyView(doc, view({ kind: 'formal-r2', version: '0.2.0', url: R2 }, 'en'))
    const got = read(doc)
    expect(got.hero).toEqual({ text: 'Download JustSnap 0.2.0', href: R2, target: null, rel: null })
    expect(got.heroIcon).toBe(1)
    expect(got.platform).toBe('macOS 14.4 or later · Apple silicon')
    expect(got.every).toEqual({ text: 'See every version on GitHub', href: `${REPO}/releases`, target: '_blank', rel: 'noopener' })
    expect(got.line).toBe('Current version 0.2.0')
    expect(got.buttons).toEqual([
      { text: 'Download', href: R2, target: null, rel: null, kind: 'primary', icon: 1 },
      { text: 'GitHub', href: `${REPO}/releases/download/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg`, target: '_blank', rel: 'noopener', kind: 'ghost', icon: 0 }
    ])
  })

  test('the state from GitHub: every link on GitHub, one button', () => {
    const doc = page('en')
    applyView(doc, view({ kind: 'formal-github', version: '0.2.0', dmg: true }, 'en'))
    const got = read(doc)
    const dmg = `${REPO}/releases/download/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg`
    expect(got.hero).toEqual({ text: 'Download JustSnap 0.2.0', href: dmg, target: '_blank', rel: 'noopener' })
    expect(got.every?.href).toBe(`${REPO}/releases`)
    expect(got.buttons).toEqual([{ text: 'Download', href: dmg, target: '_blank', rel: 'noopener', kind: 'primary', icon: 1 }])
  })

  test.each(['zh', 'en'] as const)('%s: a later state replaces an earlier one in place, leaving nothing of it (failure A7)', (locale) => {
    const doc = page(locale)
    const served = markup(doc)
    applyView(doc, view({ kind: 'formal-r2', version: '0.2.0', url: R2 }, locale))
    expect(read(doc).buttons).toHaveLength(2)
    applyView(doc, view({ kind: 'formal-github', version: '0.2.0', dmg: true }, locale))
    const got = read(doc)
    expect(got.buttons).toHaveLength(1)
    expect(got.platform).toBe(ui[locale].platform)
    // And back to the list state: the markup as served, so a change to the components that applyView does not
    // follow fails here
    applyView(doc, view({ kind: 'list' }, locale))
    expect(markup(doc)).toEqual(served)
  })

  test.each(['zh', 'en'] as const)('%s: each state applies with the language’s own copy', (locale) => {
    const states: DownloadState[] = [
      { kind: 'formal-r2', version: '0.2.0', url: R2 },
      { kind: 'formal-github', version: '0.2.0', dmg: true }
    ]
    for (const state of states) {
      const doc = page(locale)
      const v = view(state, locale)
      // Copied out before the view is applied, so the expectation is not the object applyView receives
      const expected = { hero: v.hero.label, line: v.section.line, buttons: v.section.buttons.map((b) => b.label) }
      applyView(doc, v)
      const got = read(doc)
      expect(got.hero?.text, state.kind).toBe(expected.hero)
      expect(got.line, state.kind).toBe(expected.line)
      expect(got.buttons.map((b) => b.text), state.kind).toEqual(expected.buttons)
    }
  })

  test.each(['zh', 'en'] as const)('%s: every string of the states’ copy is on the page once its state is applied', (locale) => {
    const doc = page(locale)
    applyView(doc, view({ kind: 'formal-r2', version: '0.2.0', url: R2 }, locale))
    const shown = text(doc.body)
    const strings = Object.values(ui[locale].download.formal).map((s) => s.replace('{version}', '0.2.0'))
    expect(strings).toHaveLength(5)
    expect(strings.filter((s) => !shown.includes(s))).toEqual([])
  })

  test('labels are set as text: markup in one creates no element (failure E1)', () => {
    const doc = page('en')
    const v = view({ kind: 'formal-r2', version: '0.2.0', url: R2 }, 'en')
    v.hero.label = '<img src=x onerror=alert(1)>'
    v.every!.label = '<b>bold</b>'
    v.section.line = '<i>line</i>'
    v.section.buttons[0]!.label = '<u>button</u>'
    applyView(doc, v)
    expect(text(doc.querySelector('.hero .dl a.btn'))).toBe('<img src=x onerror=alert(1)>')
    expect(text(doc.querySelector('.hero .dl .more'))).toBe('<b>bold</b>')
    expect(text(doc.querySelector('.dlbox .ver'))).toBe('<i>line</i>')
    expect(doc.querySelectorAll('.hero .dl img, .hero .dl b, .dlbox i, .dlbox u')).toHaveLength(0)
  })
})
