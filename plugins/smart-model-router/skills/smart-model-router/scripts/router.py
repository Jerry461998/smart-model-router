#!/usr/bin/env python3
"""Deterministic phase router for the Smart Model Router Codex skill."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass, replace
from typing import Iterable


POLICY_VERSION = "3.0.0"
MODELS = {
    "luna": "gpt-6-luna",
    "sol": "gpt-6.1-sol",
    "astra": "gpt-6-astra",
    "sol_legacy": "gpt-6-sol",
    "terra": "gpt-6.1-terra",
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
    aliases = {
        "luna": r"(?:gpt-6-luna|(?:gpt[- ]?6\s+)?luna)",
        "sol": r"(?:gpt-6\.1-sol|(?:gpt[- ]?)?6\.1\s*sol|sol)",
        "sol_legacy": r"gpt-6-sol",
        "terra": r"(?:gpt-6\.1-terra|(?:gpt[- ]?)?6\.1\s*terra|terra)",
        "astra": r"(?:gpt-6-astra|(?:gpt[- ]?6\s+)?astra)",
    }
    for model, alias in aliases.items():
        if _has(
            text,
            rf"只(?:使用|用)\s*{alias}(?![a-z0-9_.-])",
            rf"(?:这次|本次).*?用\s*{alias}(?![a-z0-9_.-])",
            rf"(?:only\s+use|use(?:\s+only)?)\s+{alias}(?![a-z0-9_.-])",
            rf"(?:使用|用)\s*{alias}(?![a-z0-9_.-])",
            rf"(?<![a-z0-9_.-]){alias}\s+only\b",
        ):
            return model
    return None


def _forbids_astra(text: str) -> bool:
    return _has(text, r"不要(?:使用|用|调用)\s*(?:gpt-6-)?astra", r"禁止\s*(?:gpt-6-)?astra", r"no\s+(?:gpt-6-)?astra", r"do\s+not\s+use\s+(?:gpt-6-)?astra")


def _forbids_terra(text: str) -> bool:
    alias = r"(?:gpt-6\.1-terra|(?:gpt[- ]?)?6\.1\s*terra|terra)"
    return _has(text, rf"(?:不要|禁止|别)(?:使用|用|调用)?\s*{alias}",
                rf"(?:do\s+not\s+use|don't\s+use|no)\s+{alias}")


def _analysis_only(text: str) -> bool:
    return _has(text, r"只分析", r"只调查", r"先别改", r"不要(?:改|修改)(?:代码|文件)?", r"don't\s+(?:edit|modify)", r"(?:analysis|analyze)\s+only", r"no[- ]edits?", r"只读|仅分析|不改代码|不修改文件", r"do\s+not\s+(?:edit|modify)")


def _observability(phases: Iterable[Phase]) -> list[str]:
    lines = ["Routing:"]
    for item in phases:
        suffix = " (conditional)" if item.mode == "conditional" else ""
        short = {"gpt-6.1-sol": "GPT-6.1 Sol", "gpt-6-sol": "GPT-6 Sol",
                 "gpt-6.1-terra": "GPT-6.1 Terra", "gpt-6-luna": "GPT-6 Luna", "gpt-6-astra": "GPT-6 Astra"}[item.model]
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
    forbidden_terra = _forbids_terra(lower)
    explicit = _explicit_model(lower)
    analysis_only = _analysis_only(lower)

    def result(prompt, task_class, phases, *args):
        if forbidden_terra:
            phases = [replace(item, model=MODELS["sol"], worker="smart_router_sol_builder",
                              reason="Terra forbidden by user; compatible Sol medium phase")
                      if item.model == MODELS["terra"] else item for item in phases]
        # The failure count attests to evidence-backed reasoning attempts, never tool failures.
        if sol_failures >= 1 and task_class in {
            "architecture", "complex-debug", "complex-consistency", "complex", "analysis-only"
        }:
            phases = [replace(item, effort="xhigh", reason=item.reason + "; serious Sol retry after evidence-backed failure")
                      if item.model == MODELS["sol"] and
                      (item.effort == "high" or item.phase == "diagnose") else item
                      for item in phases]
        return _result(prompt, task_class, phases, *args)

    if forbidden_terra and explicit == "terra":
        # The negative phrase itself may look like an override. Only a separate
        # affirmative Terra-only instruction is a conflict, never permission.
        terra_alias = r"(?:gpt-6\.1-terra|(?:gpt[- ]?)?6\.1\s*terra|terra)"
        if _has(lower, rf"(?:only\s+use|use\s+only)\s+{terra_alias}",
                rf"只(?:用|使用)\s*{terra_alias}", rf"{terra_alias}\s+only"):
            blocked = result(text, "constraint-conflict", [], forbidden_astra, False, escalation_reason)
            blocked["blocker"] = "Terra-only conflicts with no-Terra; coordinator must resolve constraints before dispatch"
            return blocked
        explicit = None

    if explicit:
        effort = "xhigh" if explicit == "astra" else "medium"
        if explicit in {"sol", "sol_legacy"}:
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
                    f"smart_router_{'sol' if explicit == 'sol_legacy' else explicit}_explicit",
                    "explicit user model override",
                )
            ]
            return result(text, "user-override", phases, forbidden_astra, explicit == "astra", escalation_reason)

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
                "analyze" if analysis_only else "escalate",
                "astra",
                "xhigh",
                "smart_router_astra_escalation",
                f"ESCALATION_REASON: {escalation_reason.strip()}",
            )
        ]
        return result(text, "extreme", phases, forbidden_astra, True, escalation_reason)

    consequential = _has(lower, r"生产|production|架构|architecture|security|安全|concurr|并发|race condition|transaction|事务|consistency|一致性|migration|迁移|authorization|authentication|鉴权|认证|多服务|cross[- ]service")
    visual = _has(lower, r"(?:review|inspect|compare|verify|accept|修复|检查|对比|验收|审查|根据|按照|分析).*?(?:screenshot|截图|视觉|界面|ui\b|layout|布局)", r"(?:screenshot|截图|视觉|界面|ui\b|layout|布局).*?(?:review|验收|审查|对比|修复|检查|分析|acceptance|regression)")
    computer_use = _has(lower, r"(?:computer[- ]use|电脑操作|桌面操作).*?(?:verify|test|check|flow|验收|验证|测试|流程)", r"(?:verify|test|验证|验收|测试).*?(?:computer[- ]use|电脑操作|桌面操作)")

    if analysis_only:
        if not consequential and (visual or computer_use):
            return result(text, "visual-analysis", [_phase("analyze", "terra", "medium", "smart_router_terra_visual_reviewer", "read-only visual or defined computer-use analysis")], forbidden_astra, False, escalation_reason)
        model = "sol" if consequential else "luna"
        effort = "high" if model == "sol" else "low"
        worker = "smart_router_sol_expert" if model == "sol" else "smart_router_luna_explorer"
        phases = [_phase("analyze", model, effort, worker, "analysis-only user constraint")]
        return result(text, "analysis-only", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"生产.*(?:ci/?cd|github actions).*?(?:rollback|回滚|migration|迁移)",
        r"(?:redesign|重新设计).*?(?:ci/?cd|部署).*?(?:rollback|回滚|migration|迁移)",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "mechanical inventory of current deployment state"),
            _phase("architecture", "sol", "high", "smart_router_sol_expert", "high-consequence deployment and migration-safety design"),
            _phase("implement", "sol", "high", "smart_router_sol_diagnostician", "bounded CI/CD implementation from approved architecture"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "deterministic workflow and configuration checks"),
            _phase("review", "sol", "high", "smart_router_sol_expert", "consequential production architecture review", "conditional"),
        ]
        return result(text, "architecture", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:docker.*caddy|caddy.*docker).*?(?:502|unhealthy|permissionerror|间歇|偶发)",
        r"生产.*502.*本地.*(?:正常|没有)",
        r"production.*502.*local",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "collect Docker, proxy, permissions, health, and log evidence"),
            _phase("diagnose", "sol", "medium", "smart_router_sol_builder", "initial evidence-based integration diagnosis"),
            _phase("expert", "sol", "high", "smart_router_sol_expert", "production-only cross-service ambiguity after initial diagnosis", "conditional"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "targeted regression and configuration verification", "conditional"),
        ]
        return result(text, "complex-debug", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:并发|race condition|重复扣库存|transaction consistency|事务一致性)",
        r"跨服务.*(?:transaction|一致性)",
    ):
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "map the narrow concurrency path and existing tests"),
            _phase("reason", "sol", "high", "smart_router_sol_expert", "concurrency or transaction semantics require expert reasoning"),
            _phase("implement", "sol", "high", "smart_router_sol_diagnostician", "bounded fix guided by the expert result"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "deterministic regression and concurrency tests"),
        ]
        return result(text, "complex-consistency", phases, forbidden_astra, False, escalation_reason)

    if consequential:
        phases = [
            _phase("collect", "luna", "low", "smart_router_luna_explorer", "collect current-state evidence"),
            _phase("reason", "sol", "high", "smart_router_sol_expert", "high-consequence or cross-system reasoning"),
            _phase("implement", "sol", "high", "smart_router_sol_diagnostician", "bounded implementation from expert guidance", "conditional"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent verification", "conditional"),
        ]
        return result(text, "complex", phases, forbidden_astra, False, escalation_reason)


    if _has(
        lower,
        r"公告.*(?:每个用户|只确认一次).*?(?:新公告|再次弹)",
        r"announcement.*(?:once|confirm).*?(?:new|again)",
    ):
        phases = [
            _phase("explore", "luna", "low", "smart_router_luna_explorer", "map announcement model, API, UI, and tests"),
            _phase("implement", "sol", "medium", "smart_router_sol_builder", "ordinary bounded full-stack feature implementation"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent behavior and regression verification"),
        ]
        return result(text, "ordinary-feature", phases, forbidden_astra, False, escalation_reason)

    if _has(
        lower,
        r"(?:普通\s*)?(?:crud|增删改查|登录记录).*?(?:页面|管理)",
        r"django.*(?:crud|登录记录|management page)",
    ):
        phases = [
            _phase("explore", "luna", "low", "smart_router_luna_explorer", "bounded repository mapping"),
            _phase("implement", "sol", "medium", "smart_router_sol_builder", "ordinary product implementation"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent routine verification"),
        ]
        return result(text, "ordinary-feature", phases, forbidden_astra, False, escalation_reason)

    if not consequential and _has(
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
        return result(text, "mechanical", phases, forbidden_astra, False, escalation_reason)

    if not consequential and (visual or computer_use):
        phases = [
            _phase("review", "terra", "medium", "smart_router_terra_visual_reviewer", "visual acceptance or defined computer-use task with explicit scope"),
        ]
        if _has(lower, r"fix|修复|调整|implement|实现"):
            phases += [_phase("implement", "terra", "medium", "smart_router_terra_builder", "bounded visual correction"),
                       _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent functional regression checks"),
                       _phase("visual-verify", "terra", "medium", "smart_router_terra_visual_reviewer", "compare final visual result with acceptance criteria")]
        return result(text, "visual-computer-use" if computer_use else "visual-acceptance", phases, forbidden_astra, False, escalation_reason)

    if not consequential and _has(
        lower, r"(?:fix|修复).*?(?:off-by-one|边界错误|guard clause|空值检查|local null check)",
    ):
        phases = [
            _phase("implement", "terra", "medium", "smart_router_terra_builder", "clearly bounded local behavioral fix"),
            _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent targeted behavior verification"),
        ]
        return result(text, "bounded-fix", phases, forbidden_astra, False, escalation_reason)


    phases = [
        _phase("explore", "luna", "low", "smart_router_luna_explorer", "cheap bounded context collection"),
        _phase("implement", "sol", "medium", "smart_router_sol_builder", "default ordinary development worker"),
        _phase("verify", "luna", "medium", "smart_router_luna_verifier", "independent routine verification"),
    ]
    return result(text, "ordinary", phases, forbidden_astra, False, escalation_reason)


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
        "execution": "plan-only-not-dispatched",
        "constraints": {"can_modify_files": not _analysis_only(prompt),
                        "explicit_model": None if _forbids_terra(prompt) and _explicit_model(prompt) == "terra" else _explicit_model(prompt),
                        "terra_forbidden": _forbids_terra(prompt),
                        "model_only": _has(prompt, r"only\s+(?:use\s+)?|use\s+only|只(?:用|使用)")},
        "availability_policy": "Check runtime metadata; disclose missing Terra before compatible Sol fallback; Terra-only blocks fallback; never count availability as reasoning failure",
        "default_root": {"model": MODELS["sol"], "effort": "medium"},
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
    route.add_argument("--sol-failures", type=int, default=0,
                       help="Count distinct completed evidence-backed Sol reasoning attempts; excludes infrastructure failures")
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
