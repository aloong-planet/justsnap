# Clipboard Paste

> Related: ADR-0019, ADR-0015, ADR-0006

## Problem Statement

A user often already has the image they want read, copied from a chat, a web page or another app, but VLMSnapper only reads what is captured from the screen. To get text out of a copied image the user has to show it on screen first and then capture it.

## Solution

The menu bar panel offers Paste next to Capture, and a global paste shortcut does the same. Paste takes the Pasted Image on the clipboard, saves it as a Managed Capture File and runs Text Extraction on it at once. The result streams into a paste result box that floats at the right edge of the screen, outside any capture overlay (ADR-0019). The box can switch to Screenshot Translation of the same image. Pasted images go into history like captures.

## Functional Requirements

### clipboard-paste::REQ-001 Paste entry points

- clipboard-paste::REQ-001/AC-01: The menu bar panel's capture row holds two buttons side by side that split the row equally: Capture on the left and Paste on the right. Each shows its icon, its title and its current global shortcut, in the style the capture button has in v1-core §1 ([v1-core](v1-core.md)).
- clipboard-paste::REQ-001/AC-02: Clicking Paste in the panel closes the panel at once and starts a paste; the panel closes even when the paste only reports a clipboard problem (clipboard-paste::REQ-003).
- clipboard-paste::REQ-001/AC-03: A global paste shortcut starts the same paste as the panel button. Its default is `⌥⇧V`. General settings record it with the same recorder as the capture shortcut, directly below it.
- clipboard-paste::REQ-001/AC-04: Saving a new paste shortcut follows the capture shortcut's rules in v1-core §3: the app tries to register it at once; on a conflict or a registration failure it shows the specific error and keeps the old shortcut; on success it takes effect at once. A paste shortcut equal to the capture shortcut, and a capture shortcut equal to the paste shortcut, are rejected as conflicts.

### clipboard-paste::REQ-002 When a paste may start

- clipboard-paste::REQ-002/AC-01: A paste needs a usable Provider and Selected Model only; Screen Recording permission is not required. Without a usable Provider or Selected Model, the paste brings the first-run onboarding window to the front, as a capture does (v1-core §2), and does not read the clipboard.
- clipboard-paste::REQ-002/AC-02: While a Provider credential job is active, a paste does what a capture does in v1-core Failure Modes item 44: it brings the Management Center's Provider page and the job to the front and does not read the clipboard.
- clipboard-paste::REQ-002/AC-03: While the capture interface is open, from the pending overlay until the capture is exited, a paste does nothing.
- clipboard-paste::REQ-002/AC-04: While the paste result box has a running request or an unsaved result, a paste does nothing.
- clipboard-paste::REQ-002/AC-05: While the history database is unavailable or read-only (v1-core §9), a paste sends no request, as with any new model operation, and the paste result box shows the database error.

### clipboard-paste::REQ-003 Reading the clipboard

- clipboard-paste::REQ-003/AC-01: A paste reads the clipboard once, when it is triggered. It reads only image data and plain text; file references on the clipboard are not read as files, so a file copied in Finder is judged by the plain text and image data that come with it.
- clipboard-paste::REQ-003/AC-02: When the clipboard holds image data and its plain text is empty or is a single URL, the paste uses the image.
- clipboard-paste::REQ-003/AC-03: When the clipboard holds any other plain text, it is a text clipboard, whether or not it also holds image data: the paste result box says that only images can be pasted for now.
- clipboard-paste::REQ-003/AC-04: When the clipboard holds neither image data nor plain text, the paste result box says there is no image on the clipboard and asks the user to copy one.
- clipboard-paste::REQ-003/AC-05: The paste accepts any bitmap format macOS can decode, such as PNG, JPEG, TIFF, HEIC, WebP and GIF; an animated image uses its first frame. When the clipboard's image data cannot be decoded as a bitmap, including when its only image is vector PDF content, the paste result box says the clipboard content cannot be read as an image.
- clipboard-paste::REQ-003/AC-06: For AC-03, AC-04 and AC-05 the box is titled Paste, shows the reason in its body, has no operation row, and has Copy and Retry disabled; Close works. No file is written, no history record is added and no request is sent.
- clipboard-paste::REQ-003/AC-07: Changing the clipboard after a paste does not change the box or its records; retries use the saved Pasted Image.

