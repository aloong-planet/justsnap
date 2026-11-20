// This repository's routing rules (.github/ci/routing.json). Written for the repository from the github-ops
// skill's template; ci-routing.test.mjs beside it tests the fixed behaviour and is not edited.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { classifyPath, readConfig } from './ci-scope.mjs'

const config = readConfig()

test('each pattern of routing.json routes a real path to the scopes written here', () => {
  // [a tracked path, the scopes it must select]. Take each path from the repository's tracked tree, and write
  // the scopes as literals: computing them from routing.json would only repeat it.
  const cases = [
    ['AGENTS.md', []],
    ['CODEX.md', []],
    ['docs/CONTEXT.md', []],
    ['docs/adr/0018-merge-prs-without-executable-changes-once-ci-passes.md', []],
    ['docs/agents/issue-tracker.md', []],
    ['docs/ops/macos-signing.md', []],
    ['docs/postmortems/result-box-test-reads.md', []],
    ['docs/prototypes/capture-overlay/prototype-result-box.html', []],
    ['docs/specs/v1-core.md', []],
    ['Sources/JustSnapApp/JustSnapApplicationModel.swift', ['app']],
    ['JustSnap/UI/CaptureOperationToolbar.swift', ['app']],
    ['Tests/JustSnapUITests/CaptureResultBoxTests.swift', ['app']],
    ['Scripts/test-local-regression.sh', ['app']],
    ['Distribution/Info.plist', ['app']],
    ['Package.swift', ['app']],
    ['Package.resolved', ['app']],
    // No rule matches: every scope runs
    ['capabilities.toml', ['app']],
    ['docs/unlisted.md', ['app']]
  ]
  const hit = new Set()
  for (const [path, expected] of cases) {
    const { select, pattern } = classifyPath(path, config)
    assert.deepEqual(select, expected, path)
    if (pattern !== null) hit.add(pattern)
  }
  // Every pattern needs a case of its own; a pattern no case reaches is a rule nothing here checks
  const patterns = config.rules.flatMap((rule) => rule.patterns.map(({ pattern }) => pattern))
  assert.ok(patterns.length > 0)
  assert.deepEqual(patterns.filter((pattern) => !hit.has(pattern)), [])
})
