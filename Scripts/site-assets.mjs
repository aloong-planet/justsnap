#!/usr/bin/env node
// The website's app assets: the screenshots and the app icon that JustSnap's website takes from the app. The website
// lives in the aloong-planet-home repository (apps/justsnap/), and its assets change there only through a pull
// request that this command opens (aloong-planet-home app-sites::REQ-004/AC-01).
//
//   node Scripts/site-assets.mjs [--shots <directory>] [--dry-run] [--title <text>] [--note <text>]
//                                [--remote <git url>] [--repo <owner/name>] [--base <branch>]
//
// What it does, in order:
//   1. Refuses to go on when anything the assets are made from has uncommitted changes, since the pull request names
//      this repository's HEAD as their source: Distribution/AppIcon.svg always, and when it renders the screenshots
//      itself also Sources/, JustSnap/, Package.swift and Package.resolved.
//   2. Derives the site's icon from the app icon's SVG (the 824-point tile without the drop shadow) and refuses to go on
//      unless the result draws the same artwork as Distribution/AppIcon.svg; the PNG is rendered from that SVG with
//      `sips` at 192 pixels, so it runs on macOS.
//   3. Gets the screenshots: from the app's own tool `JustSnapSiteShots`, which renders them offscreen (no window, no
//      screen capture) into a temporary directory with `swift run`, or, with --shots, from the directory given. Either
//      way the directory must hold exactly the fourteen files <view>-<language>.png (seven views, Chinese and English),
//      each a whole PNG of 1840×1035 pixels. Anything missing, extra, damaged or of another size fails the run before
//      anything is cloned, and every problem is listed.
//   4. Clones the website repository's base branch into a new temporary directory, writes the sixteen files at their
//      paths under apps/justsnap/public/, stages exactly those paths, and refuses to go on when anything else is changed
//      or staged. When no byte changed, it says so and opens nothing.
//   5. Commits on a new branch assets/justsnap-<date>-<source commit>, pushes it and opens the pull request with `gh`,
//      whose body names the commit of this repository the assets come from. With --dry-run it stops after the local
//      commit, prints what it would send, and keeps the clone for inspection.
//
// It runs on its own, and the release script runs it as its last step. --title and --note replace the pull request's
// title and add a line at the top of its body, for a run whose pull request is not meant to be merged. Needs: git, gh
// logged in with access to the website repository, sips, and for rendering the screenshots the Swift toolchain, with the
// release script's JUSTSNAP_SCRATCH_PATH and DEVELOPER_DIR. Exit code 0 when the pull request is opened, the dry run is
// done or nothing changed, 1 otherwise.
import { execFileSync } from 'node:child_process'
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const VIEWS = ['hero', 'select', 'extract', 'translate', 'paste', 'history', 'providers']
export const LANGUAGES = ['zh', 'en']
export const SHOT_SIZE = { width: 1840, height: 1035 }
export const ASSET_DIR = 'apps/justsnap/public'
export const ICON_SOURCE = 'Distribution/AppIcon.svg'
export const ICON_PNG_SIZE = 192
/** What the screenshots are rendered from: the tool, the app's views and their resources, and the package that builds them */
export const SHOT_INPUTS = ['Sources', 'JustSnap', 'Package.swift', 'Package.resolved']
const XCRUN = '/usr/bin/xcrun'
const DEFAULT_DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer'

export const DEFAULT_REMOTE = 'https://github.com/aloong-planet/aloong-planet-home.git'
export const DEFAULT_REPO = 'aloong-planet/aloong-planet-home'
export const DEFAULT_BASE = 'main'

const here = dirname(fileURLToPath(import.meta.url))

/** The screenshot files the site shows, by name */
export const SHOT_NAMES = VIEWS.flatMap((view) => LANGUAGES.map((language) => `${view}-${language}.png`))

/** Every path the pull request may change, relative to the website repository's root */
export const ASSET_PATHS = [
  ...SHOT_NAMES.map((name) => `${ASSET_DIR}/shots/${name}`),
  `${ASSET_DIR}/icon.svg`,
  `${ASSET_DIR}/icon.png`
]

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
const PNG_END = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82])

/** The size a PNG's header gives, or the reason it is not a whole PNG */
export function pngSize(bytes) {
  if (bytes.length < 33 || !bytes.subarray(0, 8).equals(PNG_SIGNATURE) || bytes.toString('latin1', 12, 16) !== 'IHDR') {
    return { problem: 'is not a PNG' }
  }
  if (!bytes.subarray(bytes.length - PNG_END.length).equals(PNG_END)) return { problem: 'is cut short: it does not end with the PNG end chunk' }
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) }
}

