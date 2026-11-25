// The command that sends the website's app assets to the website repository (Scripts/site-assets.mjs): what it refuses
// before it touches anything, what it sends when an asset changed, and that what it sends is the assets alone
// (aloong-planet-home app-sites::REQ-004/AC-01).
//
// The website repository is a bare repository on disk, cloned through a file:// URL so that `--depth` works as it does
// against GitHub; JustSnap's own repository is a scratch repository holding a copy of Distribution/AppIcon.svg; git runs
// for real in both. What stands in for the system boundary: `gh` (`gh api user` answers a fixed account, and the pull
// request is a recorded call), `swift` (a function that writes the screenshots the tool would write), and `sips` (a
// function that makes bytes from the SVG), except in the one case that runs the real `sips` on macOS.
//
// Gaps: nothing here reaches GitHub, and nothing builds or runs JustSnapSiteShots (that needs the Swift toolchain and
// minutes of compiling). `git push` to github.com, `gh pr create` and the real tool run only in a run of the command
// itself; the evidence runs recorded in the delivery of the pull request that added the command are those runs.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  ASSET_DIR, ASSET_PATHS, DEFAULT_REPO, ICON_PNG_SIZE, SHOT_NAMES, SHOT_SIZE, deriveSiteIcon, identityFromUser, main, pngSize, readShots,
  renderIconWithSips, runCommand, sameArtwork
} from '../site-assets.mjs'

// No test reads the machine's git configuration: a signing key or a commit template there must not change a run
Object.assign(process.env, {
  GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_SYSTEM: '/dev/null',
  GIT_AUTHOR_NAME: 'Test', GIT_AUTHOR_EMAIL: 'test@example.com', GIT_COMMITTER_NAME: 'Test', GIT_COMMITTER_EMAIL: 'test@example.com'
})

const scratch = []
const dir = (name) => {
  const path = mkdtempSync(join(tmpdir(), `site-assets-test-${name}-`))
  scratch.push(path)
  return path
}
test.after(() => scratch.forEach((path) => rmSync(path, { recursive: true, force: true })))

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
const PNG_END = Buffer.from([0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82])

/** The bytes of a PNG that has a header of this size and an end chunk, and a body that tells one picture from another */
function png(width, height, picture = '') {
  const header = Buffer.alloc(33)
  PNG_SIGNATURE.copy(header, 0)
  header.writeUInt32BE(13, 8)
  header.write('IHDR', 12, 'latin1')
  header.writeUInt32BE(width, 16)
  header.writeUInt32BE(height, 20)
  return Buffer.concat([header, Buffer.from(picture), PNG_END])
}
const shot = (name, picture = name) => png(SHOT_SIZE.width, SHOT_SIZE.height, picture)

/** A directory with every screenshot, `overrides` replacing the bytes of the ones it names */
function shotsDir(overrides = {}) {
  const path = dir('shots')
  for (const name of SHOT_NAMES) writeFileSync(join(path, name), overrides[name] ?? shot(name))
  return path
}

test('the site shows fourteen screenshots, seven views in two languages, and two icon files', () => {
  assert.deepEqual(SHOT_NAMES, [
    'hero-zh.png', 'hero-en.png', 'select-zh.png', 'select-en.png', 'extract-zh.png', 'extract-en.png', 'translate-zh.png',
    'translate-en.png', 'paste-zh.png', 'paste-en.png', 'history-zh.png', 'history-en.png', 'providers-zh.png', 'providers-en.png'
  ])
  assert.deepEqual(ASSET_PATHS.filter((path) => !path.includes('/shots/')), [`${ASSET_DIR}/icon.svg`, `${ASSET_DIR}/icon.png`])
  assert.equal(ASSET_DIR, 'apps/justsnap/public')
  assert.equal(ASSET_PATHS.length, 16)
  assert.deepEqual(SHOT_SIZE, { width: 1840, height: 1035 })
})

test('a PNG is read for its size, and a file that is no whole PNG is named for what is wrong with it', () => {
  assert.deepEqual(pngSize(png(1840, 1035)), { width: 1840, height: 1035 })
  assert.match(pngSize(Buffer.from('GIF89a, not a PNG at all, but long enough to have a header to read')).problem, /not a PNG/)
  assert.match(pngSize(png(1840, 1035).subarray(0, 40)).problem, /cut short/)
  assert.match(pngSize(Buffer.alloc(0)).problem, /not a PNG/)
})

