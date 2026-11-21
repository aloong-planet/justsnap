// The release mirror (release-mirror::REQ-001 to REQ-005, CON-001): a formal release's DMG and appcast go to R2 and
// the latest pointer is written last, only after the files it depends on are served and checked.
//
// mirrorRelease is driven against an in-memory model of the bucket standing in for R2 at the system boundary. The
// probe and the text reader answer from the same model by mapping the download host's URL to a key, so what the
// host "serves" is exactly what was uploaded unless a test tampers with it. The model records the order of the
// writes. awsBucket is tested for the aws-cli arguments it sends, httpProbe and httpText against a real HTTP server
// on localhost. The appcast fixture has the shape of Sparkle's generate_appcast output (the 2026-11 tool, signed
// with a throwaway key).
//
// Gaps: the pointer's shape is checked against the download page's reader only by hand, since the page is a package
// of its own. Nothing here touches R2, the download host or GitHub. The workflow's first real run is the first formal
// release; its text is checked in mirror-workflow.test.mjs. release-mirror::CON-002 (the built app's feed address is
// the fixed appcast address) is attested by the maintainer's release command (docs/ops/macos-signing.md): the mirror
// never opens the signed DMG, so no test here sees the address inside the app.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { createServer } from 'node:http'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import {
  APPCAST_KEY, DOWNLOAD_HOST, POINTER_KEY, awsBucket, checkAppcast, compareVersions, dmgKey, dmgName, formalVersion,
  httpProbe, httpText, main, mirrorRelease, releaseFiles
} from '../mirror-release.mjs'

const HOST = DOWNLOAD_HOST
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex')
const SIGNATURE = 'p83fmN26Uhw2QptcEJaSo6GtWPj62iO1HpSfMuvK7wacDdqu57mN/sBsbxFe9A/YhGQkm1v9Mqm9+cR3pXoqAw=='

/** An appcast shaped like Sparkle's generate_appcast output, for `version` and a DMG of `length` bytes */
function appcast({ version = '0.1.8', length, url = `${HOST}/releases/v${version}/JustSnap-${version}-mac-arm64.dmg`, shortVersion = version, signature = SIGNATURE, extraItem = '' }) {
  const signed = signature === null ? '' : ` sparkle:edSignature="${signature}"`
  return `<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>JustSnap</title>
        <item>
            <title>${version}</title>
            <pubDate>Sat, 21 Nov 2026 17:41:09 +0800</pubDate>
            <sparkle:version>9</sparkle:version>
            <sparkle:shortVersionString>${shortVersion}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.4</sparkle:minimumSystemVersion>
            <enclosure url="${url}" length="${length}" type="application/octet-stream"${signed}/>
        </item>${extraItem}
    </channel>
</rss>`
}

/** A directory as the workflow leaves it: the release's DMG and appcast (and whatever else `extra` names) */
function releaseDir(t, { version = '0.1.8', dmg = `bytes of the ${version} DMG`, appcastOptions = {}, extra = [], skip = [] } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mirror-release-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const files = {
    [dmgName(version)]: dmg,
    'appcast-arm64.xml': appcast({ version, length: Buffer.byteLength(dmg), ...appcastOptions })
  }
  for (const name of extra) files[name] = 'not part of the mirror'
  for (const [name, content] of Object.entries(files)) if (!skip.includes(name)) writeFileSync(join(dir, name), content)
  return { dir, dmg, dmgBytes: Buffer.from(dmg) }
}

/**
 * A model of the R2 bucket and the download host in front of it: objects by key, the keys in the order they were
 * written, and hooks to make the host serve other bytes, serve late, or an upload fail.
 */
