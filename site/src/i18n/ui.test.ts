// The page's dictionary (landing-page::CON-002): two languages, the same strings in each. A string present in one
// language and missing in the other would show as a hole on that language's page.
import { describe, expect, test } from 'vitest'
import { LOCALES, ui } from './ui'

/** Every path to a string in the dictionary, arrays by index: `steps.0.title` */
function paths(value: unknown, prefix = ''): string[] {
  if (typeof value === 'string') return [prefix]
  if (Array.isArray(value)) return value.flatMap((v, i) => paths(v, `${prefix}${prefix ? '.' : ''}${i}`))
  if (typeof value === 'object' && value !== null)
    return Object.entries(value).flatMap(([k, v]) => paths(v, `${prefix}${prefix ? '.' : ''}${k}`))
  throw new Error(`not a string, list or group at ${prefix}`)
}
const strings = (locale: (typeof LOCALES)[number]): [string, string][] =>
  paths(ui[locale]).map((p) => [p, p.split('.').reduce<unknown>((o, k) => (o as Record<string, unknown>)[k], ui[locale]) as string])

describe('the dictionary', () => {
  test('the languages are Chinese (the default) and English', () => {
    expect(LOCALES).toEqual(['zh', 'en'])
  })

  test('both languages have the same keys, with the same number of steps', () => {
    const zh = paths(ui.zh)
    expect(zh.length).toBeGreaterThan(40)
    expect(paths(ui.en)).toEqual(zh)
    expect(ui.zh.steps).toHaveLength(6)
    expect(ui.zh.install.steps).toHaveLength(3)
  })

  test.each(LOCALES)('%s: no string is empty', (locale) => {
    const all = strings(locale)
    expect(all.length).toBeGreaterThan(40)
    for (const [path, text] of all) expect(text.trim(), path).not.toBe('')
  })
})