/** The names of the usable screenshots of a directory, and every problem with the directory, one sentence each */
export function readShots(dir) {
  const problems = []
  let entries = []
  try {
    entries = readdirSync(dir).filter((name) => name !== '.DS_Store').sort()
  } catch (error) {
    return { shots: [], problems: [`${dir} cannot be read: ${error.code ?? error.message}`] }
  }
  for (const name of SHOT_NAMES) if (!entries.includes(name)) problems.push(`${name} is missing`)
  for (const name of entries) if (!SHOT_NAMES.includes(name)) problems.push(`${name} is not one of the site's screenshots`)
  const shots = []
  for (const name of SHOT_NAMES.filter((n) => entries.includes(n))) {
    const size = pngSize(readFileSync(join(dir, name)))
    if (size.problem) problems.push(`${name} ${size.problem}`)
    else if (size.width !== SHOT_SIZE.width || size.height !== SHOT_SIZE.height) {
      problems.push(`${name} is ${size.width}×${size.height}, not ${SHOT_SIZE.width}×${SHOT_SIZE.height}`)
    } else shots.push(name)
  }
  return { shots, problems }
}

const APP_ICON_ROOT = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
const SITE_ICON_ROOT = '<svg xmlns="http://www.w3.org/2000/svg" width="824" height="824" viewBox="100 100 824 824">'

/** Throws unless `pattern` matches `count` times in `source`: the source is not what this derivation expects when it does not */
function expectCount(source, pattern, count, what) {
  const found = source.match(pattern)?.length ?? 0
  if (found !== count) throw new Error(`the app icon has ${found} ${what}, not ${count}: the derivation of the site's icon was written for another app icon`)
}

/**
 * The website's icon from the app's: the app icon's SVG cropped to its tile (the 824-point square at 100,100 of the
 * 1024-point canvas), without the drop shadow, which would be cut off at the tile's edge, and without the leading
 * comment that is about the app's own icon file. A source that does not have the one root element, the one shadow
 * filter and the one shape using it is refused.
 */
export function deriveSiteIcon(source) {
  if (source.split('\n').filter((line) => line.startsWith('<svg ')).join('') !== APP_ICON_ROOT) {
    throw new Error('the app icon\'s root element is not the 1024-point svg this derivation was written for')
  }
  let svg = source.replace(/^<!--[\s\S]*?-->\n/, '').replace(APP_ICON_ROOT, SITE_ICON_ROOT)
  expectCount(svg, /<filter\b/g, 1, 'shadow filter')
  expectCount(svg, /^ *<filter id="shadow"[\s\S]*?<\/filter>\n/gm, 1, 'shadow filter')
  svg = svg.replace(/^ *<filter id="shadow"[\s\S]*?<\/filter>\n/m, '')
  expectCount(svg, / filter="url\(#shadow\)"/g, 1, 'filter attribute using it')
  return svg.replace(/ filter="url\(#shadow\)"/, '')
}

