"""Small YAML subset used only to run bundled validators without PyYAML.

Supports the mapping-only YAML used by this package's frontmatter and openai.yaml.
It is not imported by the installed plugin or router runtime.
"""

from __future__ import annotations

import json


class YAMLError(ValueError):
    pass


def _scalar(value: str):
    value = value.strip()
    if not value:
        return {}
    if value in {"true", "false"}:
        return value == "true"
    if value in {"null", "~"}:
        return None
    if value.startswith(('"', "'")):
        if value.startswith('"'):
            return json.loads(value)
        if not value.endswith("'"):
            raise YAMLError("unterminated quoted scalar")
        return value[1:-1].replace("''", "'")
    return value


def safe_load(text: str):
    root = {}
    stack = [(-1, root)]
    for raw in text.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if "\t" in raw[:indent]:
            raise YAMLError("tabs are not supported")
        body = raw.strip()
        if ":" not in body:
            raise YAMLError(f"expected mapping entry: {body}")
        key, value = body.split(":", 1)
        key = key.strip()
        if not key:
            raise YAMLError("empty mapping key")
        while stack and indent <= stack[-1][0]:
            stack.pop()
        if not stack:
            raise YAMLError("invalid indentation")
        parent = stack[-1][1]
        parsed = _scalar(value)
        parent[key] = parsed
        if isinstance(parsed, dict):
            stack.append((indent, parsed))
    return root
