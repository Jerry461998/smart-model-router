#!/usr/bin/env python3
"""Deterministic phase router for the Smart Model Router Codex skill."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from typing import Iterable


POLICY_VERSION = "1.0.0"
MODELS = {
    "luna": "gpt-5.6-luna",
    "terra": "gpt-5.6-terra",
    "sol": "gpt-5.6-sol",
    "astra": "gpt-6-astra",
}


@dataclass(frozen=True)
class Phase:
    phase: str
    model: str
    effort: str
    worker: str
    reason: str
    mode: str = "required"


def _phase(
    phase: str,
    model: str,
    effort: str,
    worker: str,
    reason: str,
    mode: str = "required",
) -> Phase:
    return Phase(phase, MODELS[model], effort, worker, reason, mode)


def _has(text: str, *patterns: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def _explicit_model(text: str) -> str | None:
    for model in ("luna", "terra", "sol", "astra"):
        if _has(
            text,
            rf"只(?:使用|用)\s*{model}",
            rf"(?:这次|本次).*?用\s*{model}",
            rf"only\s+use\s+{model}",
            rf"use\s+{model}\b",
            rf"用\s*{model}\b",
        ):
            return model
    return None


def _forbids_astra(text: str) -> bool:
    return _has(text, r"不要(?:使用|用|调用)\s*astra", r"禁止\s*astra", r"no\s+astra", r"do\s+not\s+use\s+astra")


def _analysis_only(text: str) -> bool:
    return _has(text, r"只分析", r"只调查", r"先别改", r"不要改(?:代码|文件)", r"analysis\s+only", r"do\s+not\s+(?:edit|modify)")


def _observability(phases: Iterable[Phase]) -> list[str]:
    lines = ["Routing:"]
    for item in phases:
        suffix = " (conditional)" if item.mode == "conditional" else ""
        short = item.model.replace("gpt-5.6-", "").replace("gpt-6-", "").title()
        lines.append(f"- {item.phase.title()} -> {short} {item.effort}{suffix}")
    return lines


def route_prompt(
    prompt: str,
    *,
    sol_failures: int = 0,
    escalation_reason: str = "",
) -> dict:
    text = " ".join(prompt.strip().split())
    lower = text.lower()
    forbidden_astra = _forbids_astra(lower)
    explicit = _explicit_model(lower)
    analysis_only = _analysis_only(lower)

    if explicit:
        effort = "xhigh" if explicit == "astra" else "medium"
        if explicit == "sol":
            effort = "high"
        if explicit == "luna":
            effort = "low"
        if explicit == "astra" and forbidden_astra:
            explicit = None
        else:
            phases = [
                _phase(
                    "analyze" if analysis_only else "execute",
                    explicit,
                    effort,
                    f"smart_router_{explicit}_explicit",
                    "explicit user model override",
                )
            ]
            return _result(text, "user-override", phases, forbidden_astra, explicit == "astra", escalation_reason)

    astra_candidate = _has(
        lower,
        r"跨服务.*(?:一致性|transaction)",
        r"cross[- ]service.*(?:consistency|transaction)",
        r"极复杂.*(?:分布式|并发|一致性)",
    )
    astra_allowed = bool(
        astra_candidate
        and sol_failures >= 2
        and escalation_reason.strip()
        and not forbidden_astra
    )
    if astra_allowed:
        phases = [
            _phase(
                "escalate",
                "astra",
                "xhigh",
                "smart_router_astra_escalation",
                f"ESCALATION_REASON: {escalation_reason.strip()}",
            )
        ]
        return _result(text, "extreme", phases, forbidden_astra, True, escalation_reason)

    if analysis_only:
        model = "sol" if _has(lower, r"架构", r"并发", r"一致性", r"architecture", r"concurr", r"consistency") else "luna"
        effort = "high" if model == "sol" else "low"
        worker = "smart_router_sol_expert" if model == "sol" else "smart_router_luna_explorer"
        phases = [_phase("analyze", model, effort, worker, "analysis-only user constraint")]
        return _result(text, "analysis-only", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"生产.*(?:ci/?cd|github actions).*?(?:rollback|回滚|migration|迁移)",
        r"(?:redesign|重新设计).*?(?:ci/?cd|部署).*?(?:rollback|回滚|migration|迁移)",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "mechanical inventory of current deployment state"),
            _phase("architecture", "sol", "high", "smart_router_sol_expert", "high-consequence deployment and migration-safety design"),
            _phase("implement", "terra", "high", "smart_router_terra_diagnostician", "bounded CI/CD implementation from approved architecture"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "deterministic workflow and configuration checks"),
            _phase("review", "sol", "high", "smart_router_sol_expert", "consequential production architecture review", "conditional"),
        ]
        return _result(text, "architecture", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:docker.*caddy|caddy.*docker).*?(?:502|unhealthy|permissionerror|间歇|偶发)",
        r"生产.*502.*本地.*(?:正常|没有)",
        r"production.*502.*local",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "collect Docker, proxy, permissions, health, and log evidence"),
            _phase("diagnose", "terra", "high", "smart_router_terra_diagnostician", "initial evidence-based integration diagnosis"),
            _phase("expert", "sol", "high", "smart_router_sol_expert", "production-only cross-service ambiguity after Terra evidence", "conditional"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "targeted regression and configuration verification", "conditional"),
        ]
        return _result(text, "complex-debug", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:并发|race condition|重复扣库存|transaction consistency|事务一致性)",
        r"跨服务.*(?:transaction|一致性)",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "map the narrow concurrency path and existing tests"),
            _phase("reason", "sol", "high", "smart_router_sol_expert", "concurrency or transaction semantics require expert reasoning"),
            _phase("implement", "terra", "high", "smart_router_terra_diagnostician", "bounded fix guided by the expert result"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "deterministic regression and concurrency tests"),
        ]
        return _result(text, "complex-consistency", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"公告.*(?:每个用户|只确认一次).*?(?:新公告|再次弹)",
        r"announcement.*(?:once|confirm).*?(?:new|again)",
    ):
        phases = [
            _phase("explore", "luna", "low", "smart_router_luna_explorer", "map announcement model, API, UI, and tests"),
            _phase("implement", "terra", "medium", "smart_router_terra_builder", "ordinary bounded full-stack feature implementation"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent behavior and regression verification"),
        ]
        return _result(text, "ordinary-feature", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:普通\s*)?(?:crud|增删改查|登录记录).*?(?:页面|管理)",
        r"django.*(?:crud|登录记录|management page)",
    ):
        phases = [
            _phase("explore", "luna", "low", "smart_router_luna_explorer", "bounded repository mapping"),
            _phase("implement", "terra", "medium", "smart_router_terra_builder", "ordinary product implementation"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent routine verification"),
        ]
        return _result(text, "ordinary-feature", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"搜索.*(?:deployment|部署).*文件",
        r"search.*all.*deployment.*files",
        r"批量替换.*(?:1000|文件|版权年份)",
        r"replace.*(?:1000|copyright year)",
        r"button.*(?:文案|提交|确认|label)",
        r"按钮.*(?:文案|标题|文字)",
        r"css.*(?:margin|颜色|color|px)",
        r"margin.*(?:20px|16px)",
    ):
        phases = [_phase("execute", "luna", "low", "smart_router_luna_explorer", "clear deterministic or mechanical task")]
        return _result(text, "mechanical", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"生产|production|架构|architecture|security|安全|migration|迁移|authorization|authentication|一致性|多服务|cross[- ]service",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "collect current-state evidence"),
            _phase("reason", "sol", "high", "smart_router_sol_expert", "high-consequence or cross-system reasoning"),
            _phase("implement", "terra", "high", "smart_router_terra_diagnostician", "bounded implementation from expert guidance", "conditional"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent verification", "conditional"),
        ]
        return _result(text, "complex", phases, forbidden_astra, False, escalation_reason)

    phases = [
        _phase("explore", "luna", "low", "smart_router_luna_explorer", "cheap bounded context collection"),
        _phase("implement", "terra", "medium", "smart_router_terra_builder", "default ordinary development worker"),
        _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent routine verification"),
    ]
    return _result(text, "ordinary", phases, forbidden_astra, False, escalation_reason)


def _result(
    prompt: str,
    task_class: str,
    phases: list[Phase],
    astra_forbidden: bool,
    astra_selected: bool,
    escalation_reason: str,
) -> dict:
    return {
        "policy_version": POLICY_VERSION,
        "prompt": prompt,
        "task_class": task_class,
        "quota_aware_routing": "disabled-no-reliable-api",
        "default_root": {"model": MODELS["terra"], "effort": "medium"},
        "phases": [asdict(item) for item in phases],
        "escalation": {
            "astra_forbidden": astra_forbidden,
            "astra_selected": astra_selected,
            "escalation_reason": escalation_reason.strip(),
        },
        "observability": _observability(phases),
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    route = subparsers.add_parser("route", help="Classify a task and return a JSON phase plan")
    route.add_argument("--text", required=True)
    route.add_argument("--sol-failures", type=int, default=0)
    route.add_argument("--escalation-reason", default="")
    simulate = subparsers.add_parser("simulate", help="Run the standard announcement-feature simulation")
    simulate.add_argument("--pretty", action="store_true")
    return parser


def main() -> None:
    args = _build_parser().parse_args()
    if args.command == "simulate":
        result = route_prompt("修改网站公告功能：每个用户每条公告只确认一次，新公告发布后再次弹窗，改完自己测试。")
    else:
        result = route_prompt(
            args.text,
            sol_failures=max(args.sol_failures, 0),
            escalation_reason=args.escalation_reason,
        )
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