test('the screenshots are checked as a set: each one that is missing, extra, damaged or of another size is a problem of its own', () => {
  assert.deepEqual(readShots(shotsDir()).problems, [])
  assert.equal(readShots(shotsDir()).shots.length, 14)

  const incomplete = shotsDir()
  rmSync(join(incomplete, 'history-zh.png'))
  writeFileSync(join(incomplete, 'overview-en.png'), shot('overview'))
  writeFileSync(join(incomplete, 'paste-en.png'), png(1800, 1000))
  writeFileSync(join(incomplete, 'providers-en.png'), 'not a picture')
  writeFileSync(join(incomplete, 'hero-zh.png'), png(1840, 1035).subarray(0, 40))
  assert.deepEqual(readShots(incomplete).problems, [
    'history-zh.png is missing',
    'overview-en.png is not one of the site\'s screenshots',
    'hero-zh.png is cut short: it does not end with the PNG end chunk',
    'paste-en.png is 1800×1000, not 1840×1035',
    'providers-en.png is not a PNG'
  ])
  // Fourteen, less the one that is missing and the three that are damaged; the extra file is not one of them
  assert.equal(readShots(incomplete).shots.length, 10)

  // The Finder's file is no screenshot and no problem
  const finder = shotsDir()
  writeFileSync(join(finder, '.DS_Store'), 'x')
  assert.deepEqual(readShots(finder).problems, [])
  assert.match(readShots(join(finder, 'nowhere')).problems[0], /cannot be read: ENOENT/)
})

// The app icon's SVG as the repository has it, and a small one with every feature the derivation deals with, whose
// derived text is written out here by hand
const APP_ICON = readFileSync(new URL('../../Distribution/AppIcon.svg', import.meta.url), 'utf8')
const APP_ICON_SMALL = `<!-- the app icon source -->
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="body"><stop offset="0" stop-color="#000"/></linearGradient>
    <filter id="shadow" x="-10%">
      <feDropShadow dx="0" dy="14"/>
    </filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#body)" filter="url(#shadow)"/>
  <path d="M1 2"/>
</svg>
`
const SITE_ICON_SMALL = `<svg xmlns="http://www.w3.org/2000/svg" width="824" height="824" viewBox="100 100 824 824">
  <defs>
    <linearGradient id="body"><stop offset="0" stop-color="#000"/></linearGradient>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#body)"/>
  <path d="M1 2"/>
</svg>
`

test('the site\'s icon is the app icon cropped to its tile, without the drop shadow and the comment', () => {
  assert.equal(deriveSiteIcon(APP_ICON_SMALL), SITE_ICON_SMALL)
  // Without the comment the source is still an app icon
  assert.equal(deriveSiteIcon(APP_ICON_SMALL.replace(/^<!--.*-->\n/, '')), SITE_ICON_SMALL)

  const real = deriveSiteIcon(APP_ICON)
  assert.ok(real.startsWith('<svg xmlns="http://www.w3.org/2000/svg" width="824" height="824" viewBox="100 100 824 824">\n'))
  for (const gone of ['<!--', 'filter', 'feDropShadow', 'shadow']) assert.ok(!real.includes(gone), `${gone} is still there`)
  assert.ok(real.includes('<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#body)"/>'))
})

test('a source that is no longer the app icon this derivation was written for is refused, naming what it did not find', () => {
  const rows = [
    ['the root is another size', APP_ICON_SMALL.replace('viewBox="0 0 1024 1024"', 'viewBox="0 0 512 512"'), /root element/],
    ['the shadow filter is gone', APP_ICON_SMALL.replace(/ *<filter[\s\S]*<\/filter>\n/, ''), /shadow filter/],
    ['two shapes use the filter', APP_ICON_SMALL.replace('<path d="M1 2"/>', '<path d="M1 2" filter="url(#shadow)"/>'), /filter attribute/],
    ['a second filter is defined', APP_ICON_SMALL.replace('</defs>', '<filter id="shadow"></filter></defs>'), /shadow filter/]
  ]
  for (const [name, source, message] of rows) assert.throws(() => deriveSiteIcon(source), message, name)
})

test('two icons draw the same artwork when their shapes and gradients are the same, whatever the size, shadow and layout', () => {
  assert.equal(sameArtwork(APP_ICON, deriveSiteIcon(APP_ICON)), true)
  assert.equal(sameArtwork(APP_ICON_SMALL, SITE_ICON_SMALL), true)
  // Attribute order and spacing are not artwork
  assert.equal(sameArtwork(SITE_ICON_SMALL, SITE_ICON_SMALL.replace('<rect x="100" y="100"', '<rect   y="100"   x="100"').replace('<path d="M1 2"/>', '<path\n d="M1 2" />')), true)
})

test('two icons that draw something else, or nothing, are not the same artwork', () => {
  const rows = [
    ['a shape differs in one attribute', SITE_ICON_SMALL.replace('rx="185"', 'rx="186"')],
    ['a shape is added', SITE_ICON_SMALL.replace('</svg>', '  <circle cx="1" cy="1" r="1"/>\n</svg>')],
    ['a shape is gone', SITE_ICON_SMALL.replace('  <path d="M1 2"/>\n', '')],
    ['a gradient stop differs', SITE_ICON_SMALL.replace('stop-color="#000"', 'stop-color="#001"')]
  ]
  for (const [name, other] of rows) assert.equal(sameArtwork(APP_ICON_SMALL, other), false, name)
  // An icon that draws nothing is not an app icon to compare with
  assert.equal(sameArtwork('<svg xmlns="http://www.w3.org/2000/svg"/>', '<svg xmlns="http://www.w3.org/2000/svg"/>'), false)
})