### clipboard-paste::REQ-004 Saving the Pasted Image

- clipboard-paste::REQ-004/AC-01: The pasted bitmap is converted to an 8-bit sRGB PNG with its pixel dimensions and its transparency unchanged; it is not scaled, composited onto a background or otherwise altered.
- clipboard-paste::REQ-004/AC-02: The PNG becomes a Managed Capture File under v1-core §9's rules: the same folder and file naming, an atomic write and SHA-256 before a "preparing request" history record is created, and no upload until both have succeeded and the request-body check passes.
- clipboard-paste::REQ-004/AC-03: When the PNG cannot be saved, the box shows the reason and Retry, keeps the image in memory while it stays open, and adds no history record; closing the box discards the image.
- clipboard-paste::REQ-004/AC-04: When the image is larger than the Provider's request-body limit, nothing is sent and the image is not shrunk; the failed record is kept, and the box shows the actual size, the limit, and a suggestion to copy a smaller image.

> Pending: OpenAI and DeepSeek request-body limits are confirmed and part of the signed Provider configuration (v1-core Pending). Until then only a Gemini request rejects an oversized image before anything is sent.

- clipboard-paste::REQ-004/AC-05: History records from a paste behave like records from a capture in list, detail, search, filters, retry, Pin, deletion and cleanup (v1-core §9, §10); history does not mark them as pasted.

### clipboard-paste::REQ-005 The paste result box

- clipboard-paste::REQ-005/AC-01: The box opens on the display under the pointer when the paste is triggered, at the place and size v1-core REQ-010/AC-02 gives the capture result box on the selection's display. Its header drags it within that display's visible area.
- clipboard-paste::REQ-005/AC-02: The box floats above other apps' windows and stays when the user switches apps or clicks elsewhere. Neither showing it nor updating its content activates the app or takes keyboard focus. After the user clicks into it, it supports text selection, ⌘C and ⌘A, and Escape closes it.
- clipboard-paste::REQ-005/AC-03: The close button, or Escape while the box has keyboard focus, closes the box. Closing it while a request runs cancels the request, and the new record is saved as Cancelled.
- clipboard-paste::REQ-005/AC-04: When the box holds an unsaved result, closing it or quitting the app first asks for confirmation in a prompt attached to the box: Cancel keeps the box and the app as they were, and Discard closes the box.
- clipboard-paste::REQ-005/AC-05: A paste allowed by clipboard-paste::REQ-002 while the box is open replaces the box's content with the new paste's result, keeping the box where it is; earlier records stay as they are.
- clipboard-paste::REQ-005/AC-06: A capture allowed while the box is open closes the box once the capture's new freeze frame is shown. If the capture ends before its freeze frame is shown, the box stays.
- clipboard-paste::REQ-005/AC-07: While the box has a running request or an unsaved result, the capture shortcut and the panel's Capture button do nothing.
- clipboard-paste::REQ-005/AC-08: When the app prepares to quit, including before installing an update, it cancels a running request in the box; an unsaved result is confirmed as in AC-04.
- clipboard-paste::REQ-005/AC-09: The box shows no thumbnail of the Pasted Image.

### clipboard-paste::REQ-006 Operations in the paste result box

