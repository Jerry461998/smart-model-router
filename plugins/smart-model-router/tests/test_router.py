import importlib.util
import sys
import json
import re
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "skills" / "smart-model-router" / "scripts" / "router.py"
SPEC = importlib.util.spec_from_file_location("smart_model_router", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def route(text, **kwargs):
    return MODULE.route_prompt(text, **kwargs)


def models(result):
    return [phase["model"] for phase in result["phases"]]


def phases(result):
    return [phase["phase"] for phase in result["phases"]]


class RequiredRoutingTests(unittest.TestCase):
    def test_01_button_copy_goes_to_luna(self):
        result = route("把 button 文案从提交改成确认")
        self.assertEqual(models(result), ["gpt-6-luna"])

    def test_02_django_crud_uses_luna_sol_luna(self):
        result = route("在 Django 中增加一个普通 CRUD 页面")
        self.assertEqual(models(result), ["gpt-6-luna", "gpt-6.1-sol", "gpt-6-luna"])
        self.assertEqual(result["default_root"], {"model": "gpt-6.1-sol", "effort": "medium"})
        self.assertEqual(phases(result), ["explore", "implement", "verify"])

    def test_03_deployment_search_goes_to_luna(self):
        result = route("搜索项目所有 deployment 文件")
        self.assertEqual(models(result), ["gpt-6-luna"])

    def test_04_production_502_not_luna_only(self):
        result = route("生产环境 Docker + Caddy 出现间歇性 502，本地没有问题")
        self.assertEqual(models(result)[:2], ["gpt-6-luna", "gpt-6.1-sol"])
        self.assertIn("gpt-6.1-sol", models(result))
        self.assertEqual(result["phases"][1]["effort"], "medium")
        self.assertEqual(result["phases"][2]["mode"], "conditional")

    def test_05_cicd_architecture_route(self):
        result = route("重新设计 production CI/CD，支持自动 rollback 和 migration safety")
        self.assertEqual(
            models(result),
            ["gpt-6-luna", "gpt-6.1-sol", "gpt-6.1-sol", "gpt-6-luna", "gpt-6.1-sol"],
        )
        self.assertEqual(result["phases"][-1]["mode"], "conditional")

    def test_06_astra_requires_two_sol_failures_and_reason(self):
        prompt = "一个跨服务 transaction consistency bug，Sol 两轮仍无法定位"
        blocked = route(prompt, sol_failures=1, escalation_reason="first hypothesis incomplete")
        self.assertNotIn("gpt-6-astra", models(blocked))
        missing_reason = route(prompt, sol_failures=2)
        self.assertNotIn("gpt-6-astra", models(missing_reason))
        allowed = route(prompt, sol_failures=2, escalation_reason="two distinct Sol hypotheses conflict with production traces")
        self.assertEqual(models(allowed), ["gpt-6-astra"])
        self.assertIn("ESCALATION_REASON", allowed["phases"][0]["reason"])

    def test_07_bulk_replace_goes_to_luna(self):
        result = route("批量替换 1000 个文件中的版权年份")
        self.assertEqual(models(result), ["gpt-6-luna"])

    def test_08_small_complex_race_uses_sol_reasoning(self):
        result = route("20 行代码里的复杂并发 race condition")
        self.assertIn("gpt-6.1-sol", models(result))
        sol_phase = next(item for item in result["phases"] if item["model"] == "gpt-6.1-sol")
        self.assertEqual(sol_phase["phase"], "reason")

    def test_09_css_margin_goes_to_luna(self):
        result = route("把一个 CSS margin 从 20px 改成 16px")
        self.assertEqual(models(result), ["gpt-6-luna"])

    def test_10_login_record_page_implemented_by_sol(self):
        result = route("实现普通 Django 登录记录管理页面")
        implementation = next(item for item in result["phases"] if item["phase"] == "implement")
        self.assertEqual(implementation["model"], "gpt-6.1-sol")
        self.assertEqual(implementation["effort"], "medium")


class PolicyInvariantTests(unittest.TestCase):
    def test_11_announcement_e2e_route(self):
        result = route("修改网站公告功能：每个用户每条公告只确认一次，新公告发布后再次弹窗，改完自己测试。")
        self.assertEqual(models(result), ["gpt-6-luna", "gpt-6.1-sol", "gpt-6-luna"])
        self.assertNotIn("gpt-6-astra", models(result))

    def test_12_no_astra_override_is_global(self):
        result = route(
            "不要使用 Astra。一个跨服务 transaction consistency bug",
            sol_failures=3,
            escalation_reason="Sol evidence exhausted",
        )
        self.assertNotIn("gpt-6-astra", models(result))
        self.assertTrue(result["escalation"]["astra_forbidden"])

    def test_13_only_luna_override(self):
        result = route("这次只使用 Luna，重新设计 production CI/CD")
        self.assertEqual(models(result), ["gpt-6-luna"])

    def test_14_analysis_only_never_implements(self):
        result = route("只分析不要改代码：数据库高并发重复扣库存")
        self.assertEqual(phases(result), ["analyze"])

    def test_15_tool_failure_does_not_escalate(self):
        result = route("普通 Django 页面，刚才路径写错导致命令失败")
        self.assertNotIn("gpt-6-astra", models(result))
        self.assertFalse(any(phase["worker"] == "smart_router_sol_expert" for phase in result["phases"]))
        self.assertNotIn("gpt-6-astra", models(result))

    def test_16_quota_router_is_disabled(self):
        result = route("实现一个普通功能")
        self.assertEqual(result["quota_aware_routing"], "disabled-no-reliable-api")

    def test_17_every_selected_model_is_gpt6(self):
        prompts = (
            "把按钮文案从提交改成确认",
            "实现普通 Django 登录记录管理页面",
            "生产环境 Docker + Caddy 出现间歇性 502，本地没有问题",
            "重新设计 production CI/CD，支持自动 rollback 和 migration safety",
            "跨服务 transaction consistency bug",
        )
        for prompt in prompts:
            result = route(prompt)
            self.assertTrue(result["default_root"]["model"].startswith(("gpt-6-", "gpt-6.1-")))
            self.assertTrue(all(model.startswith(("gpt-6-", "gpt-6.1-")) for model in models(result)))


class SolFirstReleaseTests(unittest.TestCase):
    def test_release_and_all_sol_profiles(self):
        package = SCRIPT.parents[3]
        manifest = json.loads((package / ".codex-plugin" / "plugin.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], "0.2.0")
        self.assertEqual(MODULE.POLICY_VERSION, "2.1.0")
        self.assertEqual(route("ordinary feature")["default_root"],
                         {"model": "gpt-6.1-sol", "effort": "medium"})
        for profile, effort in (("builder", "medium"), ("diagnostician", "high"), ("expert", "high")):
            text = (package / "codex-agents" / f"smart_router_sol_{profile}.toml").read_text(encoding="utf-8")
            self.assertIn(f'name = "smart_router_sol_{profile}"', text)
            self.assertIn('model = "gpt-6.1-sol"', text)
            self.assertIn(f'model_reasoning_effort = "{effort}"', text)

    def test_model_identifier_overrides_and_observability(self):
        for prompt in ("use gpt-6.1-sol for a feature", "use 6.1 Sol", "use GPT-6.1 Sol",
                       "只使用6.1sol修复", "使用6.1sol修复这个问题", "用 gpt-6.1-sol 修复", "use Sol", "只用Sol"):
            with self.subTest(prompt=prompt):
                result = route(prompt)
                self.assertEqual(result["task_class"], "user-override")
                self.assertEqual(models(result), ["gpt-6.1-sol"])
                self.assertIn("GPT-6.1 Sol high", result["observability"][1])
                self.assertNotIn("Gpt-6.1-Sol", result["observability"][1])
        legacy = route("use gpt-6-sol")
        self.assertEqual(models(legacy), ["gpt-6-sol"])
        self.assertIn("GPT-6 Sol high", legacy["observability"][1])

    def test_serious_retry_preserves_conditional_phases(self):
        for prompt in ("architecture redesign", "production Docker Caddy intermittent 502 local fine",
                       "cross-service transaction consistency", "security review"):
            result = route(prompt, sol_failures=1, escalation_reason="tested hypothesis contradicted logs")
            self.assertNotIn("gpt-6-astra", models(result))
            original = route(prompt)
            for before, after in zip(original["phases"], result["phases"]):
                self.assertEqual(before["mode"], after["mode"])
                if before["model"] == "gpt-6.1-sol" and (before["effort"] == "high" or before["phase"] == "diagnose"):
                    self.assertEqual(after["effort"], "xhigh")
                else:
                    self.assertEqual(before["effort"], after["effort"])

    def test_retry_preserves_analysis_only_and_no_astra(self):
        result = route("analysis only cross-service transaction consistency no Astra",
                       sol_failures=2, escalation_reason="two tested serious hypotheses insufficient")
        self.assertEqual(phases(result), ["analyze"])
        self.assertEqual(models(result), ["gpt-6.1-sol"])
        self.assertEqual(result["phases"][0]["effort"], "xhigh")
        explicit = route("analysis only use gpt-6.1-sol", sol_failures=2)
        self.assertEqual(phases(explicit), ["analyze"])
        self.assertEqual(explicit["phases"][0]["effort"], "high")

    def test_astra_gate_consequence_and_explicit_bypass(self):
        ordinary = route("ordinary CRUD page", sol_failures=2, escalation_reason="two attempts failed")
        self.assertNotIn("gpt-6-astra", models(ordinary))
        explicit = route("analysis only use gpt-6-astra")
        self.assertEqual(models(explicit), ["gpt-6-astra"])
        self.assertEqual(phases(explicit), ["analyze"])
        automatic = route("analysis only cross-service transaction consistency", sol_failures=2,
                          escalation_reason="two tested hypotheses contradict traces")
        self.assertEqual(models(automatic), ["gpt-6-astra"])
        self.assertEqual(phases(automatic), ["analyze"])
        forbidden = route("use gpt-6-astra but do not use gpt-6-astra")
        self.assertNotIn("gpt-6-astra", models(forbidden))

    def test_bounded_behavior_fix_low_and_complex_guard(self):
        result = route("fix off-by-one in a local helper")
        self.assertEqual(models(result), ["gpt-6.1-sol", "gpt-6-luna"])
        self.assertEqual(result["phases"][0]["effort"], "low")
        complex_result = route("fix off-by-one in production migration")
        self.assertEqual(complex_result["task_class"], "complex")

    def test_ordinary_failure_count_does_not_upgrade_without_consequence(self):
        result = route("ordinary feature missing dependency and bad path", sol_failures=3)
        self.assertEqual(result["phases"][1]["effort"], "medium")
        self.assertFalse(result["escalation"]["astra_selected"])


if __name__ == "__main__":
    unittest.main()