// ---- the identity of the commit

test('the commit\'s identity is the account\'s login and its noreply address, not the profile\'s name or address', () => {
  assert.deepEqual(identityFromUser(JSON.stringify({ login: 'octo-example', id: 4242, name: 'Octo Example', email: 'octo-public@example.org' })), {
    name: 'octo-example', email: '4242+octo-example@users.noreply.github.com'
  })
  // Managed accounts have an underscore in their login
  assert.equal(identityFromUser('{"login":"octo_example","id":7}').email, '7+octo_example@users.noreply.github.com')
})

test('an answer that has no login and numeric id to make the identity of is refused', () => {
  const rows = [
    ['not JSON', 'gh: Not Found (HTTP 404)'],
    ['JSON that is no account', 'null'],
    ['no id', '{"login":"octo-example"}'],
    ['an id that is text', '{"login":"octo-example","id":"4242"}'],
    ['an id that is no account number', '{"login":"octo-example","id":0}'],
    ['no login', '{"id":4242}'],
    ['a login that is no part of an address', '{"login":"octo example@","id":4242}']
  ]
  for (const [name, answer] of rows) assert.throws(() => identityFromUser(answer), /did not answer with a login and an id/, name)
})

// ---- the command: what it sends, and to where

const git = (cwd, ...args) => runCommand('git', args, { cwd }).trim()

/** The icon the fake `sips` makes from an SVG: it depends on the SVG's bytes and on the size */
const fakeRender = (svgPath, size, dest) => writeFileSync(dest, Buffer.concat([Buffer.from(`icon ${size}:`), readFileSync(svgPath)]))

/** JustSnap's repository, as far as the command reads it: a commit holding the app icon's SVG and the screenshot tool's source */
function justsnap(icon = APP_ICON) {
  const root = dir('justsnap')
  git(root, 'init', '--quiet', '--initial-branch=main')
  mkdirSync(join(root, 'Distribution'))
  writeFileSync(join(root, 'Distribution', 'AppIcon.svg'), icon)
  mkdirSync(join(root, 'Sources', 'JustSnapSiteShots'), { recursive: true })
  writeFileSync(join(root, 'Sources', 'JustSnapSiteShots', 'main.swift'), '// the tool\n')
  git(root, 'add', '.')
  git(root, 'commit', '--quiet', '-m', 'the app')
  return root
}

/** The website repository: a bare repository whose main holds every asset as the command would write it from `icon` */
function website({ icon = APP_ICON, pictures = {}, branch = 'main' } = {}) {
  const bare = join(dir('website'), 'website.git')
  git(dirname(bare), 'init', '--quiet', '--bare', `--initial-branch=${branch}`, bare)
  const work = dir('website-work')
  git(work, 'init', '--quiet', `--initial-branch=${branch}`)
  mkdirSync(join(work, ASSET_DIR, 'shots'), { recursive: true })
  for (const name of SHOT_NAMES) writeFileSync(join(work, ASSET_DIR, 'shots', name), pictures[name] ?? shot(name))
  writeFileSync(join(work, ASSET_DIR, 'icon.svg'), deriveSiteIcon(icon))
  fakeRender(join(work, ASSET_DIR, 'icon.svg'), 192, join(work, ASSET_DIR, 'icon.png'))
  mkdirSync(join(work, 'apps', 'home'), { recursive: true })
  writeFileSync(join(work, 'apps', 'home', 'index.html'), '<p>the homepage</p>')
  git(work, 'add', '.')
  git(work, 'commit', '--quiet', '-m', 'the website repository')
  git(work, 'push', '--quiet', bare, branch)
  return { bare, url: `file://${bare}` }
}

/**
 * What `gh api user` answers for the account `gh` is logged in as: the keys GitHub's answer has, with a public profile name and
 * address among them, which the commit's identity must not take
 */
const GH_USER = JSON.stringify({
  login: 'octo-example', id: 4242, node_id: 'MDQ6VXNlcjQyNDI=', type: 'User', name: 'Octo Example', email: 'octo-public@example.org',
  notification_email: 'octo-private@example.org', html_url: 'https://github.com/octo-example'
})
const NOREPLY = '4242+octo-example@users.noreply.github.com'

/**
 * A run of the command with `gh` faked and `sips` faked; resolves to what it printed and sent. `gh api user` is recorded in
 * `users` and answered by `fakeUser`, and every other `gh` call is a pull request in `prs` that `fakeGh` answers.
 */
