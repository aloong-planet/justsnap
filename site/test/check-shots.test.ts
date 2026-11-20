// The production build's screenshot check (landing-page::REQ-005/AC-04): no two screenshots are the same file, so a
// placeholder set, which repeats one picture, never reaches a published build. The command's exit status is checked
// by running it on temporary directories; the build script's wiring is asserted from package.json, since running the
// real `pnpm build` here would repeat the global setup's build.
import { spawnSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
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

const SCRIPT = fileURLToPath(new URL('../scripts/check-shots.mjs', import.meta.url))
const run = (...args: string[]) => spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8' })

test('run as a command on a directory of identical files, it exits 1 and names them', () => {
  put('hero-zh.png', 'same')
  put('select-en.png', 'same')
  const result = run(dir)
  expect(result.status).toBe(1)
  expect(result.stderr).toContain('hero-zh.png, select-en.png')
})

test('run as a command on a directory of different files, it exits 0', () => {
  put('hero-zh.png', 'a')
  put('select-en.png', 'b')
  expect(run(dir).status).toBe(0)
})

test('the production build runs the check before it builds', () => {
  const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')) as { scripts: Record<string, string> }
  expect(pkg.scripts.build).toMatch(/^node scripts\/check-shots\.mjs && astro build$/)
})
