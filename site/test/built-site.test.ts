// The built-site check (landing-page::REQ-003/AC-01, landing-page::REQ-003/AC-04, REQ-004/AC-03, REQ-005, REQ-006, landing-page::REQ-009/AC-01, CON-003, CON-004): the pages one build produces, read as files.
//
// It reads the HTML as served, before any script runs, so what it sees is what a visitor without scripts gets
// (landing-page::REQ-001/AC-04).
//
// Not covered here: the pinned showcase and how the scroll turns its steps (landing-page::REQ-004, failures C1–C4), the
// layout across widths (QR-001), the hero filling the first screen (REQ-003/AC-03), the two appearances (D1), the
// breadcrumb's look and its layout on narrow windows (landing-page::REQ-009/AC-02, landing-page::REQ-009/AC-03), and whether the screenshots show made-up
// content (REQ-005). They were measured in a headless browser against the built site when the page was written, not by a test; the
// stylesheet's rule for pages without scripts (C5) and the numbers the spec fixes are asserted below as text, since
// jsdom does not lay the page out. A test for the rest needs a real browser in CI.
import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'
import { JSDOM } from 'jsdom'
import postcss from 'postcss'
import { beforeAll, describe, expect, inject, test } from 'vitest'
import { ui } from '../src/i18n/ui'

const outDir = inject('builtSite')

/** Every file under the build output, as paths relative to it */
function files(dir = outDir): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? files(join(dir, e.name)) : [relative(outDir, join(dir, e.name))]
  )
}

const pages: Record<'zh' | 'en', Document> = {} as Record<'zh' | 'en', Document>
const sources: Record<'zh' | 'en', string> = { zh: '', en: '' }

beforeAll(() => {
  sources.zh = readFileSync(join(outDir, 'index.html'), 'utf8')
  sources.en = readFileSync(join(outDir, 'en/index.html'), 'utf8')
  pages.zh = new JSDOM(sources.zh).window.document
  pages.en = new JSDOM(sources.en).window.document
})

const REPOSITORY = 'https://github.com/aloong-planet/justsnap'
const LOCALES = ['zh', 'en'] as const

const text = (el: Element | null | undefined): string => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()
/** A PNG's pixel size, from its header */
function pngSize(path: string): { width: number; height: number } {
  const bytes = readFileSync(join(outDir, path))
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) }
}

describe('the site is two pages', () => {
  test('one page per language, and nothing else a visitor could open', () => {
    expect(files().filter((f) => f.endsWith('.html')).sort()).toEqual(['en/index.html', 'index.html'])
  })

  test.each(LOCALES)('%s: the page declares its language', (locale) => {
    expect(pages[locale].documentElement.getAttribute('lang')).toBe(ui[locale].htmlLang)
  })
})