async function send(argv, { root = justsnap(), site = website(), fakeGh, fakeUser, renderIcon = fakeRender, deriveIcon, tool, env = {} } = {}) {
  const printed = []
  const prs = []
  const users = []
  const calls = []
  const run = (command, args, options) => {
    calls.push([command, args, options])
    if (command === XCRUN) {
      if (!tool) throw new Error('a run that is given its screenshots must not start the screenshot tool')
      return tool(args, options)
    }
    if (command !== 'gh') return runCommand(command, args, options)
    if (args[0] === 'api') {
      users.push(args)
      return fakeUser ? fakeUser(args) : GH_USER
    }
    prs.push(args)
    if (fakeGh) return fakeGh(args)
    return 'https://github.com/aloong-planet/aloong-planet-home/pull/1\n'
  }
  const code = await main([...argv, '--remote', site.url], {
    root, run, renderIcon, deriveIcon, env, log: (text) => printed.push(text), now: () => new Date('2026-11-25T10:00:00Z')
  })
  return { code, printed: printed.join('\n'), prs, users, calls, site, root }
}

/** The author and the committer of a commit, as `<name> <address>` each */
const whoMade = (cwd, rev) => git(cwd, 'log', '-1', '--format=%an <%ae> | %cn <%ce>', rev)
const AS_THE_ACCOUNT = `octo-example <${NOREPLY}> | octo-example <${NOREPLY}>`

/**
 * Runs `body` as on a Mac whose own git identity is somebody's: a global git configuration and the author and committer
 * variables of the environment all name other people, as the ones that a person's shell and `~/.gitconfig` can.
 */