function modelOf({ existing = {}, serveWrong = false, notServedFor = 0, failPutOf = null } = {}) {
  const objects = new Map(Object.entries(existing).map(([key, text]) => [key, { bytes: Buffer.from(text) }]))
  const order = []
  const sleeps = []
  let unserved = notServedFor
  const keyOf = (url) => url.slice(HOST.length + 1)
  return {
    objects,
    order,
    sleeps,
    bucket: {
      put: (key, file, headers) => {
        if (key === failPutOf) throw new Error(`aws s3 cp failed (exit 1): ${key} interrupted`)
        order.push(key)
        objects.set(key, { bytes: readFileSync(file), ...headers })
      },
      putText: (key, text, headers) => {
        if (key === failPutOf) throw new Error(`aws s3 cp failed (exit 1): ${key} interrupted`)
        order.push(key)
        objects.set(key, { bytes: Buffer.from(text), ...headers })
      }
    },
    probe: async (url) => {
      const object = objects.get(keyOf(url))
      if (!object || unserved > 0) {
        unserved -= 1
        return { status: 404 }
      }
      const bytes = serveWrong ? Buffer.concat([object.bytes, Buffer.from('x')]) : object.bytes
      return { status: 200, size: bytes.length, sha256: sha256(bytes) }
    },
    readText: async (url) => {
      const object = objects.get(keyOf(url))
      return object ? { status: 200, text: object.bytes.toString('utf8') } : { status: 404 }
    },
    sleep: async (ms) => {
      sleeps.push(ms)
    }
  }
}

const run = (model, release, tag = 'v0.1.8') =>
  mirrorRelease({ tag, dir: release.dir, bucket: model.bucket, probe: model.probe, readText: model.readText, sleep: model.sleep, log: () => {} })

const pointerOf = (version, size) => ({
  version,
  files: [{ name: `JustSnap-${version}-mac-arm64.dmg`, arch: 'arm64', size, url: `${HOST}/releases/v${version}/JustSnap-${version}-mac-arm64.dmg` }]
})

// The host and the layout are written out here, not taken from the script: the appcast address is baked into every
// installed app and the page accepts only this host (release-mirror::CON-002, REQ-002/AC-03)
test('the download host and the object layout are the ones the apps and the page read', () => {
  assert.equal(DOWNLOAD_HOST, 'https://dl.justsnap.aloongplanet.com')
  assert.equal(`${DOWNLOAD_HOST}/${APPCAST_KEY}`, 'https://dl.justsnap.aloongplanet.com/appcast/appcast-arm64.xml')
  assert.equal(`${DOWNLOAD_HOST}/${dmgKey('0.1.8')}`, 'https://dl.justsnap.aloongplanet.com/releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg')
  assert.equal(POINTER_KEY, 'latest.json')
})

// ---- REQ-001: which releases are mirrored

test('a formal tag is v and three integers; any suffix or other shape is refused', () => {
  assert.equal(formalVersion('v0.1.8'), '0.1.8')
  assert.equal(formalVersion('v10.20.30'), '10.20.30')
  for (const tag of ['v0.1.8-beta.1', 'v0.1.8-rc1', '0.1.8', 'v1.2', 'v1.2.3.4', 'V1.2.3', 'v1.2.3 ', '']) {
    assert.throws(() => formalVersion(tag), /not a formal release tag/, tag)
  }
})

test('versions compare as integers, not as text: 0.10.0 is higher than 0.9.0', () => {
  assert.ok(compareVersions('0.10.0', '0.9.0') > 0)
  assert.ok(compareVersions('0.9.0', '0.10.0') < 0)
  assert.ok(compareVersions('1.0.0', '0.99.99') > 0)
  assert.equal(compareVersions('0.1.8', '0.1.8'), 0)
})

test('the DMG and the appcast are the release; other files in the directory are not mirrored', async (t) => {
  const release = releaseDir(t, { extra: ['notes.md', 'JustSnap-0.1.8-mac-arm64.dmg.sha256'] })
  const model = modelOf()
  await run(model, release)
  assert.deepEqual([...model.objects.keys()].sort(), [APPCAST_KEY, dmgKey('0.1.8'), POINTER_KEY].sort())
})

test('a release without its DMG, or without its appcast, writes nothing and fails', async (t) => {
  for (const skip of [['JustSnap-0.1.8-mac-arm64.dmg'], ['appcast-arm64.xml']]) {
    const release = releaseDir(t, { skip })
    const model = modelOf()
    await assert.rejects(run(model, release), /does not hold/)
    assert.deepEqual(model.order, [])
  }
})

