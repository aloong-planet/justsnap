# Paste result box

## Question

After a paste, does showing the result in a box that floats on its own, with no capture overlay, look and behave right? This page covers the box's place, its operation row, the clipboard problems it reports, and how a new paste or capture replaces it.

- A paste with an image on the clipboard opens the box and runs Text Extraction at once. The box sits at the right edge of the display under the pointer, 12 pt in, top-aligned below the menu bar, 380 pt wide and up to 640 pt tall. Its header drags it within the display.
- The header is the capture result box's header: title, Provider and model, Copy, Retry, Close.
- Under the header, an operation row holds the capture toolbar's Extract button and its Translate and target-language control. The operation whose result shows is selected. Pressing the other operation shows its result, or starts a request if it never ran; changing the language and pressing Translate starts a new translation with its own history record.
- The box floats above other apps and stays until closed. It never takes keyboard focus by itself: Escape closes it only after the user has clicked into it. Clicking elsewhere takes the focus away and leaves the box in place.
- Closing the box during a request cancels the request.
- A new paste replaces the box's content with the new clipboard's result, keeping the box where it is. A capture closes the box once its freeze frame shows. While a request runs or a result is unsaved, neither does anything.
- A clipboard without a usable image (only text, nothing, or content that cannot be read as an image) opens the box titled Paste with the reason in the body, no operation row, and Copy and Retry disabled. No request is sent and no history record is added.
- An image larger than the Provider allows fails before any request, with the actual size and the limit; Retry stays available.
- Other request states (preparing, streaming, no text, failed, canceled, not saved) look as in the capture result box.

## Structure basis

- The header, body, footer and their states are drawn from the app's capture result box.
- The operation row's controls are the shared capture toolbar's Extract button and Translate control, the confirmed toolbar structure. Placing them in a row under the header is the direction the user chose for this box.
- The box shows no thumbnail of the pasted image, as the user chose.
- Strings reuse the app's existing wording where it has one. The Paste title, the three clipboard messages and the too-large message are new.

## Demo scaffolding

Not part of the design; do not implement.

- The floating bar marked `data-demo-harness`: what the clipboard holds, the next request's result, and the Paste, Capture and Start over actions.
- Paste and Capture stand for the global shortcuts or the menu bar panel buttons. ⌥⇧V on the page also pastes.
- The chat window, menu bar and Dock are mock context from other apps.
- Streaming speed, sample text and the target-language sample are mock data.

## Uncovered dimensions

- Interface language: only Simplified Chinese is drawn. Longer English labels are not tested in the box header or the operation row.
- Appearance: only light is drawn. The page uses the shared tokens, which also define dark.
- Multiple displays: only one is drawn.
