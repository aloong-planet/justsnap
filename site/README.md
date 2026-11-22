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
pnpm shots      # regenerate public/shots/ (macOS with Swift only): see "Screenshots" below
```

CI runs `pnpm check` and `pnpm test` in the `site-checks` job whenever a pull request changes something under
`site/` (`.github/ci/routing.json`).

## Where things are

- `src/pages/index.astro`, `src/pages/en/index.astro`: the two pages, the same sections in the same order.
- `src/layouts/Base.astro`: the head, the sticky header (the breadcrumb back to the aloong planet homepage, ending on
  the brand; navigation; language toggle), the footer, and the page's one script.
- `src/components/`: one component per section (`Hero`, `Features`, `Download`, which also holds the install steps),
  and `Icon.astro`, the page's interface icons as inline SVG copied from Lucide. A new icon goes there, never a
  character or an emoji. The app icon in the header is the one exception: it is an image, set in `Base.astro`.
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
  1840×1035 (16:9), light appearance, over made-up content. How they are made is under "Screenshots" below.

## Screenshots

The fourteen files in `public/shots/` (`<hero|select|extract|translate|paste|history|providers>-<zh|en>.png`) are
renders of the app's own SwiftUI views over invented content, not captures of a running app or of anyone's screen.
`pnpm shots` (from `site/`) rebuilds them: it runs `swift run --package-path .. JustSnapSiteShots public/shots`
(`Sources/JustSnapSiteShots/` in the Swift package) and then `scripts/check-shots.mjs`. Run it after a change to the
views a screenshot shows, or to the fixture text in `Sources/JustSnapSiteShots/ShotCopy.swift`, and commit the result.

- The tool shows no window and activates nothing: each scene is laid out in a hosting view that is never put on the
  display and painted into a bitmap, in a process with no Dock presence. It captures no screen and reads no history,
  settings, Keychain or screenshots; the "screen being captured" is drawn in the tool, and the provider key is a
  placeholder string.
- Real views: the capture toolbar, the result box (streamed Markdown, translation, the paste box), the menu bar
  panel, and the management window's history and provider pages. Redrawn in the tool because they need a live display
  or are private to the app: the freeze overlay (dim, selection border and handles, with the app's own constants), the
  window frames and the menu bar around the views.
- Each language is rendered by its own process, started with that language's region and the UTC time zone, so
  dates and number formats follow the language and do not depend on the Mac it runs on. The output is byte-for-byte
  the same on every run. The selection and handle color is the system accent color, which is the one setting of the
  Mac that does reach the pictures: render with the default blue.
- All shots are drawn at 951×535 points into 1840×1035 pixels, so text has the same size in every one of them.

## Tests

- Unit tests sit next to the modules they test (`src/**/*.test.ts`).
- `test/built-site.test.ts` checks the pages one fresh build produces: `test/build-site.ts` builds the site into a
  new directory once per test run, so the check never reads an old `dist/`. Its file header says what it cannot see
  (scrolling, layout across widths, the two appearances), which was measured in a headless browser when the page was
  written and is not tested. It does assert the numbers the spec fixes (a turn, the pin point, the 760px breakpoint)
  from the built stylesheet. `test/features-sync.test.ts` checks which measurements turn the scroll into a step;
  `test/check-shots.test.ts` checks the screenshot check the production build runs.
- `test/shots.test.ts` checks the fourteen screenshots: every one exists, each is 1840×1035 by its PNG header, and no
  two are the same file. What they show is checked by looking at them.
- `test/apply-download.test.ts` and `test/init-download.test.ts` apply the download states to that build's pages, the
  second through the page's script with a fake network. The reads' tests answer through an injected fetch too, so no
  test reaches the network; `test/fixtures/` holds the answers they use: the pointer as agentshed's mirror script writes it, which is the shape JustSnap's own `Scripts/mirror-release.mjs` writes,
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
written by the release mirror (`Scripts/mirror-release.mjs`, run by `.github/workflows/mirror-release.yml` when a formal release is published), not by this site. Until a formal release has been mirrored there is no pointer, and the page falls back to GitHub Releases.