describe('page structure (REQ-003)', () => {
  test.each(LOCALES)('%s: the header holds the brand, the navigation and, at its right, the toggle', (locale) => {
    const doc = pages[locale]
    const header = doc.querySelector('header')
    expect(text(header?.querySelector('a.brand'))).toBe(locale === 'zh' ? '随译 JustSnap' : 'JustSnap')

    const nav = [...(header?.querySelectorAll('.nav a') ?? [])]
    expect(nav.map((a) => a.getAttribute('href'))).toEqual(['#features', '#download', REPOSITORY])
    for (const a of nav.slice(0, 2)) expect(doc.getElementById(a.getAttribute('href')!.slice(1)), a.getAttribute('href')!).not.toBeNull()

    // The toggle is the bar's last group; toggling goes to the other language's page (failures B1, B2)
    const toggle = header?.querySelector('.wrap')?.lastElementChild
    expect([...(toggle?.children ?? [])].map(text)).toEqual(['中文', 'EN'])
    const other = toggle?.querySelector('a')
    expect(other?.getAttribute('href')).toBe(locale === 'zh' ? '/en/' : '/')
    expect(toggle?.querySelector('[aria-current="page"]')?.textContent).toBe(locale === 'zh' ? '中文' : 'EN')
  })

  test.each(LOCALES)('%s: the header brand carries the app icon beside the text (REQ-008)', (locale) => {
    const mark = pages[locale].querySelector('header a.brand img')
    expect(mark?.getAttribute('src')).toBe('/icon.svg')
    // The text next to it names the app, so the picture is decoration for a screen reader
    expect(mark?.getAttribute('alt')).toBe('')
    expect(files()).toContain('icon.svg')
  })

  test.each(LOCALES)('%s: the browser tab uses the app icon, as SVG with a PNG fallback (REQ-008)', (locale) => {
    const icons = [...pages[locale].querySelectorAll('head link[rel="icon"]')].map((l) => [l.getAttribute('href'), l.getAttribute('type')])
    expect(icons).toEqual([
      ['/icon.svg', 'image/svg+xml'],
      ['/icon.png', 'image/png']
    ])
    expect(files()).toContain('icon.png')
  })

  // The way back to the author's homepage, where the other apps and tools are listed. The trail follows the WAI-ARIA
  // Authoring Practices breadcrumb pattern: a labelled navigation landmark around an ordered list, the link to this
  // page marked as the current page, and the separator kept from assistive technology.
  test.each(LOCALES)('%s: the header starts with the way back to aloong planet, then the brand (landing-page::REQ-009/AC-01)', (locale) => {
    const trail = pages[locale].querySelector('header .wrap')?.firstElementChild
    expect(trail?.tagName.toLowerCase()).toBe('nav')
    expect(trail?.getAttribute('aria-label')).toBe(locale === 'zh' ? '面包屑' : 'Breadcrumb')
    const items = [...(trail?.querySelectorAll(':scope > ol > li') ?? [])]
    expect(items).toHaveLength(2)

    // Opens in the current tab, and is written the same in both languages
    const home = items[0]?.firstElementChild
    expect([home?.tagName.toLowerCase(), text(home), home?.getAttribute('href'), home?.hasAttribute('target')]).toEqual([
      'a',
      'aloong planet',
      'https://aloongplanet.com/',
      false
    ])
    // The separator is seen, not read, and leads nowhere
    const separator = items[0]?.lastElementChild
    expect([text(separator), separator?.getAttribute('aria-hidden'), separator?.matches('a, a *')]).toEqual(['/', 'true', false])
    // The brand keeps its link to the top of the page, the page the trail ends on
    const brand = items[1]?.firstElementChild
    expect([brand?.matches('a.brand'), brand?.getAttribute('href'), brand?.getAttribute('aria-current')]).toEqual([true, '#top', 'page'])
  })

  test('the English navigation reads as the spec’s', () => {
    expect([...pages.en.querySelectorAll('header .nav a')].map(text)).toEqual(['Features', 'Download', 'GitHub'])
  })

  // A screen reader reads the role after the name, so the name leaves the role's word out (layouts/Base.astro)
  test.each(LOCALES)('%s: the header navigation is named without its role word (landing-page::REQ-003/AC-04)', (locale) => {
    const nav = pages[locale].querySelector('header .nav')
    expect([nav?.tagName.toLowerCase(), nav?.getAttribute('aria-label')]).toEqual(['nav', locale === 'zh' ? '主要' : 'Main'])
  })

  test.each(LOCALES)('%s: hero, features and download in that order, then the footer', (locale) => {
    const doc = pages[locale]
    expect([...(doc.querySelector('main')?.children ?? [])].map((s) => s.id)).toEqual(['top', 'features', 'download'])
    expect(doc.querySelector('main')?.nextElementSibling?.tagName.toLowerCase()).toBe('footer')
  })

  test.each(LOCALES)('%s: the footer links to the repository and its releases, in new tabs', (locale) => {
    const links = [...pages[locale].querySelectorAll('footer a')]
    expect(links.map((a) => [a.getAttribute('href'), a.getAttribute('target')])).toEqual([
      [REPOSITORY, '_blank'],
      [`${REPOSITORY}/releases`, '_blank']
    ])
  })

  test.each(LOCALES)('%s: the download section holds the download area, then the three install steps', (locale) => {
    const section = pages[locale].getElementById('download')!
    expect([...section.querySelector('.wrap')!.children].map((c) => c.className || c.tagName.toLowerCase())).toEqual(['h2', 'dlbox', 'sub', 'cards'])
    expect(text(section.querySelector('h2'))).toBe(locale === 'zh' ? '下载与安装' : 'Download and install')
    expect([...section.querySelectorAll('.card')].map((c) => text(c.querySelector('.no')))).toEqual(['1', '2', '3'])
  })
})

