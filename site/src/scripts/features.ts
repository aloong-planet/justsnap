// The features section's behaviour (landing-page::REQ-004), as in the confirmed prototype.
//
// On a wide screen the showcase is pinned under the header while its block scrolls by: the block is the pinned
// part followed by one turn (an empty block, 60% of the window's height) for each further step. The current step
// is how far the block has scrolled past the point where it pins, counted in turns, rounded, and kept within the
// steps (landing-page::REQ-004/AC-05); it is recomputed on every scroll and resize, at most once per animation
// frame. The page scrolls as usual: nothing here listens to the wheel. Below 760px, and without scripts, the
// showcase is not displayed and none of this applies: the stacked steps show instead.

/**
 * The step a scroll distance gives: `scrolled` pixels past the pin point, in turns of `turn` pixels, rounded, kept
 * within 0..last. A turn of no length (a minimised window) gives no answer, so the current step stays.
 */
export function stepAt(scrolled: number, turn: number, last: number, current: number): number {
  if (turn <= 0) return current
  return Math.min(last, Math.max(0, Math.round(scrolled / turn)))
}

/** The showcase's block, or null while it is not displayed (narrow screens) */
function deck(): HTMLElement | null {
  const block = document.querySelector<HTMLElement>('.deck')
  return block && getComputedStyle(block).display !== 'none' ? block : null
}

const texts = (): HTMLElement[] => [...document.querySelectorAll<HTMLElement>('.deck-text')]

/** The current step's index */
export function currentStep(): number {
  return Math.max(0, texts().findIndex((t) => t.classList.contains('on')))
}

/** Make step i the current one: its text and its screenshot show */
export function showStep(i: number): void {
  texts().forEach((t, j) => t.classList.toggle('on', j === i))
  document.querySelectorAll('.deck-shot').forEach((s, j) => s.classList.toggle('on', j === i))
}

/** Show the step the scroll position gives */
export function syncStep(): void {
  const block = deck()
  const pin = block?.querySelector<HTMLElement>('.deck-pin')
  const turn = block?.querySelector<HTMLElement>('.deck-turn')
  if (!block || !pin || !turn) return
  // Measured from the page itself, so the script and the stylesheet cannot disagree on the pin point or a turn
  const scrolled = parseFloat(getComputedStyle(pin).top) - block.getBoundingClientRect().top
  const current = currentStep()
  const step = stepAt(scrolled, turn.offsetHeight, texts().length - 1, current)
  if (step !== current) showStep(step)
}

export function initFeatures(): void {
  let ticking = false
  const onScroll = (): void => {
    if (ticking) return
    ticking = true
    requestAnimationFrame(() => {
      ticking = false
      syncStep()
    })
  }
  addEventListener('scroll', onScroll, { passive: true })
  addEventListener('resize', onScroll)
  syncStep()
}
