// The screenshots (landing-page::REQ-005/AC-01, AC-02, AC-04): all fourteen files exist under public/shots/, each is
// exactly the size the page declares for it (read from the PNG header, not from the file's name or length), and no two
// are the same picture. The production build's own check (scripts/check-shots.mjs) covers the last of these when the
// site is built for production; this runs it, and the other two, with the tests. Not covered: that a picture shows
// the right view, in the right language, with no user data in it; that was checked by looking at each file.
import { createHash } from 'node:crypto'
import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, test } from 'vitest'
import { LOCALES } from '../src/i18n/ui'
import { FEATURE_SHOTS, SHOT_SIZE, shotSrc } from '../src/shots'

const shotNames = ['hero', ...FEATURE_SHOTS] as const
const files = shotNames.flatMap((name) => LOCALES.map((locale) => ({ name, locale, path: fileURLToPath(new URL(`../public${shotSrc(name, locale)}`, import.meta.url)) })))

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])

/** The width and height in the PNG's IHDR chunk, which always comes first: bytes 16-19 and 20-23 */
function pngSize(file: Buffer): { width: number; height: number } {
  expect(file.subarray(0, 8).equals(PNG_SIGNATURE)).toBe(true)
  expect(file.subarray(12, 16).toString('latin1')).toBe('IHDR')
  return { width: file.readUInt32BE(16), height: file.readUInt32BE(20) }
}

test('there is one screenshot for each of the six features and the hero, in each language: fourteen files', () => {
  expect(files).toHaveLength(14)
  const missing = files.filter((f) => !existsSync(f.path)).map((f) => `${f.name}-${f.locale}.png`)
  expect(missing).toEqual([])
})

describe('each screenshot is the size the page declares', () => {
  test.each(files)('$name-$locale.png', ({ path }) => {
    expect(pngSize(readFileSync(path))).toEqual(SHOT_SIZE)
  })
})

test('no two screenshots are the same file', () => {
  const byHash = new Map<string, string[]>()
  for (const f of files) {
    const hash = createHash('sha256').update(readFileSync(f.path)).digest('hex')
    byHash.set(hash, [...(byHash.get(hash) ?? []), `${f.name}-${f.locale}.png`])
  }
  expect([...byHash.values()].filter((group) => group.length > 1)).toEqual([])
})