describe('the hero (REQ-007)', () => {
  test('Chinese title and lead are the spec’s', () => {
    expect(text(pages.zh.querySelector('#top h1'))).toBe('截一块屏幕，直接提取文字或翻译')
    expect(text(pages.zh.querySelector('#top .lead'))).toBe(
      '随译（JustSnap）是 macOS 菜单栏里的截图工具：框选任意区域，几秒内拿到提取的文字或译文。用你自己的模型服务商。'
    )
  })

  test('English title and lead are the spec’s', () => {
    expect(text(pages.en.querySelector('#top h1'))).toBe('Snap any part of your screen. Get the text or the translation.')
    expect(text(pages.en.querySelector('#top .lead'))).toBe(
      "JustSnap lives in your Mac's menu bar. Select any region, and seconds later a vision model hands back the text or the translation. Bring your own provider."
    )
  })
})

describe('as served, the list state (REQ-001/AC-04, REQ-002/AC-03)', () => {
  test.each(LOCALES)('%s: the hero button leads to the release list, in a new tab, with no version, and the platform line is there', (locale) => {
    const dl = pages[locale].querySelector('#top .dl')!
    const button = dl.querySelector('a.btn')!
    expect(text(button)).toBe(locale === 'zh' ? '从 GitHub 下载随译' : 'Download JustSnap from GitHub')
    expect(button.getAttribute('href')).toBe(`${REPOSITORY}/releases`)
    expect([button.getAttribute('target'), button.getAttribute('rel')]).toEqual(['_blank', 'noopener'])
    expect(text(dl.querySelector('.meta'))).toBe(locale === 'zh' ? 'macOS 14.4 或更高 · Apple 芯片' : 'macOS 14.4 or later · Apple silicon')
    expect(dl.querySelector('.more')).toBeNull()
  })

  test.each(LOCALES)('%s: the download area gives its failure line and one button to the release list', (locale) => {
    const box = pages[locale].querySelector('.dlbox')!
    expect(text(box.querySelector('.ver'))).toBe(
      locale === 'zh' ? '暂时无法读取版本信息，请前往 GitHub 下载' : "Version details can't be loaded right now — download from GitHub"
    )
    const buttons = [...box.querySelectorAll('.row a')]
    expect(buttons.map((a) => [text(a), a.getAttribute('href')])).toEqual([[locale === 'zh' ? '前往 GitHub 下载' : 'Download from GitHub', `${REPOSITORY}/releases`]])
  })
})

describe('features (REQ-004, US-003)', () => {
  test.each(LOCALES)('%s: six steps in the showcase and in the stacked list, counted 01 / 06 to 06 / 06', (locale) => {
    const doc = pages[locale]
    const t = ui[locale]
    expect([...doc.querySelectorAll('.deck-text h3')].map(text)).toEqual(t.steps.map((s) => s.title))
    expect([...doc.querySelectorAll('.fs-step h3')].map(text)).toEqual(t.steps.map((s) => s.title))
    expect([...doc.querySelectorAll('.deck-n')].map(text)).toEqual(['01 / 06', '02 / 06', '03 / 06', '04 / 06', '05 / 06', '06 / 06'])
    expect(doc.querySelectorAll('.deck-turn')).toHaveLength(5)
  })

  test.each(LOCALES)('%s: as served the first step is the current one, in text and screenshot', (locale) => {
    const doc = pages[locale]
    const on = (sel: string): number[] => [...doc.querySelectorAll(sel)].flatMap((e, i) => (e.classList.contains('on') ? [i] : []))
    expect(on('.deck-text')).toEqual([0])
    expect(on('.deck-shot')).toEqual([0])
  })

  test.each(LOCALES)('%s: each step has its own screenshot, in both layouts', (locale) => {
    const doc = pages[locale]
    const pinned = [...doc.querySelectorAll('.deck-shot img')].map((i) => i.getAttribute('src'))
    const stacked = [...doc.querySelectorAll('.fs-step img')].map((i) => i.getAttribute('src'))
    expect(pinned).toHaveLength(6)
    expect(new Set(pinned).size).toBe(6)
    expect(stacked).toEqual(pinned)
    for (const src of pinned) expect(src, 'one set per language').toMatch(new RegExp(`-${locale}\\.png$`))
  })

  test('the Chinese last step names the providers as the spec does (REQ-006)', () => {
    expect(text(pages.zh.querySelectorAll('.deck-text')[5])).toContain('OpenAI、Gemini、DeepSeek 等')
  })
})