test('a DMG of another version in the directory is not the release', async (t) => {
  const release = releaseDir(t, { version: '0.1.7' })
  const model = modelOf()
  await assert.rejects(run(model, release, 'v0.1.8'), /does not hold/)
  assert.deepEqual(model.order, [])
})

test('a pre-release tag writes nothing and fails', async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  await assert.rejects(run(model, release, 'v0.1.8-beta.1'), /not a formal release tag/)
  assert.deepEqual(model.order, [])
})

// ---- REQ-002, REQ-003/AC-03: the layout, the headers, the order

test('the DMG, the appcast and then the pointer are written, at the layout the page and the apps read, with their caching', async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  await run(model, release)

  assert.deepEqual(model.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg', 'appcast/appcast-arm64.xml', 'latest.json'])
  const dmg = model.objects.get('releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg')
  assert.deepEqual(dmg.bytes, release.dmgBytes)
  assert.equal(dmg.cacheControl, 'public, max-age=31536000, immutable')
  assert.equal(dmg.contentType, 'application/x-apple-diskimage')
  const appcastObject = model.objects.get('appcast/appcast-arm64.xml')
  assert.equal(appcastObject.bytes.toString('utf8'), readFileSync(join(release.dir, 'appcast-arm64.xml'), 'utf8'))
  assert.equal(appcastObject.cacheControl, 'public, max-age=300')
  const pointer = model.objects.get('latest.json')
  assert.equal(pointer.cacheControl, 'public, max-age=300')
  assert.equal(pointer.contentType, 'application/json')
  assert.deepEqual(JSON.parse(pointer.bytes.toString('utf8')), pointerOf('0.1.8', release.dmgBytes.length))
})

test("running the same version again leaves the bucket as the first successful run did", async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  await run(model, release)
  const first = new Map([...model.objects].map(([key, o]) => [key, o.bytes.toString('hex')]))
  await run(model, release)
  const second = new Map([...model.objects].map(([key, o]) => [key, o.bytes.toString('hex')]))
  assert.deepEqual(second, first)
})

// ---- REQ-003/AC-01: the DMG is read back before anything points at it

