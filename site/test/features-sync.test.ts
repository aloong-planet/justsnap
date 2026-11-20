// How the page's scroll position turns into a step (landing-page::REQ-004/AC-01, AC-05, failures C1, C2): the built
// page's own showcase, with the three measurements syncStep takes from the browser stubbed, since jsdom has no
// layout: the pin point (the pinned part's computed `top`), how far the block's top is from the window's, and the
// length of a turn. The pure arithmetic is in src/scripts/features.test.ts; this checks that those three
// measurements are the ones it is given. Not covered: that a real browser reports them this way (measured in
// a headless browser while the page was built, not by a test).
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { JSDOM } from 'jsdom'
import { afterEach, beforeAll, expect, inject, test, vi } from 'vitest'
import { currentStep, showStep, syncStep } from '../src/scripts/features'

let html = ''
beforeAll(() => {
  html = readFileSync(join(inject('builtSite'), 'index.html'), 'utf8')
})
afterEach(() => vi.unstubAllGlobals())

/** The page with the showcase's block `scrolled` px past a pin point of 56px (or past `pinTop`, at the same place on screen), turns of `turn` px */
function mount({ scrolled, pinTop = 56, turn = 480, display = 'block' }: { scrolled: number; pinTop?: number; turn?: number; display?: string }): Document {
  const { window } = new JSDOM(html)
  const { document } = window
  const real = window.getComputedStyle.bind(window)
  vi.stubGlobal('document', document)
  vi.stubGlobal(
    'getComputedStyle',
    (el: Element) => (el.matches('.deck-pin') ? { top: `${pinTop}px` } : el.matches('.deck') ? { display } : real(el))
  )
  // Where the block's top is on screen does not depend on the pin point: `scrolled` is counted from a pin point of 56px
  document.querySelector('.deck')!.getBoundingClientRect = () => ({ top: 56 - scrolled }) as DOMRect
  for (const t of document.querySelectorAll<HTMLElement>('.deck-turn')) Object.defineProperty(t, 'offsetHeight', { value: turn })
  return document
}

test('the step is how many turns the block has scrolled past the pin point, rounded', () => {
  mount({ scrolled: 480 * 2.4 })
  syncStep()
  expect(currentStep()).toBe(2)
})

test('the pin point is the pinned part’s own `top`, not a number of the script’s: a pin point 480px lower, one step later', () => {
  mount({ scrolled: 480 * 2.4 })
  syncStep()
  expect(currentStep()).toBe(2)
  mount({ scrolled: 480 * 2.4, pinTop: 56 + 480 })
  syncStep()
  expect(currentStep()).toBe(3)
})

test('a turn is measured from the page: twice the length, half the steps', () => {
  mount({ scrolled: 480 * 2.4, turn: 960 })
  syncStep()
  expect(currentStep()).toBe(1)
})

test('scrolling back up goes back, and the block not yet pinned shows the first step (failure C1)', () => {
  mount({ scrolled: -300 })
  showStep(3)
  syncStep()
  expect(currentStep()).toBe(0)
})

test('past the end the last step stays', () => {
  mount({ scrolled: 100000 })
  syncStep()
  expect(currentStep()).toBe(5)
})

test('a showcase that is not displayed (below 760px) is left alone (failure C2)', () => {
  mount({ scrolled: 480 * 4, display: 'none' })
  showStep(1)
  syncStep()
  expect(currentStep()).toBe(1)
})
