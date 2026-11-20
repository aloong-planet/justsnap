// Switching language keeps the current step and the scroll position (landing-page::REQ-004/AC-04, failures B1, B2,
// C5): the two pages are two documents here, built from the run's fresh build, and a fake session storage carries the
// note from one to the other. jsdom has no layout, so each element's rectangle is stubbed: what is under test is
// which element is noted and how the other page is moved to put it back, not the browser's measuring.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { JSDOM } from 'jsdom'
import { afterEach, beforeAll, beforeEach, describe, expect, inject, test, vi } from 'vitest'
import { initLanguageSwitch } from '../src/scripts/language-switch'

const html: Record<'zh' | 'en', string> = { zh: '', en: '' }
beforeAll(() => {
  const outDir = inject('builtSite')
  html.zh = readFileSync(join(outDir, 'index.html'), 'utf8')
  html.en = readFileSync(join(outDir, 'en/index.html'), 'utf8')
})

const store = new Map<string, string>()
const storage = {
  getItem: (k: string): string | null => store.get(k) ?? null,
  setItem: (k: string, v: string): void => void store.set(k, v),
  removeItem: (k: string): void => void store.delete(k)
}
const scrollTo = vi.fn()

/** Makes `locale`'s page the current document, with the rectangles given by selector (an element not named is 0×0 at the top) */
function mount(locale: 'zh' | 'en', rects: Record<string, [top: number, bottom: number]> = {}): Document {
  const path = locale === 'zh' ? '/' : '/en/'
  const dom = new JSDOM(html[locale], { url: `https://justsnap.aloongplanet.com${path}` })
  const { document } = dom.window
  for (const [selector, [top, bottom]] of Object.entries(rects)) {
    for (const el of document.querySelectorAll(selector)) {
      el.getBoundingClientRect = () => ({ top, bottom, left: 0, right: 0, width: 0, height: bottom - top, x: 0, y: top, toJSON: () => ({}) })
    }
  }
  vi.stubGlobal('document', document)
  vi.stubGlobal('location', dom.window.location)
  vi.stubGlobal('sessionStorage', storage)
  vi.stubGlobal('innerHeight', 800)
  vi.stubGlobal('scrollY', 0)
  vi.stubGlobal('scrollTo', scrollTo)
  vi.stubGlobal('getComputedStyle', dom.window.getComputedStyle.bind(dom.window))
  return document
}

const stepsOn = (doc: Document): number[] => [...doc.querySelectorAll('.deck-text')].flatMap((t, i) => (t.classList.contains('on') ? [i] : []))
const clickSwitch = (doc: Document, init: MouseEventInit = {}): void => {
  doc.querySelector<HTMLAnchorElement>('a[data-switch-language]')!.dispatchEvent(new (doc.defaultView as unknown as { MouseEvent: typeof MouseEvent }).MouseEvent('click', { button: 0, bubbles: true, cancelable: true, ...init }))
}

beforeEach(() => {
  store.clear()
  scrollTo.mockClear()
  vi.useFakeTimers()
  vi.setSystemTime(new Date('2026-11-21T10:00:00Z'))
})
afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

describe('the toggle as served', () => {
  test.each([
    ['zh', '/en/', 'EN'],
    ['en', '/', '中文']
  ] as const)('%s: the other language is a plain link to its page, marked for the script (failures B1, B2)', (locale, href, label) => {
    const doc = mount(locale)
    const links = [...doc.querySelectorAll('.lang a')]
    expect(links.map((a) => [a.getAttribute('href'), a.textContent, a.hasAttribute('data-switch-language')])).toEqual([[href, label, true]])
    expect(doc.querySelector('.lang [aria-current="page"]')).not.toBeNull()
  })
})

describe('keeping the place across the switch', () => {
  /** The visitor is in the showcase, on step 3, with its block's top 50px above the window's top */
  const reading = { '.deck': [-50, 1500] as [number, number], '#features': [-300, 2000] as [number, number], '#top': [-1200, -300] as [number, number] }

  test('the other page scrolls the same element to the same distance from the top, and shows the same step', () => {
    const zh = mount('zh', reading)
    initLanguageSwitch()
    // Initialised as the page is: first the showcase's step is set, then the switch
    zh.querySelectorAll('.deck-text')[2]!.classList.add('on')
    zh.querySelectorAll('.deck-text')[0]!.classList.remove('on')
    clickSwitch(zh)
    expect(JSON.parse(store.get('justsnap:language-switch')!)).toMatchObject({ to: 'https://justsnap.aloongplanet.com/en/', anchor: 'showcase', top: -50, step: 2 })

    // The English page: its showcase starts 120px below the window's top
    const en = mount('en', { '.deck': [120, 1700] })
    initLanguageSwitch()
    expect(scrollTo).toHaveBeenCalledTimes(1)
    expect(scrollTo).toHaveBeenCalledWith({ top: 0 + 120 - -50, behavior: 'instant' })
    expect(stepsOn(en)).toEqual([2])
    expect(store.has('justsnap:language-switch')).toBe(false)
  })

  test('a note older than ten seconds is ignored: the other page opens from the top', () => {
    const zh = mount('zh', reading)
    initLanguageSwitch()
    clickSwitch(zh)
    vi.setSystemTime(new Date('2026-11-21T10:00:11Z'))
    const en = mount('en', { '.deck': [120, 1700] })
    initLanguageSwitch()
    expect(scrollTo).not.toHaveBeenCalled()
    expect(stepsOn(en)).toEqual([0])
  })

  test('a note for another page is ignored', () => {
    const zh = mount('zh', reading)
    initLanguageSwitch()
    clickSwitch(zh)
    mount('zh', reading)
    initLanguageSwitch()
    expect(scrollTo).not.toHaveBeenCalled()
  })

  test('a click that opens a new tab, or any other button, notes nothing', () => {
    const zh = mount('zh', reading)
    initLanguageSwitch()
    clickSwitch(zh, { metaKey: true })
    clickSwitch(zh, { ctrlKey: true })
    clickSwitch(zh, { button: 1 })
    expect(store.size).toBe(0)
  })

  test('where the showcase is not displayed, the stacked step the visitor is in is what is kept', () => {
    const zh = mount('zh', { '.fs-step': [-20, 700] })
    initLanguageSwitch()
    clickSwitch(zh)
    expect(JSON.parse(store.get('justsnap:language-switch')!)).toMatchObject({ anchor: 'step:5', top: -20 })
  })

  test('a storage that throws does not stop the link, and the other page just opens', () => {
    const zh = mount('zh', reading)
    initLanguageSwitch()
    vi.stubGlobal('sessionStorage', {
      getItem: () => {
        throw new Error('blocked')
      },
      setItem: () => {
        throw new Error('blocked')
      },
      removeItem: () => {
        throw new Error('blocked')
      }
    })
    expect(() => clickSwitch(zh)).not.toThrow()
    mount('en')
    vi.stubGlobal('sessionStorage', {
      getItem: () => {
        throw new Error('blocked')
      },
      setItem: () => undefined,
      removeItem: () => undefined
    })
    expect(() => initLanguageSwitch()).not.toThrow()
    expect(scrollTo).not.toHaveBeenCalled()
  })
})
