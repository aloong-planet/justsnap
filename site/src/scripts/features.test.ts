// The step the scroll gives (landing-page::REQ-004/AC-05, failures C1, C3): how far the pinned block has scrolled,
// counted in turns of the window's height, rounded, and kept within the steps. The pure part of features.ts; what
// the page does with it (pinning, fading) is layout: test/features-sync.test.ts checks what is measured, and the
// layout itself was measured in a headless browser when the page was written, not by a test.
import { describe, expect, test } from 'vitest'
import { stepAt } from './features'

describe('the step at a scroll distance', () => {
  const turn = 100
  const last = 5

  test('before the block pins, and exactly at the pin point: the first step', () => {
    expect(stepAt(-250, turn, last, 3)).toBe(0)
    expect(stepAt(0, turn, last, 3)).toBe(0)
  })

  test('the next step comes at half a turn: just under it is still the step before', () => {
    expect(stepAt(49, turn, last, 0)).toBe(0)
    expect(stepAt(50, turn, last, 0)).toBe(1)
    expect(stepAt(149, turn, last, 0)).toBe(1)
    expect(stepAt(150, turn, last, 0)).toBe(2)
  })

  test('a fast scroll past several turns lands on the right step at once', () => {
    expect(stepAt(300, turn, last, 0)).toBe(3)
  })

  test('past the last step, and past the block: the last step', () => {
    expect(stepAt(500, turn, last, 0)).toBe(5)
    expect(stepAt(9000, turn, last, 0)).toBe(5)
  })

  test('a window with no height has turns of no length: the step stays as it was', () => {
    expect(stepAt(300, 0, last, 2)).toBe(2)
  })
})