async function onAMacWithAGitIdentity(body) {
  const config = join(dir('gitconfig'), 'config')
  writeFileSync(config, '[user]\n\tname = Personal Name\n\temail = personal@example.com\n')
  const keys = ['GIT_CONFIG_GLOBAL', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL']
  const before = Object.fromEntries(keys.map((key) => [key, process.env[key]]))
  Object.assign(process.env, {
    GIT_CONFIG_GLOBAL: config, GIT_AUTHOR_NAME: 'Env Author', GIT_AUTHOR_EMAIL: 'env-author@example.com',
    GIT_COMMITTER_NAME: 'Env Committer', GIT_COMMITTER_EMAIL: 'env-committer@example.com'
  })
  try {
    return await body()
  } finally {
    for (const key of keys) {
      if (before[key] === undefined) delete process.env[key]
      else process.env[key] = before[key]
    }
  }
}

const XCRUN = '/usr/bin/xcrun'

/** The screenshot tool that writes every screenshot, each showing `picture`, to the directory it is given last */
const writesShots = (picture) => (args) => {
  for (const name of SHOT_NAMES) writeFileSync(join(args.at(-1), name), shot(name, `${picture} ${name}`))
  return ''
}

/** The clones of the website repository a run made */
const clones = (result) => result.calls.filter(([command, args]) => command === 'git' && args[0] === 'clone')

const branches = (site) => git(site.bare, 'for-each-ref', '--format=%(refname:short)', 'refs/heads').split('\n').sort()
const changedBy = (site, branch) => git(site.bare, 'diff', '--name-only', `main...${branch}`).split('\n').filter(Boolean)
const pathOf = (name) => `${ASSET_DIR}/shots/${name}`

test('a dry run commits the changed assets locally on a branch of the day and the commit, sends nothing and keeps the clone', async (t) => {
  const result = await send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') }), '--dry-run'])
  assert.equal(result.code, 0)
  assert.deepEqual(result.prs, [])
  assert.deepEqual(branches(result.site), ['main'])
  const head = git(result.root, 'rev-parse', 'HEAD')
  const kept = result.printed.match(/in (\S+site-assets-\S+\/home), nothing pushed/)?.[1]
  assert.ok(kept && existsSync(kept), 'the clone is kept and named')
  t.after(() => rmSync(dirname(kept), { recursive: true, force: true }))
  assert.equal(git(kept, 'branch', '--show-current'), `assets/justsnap-20261125-${head.slice(0, 7)}`)
  assert.deepEqual(git(kept, 'show', '--name-only', '--format=', 'HEAD').split('\n'), [pathOf('hero-zh.png')])
  // The identity of the commit is the one a run that pushes would make it with, though nothing is pushed
  assert.equal(whoMade(kept, 'HEAD'), AS_THE_ACCOUNT)
  assert.ok(result.printed.includes(`  ${pathOf('hero-zh.png')}`))
  assert.match(result.printed, /title: Update JustSnap's site screenshots and icon \(justsnap /)
})

test('a retaken screenshot is sent as one branch and one pull request that change that file alone', async () => {
  const result = await send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') })])
  assert.equal(result.code, 0)
  const head = git(result.root, 'rev-parse', 'HEAD')
  const branch = `assets/justsnap-20261125-${head.slice(0, 7)}`
  assert.deepEqual(branches(result.site), [branch, 'main'])
  assert.deepEqual(changedBy(result.site, branch), [pathOf('hero-zh.png')])
  assert.equal(git(result.site.bare, 'rev-list', '--count', `main..${branch}`), '1')

  assert.equal(result.prs.length, 1)
  const [pr] = result.prs
  const arg = (flag) => pr[pr.indexOf(flag) + 1]
  assert.deepEqual(pr.slice(0, 2), ['pr', 'create'])
  assert.equal(arg('--repo'), DEFAULT_REPO)
  assert.equal(arg('--base'), 'main')
  assert.equal(arg('--head'), branch)
  assert.equal(arg('--title'), `Update JustSnap's site screenshots and icon (justsnap ${head.slice(0, 7)})`)
  const body = arg('--body')
  assert.match(body, new RegExp(`from its commit ${head}`))
  assert.match(body, /Changed files \(1\)/)
  assert.ok(body.includes(`- ${pathOf('hero-zh.png')}`))
  // The text says nothing about where the command ran, and closes no ticket of the website repository
  for (const local of [result.root, tmpdir()]) assert.ok(!body.includes(local), `the body names ${local}`)
  assert.doesNotMatch(body, /\b(close[sd]?|fix(e[sd])?|resolve[sd]?):? *#\d+/i)
  assert.match(result.printed, /opened https:\/\/github\.com\/aloong-planet\/aloong-planet-home\/pull\/1/)
  // The commit's own message says the same as the pull request
  assert.match(git(result.site.bare, 'log', '-1', '--format=%B', branch), new RegExp(`from its commit ${head}`))
})

test('the commit that is pushed is the logged-in account\'s, under its noreply address, whatever the Mac\'s own git identity is', async () => {
  const result = await onAMacWithAGitIdentity(() => send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') })]))
  assert.equal(result.code, 0)
  const branch = branches(result.site).find((name) => name !== 'main')
  // Author and committer both: the login as the name and `<id>+<login>@users.noreply.github.com` as the address, not the
  // profile's public name or address that gh's answer also holds
  assert.equal(whoMade(result.site.bare, branch), AS_THE_ACCOUNT)
  assert.deepEqual(result.users, [['api', 'user']])
  assert.equal(result.prs.length, 1)
})

test('when gh cannot say who is logged in, the run stops before it renders, clones or sends anything, and says why', async () => {
  const rows = [
    ['gh fails', () => { throw new Error('gh api user failed: not logged in') }, /gh api user failed: not logged in/],
    ['gh answers with something else', () => 'Not Found', /`gh api user` did not answer with a login and an id/]
  ]
  for (const [name, fakeUser, reason] of rows) {
    const result = await send([], { tool: writesShots('rendered'), fakeUser })
    assert.equal(result.code, 1, name)
    assert.match(result.printed, /the identity of the commit cannot be taken from gh: /, name)
    assert.match(result.printed, reason, name)
    assert.deepEqual(result.calls.filter(([command]) => command === XCRUN), [], `${name}: the screenshot tool did not start`)
    assert.deepEqual(clones(result), [], name)
    assert.deepEqual(result.prs, [], name)
    assert.deepEqual(branches(result.site), ['main'], name)
  }
})

test('a changed app icon sends both icon files, derived from the SVG, and not the screenshots that did not change', async () => {
  const redrawn = APP_ICON.replace('rx="185"', 'rx="150"')
  const result = await send(['--shots', shotsDir()], { root: justsnap(redrawn), site: website({ icon: APP_ICON }) })
  assert.equal(result.code, 0)
  const branch = branches(result.site).find((name) => name !== 'main')
  assert.deepEqual(changedBy(result.site, branch).sort(), [`${ASSET_DIR}/icon.png`, `${ASSET_DIR}/icon.svg`])
  const svg = git(result.site.bare, 'show', `${branch}:${ASSET_DIR}/icon.svg`)
  assert.ok(svg.includes('rx="150"') && !svg.includes('filter'))
  assert.equal(git(result.site.bare, 'show', `${branch}:${ASSET_DIR}/icon.png`), `icon 192:${svg}`)
})

test('when no asset changed, nothing is pushed and no pull request is opened', async () => {
  const result = await send(['--shots', shotsDir()])
  assert.equal(result.code, 0)
  assert.match(result.printed, /nothing to send/)
  assert.deepEqual(result.prs, [])
  assert.deepEqual(branches(result.site), ['main'])
})

test('a file that is not one of the assets stops the run before anything is committed', async () => {
  const stray = (svgPath, size, dest) => {
    fakeRender(svgPath, size, dest)
    writeFileSync(join(dirname(dest), 'extra.png'), 'not an asset')
  }
  const result = await send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') })], { renderIcon: stray })
  assert.equal(result.code, 1)
  assert.match(result.printed, /refusing to go on: 1 changed path\(s\) are not the site's assets: apps\/justsnap\/public\/extra\.png/)
  assert.deepEqual(result.prs, [])
  assert.deepEqual(branches(result.site), ['main'])
  rmSync(result.printed.match(/kept in (\S+)\)/)[1], { recursive: true, force: true })
})

test('a failed pull request is reported, with where the clone was kept', async () => {
  const result = await send(['--shots', shotsDir({ 'history-zh.png': shot('history-zh.png', 'retaken') })], {
    fakeGh: () => { throw new Error('gh pr create failed: not logged in') }
  })
  assert.equal(result.code, 1)
  assert.match(result.printed, /failed: gh pr create failed: not logged in/)
  const kept = result.printed.match(/kept in (\S+)\)/)?.[1]
  assert.ok(kept && existsSync(kept))
  rmSync(kept, { recursive: true, force: true })
})

test('shots that cannot be used stop the run before anything is cloned, and every problem is listed', async () => {
  const incomplete = shotsDir()
  rmSync(join(incomplete, 'hero-en.png'))
  writeFileSync(join(incomplete, 'select-zh.png'), 'not a picture')
  const result = await send(['--shots', incomplete])
  assert.equal(result.code, 1)
  assert.match(result.printed, /hero-en\.png is missing/)
  assert.match(result.printed, /select-zh\.png is not a PNG/)
  assert.deepEqual(clones(result), [])
  assert.deepEqual(branches(result.site), ['main'])
})

test('options that make no sense are refused', async () => {
  assert.equal(await main(['--shots']), 1)
  assert.equal(await main(['--shots', 'x', '--frobnicate']), 1)
})

test('an app icon with uncommitted changes stops the run, because the pull request names a commit that would not hold it', async () => {
  const root = justsnap()
  writeFileSync(join(root, 'Distribution', 'AppIcon.svg'), `${APP_ICON}<!-- edited, not committed -->\n`)
  const result = await send(['--shots', shotsDir()], { root })
  assert.equal(result.code, 1)
  assert.match(result.printed, /Distribution\/AppIcon\.svg has uncommitted changes/)
  assert.deepEqual(clones(result), [])
  assert.deepEqual(result.prs, [])
})

test('shots given by directory do not depend on the screenshot tool\'s sources being committed, which they were not made from', async () => {
  const root = justsnap()
  writeFileSync(join(root, 'Sources', 'JustSnapSiteShots', 'main.swift'), '// edited, not committed\n')
  const result = await send(['--shots', shotsDir()], { root })
  assert.equal(result.code, 0)
  assert.match(result.printed, /nothing to send/)
})

test('an app icon that this derivation was not written for stops the run before anything is cloned', async () => {
  const noShadow = APP_ICON.replace(/ *<filter[\s\S]*<\/filter>\n/, '').replace(' filter="url(#shadow)"', '')
  const result = await send(['--shots', shotsDir()], { root: justsnap(noShadow) })
  assert.equal(result.code, 1)
  assert.match(result.printed, /the app icon has 0 shadow filter/)
  assert.deepEqual(clones(result), [])
})

test('a derived icon that draws something else than the app icon stops the run before anything is cloned', async () => {
  const wrong = (svg) => deriveSiteIcon(svg).replace('rx="185"', 'rx="1"')
  const result = await send(['--shots', shotsDir()], { deriveIcon: wrong })
  assert.equal(result.code, 1)
  assert.match(result.printed, /does not draw the same artwork as Distribution\/AppIcon\.svg/)
  assert.deepEqual(clones(result), [])
})

test('without --shots the command has the screenshot tool render them, before anything is cloned, and sends all fourteen', async () => {
  const root = justsnap()
  const result = await send([], { root, tool: writesShots('rendered') })
  assert.equal(result.code, 0)
  const toolCalls = result.calls.filter(([command]) => command === XCRUN)
  assert.equal(toolCalls.length, 1)
  const [, args, options] = toolCalls[0]
  const outDir = args.at(-1)
  assert.deepEqual(args, ['swift', 'run', '--scratch-path', join(root, '.build'), '--package-path', root, 'JustSnapSiteShots', outDir])
  assert.equal(options.env.DEVELOPER_DIR, '/Applications/Xcode.app/Contents/Developer')
  assert.ok(result.calls.indexOf(toolCalls[0]) < result.calls.indexOf(clones(result)[0]), 'the tool ran before the clone')
  assert.ok(!existsSync(outDir), 'the tool\'s output directory is removed')

  const branch = branches(result.site).find((name) => name !== 'main')
  assert.deepEqual(changedBy(result.site, branch).sort(), SHOT_NAMES.map(pathOf).sort())
  assert.match(result.prs[0][result.prs[0].indexOf('--body') + 1], /Screenshots: rendered by `JustSnapSiteShots` from that commit/)
})

test('the screenshot tool\'s build directory and developer directory follow the environment, as the release script\'s do', async () => {
  const result = await send([], { tool: writesShots('rendered'), env: { JUSTSNAP_SCRATCH_PATH: '/scratch/elsewhere', DEVELOPER_DIR: '/xcode/elsewhere' } })
  const [, args, options] = result.calls.find(([command]) => command === XCRUN)
  assert.equal(args[args.indexOf('--scratch-path') + 1], '/scratch/elsewhere')
  assert.equal(options.env.DEVELOPER_DIR, '/xcode/elsewhere')
})

test('screenshots given by directory are used as they are, and the tool is not started', async () => {
  const result = await send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') })])
  assert.equal(result.code, 0)
  assert.deepEqual(result.calls.filter(([command]) => command === XCRUN), [])
  assert.match(result.prs[0][result.prs[0].indexOf('--body') + 1], /Screenshots: taken from a directory given with `--shots`, not rendered by this run/)
})

test('a screenshot tool that fails stops the run before anything is cloned, and its output directory is removed', async () => {
  let outDir
  const result = await send([], { tool: (args) => { outDir = args.at(-1); throw new Error('swift run failed: the build broke') } })
  assert.equal(result.code, 1)
  assert.match(result.printed, /the screenshots cannot be rendered: .*the build broke/)
  assert.deepEqual(clones(result), [])
  assert.ok(outDir && !existsSync(outDir))
})

test('screenshots the tool did not finish stop the run, with every problem listed, like screenshots given by directory', async () => {
  const result = await send([], { tool: (args) => { writeFileSync(join(args.at(-1), 'hero-zh.png'), shot('hero-zh.png')); return '' } })
  assert.equal(result.code, 1)
  assert.match(result.printed, /the screenshots JustSnapSiteShots rendered cannot be used/)
  assert.match(result.printed, /select-en\.png is missing/)
  assert.deepEqual(clones(result), [])
})

test('what the screenshots are rendered from must be committed: a change to the tool, the app\'s views or the package stops the run before the tool starts', async () => {
  for (const [path, text] of [['Sources/JustSnapSiteShots/main.swift', '// edited\n'], ['JustSnap/UI/ResultBox.swift', '// new, not added\n'], ['Package.swift', '// edited\n'], ['Package.resolved', '{}\n']]) {
    const root = justsnap()
    mkdirSync(dirname(join(root, path)), { recursive: true })
    writeFileSync(join(root, path), text)
    const result = await send([], { root, tool: writesShots('rendered') })
    assert.equal(result.code, 1, path)
    assert.match(result.printed, new RegExp(`${path.split('/')[0].replace('.', '\\.')}.* has uncommitted changes`), path)
    assert.deepEqual(result.calls.filter(([command]) => command === XCRUN), [], path)
    assert.deepEqual(clones(result), [], path)
  }
})

test('--title and --note describe a pull request that is not meant to be merged', async () => {
  const result = await send(['--shots', shotsDir({ 'paste-zh.png': shot('paste-zh.png', 'marked') }), '--title', 'Evidence run: do not merge', '--note', 'An evidence run of the asset command; it will not be merged.'])
  const [pr] = result.prs
  assert.equal(pr[pr.indexOf('--title') + 1], 'Evidence run: do not merge')
  assert.ok(pr[pr.indexOf('--body') + 1].startsWith('An evidence run of the asset command; it will not be merged.\n\nOpened by'))
})

test('a second run from the same commit on the same day takes the next free branch name', async () => {
  const site = website()
  const root = justsnap()
  const first = await send(['--shots', shotsDir({ 'paste-en.png': shot('paste-en.png', 'once') })], { site, root })
  const second = await send(['--shots', shotsDir({ 'paste-en.png': shot('paste-en.png', 'twice') })], { site, root })
  assert.equal(first.code + second.code, 0)
  const head = git(root, 'rev-parse', 'HEAD').slice(0, 7)
  assert.deepEqual(branches(site), [`assets/justsnap-20261125-${head}`, `assets/justsnap-20261125-${head}-2`, 'main'])
})

test('--base picks the branch of the website repository that the clone, the commit and the pull request start from', async () => {
  const result = await send(['--shots', shotsDir({ 'providers-en.png': shot('providers-en.png', 'retaken') }), '--base', 'trunk'], { site: website({ branch: 'trunk' }) })
  assert.equal(result.code, 0)
  const [pr] = result.prs
  assert.equal(pr[pr.indexOf('--base') + 1], 'trunk')
  assert.equal(git(result.site.bare, 'rev-list', '--count', `trunk..${pr[pr.indexOf('--head') + 1]}`), '1')
})

test('run as a command, it exits 1 on an option it does not know, and says so', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('../site-assets.mjs', import.meta.url)), '--frobnicate'], { encoding: 'utf8' })
  assert.equal(result.status, 1)
  assert.match(result.stderr, /unknown option --frobnicate/)
})

