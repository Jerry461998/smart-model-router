# Routing Policy

## Principles

- The active main-task model is fixed for that task. Routing means starting a separate Codex subagent with an explicit model and effort.
- Prefer the smallest capable worker, but do not split work when the startup and handoff cost exceeds the useful boundary.
- The user’s explicit model, no-edit, no-Astra, analysis-only, and scope instructions always win.
- File count, log size, or a single command failure is not evidence of reasoning difficulty.
- Quota-aware routing is reserved and disabled because this package has no reliable percentage/quota API.

## Model roles

### GPT-6 Luna

Use low for repository search, file discovery, mechanical edits and deterministic transformations. Use medium for independent routine tests, lint, syntax and regression verification. Use high only when a bounded validation task needs more care.

### GPT-6.1 Sol Low

Use low for a local nonmechanical behavior fix with a clear acceptance criterion, such as a bounded off-by-one correction or guard clause. Keep mechanical edits on Luna low and complex/security/production changes on Sol high.

### GPT-6.1 Sol Medium

Use medium for normal product development, CRUD, ordinary backend/frontend integration, refactors, API work, and typical debugging. Sol Medium is the recommended main-task default.

### GPT-6.1 Sol High

Use high for architecture, production incidents, cross-service behavior, reverse-proxy/deployment design, difficult PostgreSQL semantics, concurrency, transactions, data/session/cache consistency, authentication/authorization architecture, high-risk migrations, and evidence-backed issues that remain after a reasonable Sol Medium attempt. Give Sol condensed evidence rather than mechanical exploration.

### GPT-6.1 Sol Xhigh retry

After one completed evidence-backed complex Sol attempt remains unresolved, use xhigh for the serious retry. Keep conditional phases conditional and analysis-only work read-only. Prefer this retry before automatic Astra; a failure count alone does not establish evidence. The coordinator verifies two distinct tested hypotheses and concrete results before the final gate.

Generic Sol selects `gpt-6.1-sol`. Stable Sol profiles use medium/high/high; dispatch a native default worker with explicit model and effort if a locked profile cannot run low/xhigh. An explicit `gpt-6-sol` request selects that model. See [official model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol).

If GPT-6.1 Sol is unavailable, disclose the runtime limitation and use GPT-6 Sol at the same effort only when available and compatible with user instructions. A user requiring only GPT-6.1 Sol needs the blocker reported. Model availability is infrastructure; it never counts as a Sol reasoning failure or triggers Astra.

### GPT-6 Astra

Use xhigh only when the user explicitly requests Astra or two distinct Sol attempts with evidence remain insufficient for a very high-complexity/high-consequence problem. The coordinator must emit `ESCALATION_REASON` before dispatch.

## Common routes

| Scenario | Required route |
|---|---|
| Change a button label | Luna low |
| Add an ordinary Django CRUD page | Luna explore → Sol medium build → Luna verify |
| Search all deployment files | Luna low |
| Intermittent production Docker+Caddy 502 | Luna collect → Sol medium initial diagnosis → conditional Sol high |
| Redesign CI/CD with rollback and migration safety | Luna collect → Sol high architecture and implementation → Luna verify → conditional Sol review |
| Cross-service consistency bug after two failed Sol hypotheses | Astra xhigh with explicit reason |
| Replace years in 1000 files | Luna low |
| Small but complex race condition | Luna collect → Sol high reason and implement → Luna verify |
| Change CSS margin | Luna low |
| Ordinary Django login-record management page | Luna explore → Sol medium implement → Luna verify |

## Failure classification

Infrastructure failures include missing executables, bad paths, permissions, locks, missing fixtures, malformed commands, dependency absence, timeouts without evidence of a stall, and insufficient context. Correct the cause without model escalation.

Reasoning failures include contradictory evidence after a tested hypothesis, unresolved transaction semantics, cross-worker state inconsistency, production/local divergence after environment evidence is complete, or a high-consequence architecture ambiguity. These may justify Sol Medium→Sol High, an evidence-backed Sol Xhigh retry, then Astra after the full gate. The `--sol-failures` flag is a coordinator attestation of completed reasoning attempts; it is not evidence by itself.
