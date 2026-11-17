# ADR-0019: Show paste results in a floating result box

- Status: Proposed

## Context

Paste sends a Pasted Image to the model without freezing the screen, so there is no capture overlay for the result box to sit on, while ADR-0015 ties the result box to that overlay. The user usually pastes while working in another app and wants the result without leaving it.

## Options

1. **Show the result in a result box that floats above other apps on its own, used only for paste**
2. Show a preview of the pasted image with the result box beside it in the middle of the screen — rejected by the user on 2026-11-17 (reason not recorded); it is also more new interface to build.
3. Run the request and open the record in the Management Center history — rejected by the user on 2026-11-17 (reason not recorded); it opens the heavier window that new operations otherwise never open automatically.
4. Close the result box when the user clicks outside it — rejected by the user on 2026-11-17 (reason not recorded); it was offered with the drawback that the box is easy to lose while reading.

## Decision

We adopt **option 1**: a paste result box floats above other apps until the user closes it, never takes keyboard focus by itself, and is the only paste result surface. It keeps ADR-0015's rule that only one result box is shown at a time: the next paste replaces its content, and a new capture closes it once the new freeze frame is shown. While a request runs or a result is unsaved, a new paste or capture does nothing. Capture results stay inside the capture overlay as ADR-0015 decides; this decision does not revive ADR-0015's rejected floating box for captures.

## Consequences

- Positive: the user reads and copies the result next to the app they are working in, with one click or one shortcut after copying.
- Negative: the app now has a result surface with its own lifecycle outside the capture overlay, which ADR-0015 had removed: its window level, closing, and replacement by the next paste or capture are rules of their own.
- Negative: a non-activating floating panel has to support text selection and ⌘C, which is not yet tested on an installed build; this entry becomes Accepted once it is.
- Neutral: a request still cannot continue after its result box closes; closing the box during a request cancels it.

## Sources

- The user's decisions of 2026-11-17 in the clipboard paste alignment (`docs/.workings/clipboard-paste/alignment.md`, not committed).