test('a DMG the host serves with other bytes stops the run before the appcast and the pointer', async (t) => {
  const release = releaseDir(t)
  const model = modelOf({ serveWrong: true })
  await assert.rejects(run(model, release), /other bytes/)
  assert.deepEqual(model.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg'])
})

test('a DMG the host serves with the right size but another content also stops the run', async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  const honest = model.probe
  model.probe = async (url) => {
    const answer = await honest(url)
    return answer.status === 200 ? { ...answer, sha256: sha256('same size, other content') } : answer
  }
  await assert.rejects(run(model, release), /other bytes/)
  assert.deepEqual(model.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg'])
})

test('a DMG the host does not serve at once is read again, ten seconds apart, up to three reads', async (t) => {
  const release = releaseDir(t)
  const late = modelOf({ notServedFor: 2 })
  await run(late, release)
  assert.deepEqual(late.sleeps, [10_000, 10_000])
  assert.deepEqual(late.order.at(-1), 'latest.json')

  const never = modelOf({ notServedFor: 3 })
  await assert.rejects(run(never, release), /is not served: HTTP 404/)
  assert.deepEqual(never.sleeps, [10_000, 10_000])
  assert.deepEqual(never.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg'])
})

// ---- REQ-003/AC-02: the appcast is checked against the release before anything is written

test('an appcast shaped like Sparkle writes it passes the check', () => {
  assert.doesNotThrow(() => checkAppcast(appcast({ length: 1234 }), { version: '0.1.8', host: HOST, dmgSize: 1234 }))
})

test('an appcast that does not describe this release is refused, whichever way it differs', () => {
  const check = (options, message) =>
    assert.throws(() => checkAppcast(appcast({ length: 1234, ...options }), { version: '0.1.8', host: HOST, dmgSize: 1234 }), message)
  check({ url: 'https://github.com/aloong-planet/justsnap/releases/download/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg' }, /enclosure is/)
  check({ url: `${HOST}/releases/v0.1.7/JustSnap-0.1.7-mac-arm64.dmg` }, /enclosure is/)
  check({ url: `${HOST}/releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg?x=1` }, /enclosure is/)
  check({ length: 1235 }, /length is 1235/)
  check({ shortVersion: '0.1.7' }, /version is 0\.1\.7/)
  check({ signature: null }, /no EdDSA signature/)
  check({ signature: '' }, /no EdDSA signature/)
  check({ extraItem: `<item><enclosure url="${HOST}/releases/v0.1.7/JustSnap-0.1.7-mac-arm64.dmg" length="1" sparkle:edSignature="x"/></item>` }, /2 enclosures/)
  assert.throws(() => checkAppcast('<rss></rss>', { version: '0.1.8', host: HOST, dmgSize: 1234 }), /0 enclosures/)
})

test('an appcast that does not describe the release is found before anything is uploaded, the DMG included', async (t) => {
  const release = releaseDir(t, { appcastOptions: { shortVersion: '0.1.7' } })
  const model = modelOf()
  await assert.rejects(run(model, release), /version is 0\.1\.7/)
  assert.deepEqual(model.order, [])
})

// ---- REQ-004: the pointer does not move back

test('a pointer that already names a higher version stops the run before anything is written', async (t) => {
  const release = releaseDir(t)
  const model = modelOf({ existing: { 'latest.json': JSON.stringify(pointerOf('0.2.0', 1)) } })
  await assert.rejects(run(model, release), /0\.2\.0, higher than 0\.1\.8/)
  assert.deepEqual(model.order, [])
})

test('versions compare as integers when the pointer is checked: 0.9.0 does not block 0.10.0', async (t) => {
  const release = releaseDir(t, { version: '0.10.0' })
  const model = modelOf({ existing: { 'latest.json': JSON.stringify(pointerOf('0.9.0', 1)) } })
  await run(model, release, 'v0.10.0')
  assert.equal(JSON.parse(model.objects.get('latest.json').bytes.toString('utf8')).version, '0.10.0')
})

test('a pointer at the same or a lower version, or one that is absent or cannot be read, does not stop the run', async (t) => {
  const release = releaseDir(t)
  const existing = {
    same: JSON.stringify(pointerOf('0.1.8', 1)),
    lower: JSON.stringify(pointerOf('0.1.7', 1)),
    garbage: '<html>not json</html>',
    noVersion: '{}',
    badVersion: JSON.stringify({ version: '9.9.9-beta.1' })
  }
  for (const [name, text] of [['absent', null], ...Object.entries(existing)]) {
    const model = modelOf({ existing: text === null ? {} : { 'latest.json': text } })
    await run(model, release)
    assert.equal(JSON.parse(model.objects.get('latest.json').bytes.toString('utf8')).version, '0.1.8', name)
  }
  const unreadable = modelOf()
  unreadable.readText = async () => {
    throw new Error('network down')
  }
  await run(unreadable, release)
  assert.equal(unreadable.order.at(-1), 'latest.json')
})

// ---- REQ-005, A1, A7: a failed step ends the run and nothing later is written

test('a failed DMG upload writes nothing else; a failed appcast upload leaves the pointer alone', async (t) => {
  const release = releaseDir(t)
  const dmgFails = modelOf({ failPutOf: 'releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg' })
  await assert.rejects(run(dmgFails, release), /interrupted/)
  assert.deepEqual(dmgFails.order, [])

  const appcastFails = modelOf({ failPutOf: 'appcast/appcast-arm64.xml' })
  await assert.rejects(run(appcastFails, release), /interrupted/)
  assert.deepEqual(appcastFails.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg'])
  assert.equal(appcastFails.objects.has('latest.json'), false)
})

test('after a failed pointer write, running again finishes the release', async (t) => {
  const release = releaseDir(t)
  const model = modelOf({ failPutOf: 'latest.json' })
  await assert.rejects(run(model, release), /interrupted/)
  assert.deepEqual(model.order, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg', 'appcast/appcast-arm64.xml'])
  const retry = modelOf({ existing: Object.fromEntries([...model.objects].map(([key, o]) => [key, o.bytes.toString('utf8')])) })
  await run(retry, release)
  assert.equal(JSON.parse(retry.objects.get('latest.json').bytes.toString('utf8')).version, '0.1.8')
})

// ---- the real boundaries

test('aws-cli is told R2 as the endpoint, the key, the caching and the content type, and the pointer goes through a temporary file that is removed', () => {
  const calls = []
  const files = []
  const bucket = awsBucket({
    bucket: 'justsnap-releases',
    endpoint: 'https://account.r2.cloudflarestorage.com',
    run: (args) => {
      calls.push(args)
      if (args[2] !== '/the/dmg') files.push([args[2], readFileSync(args[2], 'utf8')])
    }
  })
  bucket.put('releases/v0.1.8/x.dmg', '/the/dmg', { cacheControl: 'public, max-age=1', contentType: 'application/x-apple-diskimage' })
  bucket.putText('latest.json', '{"a":1}\n', { cacheControl: 'public, max-age=300', contentType: 'application/json' })

  assert.deepEqual(calls[0], ['s3', 'cp', '/the/dmg', 's3://justsnap-releases/releases/v0.1.8/x.dmg', '--endpoint-url',
    'https://account.r2.cloudflarestorage.com', '--region', 'auto', '--cache-control', 'public, max-age=1',
    '--content-type', 'application/x-apple-diskimage', '--only-show-errors'])
  assert.deepEqual(calls[1].slice(3, 4), ['s3://justsnap-releases/latest.json'])
  assert.deepEqual(files.map(([, content]) => content), ['{"a":1}\n'])
  assert.equal(existsSync(files[0][0]), false)
})

test('the probe reports the size and sha256 of what a server sends, and the status when it is not a 200', async (t) => {
  const body = Buffer.from('the served DMG')
  const server = createServer((req, res) => {
    if (req.url === '/dmg') res.end(body)
    else if (req.url === '/latest.json') res.end('{"version":"0.1.8"}')
    else {
      res.statusCode = 404
      res.end('missing')
    }
  })
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  t.after(() => server.close())
  const base = `http://127.0.0.1:${server.address().port}`

  assert.deepEqual(await httpProbe()(`${base}/dmg`), { status: 200, size: body.length, sha256: sha256(body) })
  assert.deepEqual(await httpProbe()(`${base}/none`), { status: 404 })
  assert.deepEqual(await httpText()(`${base}/latest.json`), { status: 200, text: '{"version":"0.1.8"}' })
  assert.deepEqual(await httpText()(`${base}/none`), { status: 404 })
})

// ---- the command (CON-001)

const ENV = { R2_ACCOUNT_ID: 'account', R2_BUCKET: 'justsnap-releases', AWS_ACCESS_KEY_ID: 'id', AWS_SECRET_ACCESS_KEY: 'secret' }

test('a missing R2 setting fails the run, naming it, before anything is written', async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  const calls = []
  const deps = { run: (args) => calls.push(args), probe: model.probe, readText: model.readText, sleep: model.sleep }
  for (const name of Object.keys(ENV)) {
    await assert.rejects(main(['v0.1.8', release.dir], { ...ENV, [name]: '' }, deps), new RegExp(`${name} is not set`))
  }
  await assert.rejects(main([], ENV, deps), /usage/)
  assert.deepEqual(calls, [])
})

test('the command mirrors a release through aws-cli to the bucket named by the environment', async (t) => {
  const release = releaseDir(t)
  const model = modelOf()
  const keys = []
  const deps = {
    // aws-cli stands for R2: what it is told to copy is what the host then serves
    run: (args) => {
      const key = args[3].slice('s3://justsnap-releases/'.length)
      model.bucket.put(key, args[2], {})
      keys.push(key)
      assert.equal(args[5], 'https://account.r2.cloudflarestorage.com')
    },
    probe: model.probe,
    readText: model.readText,
    sleep: model.sleep
  }
  await main(['v0.1.8', release.dir], ENV, deps)
  assert.deepEqual(keys, ['releases/v0.1.8/JustSnap-0.1.8-mac-arm64.dmg', 'appcast/appcast-arm64.xml', 'latest.json'])
})
