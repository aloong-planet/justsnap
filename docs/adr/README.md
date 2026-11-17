# Architecture decision records

This directory records VLMSnapper's architecture decisions.

## Rules

- **What goes in an ADR**: a decision that is hard to reverse, would puzzle a future reader without its context, and came out of a real trade-off — all three. Architecture decisions, and the trade-offs behind product behavior, go here. Product behavior itself goes in the feature's spec, rules for people changing the code go in `AGENTS.md`, incidents go in a postmortem, and how code implements a decision goes in that code's comments.
- **Sections**: every entry has Context (the problem and its constraints, at most 3 sentences), Options (one numbered item per option, the chosen one in bold, at most 2 sentences each), Decision (the rule in force, in the active voice), Consequences (`Positive:`, `Negative:` and `Neutral:` items, at most 2 sentences each, every kind present) and Sources (pointers to evidence, and the key numbers with their conditions).
- **Never written in an entry**: how the rule came about; how it was verified or rolled out; one-off costs already paid; how code implements it, or interface details; how a measurement was taken; line numbers or lists of places; restatements of other ADRs, specs or skills; options about how to record the decision.
- **Length**: at most 5,000 characters per entry, title and status line excluded.
- **Status**: `Proposed` while the evidence is not closed; `Accepted (YYYY-MM-DD)` once it is, dated with the day the user confirmed the decision in force.
- **Changes**: an entry states only the decision in force and is edited in place. A change to what it chose, rejected or accepted needs the user's confirmation first; the abandoned way becomes a rejected option with its reason. A new decision that makes a sentence of an entry's Decision untrue changes that entry; only a decision no entry covers opens a new one.
- **Retiring a number**: an entry merged into another, or withdrawn, is deleted; every reference to it points to the entry it merged into, or is removed; and its number is listed under Retired numbers. Numbers are never reused.

Entries written under earlier rules keep their form until a change touches what they state.

| # | Decision | Status |
|---|---|---|
| [0001](0001-store-provider-api-keys-in-apple-keychain.md) | 使用 Apple Keychain 保存 Provider API Key | 已接受（2026-08-24） |
| [0002](0002-local-history-without-app-layer-encryption.md) | 本地历史不做应用层加密 | 已接受（2026-08-25） |
| [0003](0003-v1-interface-localization-boundary.md) | 固定 v1 界面本地化边界 | 已接受（2026-08-25） |
| [0004](0004-separate-sparkle-feeds-per-distribution-architecture.md) | 为三个发行架构使用独立 Sparkle appcast | 已接受（2026-08-25） |
| [0005](0005-stable-direct-distribution-application-identity.md) | 固定直接分发应用身份 | 已接受（2026-08-25） |
| [0006](0006-layer-user-screenshots-and-internal-history-storage.md) | 将原始截图与应用内部历史分层存储 | 已接受（2026-08-25） |
| [0007](0007-direct-distribution-only-for-v1.md) | v1 仅采用 Developer ID 直接分发 | 已接受（2026-08-25） |
| [0008](0008-preserve-failed-history-database-before-reset.md) | 历史数据库故障时禁止静默重建 | 已接受（2026-08-25） |
| [0009](0009-single-primary-instance-per-user.md) | 每个用户只允许一个应用主实例 | 已接受（2026-08-25） |
| [0010](0010-freeze-display-frames-before-region-selection.md) | 快捷键触发时冻结屏幕帧再选区 | 已接受（2026-08-25） |
| [0011](0011-discover-deepseek-experimental-vision-model-per-account.md) | Discover DeepSeek vision models from the account's model list and disable their thinking | Accepted (2026-11-17) |
| [0012](0012-replace-provider-credential-without-rollback.md) | Provider 新凭据直接替换且不保留回退副本 | 已接受（2026-09-04） |
| [0013](0013-show-pending-overlay-before-freezing.md) | 截图触发后先显示待冻结遮罩 | 已接受（2026-10-28） |
| [0014](0014-snap-regions-from-window-list.md) | 吸附区域只取自屏幕窗口列表，不使用辅助功能接口 | 已接受（2026-10-28） |
| [0015](0015-show-results-inside-capture-overlay.md) | 在截图界面内显示模型结果，弃用独立结果窗口 | 提议 |
| [0016](0016-file-application-tests-by-module.md) | File the application tests by module | Accepted (2026-11-10) |
| [0017](0017-allowlist-gemini-and-openai-models-with-built-in-thinking-settings.md) | Allowlist Gemini and OpenAI models with built-in thinking settings | Proposed |