describe('screenshots (REQ-005)', () => {
  test.each(LOCALES)('%s: every image declares the size of its file, every cut is 16:9 and one size', (locale) => {
    const images = [...pages[locale].querySelectorAll('main img')]
    expect(images).toHaveLength(1 + 6 + 6)
    const sizes = new Set<string>()
    for (const img of images) {
      const src = img.getAttribute('src')!
      const declared = { width: Number(img.getAttribute('width')), height: Number(img.getAttribute('height')) }
      expect(pngSize(src.slice(1)), src).toEqual(declared)
      expect(declared.width / declared.height, src).toBeCloseTo(16 / 9, 2)
      expect(img.getAttribute('alt')?.trim(), src).toBeTruthy()
      sizes.add(`${declared.width}x${declared.height}`)
    }
    expect(sizes.size).toBe(1)
  })
})

describe('install steps (US-004)', () => {
  test.each(LOCALES)('%s: three steps with the copy’s words', (locale) => {
    const cards = [...pages[locale].querySelectorAll('.card')]
    expect(cards.map((c) => text(c.querySelector('h3')))).toEqual(ui[locale].install.steps.map((s) => s.title))
    expect(text(cards[0]?.querySelector('p'))).toBe(locale === 'zh' ? '点上方的下载按钮，得到 DMG 安装包。' : 'Use the download button above to get the installer.')
    expect(text(cards[2]?.querySelector('p'))).toContain(locale === 'zh' ? '屏幕录制权限' : 'Screen Recording permission')
  })
})

