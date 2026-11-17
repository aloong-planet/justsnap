# ADR-0011: Discover DeepSeek vision models from the account's model list and disable their thinking

- Status: Accepted (2026-11-17)

## Context

Only some DeepSeek models take images, and names change, retire and differ per account, so a list fixed in the app would offer models that cannot read a screenshot or miss ones that can. DeepSeek models think by default, and a request waits for all of that hidden reasoning before its first visible text. The Chat Completions stream has no native JSON Schema and may carry private `reasoning_content` before the visible output.

## Options

1. **Offer the DeepSeek models whose official `/models` entry declares image input and text output, and send every request with thinking disabled**
2. Hard-code and preselect a vision model ID on every account — rejected: IDs have been renamed and retired (`deepseek-v4-flash-vision-exp` now resolves to Flash), and availability is per account.
3. Allow only an exact ID list in the app — rejected by the user on 2026-11-17: `/models` already declares each model's modalities, and a fixed list misses new vision models until a release.
4. Keep the default thinking, or lower it with `reasoning_effort: "low"` — rejected: the first visible text still took seconds.
5. Drop DeepSeek from v1 — rejected: the target accounts can send images through the official endpoint.

## Decision

We adopt **option 1**. A DeepSeek model is selectable only when the full official `/models` refresh for the current key lists it with `image` among its `input_modalities` and `text` among its `output_modalities`; a model missing either field is not offered, and the app never injects or preselects a model or uses a gateway. Every request sends `thinking: {"type": "disabled"}`. Should a stream still carry non-empty `reasoning_content`, it only refreshes the 10-second inactivity timer: it never enters the Provider event stream, results, history or diagnostics, nor extends the 90-second total.

The adapter normalizes the stream to the app's unified events in JSON mode, with an English versioned prompt that states the JSON instruction and its shape, and accepts output only after the final structure validates. A failure ends the request and waits for the user to retry, with no extra request, no non-streaming or two-request downgrade and no other model. Extraction alone also accepts the exact single-field object `{"text": ...}` as its source; translation requires `segments`, and any other extra field is a structure error.

Request-size limits come from the protected live contract and ship in the signed app's versioned Provider configuration; while a limit is unknown the app does not upload, and no unsigned remote rule may lift it. DeepSeek is release-ready only when the protected live gate passes extraction and translation, each reported separately.

## Consequences

- Positive: the first visible text arrives in under a second instead of after seconds of hidden reasoning, and `temperature: 0` takes effect again.
- Positive: the selectable models follow what the account declares, with no model ID kept in the app.
- Negative: model discovery depends on DeepSeek keeping `input_modalities` and `output_modalities` in `/models`; if they disappear, no DeepSeek model is offered until a release.
- Negative: output quality without thinking rests on one synthetic screenshot, not on an accuracy evaluation.
- Negative: DeepSeek may change these models' names or protocol at any time, so its regression risk is higher than OpenAI's and Gemini's.
- Neutral: the legacy names `deepseek-v4-flash` and `deepseek-v4-flash-vision-exp` are still accepted by the API but no longer listed, so they are not selectable.

## Sources

- [DeepSeek models and pricing](https://api-docs.deepseek.com/quick_start/pricing/): `deepseek-flash` supports vision, `deepseek-v4-pro` does not; the legacy Flash names are served by `deepseek-flash`.
- [DeepSeek thinking mode](https://api-docs.deepseek.com/guides/thinking_mode): thinking is on by default at effort `high`, `{"thinking": {"type": "disabled"}}` turns it off, and `temperature` has no effect while thinking.
- [DeepSeek JSON mode](https://api-docs.deepseek.com/guides/json_mode/) and [Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion).
- The account's `/models` on 2026-11-17: `deepseek-flash` declares input `text`, `image` and output `text`; `deepseek-v4-pro` declares input `text` only.
- 2026-11-17, `deepseek-flash`, production request body, synthetic 1240×660 English paragraph PNG: translation's first visible text at 6.2–8.4 s by default, 4.7–6.3 s with `reasoning_effort: "low"` and 0.46–0.59 s with thinking disabled; extraction's at 2.6 s and 0.66–0.70 s.
- Local history, 21 successful DeepSeek operations to 2026-11-16: 89% of latency preceded the first visible text, about 3.96 ms per output token (R² 0.97).
- The protected live contract of 2026-09-02: extraction may return the `text`-only object, and `reasoning_content` may stream before visible output.
- Canonical provider research: `~/research/macos-screenshot-ocr-translator/provider-contracts-2026-08-25.md`.