test('the real sips renders the derived SVG as a 192-pixel PNG with an alpha channel', { skip: process.platform !== 'darwin' && 'sips is on macOS only' }, () => {
  const work = dir('sips')
  writeFileSync(join(work, 'icon.svg'), deriveSiteIcon(APP_ICON))
  renderIconWithSips(join(work, 'icon.svg'), ICON_PNG_SIZE, join(work, 'icon.png'))
  const bytes = readFileSync(join(work, 'icon.png'))
  assert.deepEqual(pngSize(bytes), { width: 192, height: 192 })
  assert.equal(bytes[25], 6, 'the PNG has a colour type with an alpha channel (RGBA): the tile\'s corners are transparent')
})

// ---- the release script runs it, and it runs without the release

const RELEASE_SCRIPT = readFileSync(new URL('../release-macos.sh', import.meta.url), 'utf8')

/** The release script's last step, the one that opens the website's asset pull request, as a piece of shell of its own */
function releaseStep() {
  const rows = RELEASE_SCRIPT.split('\n')
  const done = rows.findIndex((row) => row.startsWith('echo "Formal macOS release artifacts verified in'))
  assert.ok(done > rows.indexOf('/bin/mv "$publish_staging" "$output_root"') && done > 0, 'the artifacts are moved into place and reported first')
  const start = rows.findIndex((row, i) => i > done && row.startsWith('# The website\'s screenshots and icon'))
  assert.ok(start > done, 'the step follows the report')
  return rows.slice(start).join('\n')
}

