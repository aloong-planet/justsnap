# ADR-0017: Allowlist Gemini and OpenAI models with built-in thinking settings

- Status: Proposed

## Context

Text extraction and screenshot translation should not wait on a model's hidden thinking, but Gemini and OpenAI take thinking controls per model, a value a model does not accept fails the request with HTTP 400, and the app never retries. Neither Provider's `/models` says which models read images and return text or which thinking values each accepts; Gemini only flags whether a model thinks. Both lists also carry many models unrelated to extraction and translation, such as speech, image generation, embeddings and realtime models.

## Options

1. **Show only allowlisted models, each with a built-in thinking setting: Gemini by version-tolerant ID patterns, OpenAI by exact IDs**
2. Hide only known unrelated kinds and send no thinking parameter to other models — rejected by the user on 2026-11-17: new unrelated kinds reappear in the list, and new models keep their default thinking.
3. Send one parameter to every model of a Provider — rejected: models reject it (gemini-2.5-flash and gemma-4-31b-it reject any `thinkingLevel`, gemini-3.8-flash rejects `minimal`, OpenAI non-reasoning models take no `reasoning`).
4. Send each Gemini model its own lowest level, `minimal` where accepted — rejected by the user on 2026-11-17: it needs a per-model table, while `low` is accepted by every documented Gemini 3 and 4 model.
5. Keep OpenAI `*-pro` models at their lowest effort — rejected by the user on 2026-11-17: that lowest is `medium` or `high`, so they stay slow.

## Decision

We adopt **option 1**. A Gemini model is offered when its ID is a versioned `gemini-<version>-…` ID or a `-latest` alias, minus the variants whose IDs mark non-text work; requests to Gemini 2.x send no `thinkingConfig`, and requests to every other offered Gemini model send `thinkingConfig.thinkingLevel: "low"`. An OpenAI model is offered when its ID, or that ID without a `-YYYY-MM-DD` snapshot suffix, is on the built-in list, and each listed model carries one setting: `reasoning.effort: "none"` with `temperature: 0`, its lowest documented effort without `temperature`, or, for a non-reasoning model, no `reasoning` with `temperature: 0`. OpenAI `*-pro` models are not listed.

A model without a rule never receives a thinking parameter or, for OpenAI, a `temperature`. The patterns, the list and the settings ship in the signed app and are stated in the v1-core spec; supporting a new OpenAI model or a new Gemini naming scheme takes a release.

## Consequences

- Positive: the model lists show only models that can extract and translate; the Gemini list of the account checked on 2026-11-17 shrinks from 56 models to 18.
- Positive: every offered model gets a thinking setting that its documentation or a measured request shows it accepts, so the setting alone does not fail a request.
- Negative: an OpenAI model released after a build stays hidden until the next release, and a Gemini variant with a new non-text suffix shows until the patterns change.
- Negative: Gemini models that accept `minimal` think more under `low` than they could; gemini-3-flash-preview spent 57 thought tokens on a one-word reply under `low` and none under `minimal`.
- Negative: the OpenAI settings rest on documentation alone, so this decision stays proposed until an OpenAI live gate passes.
- Neutral: Gemini 2.x models keep their default thinking.

## Sources

- [Gemini thinking](https://ai.google.dev/gemini-api/docs/thinking): the levels each model accepts; `minimal` is not accepted by Gemini 4 models or gemini-3.8-flash.
- The Gemini `/models` of 2026-11-17: 56 models, with a `thinking` flag and no input-modality field.
- Gemini requests of 2026-11-17 with a one-word prompt: gemini-2.5-flash rejected `thinkingLevel` with HTTP 400 and accepted `thinkingBudget: 0`; gemini-3.8-flash and gemini-flash-latest rejected `minimal`; gemma-4-31b-it rejected `low`; gemini-3.5-flash and gemini-3-flash-preview accepted `low`.
- [OpenAI reasoning](https://developers.openai.com/api/docs/guides/reasoning), [OpenAI models](https://developers.openai.com/api/docs/models/all) and [OpenAI latest-model guide](https://developers.openai.com/api/docs/guides/latest-model): accepted efforts per model, and that `temperature` must be removed whenever the effort is not `none`.
- The user's decisions of 2026-11-17, in the alignment on Provider thinking and model filtering.
