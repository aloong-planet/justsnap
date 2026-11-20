// The production build's screenshot check (landing-page::REQ-005/AC-04): no two screenshots are the same file, so a
// placeholder set, which repeats one picture, never reaches a published build. The build script's wiring is asserted
// from package.json, since running the real `pnpm build` here would repeat the global setup's build.
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, beforeEach, expect, test } from 'vitest'
import { duplicateShots } from '../scripts/check-shots.mjs'

let dir: string
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'justsnap-shots-'))
})
afterEach(() => rmSync(dir, { recursive: true, force: true }))

const put = (name: string, content: string): void => writeFileSync(join(dir, name), content)

test('screenshots that all differ pass', () => {
  put('hero-zh.png', 'a')
  put('hero-en.png', 'b')
  put('select-zh.png', 'c')
  expect(duplicateShots(dir)).toEqual([])
})

test('two screenshots with the same content are reported together, whatever their names', () => {
  put('hero-zh.png', 'same')
  put('select-en.png', 'same')
  put('extract-zh.png', 'other')
  expect(duplicateShots(dir)).toEqual([['hero-zh.png', 'select-en.png']])
})

test('a directory with no screenshot is reported as missing, not as passing', () => {
  mkdirSync(join(dir, 'empty'))
  expect(() => duplicateShots(join(dir, 'empty'))).toThrow(/no screenshots/i)
})

test('the production build runs the check before it builds', () => {
  const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')) as { scripts: Record<string, string> }
  expect(pkg.scripts.build).toMatch(/^node scripts\/check-shots\.mjs && astro build$/)
})
