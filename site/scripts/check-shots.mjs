// The production build's screenshot check (landing-page::REQ-005/AC-04): fails the build while any two screenshots are
// the same file. A placeholder set is one picture repeated for every step and both languages, so it cannot pass;
// real screenshots, which each show a different view, do.
import { createHash } from 'node:crypto'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

/** The groups of screenshot names (each of two or more) whose files have the same content */
export function duplicateShots(dir) {
  const names = readdirSync(dir).filter((n) => n.endsWith('.png')).sort()
  if (names.length === 0) throw new Error(`no screenshots in ${dir}`)
  const byHash = new Map()
  for (const name of names) {
    const hash = createHash('sha256').update(readFileSync(join(dir, name))).digest('hex')
    byHash.set(hash, [...(byHash.get(hash) ?? []), name])
  }
  return [...byHash.values()].filter((group) => group.length > 1)
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const dir = fileURLToPath(new URL('../public/shots', import.meta.url))
  const groups = duplicateShots(dir)
  if (groups.length > 0) {
    console.error('The screenshots are not real: these files are identical, so they are placeholders.')
    for (const group of groups) console.error(`  ${group.join(', ')}`)
    console.error('Replace them with screenshots of the app before building for production (see site/README.md).')
    process.exit(1)
  }
}