- clipboard-paste::REQ-006/AC-01: A paste that uses an image starts Text Extraction at once, with one request and a new history record.
- clipboard-paste::REQ-006/AC-02: The box's header, body states, copying and Retry are those of the capture result box in v1-core REQ-010/AC-04–11; Retry is a Current Result Rerun (v1-core REQ-002).
- clipboard-paste::REQ-006/AC-03: Below the header, an operation row holds the capture toolbar's Extract button and its Translate and target-language control, with the look and behavior of v1-core REQ-013/AC-02–05. The target language is the app's remembered target language (v1-core §5).
- clipboard-paste::REQ-006/AC-04: The operations work on the one Pasted Image as the capture result box's operations work on one capture (v1-core REQ-011/AC-01–07): one result per operation, an operation never run starts a request, one with a result shows it again, and Translate after a target-language change starts a new record that reuses the same Managed Capture File.

## Constraints

### clipboard-paste::CON-001 The clipboard is read only on an explicit paste (direct acceptance)

Applies to: the whole app. The app reads the clipboard only when the user triggers a paste, never in the background, and sends only the Pasted Image of that paste to the Provider.

## Failure modes and boundaries

1. The user copies an image in a browser whose clipboard also carries the image's URL as text: the image is pasted (clipboard-paste::REQ-003/AC-02). Copy Image in Safari and other WebKit views puts the image on the clipboard as TIFF only, together with its address as plain text, as a URL and inside HTML and a web archive.
2. The user copies cells in a spreadsheet or text in a word processor, which put both text and a rendered picture on the clipboard: it is a text clipboard and nothing is sent (clipboard-paste::REQ-003/AC-03).
3. The user copies a file in Finder: its file name is plain text, so it is a text clipboard (clipboard-paste::REQ-003/AC-01, AC-03).
4. The user pastes a very large image: decoding and conversion do not block the interface; the box shows that the request is being prepared until the PNG is saved, and an image over the Provider's limit fails as in clipboard-paste::REQ-004/AC-04.
5. The user pastes, then copies something else and presses Retry: Retry uses the saved Pasted Image (clipboard-paste::REQ-003/AC-07).
6. The user triggers paste while a request runs or a result is unsaved in the box, or while the capture interface is open: nothing happens (clipboard-paste::REQ-002/AC-03, AC-04).
7. The user triggers a capture while the box is open and idle, then presses Escape before the freeze frame is shown, or the freeze fails: the box stays (clipboard-paste::REQ-005/AC-06).
8. The user closes the box while the result is unsaved and chooses Cancel: the box, its result and Retry Save stay (clipboard-paste::REQ-005/AC-04).
9. The user quits the app while a paste request runs: the request is cancelled and its record is saved as Cancelled (clipboard-paste::REQ-005/AC-08).
10. The model returns long text, long URLs, bidirectional text or text shaped like links, HTML or Markdown: the box lays it out as local read-only text and opens nothing, as in v1-core REQ-010/AC-11.
11. The selected model is found not to accept images, or has left the model list: the box fails as the capture result box does (v1-core Failure Modes items 10, 11, 56).

## Implementation Decisions

- A single URL is plain text that, with surrounding whitespace removed, contains no whitespace and is an absolute URL whose scheme is followed by `//`, such as `https://…` or `file://…`.
- Clipboard decision order, evaluated once per paste: (1) image data present and plain text empty or a single URL → image; (2) any other plain text → text clipboard; (3) image data present → image, or unreadable when it cannot be decoded as a bitmap; (4) nothing usable → empty clipboard.
- A Pasted Image becomes an ordinary Managed Capture File and its records ordinary history records: the history database's format does not change, and no record stores whether it came from a paste (ADR-0006).
- The paste shortcut is stored like the capture shortcut, as its own preference.
- A paste request is a model request under the app's single owner-token mutual exclusion with captures and Provider credential jobs (v1-core Implementation Decisions). The paste result box is not part of the capture interface (ADR-0019).

## Out of Scope

- Pasting text: a text clipboard is reported, not sent. Text paste is a later increment whose behavior is not yet decided.
- Reading file references, such as files copied in Finder, as images.
- Vector PDF content, more than one image per paste, and shrinking images to fit a Provider's limit.
- Marking pasted records in history.
- Watching the clipboard in the background.
- A thumbnail of the Pasted Image in the paste result box, and an operation row in the capture result box.
