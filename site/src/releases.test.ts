// The two reads (landing-page::REQ-001, CON-003, failures A1–A7, E1), through an injected fetch: no case reaches
// the network. The fixtures are real shapes: the pointer as agentshed's mirror script writes it (JustSnap's own writer is not built
// yet; when it is, its output replaces this fixture), the 404 the download
// host answers before the first release (an HTML body), and a public GitHub releases answer (drafts, pre-releases,
// assets with their upload state) renamed to this repository.
//
// Not covered here: what a browser does with CORS and with the time limit. A rejected fetch stands for both;
// the browser behaviour is measured with the page.
import { readFileSync } from 'node:fs'
import { describe, expect, test } from 'vitest'
import { readGitHub, readPointer, type Fetch } from './releases'

const POINTER = readFileSync(new URL('../test/fixtures/pointer.json', import.meta.url), 'utf8')
const RELEASES = JSON.parse(readFileSync(new URL('../test/fixtures/github-releases.json', import.meta.url), 'utf8')) as Release[]

interface Release {
  tag_name: string
  draft: boolean
  prerelease: boolean
  published_at: string | null
  assets: { name: string; state: string }[]
}

type Requested = { urls: string[]; headers: (HeadersInit | undefined)[] }

/** A fetch answering every request with one response, recording what was asked for */
function answering(status: number, body: string, type = 'application/json'): Fetch & Requested {
  const requested: Requested = { urls: [], headers: [] }
  const fetch = (url: string, init?: RequestInit): Promise<Response> => {
    requested.urls.push(url)
    requested.headers.push(init?.headers)
    return Promise.resolve(new Response(body, { status, headers: { 'content-type': type } }))
  }
  return Object.assign(fetch, requested)
}
const failing =
  (error: Error): Fetch =>
  () =>
    Promise.reject(error)
type PointerShape = { version: unknown; files: Record<string, unknown>[] }
const pointerWith = (change: (p: PointerShape) => void): string => {
  const p = JSON.parse(POINTER) as PointerShape
  change(p)
  return JSON.stringify(p)
}
const releasesWith = (change: (r: Release[]) => Release[] | void): string => {
  const copy = structuredClone(RELEASES)
  return JSON.stringify(change(copy) ?? copy)
}

const DL = 'https://dl.justsnap.aloongplanet.com'
const DMG = `${DL}/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg`