describe('what the page may say and link to', () => {
  test.each(LOCALES)('%s: no package other than Apple silicon is named (CON-004)', (locale) => {
    expect(sources[locale]).not.toMatch(/universal|intel|x64|x86/i)
  })

  test('the English page has no Chinese but the toggle’s own name', () => {
    const copy = new JSDOM(sources.en).window.document
    copy.querySelector('.lang')?.remove()
    expect(copy.documentElement.outerHTML).not.toMatch(/\p{Script=Han}/u)
  })

  test.each(LOCALES)('%s: every link out of the page but the way back to aloong planet goes to github.com or the download host, and opens in a new tab (CON-003)', (locale) => {
    // The homepage link is the one exception (landing-page::REQ-009/AC-01)
    const outbound = [...pages[locale].querySelectorAll('a[href^="http"]')].filter((a) => a.getAttribute('href') !== 'https://aloongplanet.com/')
    expect(outbound.length).toBeGreaterThan(3)
    for (const a of outbound) {
      expect(new URL(a.getAttribute('href')!).hostname, a.getAttribute('href')!).toBe('github.com')
      expect([a.getAttribute('target'), a.getAttribute('rel')]).toEqual(['_blank', 'noopener'])
    }
  })

  test.each(LOCALES)('%s: the page loads nothing from another site (CON-003)', (locale) => {
    const loaded = [...pages[locale].querySelectorAll('[src], link[href], script[src]')].map((e) => e.getAttribute('src') ?? e.getAttribute('href')!)
    for (const url of loaded) expect(url, url).not.toMatch(/^(https?:)?\/\//)
  })

  test.each(LOCALES)('%s: every string of the dictionary is on its page, but the states’ copy a read brings', (locale) => {
    const doc = pages[locale]
    const shown = [text(doc.documentElement), ...[...doc.querySelectorAll('*')].flatMap((e) => [...e.attributes].map((a) => a.value))].join('\n')
    const strings: string[] = []
    const walk = (value: unknown, path: string): void => {
      if (typeof value === 'string') strings.push(`${path}\u0000${value}`)
      else if (Array.isArray(value)) value.forEach((v, i) => walk(v, `${path}.${i}`))
      else if (typeof value === 'object' && value !== null) for (const [k, v] of Object.entries(value)) walk(v, path ? `${path}.${k}` : k)
    }
    walk(ui[locale], '')
    const missing = strings
      .map((s) => s.split('\u0000') as [string, string])
      // The states a read brings (formal copy, with a version in it), and the count's template, which is filled per step
      .filter(([path]) => !path.startsWith('download.formal') && path !== 'features.count')
      .filter(([, value]) => !shown.includes(value))
      .map(([path]) => path)
    expect(missing).toEqual([])
  })
})

describe('the stylesheet’s rules for pages without scripts (failure C5)', () => {
  test('with scripting off the showcase is not displayed and the stacked steps are', () => {
    const cssFile = files().find((f) => f.endsWith('.css'))
    const css = cssFile ? readFileSync(join(outDir, cssFile), 'utf8') : [...pages.zh.querySelectorAll('style')].map((s) => s.textContent).join('\n')
    const rules: Record<string, string[]> = {}
    postcss.parse(css).walkAtRules('media', (at) => {
      if (!/scripting:\s*none/.test(at.params)) return
      at.walkRules((r) => r.walkDecls('display', (d) => void (rules[r.selector] = [...(rules[r.selector] ?? []), d.value])))
    })
    expect(rules['.deck']).toEqual(['none'])
    expect(rules['.fs-list']).toEqual(['flex'])
  })
})

// The numbers the spec fixes, read from the stylesheet as built (jsdom does not lay the page out, so the rules are
// read as text). The scroll script measures a turn and the pin point from the page itself, so a changed number here
// would pass every other test while changing how the page behaves.
describe('the stylesheet’s fixed numbers (landing-page::REQ-003, REQ-004)', () => {
  const stylesheet = (): string => {
    const cssFile = files().find((f) => f.endsWith('.css'))
    return cssFile ? readFileSync(join(outDir, cssFile), 'utf8') : [...pages.zh.querySelectorAll('style')].map((s) => s.textContent).join('\n')
  }
  // The build's minifier may drop the spaces inside a query, so compare with them removed
  const widthQuery = (params: string): string => params.replace(/\s+/g, '')
  /** What `selector` sets for `prop`, outside any at-rule (`media` empty) or inside the media query with that text */
  const declared = (selector: string, prop: string, media = ''): string[] => {
    const values: string[] = []
    postcss.parse(stylesheet()).walkRules(selector, (r) => {
      const at = r.parent?.type === 'atrule' ? (r.parent as postcss.AtRule) : undefined
      if (media ? !at || widthQuery(at.params) !== widthQuery(media) : at) return
      r.walkDecls(prop, (d) => void values.push(d.value.replace(/\s+/g, ' ')))
    })
    return values
  }

  test('a turn is 60% of the window’s height (REQ-004/AC-05)', () => {
    expect(declared('.deck-turn', 'height')).toEqual(['60svh'])
  })

  test('the showcase pins under the header and fills the rest of the window (REQ-004/AC-01)', () => {
    expect(declared('.deck-pin', 'top')).toEqual(['var(--hdr)'])
    expect(declared('.deck-pin', 'height')).toEqual(['calc(100svh - var(--hdr))'])
  })

  test('the first screen fills the window under the header (REQ-003/AC-03)', () => {
    expect(declared('.hero', 'min-height')).toEqual(['calc(100svh - var(--hdr))'])
  })

  test('the header is 56px, so the pin point and the first screen agree with it', () => {
    expect(declared('html', '--hdr')).toEqual(['56px'])
    expect(declared('.hdr', 'height')).toEqual(['var(--hdr)'])
  })

  test('below 760px the showcase and the navigation give way to the stacked steps (REQ-003/AC-01, REQ-004/AC-03)', () => {
    const narrow = '(width < 760px)'
    expect(declared('.deck', 'display', narrow)).toEqual(['none'])
    expect(declared('.nav', 'display', narrow)).toEqual(['none'])
    expect(declared('.fs-list', 'display', narrow)).toEqual(['flex'])
  })
})

// The section headings the spec gives literally (landing-page::REQ-006): written out here, not read from the
// dictionary, so a changed dictionary string cannot agree with itself.
describe('the features and install headings (REQ-006)', () => {
  const literals = {
    zh: { title: '一个快捷键，从屏幕到文字', sub: '不做标注，也不先过传统 OCR：原图直接交给视觉模型。', install: '三步装好' },
    en: {
      title: 'From screen to text in one shortcut',
      sub: 'No annotation tools, no classic OCR step: the original image goes straight to a vision model.',
      install: 'Installed in three steps'
    }
  }
  test.each(LOCALES)('%s: the features title and sub-heading, and the install title', (locale) => {
    const doc = pages[locale]
    expect(text(doc.querySelector('#features .f-head h2'))).toBe(literals[locale].title)
    expect(text(doc.querySelector('#features .f-head p'))).toBe(literals[locale].sub)
    expect(text(doc.querySelector('#download h3.sub'))).toBe(literals[locale].install)
  })
})
