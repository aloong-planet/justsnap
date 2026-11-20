// What the page's download buttons say and where they lead, per download state (landing-page::REQ-002).
//
// The page as served is in the list state (landing-page::REQ-001/AC-04): it names no version and leads to
// GitHub's release list, which is a valid way to download whatever exists. There is no pre-release state: a
// pre-release is never offered (landing-page failure A7).
import { ui, type Locale } from './i18n/ui'
import { dmgName, type GitHubRead, type PointerRead } from './releases'

export const REPOSITORY = 'https://github.com/aloong-planet/justsnap'
export const RELEASE_LIST = `${REPOSITORY}/releases`

export type DownloadState =
  | { kind: 'formal-r2'; version: string; url: string }
  | { kind: 'formal-github'; version: string; dmg: boolean }
  | { kind: 'list' }

export interface DownloadLink {
  label: string
  href: string
  /** Links to GitHub open in a new tab; the R2 download starts in place (landing-page::REQ-002/AC-04) */
  newTab: boolean
  kind: 'primary' | 'ghost'
}

export interface DownloadView {
  /** The hero's button */
  hero: DownloadLink
  /** The link to every version, beneath the platform line */
  every: DownloadLink | null
  /** The download area: its line, and its row's buttons */
  section: { line: string; buttons: DownloadLink[] }
}

/** A version's DMG on GitHub and its release page there: GitHub's URLs for a release, with the DMG named as packaged */
const githubDmg = (version: string): string => `${RELEASE_LIST}/download/v${version}/${dmgName(version)}`
const releasePage = (version: string): string => `${RELEASE_LIST}/tag/v${version}`

/**
 * The state the page shows, from the two reads (landing-page::REQ-001): a readable pointer means a release on R2;
 * otherwise GitHub's latest release; otherwise, or when GitHub was not read or could not be, the release list. A
 * version only ever comes from a read.
 */
export function decide(pointer: PointerRead, github?: GitHubRead): DownloadState {
  if (pointer.kind === 'formal') return { kind: 'formal-r2', version: pointer.version, url: pointer.url }
  if (github?.kind === 'formal') return { kind: 'formal-github', version: github.version, dmg: github.dmg }
  return { kind: 'list' }
}

const fill = (template: string, version: string): string => template.replace('{version}', version)
const github = (label: string, href: string, kind: DownloadLink['kind'] = 'primary'): DownloadLink => ({ label, href, newTab: true, kind })

export function view(state: DownloadState, locale: Locale): DownloadView {
  const copy = ui[locale].download
  switch (state.kind) {
    case 'formal-r2': {
      const r2: DownloadLink = { label: fill(copy.formal.hero, state.version), href: state.url, newTab: false, kind: 'primary' }
      return {
        hero: r2,
        every: github(copy.formal.every, RELEASE_LIST),
        section: {
          line: fill(copy.formal.line, state.version),
          buttons: [{ ...r2, label: copy.formal.download }, github(copy.formal.github, githubDmg(state.version), 'ghost')]
        }
      }
    }
    case 'formal-github': {
      // A release without its DMG is not offered as a direct download: its page is (landing-page failure A6)
      const href = state.dmg ? githubDmg(state.version) : releasePage(state.version)
      return {
        hero: github(fill(copy.formal.hero, state.version), href),
        every: github(copy.formal.every, RELEASE_LIST),
        section: { line: fill(copy.formal.line, state.version), buttons: [github(copy.formal.download, href)] }
      }
    }
    case 'list':
      return {
        hero: github(copy.list.hero, RELEASE_LIST),
        every: null,
        section: { line: copy.list.line, buttons: [github(copy.list.button, RELEASE_LIST)] }
      }
  }
}