describe('the pointer', () => {
  test('a pointer as agentshed’s mirror script writes it: the version and its Apple silicon DMG on the download host', async () => {
    const fetch = answering(200, POINTER)
    expect(await readPointer(fetch)).toEqual({ kind: 'formal', version: '0.2.0', url: DMG })
    expect(fetch.urls).toEqual([`${DL}/latest.json`])
  })

  test('a pointer listing another architecture first still offers the arm64 DMG; the other entry is ignored', async () => {
    const body = pointerWith((p) => {
      p.files.unshift({ name: 'JustSnap-0.2.0-mac-x64.dmg', arch: 'x64', size: 1, url: `${DL}/releases/v0.2.0/JustSnap-0.2.0-mac-x64.dmg` })
    })
    expect(await readPointer(answering(200, body))).toEqual({ kind: 'formal', version: '0.2.0', url: DMG })
  })

  test('no pointer yet: the host answers 404 with an HTML page', async () => {
    expect(await readPointer(answering(404, '<html><body>Not Found</body></html>', 'text/html'))).toEqual({ kind: 'absent' })
  })

  const unreadable: [string, Fetch][] = [
    ['the request fails (CORS refused, offline)', failing(new TypeError('Failed to fetch'))],
    ['the request is aborted', failing(new DOMException('The operation was aborted.', 'AbortError'))],
    ['the host errs', answering(500, 'Internal Server Error', 'text/plain')],
    ['the body is not JSON', answering(200, 'not json')],
    ['the body is not an object', answering(200, 'null')],
    ['no version', answering(200, pointerWith((p) => delete (p as Partial<PointerShape>).version))],
    ['a version written with its v', answering(200, pointerWith((p) => (p.version = 'v0.2.0')))],
    [
      'a pre-release version, which never reaches R2',
      answering(
        200,
        pointerWith((p) => {
          p.version = '0.2.0-beta'
          p.files[0].name = 'JustSnap-0.2.0-beta-mac-arm64.dmg'
          p.files[0].url = `${DL}/releases/v0.2.0-beta/JustSnap-0.2.0-beta-mac-arm64.dmg`
        })
      )
    ],
    ['only an x64 entry', answering(200, pointerWith((p) => (p.files[0].arch = 'x64')))],
    ['files is not a list', answering(200, pointerWith((p) => ((p as { files: unknown }).files = DMG)))],
    ['the DMG on another host', answering(200, pointerWith((p) => (p.files[0].url = 'https://evil.example/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg')))],
    [
      'the DMG on a host that only starts like the download host',
      answering(200, pointerWith((p) => (p.files[0].url = 'https://dl.justsnap.aloongplanet.com.evil.example/releases/v0.2.0/JustSnap-0.2.0-mac-arm64.dmg')))
    ],
    ['the DMG over plain http', answering(200, pointerWith((p) => (p.files[0].url = DMG.replace('https:', 'http:'))))],
    ['the DMG under another version’s directory', answering(200, pointerWith((p) => (p.files[0].url = DMG.replace('/v0.2.0/', '/v0.1.0/'))))],
    ['a DMG named for another version', answering(200, pointerWith((p) => (p.files[0].name = 'JustSnap-0.1.0-mac-arm64.dmg')))],
    ['a query string on the DMG link', answering(200, pointerWith((p) => (p.files[0].url = `${DMG}?x=1`)))]
  ]
  test.each(unreadable)('unreadable when %s', async (_, fetch) => {
    expect(await readPointer(fetch)).toEqual({ kind: 'unreadable' })
  })

  test('a read that does not answer within the time limit is unreadable', async () => {
    const hanging: Fetch = (_, init) =>
      new Promise((_, reject) => init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError'))))
    const started = Date.now()
    expect(await readPointer(hanging, { timeoutMs: 30 })).toEqual({ kind: 'unreadable' })
    expect(Date.now() - started).toBeLessThan(2000)
  })

  test('the read sends only the accept header, which needs no CORS preflight', async () => {
    const fetch = answering(200, POINTER)
    await readPointer(fetch)
    expect(fetch.headers).toEqual([{ accept: 'application/json' }])
  })
})

describe('GitHub’s releases', () => {
  test('the latest release, with its DMG', async () => {
    const fetch = answering(200, JSON.stringify(RELEASES))
    expect(await readGitHub(fetch)).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
    expect(fetch.urls).toEqual(['https://api.github.com/repos/aloong-planet/justsnap/releases?per_page=100'])
    expect(fetch.headers).toEqual([{ accept: 'application/json' }])
  })

  test('a pre-release newer than the latest release is not offered (failure A7)', async () => {
    const body = releasesWith((r) => {
      r.find((x) => x.tag_name === 'v1.2.0-beta')!.published_at = '2026-09-30T00:00:00Z'
    })
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  test('the newest by date, whatever order the list comes in', async () => {
    const body = releasesWith((r) => [...r].reverse())
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  test('only pre-releases: nothing to offer (failure A7)', async () => {
    const body = releasesWith((r) => r.filter((x) => x.prerelease))
    expect(body).toContain('v1.2.0-beta')
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'none' })
  })

  test('no release at all (failure A1)', async () => {
    expect(await readGitHub(answering(200, '[]'))).toEqual({ kind: 'none' })
  })

  test('a draft is ignored, however new (failure A6)', async () => {
    const body = releasesWith((r) => [{ ...structuredClone(r[0]), tag_name: 'v1.3.0', draft: true, published_at: null }, ...r])
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  test('a release without the DMG is offered without it (failure A6)', async () => {
    const body = releasesWith((r) => {
      r[0].assets = r[0].assets.filter((a) => a.name !== 'JustSnap-1.2.1-mac-arm64.dmg')
    })
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: false })
  })

  test('a DMG whose upload has not finished does not count', async () => {
    const body = releasesWith((r) => {
      r[0].assets.find((a) => a.name === 'JustSnap-1.2.1-mac-arm64.dmg')!.state = 'starter'
    })
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: false })
  })

  test('an entry that is not a release of this kind is passed over, the others still count', async () => {
    const body = releasesWith((r) => [
      { ...structuredClone(r[0]), tag_name: 'nightly', published_at: '2026-10-01T00:00:00Z' },
      { ...structuredClone(r[0]), tag_name: 'v1.3.0-rc', prerelease: false, published_at: '2026-10-02T00:00:00Z' },
      ...r
    ])
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  test('a release flagged as a pre-release is not offered even under a plain tag (failure A7)', async () => {
    const body = releasesWith((r) => [{ ...structuredClone(r[0]), tag_name: 'v1.3.0', prerelease: true, published_at: '2026-10-04T00:00:00Z' }, ...r])
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  test('a tag carrying markup is passed over, never reaching the page (failure E1)', async () => {
    const body = releasesWith((r) => [{ ...structuredClone(r[0]), tag_name: 'v9.9.9<img src=x>', published_at: '2026-10-03T00:00:00Z' }, ...r])
    expect(await readGitHub(answering(200, body))).toEqual({ kind: 'formal', version: '1.2.1', dmg: true })
  })

  const unreadable: [string, Fetch][] = [
    [
      'the rate limit is spent (failure A3)',
      () =>
        Promise.resolve(
          new Response('{"message":"API rate limit exceeded"}', {
            status: 403,
            headers: { 'content-type': 'application/json', 'x-ratelimit-remaining': '0' }
          })
        )
    ],
    ['GitHub errs', answering(500, '{"message":"Server Error"}')],
    ['the body is not a list', answering(200, '{"message":"Not Found"}')],
    ['the body is not JSON', answering(200, '<html></html>', 'text/html')],
    ['the request fails', failing(new TypeError('Failed to fetch'))]
  ]
  test.each(unreadable)('unreadable when %s', async (_, fetch) => {
    expect(await readGitHub(fetch)).toEqual({ kind: 'unreadable' })
  })

  test('a read that does not answer within the time limit is unreadable (failure A2)', async () => {
    const hanging: Fetch = (_, init) =>
      new Promise((_, reject) => init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError'))))
    expect(await readGitHub(hanging, { timeoutMs: 30 })).toEqual({ kind: 'unreadable' })
  })
})
