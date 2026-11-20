// The page's download script end to end (landing-page::REQ-001, CON-003, failures A2, A3, A4, A7): the served page, a
// fake fetch standing in for the network (the pointer as agentshed's mirror script writes it, GitHub's real-shaped list),
// and the state the page ends in. Which URLs were asked for is asserted: CON-003 makes the two reads the requirement.
//
// Keeping the visitor's place when a state lands while they are scrolled (failure A5) is checked at the end of this
// file with stubbed rectangles, since jsdom has no layout. Not covered: that a real browser's layout moves the way
// the stub says it does; that has not been measured in a browser.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { JSDOM } from 'jsdom'
import { beforeAll, expect, inject, test } from 'vitest'
import { ui } from '../src/i18n/ui'
import type { Fetch } from '../src/releases'
import { initDownload } from '../src/scripts/download'

const POINTER_URL = 'https://dl.justsnap.aloongplanet.com/latest.json'
const RELEASES_API = 'https://api.github.com/repos/aloong-planet/justsnap/releases?per_page=100'
const POINTER = readFileSync(new URL('./fixtures/pointer.json', import.meta.url), 'utf8')
const RELEASES = JSON.parse(readFileSync(new URL('./fixtures/github-releases.json', import.meta.url), 'utf8')) as { prerelease: boolean }[]
const html: Record<'zh' | 'en', string> = { zh: '', en: '' }

beforeAll(() => {
  const outDir = inject('builtSite')
  html.zh = readFileSync(join(outDir, 'index.html'), 'utf8')
  html.en = readFileSync(join(outDir, 'en/index.html'), 'utf8')
})

const page = (locale: 'zh' | 'en'): Document => new JSDOM(html[locale]).window.document
const heroText = (doc: Document): string => (doc.querySelector('.hero .dl a.btn')?.textContent ?? '').replace(/\s+/g, ' ').trim()

/** A network that answers each URL as given, and fails anything else; it records what was asked */
function network(answers: Record<string, [number, string] | 'fail'>): Fetch & { urls: string[] } {
  const urls: string[] = []
  const fetch = (url: string): Promise<Response> => {
    urls.push(url)
    const a = answers[url]
    if (!a || a === 'fail') return Promise.reject(new TypeError('Failed to fetch'))
    return Promise.resolve(new Response(a[1], { status: a[0], headers: { 'content-type': 'application/json' } }))
  }
  return Object.assign(fetch, { urls })
}

test('a readable pointer: the state from R2, and GitHub is never asked', async () => {
  const doc = page('en')
  const net = network({ [POINTER_URL]: [200, POINTER], [RELEASES_API]: [200, JSON.stringify(RELEASES)] })
  expect(await initDownload(doc, net)).toEqual({
    kind: 'formal-r2',
    version: '0.2.0',
    url: 'https://dl.justsnap.aloongplanet.com/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg'
  })
  expect(heroText(doc)).toBe('Download JustSnap 0.2.0')
  expect(net.urls).toEqual([POINTER_URL])
})

test('no pointer yet: GitHub’s latest release, in the page’s language, asked after the pointer', async () => {
  const doc = page('zh')
  const net = network({ [POINTER_URL]: [404, '<html></html>'], [RELEASES_API]: [200, JSON.stringify(RELEASES)] })
  expect(await initDownload(doc, net)).toEqual({ kind: 'formal-github', version: '1.2.1', dmg: true })
  // The Chinese page's own copy, not the English page's (the copy itself is checked against the prototype)
  expect(heroText(doc)).toBe(ui.zh.download.formal.hero.replace('{version}', '1.2.1'))
  expect(net.urls).toEqual([POINTER_URL, RELEASES_API])
})

test('a pointer older than GitHub’s newest release still wins: the mirror may lag (failure A4)', async () => {
  const doc = page('en')
  const older = POINTER.replaceAll('0.2.0', '0.1.0')
  const net = network({ [POINTER_URL]: [200, older], [RELEASES_API]: [200, JSON.stringify(RELEASES)] })
  expect(await initDownload(doc, net)).toMatchObject({ kind: 'formal-r2', version: '0.1.0' })
  expect(heroText(doc)).toBe('Download JustSnap 0.1.0')
})

test('neither source readable: the page stays as served, the release list', async () => {
  const doc = page('en')
  const served = doc.body.innerHTML
  const net = network({ [POINTER_URL]: 'fail', [RELEASES_API]: 'fail' })
  expect(await initDownload(doc, net)).toEqual({ kind: 'list' })
  expect(doc.body.innerHTML).toBe(served)
  expect(net.urls).toEqual([POINTER_URL, RELEASES_API])
})

test('only pre-releases on GitHub: nothing to offer, the page stays as served (failure A7)', async () => {
  const doc = page('en')
  const served = doc.body.innerHTML
  const net = network({ [POINTER_URL]: [404, '<html></html>'], [RELEASES_API]: [200, JSON.stringify(RELEASES.filter((r) => r.prerelease))] })
  expect(await initDownload(doc, net)).toEqual({ kind: 'list' })
  expect(doc.body.innerHTML).toBe(served)
})

// Keeping the visitor's place when a state lands after the page is shown (failure A5). jsdom has no layout, so the
// rectangles are stubbed, as in language-switch.test.ts: the header ends at 56, and the next section moves by
// `shift` once the hero shows a state (the hero button's text changing is how the stub knows).
function scrolledPage(heroBottom: number, shift: number): { doc: Document; scrolls: ScrollToOptions[] } {
  const doc = page('en')
  const served = heroText(doc)
  const rect = (top: number, bottom = top): (() => DOMRect) => () => ({ top, bottom }) as DOMRect
  doc.querySelector('.hdr')!.getBoundingClientRect = rect(0, 56)
  doc.querySelector('.hero .dl')!.getBoundingClientRect = rect(heroBottom - 100, heroBottom)
  doc.getElementById('features')!.getBoundingClientRect = () => ({ top: heroText(doc) === served ? 800 : 800 + shift }) as DOMRect
  const scrolls: ScrollToOptions[] = []
  doc.defaultView!.scrollBy = ((options: ScrollToOptions) => void scrolls.push(options)) as typeof scrollBy
  return { doc, scrolls }
}

const onR2 = network({ [POINTER_URL]: [200, POINTER] })

test('a state that lands while the hero’s download block is above the view scrolls by what it moved the page', async () => {
  const { doc, scrolls } = scrolledPage(40, 30)
  await initDownload(doc, onR2)
  expect(scrolls).toEqual([{ top: 30, behavior: 'instant' }])
})

test('the same, when the state makes the block shorter: the scroll goes the other way', async () => {
  const { doc, scrolls } = scrolledPage(40, -25)
  await initDownload(doc, onR2)
  expect(scrolls).toEqual([{ top: -25, behavior: 'instant' }])
})

test('a state that lands while the block is in view changes it in place, with no scrolling', async () => {
  const { doc, scrolls } = scrolledPage(300, 30)
  await initDownload(doc, onR2)
  expect(scrolls).toEqual([])
})

test('a state that moves nothing needs no scrolling even when the block is above the view', async () => {
  const { doc, scrolls } = scrolledPage(40, 0)
  await initDownload(doc, onR2)
  expect(scrolls).toEqual([])
})