/** The shapes and gradients an icon's SVG draws as [tag, sorted attributes], without the root, the filters and the `filter` attribute */
function artwork(svg) {
  const items = []
  for (const [, tag, attributes] of svg.replace(/<!--[\s\S]*?-->/g, '').matchAll(/<([A-Za-z][\w:-]*)((?:\s+[\w:-]+="[^"]*")*)\s*\/?>/g)) {
    if (['svg', 'filter', 'feDropShadow'].includes(tag)) continue
    const pairs = [...attributes.matchAll(/([\w:-]+)="([^"]*)"/g)].map(([, name, value]) => [name, value]).filter(([name]) => name !== 'filter')
    items.push([tag, pairs.sort(([a], [b]) => (a < b ? -1 : 1))])
  }
  return items
}

/** Whether two icons' SVGs draw the same artwork; an app icon that draws nothing is the same as nothing */
export function sameArtwork(appSvg, siteSvg) {
  const app = artwork(appSvg)
  return app.length > 0 && JSON.stringify(app) === JSON.stringify(artwork(siteSvg))
}

/** Throws when a staged or changed path is not one of the site's assets */
export function assertOnlyAssets(paths) {
  const stray = paths.filter((path) => !ASSET_PATHS.includes(path))
  if (stray.length > 0) throw new Error(`refusing to go on: ${stray.length} changed path(s) are not the site's assets: ${stray.join(', ')}`)
}

function parseArgs(argv) {
  const options = { dryRun: false, remote: DEFAULT_REMOTE, repo: DEFAULT_REPO, base: DEFAULT_BASE }
  const valued = { '--shots': 'shots', '--title': 'title', '--note': 'note', '--remote': 'remote', '--repo': 'repo', '--base': 'base' }
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (arg === '--dry-run') options.dryRun = true
    else if (arg in valued) {
      if (argv[i + 1] === undefined) throw new Error(`${arg} needs a value`)
      options[valued[arg]] = argv[++i]
    } else throw new Error(`unknown option ${arg}`)
  }
  return options
}

/** Runs a command and returns its output; a failing command throws with its error output in the message */
export function runCommand(command, args, { cwd, env } = {}) {
  try {
    return execFileSync(command, args, { cwd, env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
  } catch (error) {
    const output = `${error.stderr ?? ''}`.trim()
    throw new Error(`${command} ${args.join(' ')} failed${output ? `: ${output}` : ''}`, { cause: error })
  }
}

/** The icon as a PNG of `size` pixels, rendered from the SVG by `sips` (macOS only): `sips -z <n> <n> -s format png <svg> --out <png>` */
export function renderIconWithSips(svgPath, size, dest) {
  if (process.platform !== 'darwin') throw new Error('rendering the icon needs sips, which only macOS has')
  execFileSync('sips', ['-z', String(size), String(size), '-s', 'format', 'png', svgPath, '--out', dest], { stdio: 'pipe' })
}

const defaults = {
  run: runCommand,
  renderIcon: renderIconWithSips,
  root: resolve(here, '..'),
  now: () => new Date()
}

const lines = (text) => text.split('\n').filter(Boolean)

/** The first branch name <base>, <base>-2, ... that the remote does not have */
function freeBranch(run, cwd, base) {
  for (let n = 1; n < 50; n += 1) {
    const name = n === 1 ? base : `${base}-${n}`
    if (run('git', ['ls-remote', '--heads', 'origin', `refs/heads/${name}`], { cwd }).trim() === '') return name
  }
  throw new Error(`the remote already has ${base} and 48 numbered variants`)
}

function pullRequestText({ options, source, changed, rendered }) {
  const title = options.title ?? `Update JustSnap's site screenshots and icon (justsnap ${source.slice(0, 7)})`
  const body = [
    ...(options.note ? [options.note, ''] : []),
    `Opened by \`node Scripts/site-assets.mjs\` in aloong-planet/justsnap, from its commit ${source}.`,
    '',
    rendered
      ? 'Screenshots: rendered by `JustSnapSiteShots` from that commit.'
      : 'Screenshots: taken from a directory given with `--shots`, not rendered by this run.',
    '',
    `Changed files (${changed.length}), all of them app assets of the JustSnap site:`,
    ...changed.map((path) => `- ${path}`),
    '',
    `Nothing else is in this pull request: the screenshots under ${ASSET_DIR}/shots/ and the icon files ${ASSET_DIR}/icon.svg and icon.png are the only paths the command writes, and it refuses to go on when anything else is changed.`
  ].join('\n')
  return { title, body }
}

/** The paths among `paths` that have uncommitted changes, untracked files included */
function uncommittedPaths(run, root, paths) {
  return lines(run('git', ['status', '--porcelain', '--untracked-files=all', '--', ...paths], { cwd: root })).map((line) => line.slice(3))
}

/** Has the screenshot tool render the screenshots into `outDir`, the way the release script builds: its scratch path and developer directory */
function renderShots({ run, root, env, outDir }) {
  const scratch = env.JUSTSNAP_SCRATCH_PATH ?? join(root, '.build')
  run(XCRUN, ['swift', 'run', '--scratch-path', scratch, '--package-path', root, 'JustSnapSiteShots', outDir], {
    cwd: root, env: { ...env, DEVELOPER_DIR: env.DEVELOPER_DIR ?? DEFAULT_DEVELOPER_DIR }
  })
}

/** Runs the command; resolves to the exit code. `deps` replaces the system boundary in tests. */
export async function main(argv, deps = {}) {
  const { run, renderIcon, deriveIcon = deriveSiteIcon, root, env = process.env, now, log = console.log } = { ...defaults, ...deps }
  let options
  try {
    options = parseArgs(argv)
  } catch (error) {
    console.error(error.message)
    return 1
  }
  const rendered = options.shots === undefined

  // The pull request names this repository's HEAD as the source of the assets, so what they are made from must be in it
  const uncommitted = uncommittedPaths(run, root, rendered ? [ICON_SOURCE, ...SHOT_INPUTS] : [ICON_SOURCE])
  if (uncommitted.length > 0) {
    const many = uncommitted.length > 1
    log(`${uncommitted.join(', ')} ${many ? 'have' : 'has'} uncommitted changes: commit ${many ? 'them' : 'it'} first, so that the pull request names a commit that holds what the assets are made from`)
    return 1
  }

  let siteIcon
  try {
    const appIcon = readFileSync(join(root, ICON_SOURCE), 'utf8')
    siteIcon = deriveIcon(appIcon)
    if (!sameArtwork(appIcon, siteIcon)) throw new Error(`the site's icon does not draw the same artwork as ${ICON_SOURCE}`)
  } catch (error) {
    log(`the site's icon cannot be made: ${error.message}`)
    return 1
  }

  const renderedDir = rendered ? mkdtempSync(join(tmpdir(), 'site-assets-shots-')) : undefined
  let work
  let keep = options.dryRun
  try {
    if (rendered) {
      try {
        renderShots({ run, root, env, outDir: renderedDir })
      } catch (error) {
        log(`the screenshots cannot be rendered: ${error.message}`)
        return 1
      }
    }
    const shotsDir = rendered ? renderedDir : resolve(options.shots)
    const { shots, problems } = readShots(shotsDir)
    if (problems.length > 0) {
      log(`the screenshots ${rendered ? 'JustSnapSiteShots rendered' : `in ${options.shots}`} cannot be used:\n${problems.map((p) => `  - ${p}`).join('\n')}`)
      return 1
    }
    const source = run('git', ['rev-parse', 'HEAD'], { cwd: root }).trim()

    work = mkdtempSync(join(tmpdir(), 'site-assets-'))
    const home = join(work, 'home')
    run('git', ['clone', '--quiet', '--depth', '1', '--branch', options.base, '--single-branch', options.remote, home])
    const stamp = now().toISOString().slice(0, 10).replaceAll('-', '')
    const branch = freeBranch(run, home, `assets/justsnap-${stamp}-${source.slice(0, 7)}`)
    run('git', ['switch', '--quiet', '-c', branch], { cwd: home })

    mkdirSync(join(home, ASSET_DIR, 'shots'), { recursive: true })
    for (const name of shots) copyFileSync(join(shotsDir, name), join(home, ASSET_DIR, 'shots', name))
    writeFileSync(join(home, ASSET_DIR, 'icon.svg'), siteIcon)
    renderIcon(join(home, ASSET_DIR, 'icon.svg'), ICON_PNG_SIZE, join(home, ASSET_DIR, 'icon.png'))

    // Everything git sees as changed must be an asset before anything is staged; what is staged is then the assets alone,
    // since `git add` is given those paths and no others
    const status = lines(run('git', ['status', '--porcelain', '--untracked-files=all', '-z'], { cwd: home }).replaceAll('\0', '\n')).map((l) => l.slice(3))
    assertOnlyAssets(status)
    run('git', ['add', '--', ...ASSET_PATHS], { cwd: home })
    const changed = lines(run('git', ['diff', '--cached', '--name-only'], { cwd: home }))
    if (changed.length === 0) {
      keep = false
      log(`the site's assets are already what ${rendered ? 'JustSnapSiteShots renders' : options.shots} and ${ICON_SOURCE} give: nothing to send`)
      return 0
    }

    const { title, body } = pullRequestText({ options, source, changed, rendered })
    run('git', ['commit', '--quiet', '-m', title, '-m', body], { cwd: home })
    if (options.dryRun) {
      log(`dry run: committed ${changed.length} file(s) on ${branch} in ${home}, nothing pushed:\n${changed.map((p) => `  ${p}`).join('\n')}`)
      log(`title: ${title}\nbody:\n${body}`)
      return 0
    }
    // Several images are more than git's default 1 MiB HTTP buffer, and a push that does not fit it is answered with HTTP 400
    run('git', ['-c', 'http.postBuffer=524288000', 'push', '--quiet', 'origin', branch], { cwd: home })
    const url = run('gh', ['pr', 'create', '--repo', options.repo, '--base', options.base, '--head', branch, '--title', title, '--body', body], { cwd: home }).trim()
    log(`opened ${url}`)
    return 0
  } catch (error) {
    keep = true
    log(`failed: ${error.message}${work ? `\n  (the clone is kept in ${work})` : ''}`)
    return 1
  } finally {
    if (renderedDir) rmSync(renderedDir, { recursive: true, force: true })
    if (work && !keep) rmSync(work, { recursive: true, force: true })
  }
}

function isMain() {
  return process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
}

if (isMain()) process.exitCode = await main(process.argv.slice(2))
