# JustSnap's landing page (`site/`)

An Astro static site in two languages: Chinese at `/`, English at `/en/`. What it must do is in
[the landing-page spec](../docs/specs/landing-page.md). It is a package of its own, with its own lockfile, outside
the app's Swift package. Only the Apple silicon package exists ([ADR-0004](../docs/adr/0004-distribute-one-apple-silicon-package.md)),
so the page offers one DMG, `JustSnap-<version>-mac-arm64.dmg`.

## Commands

```sh
cd site
pnpm install --frozen-lockfile
pnpm dev        # http://localhost:4321/
pnpm build      # the static site, into site/dist/
pnpm preview    # serve site/dist/
pnpm check      # astro check: the TypeScript of every .astro and .ts file
pnpm test       # unit tests and the built-site checks, on a fresh build
```

CI runs `pnpm check` and `pnpm test` in the `site-checks` job whenever a pull request changes something under
`site/` (`.github/ci/routing.json`).

## Where things are

- `src/pages/index.astro`, `src/pages/en/index.astro`: the two pages, the same sections in the same order.
- `src/layouts/Base.astro`: the head, the sticky header (brand, navigation, language toggle), the footer, and the
  page's one script.
- `src/components/`: one component per section (`Hero`, `Features`, `Download`, which also holds the install steps),
  and `Icon.astro`, the page's icons as inline SVG copied from Lucide. A new icon goes there, never a character or an
  emoji.
- `src/i18n/ui.ts`: every string of the page, in both languages. This dictionary is the site's own, separate from the
  app's. New copy goes here, in both languages.
- `src/styles/global.css`: the palette (light and dark, by the visitor's system appearance) and every rule of the page,
  interaction states included. Markup carries classes only.
- `src/releases.ts`: the two things the page reads in the visitor's browser, the R2 latest pointer and GitHub's
  releases for this repository, each answer validated before anything of it is used.
- `src/download.ts`: the download state the two reads decide (from R2, from GitHub, or the list), and what each state's
  buttons say and where they lead. The page is served in the list state, which leads to GitHub's release list. There is
  no pre-release state: a pre-release is never offered.
- `src/scripts/`: the features section's pinned showcase, whose step follows the scroll (`features.ts`), the language
  switch that keeps the current step and scroll position (`language-switch.ts`), and the download script that reads,
  decides and shows the state in place (`download.ts`, applying it with `apply-download.ts`).
- `src/shots.ts` and `public/shots/`: the screenshots, one set per language: the hero's and the six features', all
  1840×1035 (16:9), to be taken from the app in its light appearance over made-up content. Until they are, the files are one placeholder picture, and `pnpm build` refuses to build (`scripts/check-shots.mjs`: no two screenshots may be the same file), so a placeholder set is never published; `pnpm check` and `pnpm test` do not run that check.

## Tests

- Unit tests sit next to the modules they test (`src/**/*.test.ts`).
- `test/built-site.test.ts` checks the pages one fresh build produces: `test/build-site.ts` builds the site into a
  new directory once per test run, so the check never reads an old `dist/`. Its file header says what it cannot see
  (scrolling, layout across widths, the two appearances), which was measured in a headless browser when the page was
  written and is not tested. It does assert the numbers the spec fixes (a turn, the pin point, the 760px breakpoint)
  from the built stylesheet. `test/features-sync.test.ts` checks which measurements turn the scroll into a step;
  `test/check-shots.test.ts` checks the screenshot check the production build runs.
- `test/apply-download.test.ts` and `test/init-download.test.ts` apply the download states to that build's pages, the
  second through the page's script with a fake network. The reads' tests answer through an injected fetch too, so no
  test reaches the network; `test/fixtures/` holds the answers they use: the pointer as agentshed's mirror script writes it (JustSnap's own writer is not built yet),
  and a real-shaped releases answer from GitHub.
- `test/language-switch.test.ts` moves a note between the two pages through a fake session storage.

## Deploying (Cloudflare Pages)

The page is served by Cloudflare Pages at `justsnap.aloongplanet.com`; the project is defined by the `justsnap` entry in the infra
repository's `stacks/apps/landing-pages.tf`, and exists once the Terraform apps workflow has applied that entry. The Pages project needs:

| Setting | Value |
|---|---|
| Root directory | `site` |
| Build command | `pnpm install --frozen-lockfile && pnpm build` |
| Build output directory | `dist` (relative to the root directory) |
| Build watch path | `site/*`: a push that changes nothing under `site/` is skipped. The build reads nothing outside `site/`; a change that makes it depend on a file elsewhere must widen this path |
| `NODE_VERSION` | 22.23.3. Astro 7 refuses a Node older than 22.22.0; the test dependencies (jsdom's) ask for at least 22.22.2 |
| `PNPM_VERSION` | 9.12.3, so the build runs the site's pnpm rather than the build image's default |

The DMGs and the `latest.json` pointer the page reads are served from `dl.justsnap.aloongplanet.com` (an R2 bucket),
written by the release mirror, not by this site. Pending: JustSnap's mirror script and `latest.json` writer are not built yet, so until they are the page falls back to GitHub Releases.
