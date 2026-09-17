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
