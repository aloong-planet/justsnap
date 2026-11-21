#!/usr/bin/env node
// The release mirror (release-mirror::REQ-001 to REQ-005): a formal release's DMG and Sparkle appcast are copied
// from the GitHub Release to the R2 bucket behind the download host, and the latest pointer the download page
// reads is rewritten last.
//
//   node Scripts/mirror-release.mjs <tag> <directory holding the release's DMG and appcast>
//
// Environment: R2_ACCOUNT_ID, R2_BUCKET, and the aws-cli credentials AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
// (the workflow maps them from the R2 secrets). Nothing is written to R2 unless every check on the local files
// has passed; each file is made visible only after the files it depends on are served and checked.
import { spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'
import { fileURLToPath } from 'node:url'

/** The download host. The appcast's public address is baked into every installed build, so it is not configurable */
export const DOWNLOAD_HOST = 'https://dl.justsnap.aloongplanet.com'

const FORMAL_TAG = /^v(\d+\.\d+\.\d+)$/
const READS = 3
const PAUSE_MS = 10_000

export const dmgName = (version) => `JustSnap-${version}-mac-arm64.dmg`
export const APPCAST_NAME = 'appcast-arm64.xml'
export const dmgKey = (version) => `releases/v${version}/${dmgName(version)}`
export const APPCAST_KEY = `appcast/${APPCAST_NAME}`
export const POINTER_KEY = 'latest.json'

/** The version of a formal tag (`v` and three integers, no suffix); anything else is refused (REQ-001/AC-02) */
export function formalVersion(tag) {
  const match = FORMAL_TAG.exec(tag)
  if (!match) throw new Error(`${tag} is not a formal release tag (v<major>.<minor>.<patch>); only formal releases are mirrored`)
  return match[1]
}

/** Negative, zero or positive as version `a` is lower than, equal to or higher than `b`; the parts compare as integers */
export function compareVersions(a, b) {
  const [x, y] = [a, b].map((v) => v.split('.').map(Number))
  for (let i = 0; i < 3; i += 1) if (x[i] !== y[i]) return x[i] - y[i]
  return 0
}

/**
 * The release's two files in `dir`: the DMG and the appcast. Other files are ignored (not mirrored); either one
 * missing is an error (REQ-001/AC-03).
 */
export function releaseFiles(dir, version) {
  const present = new Set(readdirSync(dir))
  const missing = [dmgName(version), APPCAST_NAME].filter((name) => !present.has(name))
  if (missing.length > 0) throw new Error(`${dir} does not hold ${missing.join(' and ')}`)
  const dmg = join(dir, dmgName(version))
  return { dmg, dmgSize: statSync(dmg).size, appcast: join(dir, APPCAST_NAME) }
}

/** The value of attribute `name` on an XML start tag's text, or undefined */
function attribute(tag, name) {
  const match = new RegExp(`\\s${name.replace(':', '\\:')}="([^"]*)"`).exec(tag)
  return match?.[1]
}

/**
 * Checks Sparkle's appcast against the release before it is written (REQ-003/AC-02): one enclosure, at the DMG's
 * address on the download host, of the DMG's size, for this version, carrying an EdDSA signature.
 */
export function checkAppcast(xml, { version, host, dmgSize }) {
  const enclosures = xml.match(/<enclosure\b[^>]*>/g) ?? []
  if (enclosures.length !== 1) throw new Error(`the appcast holds ${enclosures.length} enclosures, not one`)
  const [enclosure] = enclosures
  const expectedUrl = `${host}/${dmgKey(version)}`
  if (attribute(enclosure, 'url') !== expectedUrl) {
    throw new Error(`the appcast's enclosure is ${attribute(enclosure, 'url')}, not ${expectedUrl}`)
  }
  if (attribute(enclosure, 'length') !== String(dmgSize)) {
    throw new Error(`the appcast's enclosure length is ${attribute(enclosure, 'length')}, not the DMG's ${dmgSize} bytes`)
  }
  const shortVersions = [...xml.matchAll(/<sparkle:shortVersionString>([^<]*)<\/sparkle:shortVersionString>/g)].map((m) => m[1].trim())
  if (shortVersions.length !== 1 || shortVersions[0] !== version) {
    throw new Error(`the appcast's version is ${shortVersions.join(', ') || 'missing'}, not ${version}`)
  }
  if (!attribute(enclosure, 'sparkle:edSignature')) throw new Error('the appcast has no EdDSA signature')
}

/** The latest pointer's text for a version (the contract in landing-page's Implementation Decisions) */
export function pointerText({ version, host, dmgSize }) {
  const pointer = {
    version,
    files: [{ name: dmgName(version), arch: 'arm64', size: dmgSize, url: `${host}/${dmgKey(version)}` }]
  }
  return `${JSON.stringify(pointer, null, 2)}\n`
}

/** The download host's answer for a URL, read up to READS times while it is not served (failure A3) */
async function served(url, probe, sleep) {
  let failure
  for (let attempt = 1; attempt <= READS; attempt += 1) {
    if (attempt > 1) await sleep(PAUSE_MS)
    try {
      const answer = await probe(url)
      if (answer.status === 200) return answer
      failure = `HTTP ${answer.status}`
    } catch (error) {
      failure = error instanceof Error ? error.message : String(error)
    }
  }
  throw new Error(`${url} is not served: ${failure}`)
}

/** The version the download host's pointer names, or null when it names none that can be read (REQ-004/AC-02) */
async function currentVersion(host, readText) {
  try {
    const answer = await readText(`${host}/${POINTER_KEY}`)
    if (answer.status !== 200) return null
    const { version } = JSON.parse(answer.text)
    return typeof version === 'string' && /^\d+\.\d+\.\d+$/.test(version) ? version : null
  } catch {
    return null
  }
}

/**
 * Mirrors one formal release. Order (REQ-003/AC-03): local checks, the downgrade check, the DMG, its read-back
 * through the download host against the local file, the appcast, the pointer. The first failure stops the rest.
 */
export async function mirrorRelease({ tag, dir, host = DOWNLOAD_HOST, bucket, probe, readText, sleep, log = console.log }) {
  const version = formalVersion(tag)
  const { dmg, dmgSize, appcast } = releaseFiles(dir, version)
  const appcastXml = readFileSync(appcast, 'utf8')
  checkAppcast(appcastXml, { version, host, dmgSize })

  const current = await currentVersion(host, readText)
  if (current !== null && compareVersions(current, version) > 0) {
    throw new Error(`the download host's latest is ${current}, higher than ${version}; the pointer does not move back`)
  }

  bucket.put(dmgKey(version), dmg, { cacheControl: 'public, max-age=31536000, immutable', contentType: 'application/x-apple-diskimage' })
  log(`[mirror] uploaded ${dmgKey(version)}`)
  const answer = await served(`${host}/${dmgKey(version)}`, probe, sleep)
  const digest = createHash('sha256').update(readFileSync(dmg)).digest('hex')
  if (answer.size !== dmgSize || answer.sha256 !== digest) {
    throw new Error(`${host}/${dmgKey(version)} is served with other bytes than the release's DMG`)
  }
  log(`[mirror] the download host serves the release's DMG (${dmgSize} bytes, sha256 ${digest})`)

  bucket.put(APPCAST_KEY, appcast, { cacheControl: 'public, max-age=300', contentType: 'application/xml' })
  log(`[mirror] uploaded ${APPCAST_KEY}`)
  bucket.putText(POINTER_KEY, pointerText({ version, host, dmgSize }), { cacheControl: 'public, max-age=300', contentType: 'application/json' })
  log(`[mirror] ${POINTER_KEY} now points at ${version}`)
}

/** The bucket through aws-cli on R2's S3 endpoint; `run` takes aws-cli's arguments and throws when it fails */
export function awsBucket({ bucket, endpoint, run }) {
  const copy = (file, key, { cacheControl, contentType }) =>
    run(['s3', 'cp', file, `s3://${bucket}/${key}`, '--endpoint-url', endpoint, '--region', 'auto',
      '--cache-control', cacheControl, '--content-type', contentType, '--only-show-errors'])
  return {
    put: (key, file, headers) => copy(file, key, headers),
    putText: (key, text, headers) => {
      const dir = mkdtempSync(join(tmpdir(), 'justsnap-mirror-'))
      try {
        const file = join(dir, 'object')
        writeFileSync(file, text)
        copy(file, key, headers)
      } finally {
        rmSync(dir, { recursive: true, force: true })
      }
    }
  }
}

/** A public read of a URL: its status, and for a 200 the size and sha256 of the body, hashed as it streams */
export function httpProbe(fetchUrl = fetch) {
  return async (url) => {
    const response = await fetchUrl(url)
    if (response.status !== 200) {
      await response.body?.cancel()
      return { status: response.status }
    }
    const hash = createHash('sha256')
    let size = 0
    for await (const chunk of response.body) {
      hash.update(chunk)
      size += chunk.length
    }
    return { status: 200, size, sha256: hash.digest('hex') }
  }
}

/** A public read of a small text file: its status and, for a 200, its text */
export function httpText(fetchUrl = fetch) {
  return async (url) => {
    const response = await fetchUrl(url)
    return response.status === 200 ? { status: 200, text: await response.text() } : { status: response.status }
  }
}

const USAGE = 'usage: node Scripts/mirror-release.mjs <tag> <directory>'

export async function main(argv, env, deps) {
  const [tag, dir] = argv
  if (!tag || !dir) throw new Error(USAGE)
  // Fails rather than skips: a release without its mirror is a failed run (release-mirror::CON-001)
  for (const name of ['R2_ACCOUNT_ID', 'R2_BUCKET', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']) {
    if (!env[name]) throw new Error(`${name} is not set`)
  }
  const bucket = awsBucket({ bucket: env.R2_BUCKET, endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`, run: deps.run })
  await mirrorRelease({ tag, dir, bucket, probe: deps.probe, readText: deps.readText, sleep: deps.sleep })
}

/** aws with the given arguments; its output on failure, the credentials staying in the environment it reads */
function runAws(args) {
  const result = spawnSync('aws', args, { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 })
  if (result.error) throw new Error(`aws could not start: ${result.error.message}`)
  if (result.status !== 0) {
    const output = [result.stdout, result.stderr].filter(Boolean).join('\n').trim()
    throw new Error(`aws ${args.slice(0, 2).join(' ')} failed (exit ${result.status})${output ? `\n${output}` : ''}`)
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2), process.env, { run: runAws, probe: httpProbe(), readText: httpText(), sleep: delay }).catch((error) => {
    console.error(`[mirror] ${error instanceof Error ? error.message : String(error)}`)
    process.exitCode = 1
  })
}
