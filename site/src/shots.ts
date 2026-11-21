// The screenshots (landing-page::REQ-005): the hero's and the six features' cuts, one set per language, all 16:9 and
// one size. They ship as static files under public/shots/ with their pixel sizes declared, so their space is held
// before they load. They are renders of the app's own views over made-up content, rebuilt by `pnpm shots`; the
// production build refuses to run if any two are the same file (scripts/check-shots.mjs).
import type { Locale } from './i18n/ui'

/** The features section's views, in the order of its steps (landing-page::US-003/AC-01) */
export const FEATURE_SHOTS = ['select', 'extract', 'translate', 'paste', 'history', 'providers'] as const

/** Every cut, the hero's included: 920×517pt (16:9) at 2×, one size so the text keeps one size as the steps turn */
export const SHOT_SIZE = { width: 1840, height: 1035 } as const

export const shotSrc = (name: 'hero' | (typeof FEATURE_SHOTS)[number], locale: Locale): string => `/shots/${name}-${locale}.png`
