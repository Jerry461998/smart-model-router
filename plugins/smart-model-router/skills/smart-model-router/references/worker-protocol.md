# Worker Protocol

## Bounded prompt template

```text
GOAL:
<one verifiable outcome>

RELEVANT_FILES:
<exact paths or a narrow discovery boundary>

KNOWN_FACTS:
<condensed evidence only>

CONSTRAINTS:
<user overrides, scope, preservation, risk, ordering>

EXPECTED_OUTPUT:
<one TASK_RESULT schema>

CAN_MODIFY_FILES: true|false
CAN_RUN_COMMANDS: true|false
```

## Coordinator checks

1. Verify the returned paths remain inside the assigned mutable boundary.
2. Inspect the actual diff; do not trust a changed-files list alone.
3. Keep writes serial unless paths are proven disjoint.
4. Run or delegate the promised validation and retain concise exit/result evidence.
5. Classify failures as infrastructure/input versus reasoning before considering escalation.
6. Record actual model and effort from Codex runtime/session metadata when proof is required.

## Context hygiene

The main task should retain the user goal, active plan, key facts, decisions, changed files, test summary, and unresolved issues. Raw searches, long logs, full directory listings, and temporary experiments stay in the worker thread.

## Terra phases

Use `smart_router_terra_builder` for a bounded local/visual fix with explicit mutable paths and acceptance criteria; use the Implementation TASK_RESULT schema. Use `smart_router_terra_visual_reviewer` for screenshot/UI inspection or a defined computer-use verification flow; use Verification TASK_RESULT, including inspected evidence, observed mismatches, and remaining visual/interaction risks. Set CAN_MODIFY_FILES false for review and every analysis-only/no-edit request. Run functional checks through Luna and visual reinspection through Terra when visual corrections were made. Both profiles lock `gpt-6.1-terra` medium; use a native default worker with explicit model/effort for overrides that do not match a locked profile.

If Terra is unavailable, disclose it before compatible available Sol medium fallback, retain scope and all execution limits, and report the actual model. Terra-only plus unavailable Terra blocks dispatch; Terra-only plus an explicit Terra prohibition is a constraint conflict requiring coordinator resolution. Never call availability or a tool failure a Sol reasoning failure. Report intended routes separately from actual dispatch and inspected output; do not infer comparative model quality from a passing task.
