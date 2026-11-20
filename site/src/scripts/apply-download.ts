// Applies a download state's view to the page in place (landing-page::REQ-002, failure A7): the hero's button and
// the link to every version beside its platform line, and the download area's line and buttons. The page as served
// is the list state, and a later state replaces an earlier one entirely, back to that page included.
//
// Every label is set as text, never parsed as markup (landing-page failure E1): only validated versions reach the
// labels, and this keeps it so whatever reaches them.
import type { DownloadLink, DownloadView } from '../download'

/** The served download icon, captured before the first change, so the buttons made later can have it too */
const iconOf = new WeakMap<Element, Node>()

function setLink(a: Element, link: DownloadLink): void {
  a.setAttribute('href', link.href)
  if (link.newTab) {
    a.setAttribute('target', '_blank')
    a.setAttribute('rel', 'noopener')
  } else {
    a.removeAttribute('target')
    a.removeAttribute('rel')
  }
}

/** A button's label, kept after its icon */
function setLabel(a: Element, label: string): void {
  for (const node of [...a.childNodes]) if (node.nodeName.toLowerCase() !== 'svg') node.remove()
  a.append(label)
}

export function applyView(doc: Document, view: DownloadView): void {
  const dl = doc.querySelector('.hero .dl')
  const heroButton = dl?.querySelector('a.btn')
  const meta = dl?.querySelector('.meta')
  const line = doc.querySelector('.dlbox .ver')
  const row = doc.querySelector('.dlbox .row')
  if (!heroButton || !meta || !line || !row) return

  setLink(heroButton, view.hero)
  setLabel(heroButton, view.hero.label)

  meta.querySelector('a.more')?.remove()
  if (view.every) {
    const a = doc.createElement('a')
    a.className = 'more'
    setLink(a, view.every)
    a.textContent = view.every.label
    meta.append(a)
  }

  line.textContent = view.section.line

  const served = row.querySelector('a.primary svg')
  if (!iconOf.has(row) && served) iconOf.set(row, served.cloneNode(true))
  const icon = iconOf.get(row)
  row.replaceChildren(
    ...view.section.buttons.map((b) => {
      const a = doc.createElement('a')
      a.className = b.kind === 'ghost' ? 'btn' : 'btn primary'
      if (b.kind === 'primary' && icon) a.append(icon.cloneNode(true))
      a.append(b.label)
      setLink(a, b)
      return a
    })
  )
}