/**
 * Runs the step the way the script runs it (`set -euo pipefail`), with a `node` that records its arguments and exits as told.
 * The environment is the test runner's own, minus `CI` (a runner sets it to `true`, which is the case `ci: 'true'` sets on purpose).
 */
function runReleaseStep({ ci, nodeExit }) {
  const bin = dir('bin')
  const log = join(bin, 'node.log')
  writeFileSync(join(bin, 'node'), `#!/bin/bash\necho "$@" >> '${log}'\nexit ${nodeExit}\n`, { mode: 0o755 })
  const { CI: _runnerCi, ...inherited } = process.env
  const result = spawnSync('bash', ['-c', `set -euo pipefail\nproject_root=/the/project\noutput_root=/the/output\n${releaseStep()}\necho reached-the-end`], {
    encoding: 'utf8', env: { ...inherited, PATH: `${bin}:${process.env.PATH}`, ...(ci === undefined ? {} : { CI: ci }) }
  })
  return { ...result, nodeCalls: existsSync(log) ? readFileSync(log, 'utf8').split('\n').filter(Boolean) : [] }
}

test('the release script opens the website\'s asset pull request as its last step, once the artifacts are in place', () => {
  const run = runReleaseStep({ nodeExit: 0 })
  assert.equal(run.status, 0)
  assert.deepEqual(run.nodeCalls, ['/the/project/Scripts/site-assets.mjs'])
  // Not `stderr === ''`: a runner's own tools may print to stderr; what must not appear is the step's warning.
  assert.doesNotMatch(run.stderr, /WARNING/)
})

