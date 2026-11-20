// The page's download script end to end (landing-page::REQ-001, CON-003, failures A2, A3, A4, A7): the served page, a
// fake fetch standing in for the network (the pointer as the release script writes it, GitHub's real-shaped list),
// and the state the page ends in. Which URLs were asked for is asserted: CON-003 makes the two reads the requirement.
//
// Not covered here: keeping the visitor's place when a state lands while they are scrolled (failure A5; jsdom has no
// layout); measured in a browser.
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
