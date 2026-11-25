# Website assets

JustSnap's website lives in the aloong-planet-home repository (`apps/justsnap/`), which builds, checks and deploys it. It takes two things from the app: its screenshots and its icon. They change there only through a pull request that this repository's command opens (aloong-planet-home `app-sites::REQ-004/AC-01`); nobody edits them in that repository by hand.

## Sending new assets

```sh
node Scripts/site-assets.mjs                       # renders the screenshots and opens the pull request
node Scripts/site-assets.mjs --dry-run             # stops after the local commit in a temporary clone and prints what it would send
node Scripts/site-assets.mjs --shots <directory>   # sends fourteen screenshots that already exist instead of rendering them
```

The release script runs the command as its last step, once the release artifacts are in place and reported. If the command fails there, the script prints a warning, still ends well and leaves the artifacts as they are; run the command again by itself. On a CI runner (`CI=true`) the step does not run, so a verification of the release never opens a pull request.

Run it also when a screenshot's views, the fixture text in `Sources/JustSnapSiteShots/ShotCopy.swift` or `Distribution/AppIcon.svg` change, without waiting for a release.

It sends sixteen files under `apps/justsnap/public/` of the website repository: the fourteen screenshots `shots/<view>-<language>.png` (the views `hero`, `select`, `extract`, `translate`, `paste`, `history` and `providers`, each in `zh` and `en`) and the icon files `icon.svg` and `icon.png`. It clones the website repository into a temporary directory, writes them, checks that those are the only paths changed or staged, commits on the branch `assets/justsnap-<date>-<commit>` (with `-2`, `-3` and so on after it when the website repository already has that branch), pushes it and opens the pull request with `gh`, whose body names the commit of this repository the assets come from. The commit's author and committer are the account `gh` is logged in as, under its GitHub noreply address (`<id>+<login>@users.noreply.github.com`, from `gh api user`), whatever this Mac's git configuration and environment say, so that no personal address reaches the website repository's public history; when `gh` cannot say who is logged in, the command stops with exit code 1 before it renders or clones anything. When every file is already what the website has, it says so and opens nothing. A failed run keeps its clone and names it. The command never merges the pull request.

It needs `git`, `gh` logged in with access to the website repository, `sips` (so it runs on macOS), and, to render the screenshots, the Swift toolchain. It reads `JUSTSNAP_SCRATCH_PATH` and `DEVELOPER_DIR` as the release script does.

Everything the assets are made from must be committed, because the pull request names this repository's HEAD as their source: `Distribution/AppIcon.svg` always, and when the command renders the screenshots itself also `Sources/`, `JustSnap/`, `Package.swift` and `Package.resolved`. Uncommitted changes there stop the run before anything is built or cloned.

## The screenshots

`JustSnapSiteShots` renders them from the app's own SwiftUI views over invented content. It shows no window, activates nothing, captures no screen and reads no history, settings, Keychain or screenshots, so a run needs no screen-recording permission and does not disturb the Mac; it does build the app's modules with `swift run`, which takes minutes of CPU the first time. Each language is rendered by its own process with that language's region and the UTC time zone, so the files are the same on every run; the selection color is the system accent color, which is the one setting of the Mac that reaches the pictures, so keep the default blue.

The directory must hold exactly the fourteen files, each a whole PNG of 1840×1035 pixels. Anything missing, extra, damaged or of another size stops the run before anything is cloned, and every problem is listed.

## The icon

The site's icon is `Distribution/AppIcon.svg` cropped to its tile, without the margin and the drop shadow. The command derives `icon.svg` from the app's SVG by exact text edits and refuses to go on when the SVG no longer has the shape those edits expect (the root element, one shadow filter, one shape using it), or when the result does not draw the same artwork as the app's icon. It renders `icon.png`, 192 pixels, from that SVG with `sips`. To change the icon, follow [macOS signing and notarization](macos-signing.md#app-icon) and then run the command.

## An evidence run

`--title <text>` replaces the pull request's title and `--note <text>` adds a line at the top of its body. They are for a run whose pull request is not meant to be merged, such as the one that shows the command works end to end: its text says so in both, and whoever runs it closes that pull request and deletes its branch at once: the command does neither.