test('when that step fails, the release still ends well, and says the pull request is missing and how to open it alone', () => {
  const run = runReleaseStep({ nodeExit: 1 })
  assert.equal(run.status, 0)
  assert.ok(run.stdout.includes('reached-the-end'))
  assert.match(run.stderr, /WARNING: the release artifacts are in place in \/the\/output, but the website's asset pull request was not opened\. Run it alone: node Scripts\/site-assets\.mjs/)
})

test('on a CI runner the step does not run: a verification of the release there must not open a pull request', () => {
  const run = runReleaseStep({ ci: 'true', nodeExit: 0 })
  assert.equal(run.status, 0)
  assert.deepEqual(run.nodeCalls, [])
  assert.match(run.stdout, /Not opening the website's asset pull request from a CI runner/)
})

test('the release script is valid shell', () => {
  assert.equal(spawnSync('bash', ['-n', fileURLToPath(new URL('../release-macos.sh', import.meta.url))]).status, 0)
})

// Every process a run starts through `run` is recorded in `calls`: `git`, `gh`, and the screenshot tool when the run renders. A run
// that started anything else, the release script included, would add a command here. (The icon's `sips` is started by
// `renderIcon`, which these runs replace; the real one is the `sips` case above.)
test('the command runs alone: a run starts git, gh and the screenshot tool, and nothing of the release', async () => {
  const rendering = await send([], { tool: writesShots('rendered') })
  const given = await send(['--shots', shotsDir({ 'hero-zh.png': shot('hero-zh.png', 'retaken') })])
  assert.equal(rendering.code + given.code, 0)
  assert.equal(rendering.prs.length + given.prs.length, 2, 'both runs went all the way, to the pull request')
  const started = (result) => [...new Set(result.calls.map(([command]) => command))].sort()
  assert.deepEqual(started(rendering), [XCRUN, 'gh', 'git'])
  assert.deepEqual(started(given), ['gh', 'git'])
})
