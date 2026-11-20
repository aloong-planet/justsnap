# Landing page

## Question

Does the JustSnap download page read right: its structure (header, hero with the download, the pinned features section, three install steps, the download section, footer), its Chinese and English copy, its palette in light and dark, and what the download block shows in each of the three download states? The screenshots in the hero and the features section are drawn stand-ins for the real app screenshots; what is judged is their place, size and caption, not their content.

## Structure basis

The structure follows the direction already confirmed for the page: one long page in the shape of agentshed's landing page, with a pinned features section that turns step by step with the scroll, three download states (R2 release, GitHub release, list), Apple silicon only, and a text mark in place of an app icon. No alternative structures are offered.

## Demo scaffolding

Not part of the design; do not implement.

- The harness group "Download state": switches the download block in the hero and the download section between the three states. In the product the state is decided by the visitor's browser reads, with no such control.
- The language and appearance follow the gallery's settings. The page's language toggle is drawn static: in the product it is a link to the other language's page.
- The version "0.1.8" is mock data.
- The links drawn as `#` lead nowhere.

## Uncovered dimensions

- The state the page is served in before its script runs (the list state, stacked steps) is covered by the list state of the harness, not by running without scripts.
- A GitHub release without a DMG (its button leads to the release page) is not drawn.
- Reduced motion is not drawn.
