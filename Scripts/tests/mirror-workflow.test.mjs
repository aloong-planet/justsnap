// The mirror workflow's wiring (release-mirror::REQ-001/AC-01, AC-02, CON-001): when it runs, what it may do, and
// what it hands the script. The workflow's text is read, since running it needs GitHub and R2; the script's own
// behaviour is tested in mirror-release.test.mjs.
//
// Gap: nothing here runs the workflow. The first real run is the first formal release's publication.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const workflow = readFileSync(new URL('../../.github/workflows/mirror-release.yml', import.meta.url), 'utf8')
const lines = workflow.split('\n').filter((line) => !line.trimStart().startsWith('#'))
const text = lines.join('\n')

test('it runs when a release is published, or by hand for a tag, and on nothing else', () => {
  const on = text.slice(text.indexOf('\non:'), text.indexOf('\npermissions:'))
  assert.match(on, /release:\n\s+types: \[published\]/)
  assert.match(on, /workflow_dispatch:\n\s+inputs:\n\s+tag:/)
  assert.doesNotMatch(on, /push:|pull_request|schedule:/)
})

test('a draft, a pre-release or a tag with a suffix released on GitHub is not mirrored', () => {
  assert.match(text, /github\.event\.release\.prerelease == false/)
  assert.match(text, /github\.event\.release\.draft == false/)
  assert.match(text, /!contains\(github\.event\.release\.tag_name, '-'\)/)
})

test('a tag that is not a formal version fails the run before the release is downloaded', () => {
  const check = text.indexOf('^v[0-9]+\\.[0-9]+\\.[0-9]+$')
  assert.ok(check > 0)
  assert.ok(check < text.indexOf('gh release download'))
})

test('only the release\'s DMG and appcast are downloaded', () => {
  assert.match(text, /--pattern "JustSnap-\$\{version\}-mac-arm64\.dmg" --pattern appcast-arm64\.xml/)
})

test('the script gets the R2 settings from the repository secrets and has no other permission than reading the repository', () => {
  for (const [name, secret] of [['R2_ACCOUNT_ID', 'R2_ACCOUNT_ID'], ['R2_BUCKET', 'R2_BUCKET'], ['AWS_ACCESS_KEY_ID', 'R2_ACCESS_KEY_ID'], ['AWS_SECRET_ACCESS_KEY', 'R2_SECRET_ACCESS_KEY']]) {
    assert.match(text, new RegExp(`${name}: \\$\\{\\{ secrets\\.${secret} \\}\\}`))
  }
  assert.match(text, /permissions:\n\s+contents: read\n/)
  assert.match(text, /run: node Scripts\/mirror-release\.mjs "\$TAG" release/)
  // No step may skip when a secret is missing: that is a failed run (release-mirror::CON-001)
  assert.doesNotMatch(text, /secrets\.[A-Z0-9_]+ != ''/)
})

test('two runs never overlap and a running one is never cancelled', () => {
  assert.match(text, /concurrency:\n\s+group: mirror-release\n\s+cancel-in-progress: false/)
})

test('the tag reaches the shell only through the environment, never spliced into a command', () => {
  assert.match(text, /TAG: \$\{\{ github\.event\.release\.tag_name \|\| inputs\.tag \}\}/)
  // A step's `run:` part is whatever follows its `run:` key up to the next step
  const steps = text.split(/\n {6}- /).slice(1)
  const scripts = steps.map((step) => step.slice(step.search(/\brun:/))).filter((part) => part.startsWith('run:'))
  assert.equal(scripts.length, 3)
  for (const script of scripts) assert.doesNotMatch(script, /\$\{\{/)
})
