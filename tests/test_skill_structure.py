import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class Report2PatchSkillStructureTests(unittest.TestCase):
    def test_skill_md_has_required_frontmatter_and_sections(self):
        skill_md = REPO_ROOT / "SKILL.md"
        self.assertTrue(skill_md.exists(), "SKILL.md must exist at the repo root")

        content = skill_md.read_text(encoding="utf-8")
        self.assertRegex(content, r"^---\nname: report2patch\n", "skill name must be report2patch")
        self.assertIn("description:", content)

        required_sections = [
            "## When to use this skill",
            "## Required inputs",
            "## Workflow",
            "## Failure and downgrade policy",
            "## Final deliverables",
        ]
        for section in required_sections:
            self.assertIn(section, content, f"missing section: {section}")

    def test_agents_openai_yaml_exists_with_default_prompt(self):
        openai_yaml = REPO_ROOT / "agents" / "openai.yaml"
        self.assertTrue(openai_yaml.exists(), "agents/openai.yaml must exist")

        content = openai_yaml.read_text(encoding="utf-8")
        self.assertIn('display_name: "Report2Patch"', content)
        self.assertIn('default_prompt: "Use $report2patch', content)

        match = re.search(r'short_description: "([^"]+)"', content)
        self.assertIsNotNone(match, "short_description must exist")
        self.assertGreaterEqual(len(match.group(1)), 25)
        self.assertLessEqual(len(match.group(1)), 64)

    def test_reference_docs_cover_contracts_and_state_machine(self):
        expected_files = {
            "specs/input-contract.md": [
                "Required fields",
                "Optional fields",
                "Environment prerequisites",
            ],
            "specs/workflow-state-machine.md": [
                "Parse report",
                "Wait for user confirmation",
                "Assemble final bundle",
            ],
            "specs/output-bundle.md": [
                "Runtime verification states",
                "Patch bundle",
                "Maintainer list",
            ],
        }

        for relative_path, required_snippets in expected_files.items():
            file_path = REPO_ROOT / relative_path
            self.assertTrue(file_path.exists(), f"{relative_path} must exist")
            content = file_path.read_text(encoding="utf-8")
            for snippet in required_snippets:
                self.assertIn(snippet, content, f"{relative_path} must mention {snippet!r}")

    def test_runtime_status_semantics_match_current_plan(self):
        output_bundle = (REPO_ROOT / "specs" / "output-bundle.md").read_text(encoding="utf-8")

        self.assertIn("runtime reproduction or runtime re-validation was attempted and failed", output_bundle)
        self.assertIn("runtime validation was intentionally skipped or explicitly not recommended", output_bundle)
        self.assertIn("failure-notes.md", output_bundle)

    def test_failure_notes_are_defined_under_kasan_artifact_dir(self):
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        required_snippets = [
            "`${kasan_artifact_dir}/failure-notes.md`",
            "blocking failures",
            "step, cause, and context",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, input_contract + workflow + guide, f"docs must mention {snippet!r}")

    def test_failure_note_template_exists_with_required_fields(self):
        template = REPO_ROOT / "templates" / "failure-notes-template.md"
        self.assertTrue(template.exists(), "failure note template must exist")

        content = template.read_text(encoding="utf-8")
        required_snippets = [
            "# Failure Notes Template",
            "## Entry Template",
            "`Step:`",
            "`Error:`",
            "`Cause:`",
            "`Context:`",
            "`Outcome:`",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, content, f"template must mention {snippet!r}")

    def test_architecture_doc_exists_with_prompt_locations(self):
        architecture = REPO_ROOT / "ARCHITECTURE.md"
        self.assertTrue(architecture.exists(), "ARCHITECTURE.md must exist")

        content = architecture.read_text(encoding="utf-8")
        required_snippets = [
            "# Report2Patch Architecture",
            "## File Layout",
            "## Prompt Sources",
            "`SKILL.md`",
            "`agents/openai.yaml`",
            "`guide.md`",
            "`specs/input-contract.md`",
            "`templates/failure-notes-template.md`",
            "`references/commit_example.txt`",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, content, f"architecture doc must mention {snippet!r}")

    def test_commit_generation_starts_from_subject(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        output_bundle = (REPO_ROOT / "specs" / "output-bundle.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        required_snippets = [
            "start from `Subject:`",
            "Do not include the leading mail headers",
            "`From:`",
            "`Date:`",
        ]
        combined = skill_md + output_bundle + guide
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")

    def test_workspace_path_conventions_are_documented(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")
        example_readme = (REPO_ROOT / "references" / "example" / "README.md").read_text(encoding="utf-8")

        combined = skill_md + input_contract + guide + example_readme
        required_snippets = [
            "$PWD/patch",
            "/tmp/<function-or-bug-tag>",
            "kasan_artifact_dir/pre-fix",
            "kasan_artifact_dir/post-fix",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")

    def test_new_bug_branch_is_named_after_bug_function(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        combined = skill_md + input_contract + workflow + guide
        required_snippets = [
            "create a new branch in `kernel_tree`",
            "named after the bug function",
            "use that function name as `work_branch`",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")

    def test_base_branch_is_updated_before_work_branch_rebase(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        combined = (skill_md + input_contract + workflow + guide).lower()
        required_snippets = [
            "switch to `base_branch` first",
            "`git pull --ff-only`",
            "rebase `work_branch` onto the updated `base_branch`",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet.lower(), combined, f"docs must mention {snippet!r}")

    def test_user_must_approve_fix_plan_and_commit_before_commit_or_patch(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        combined = (skill_md + workflow + guide).lower()
        required_snippets = [
            "Show the user the code modification plan and commit draft",
            "must explicitly approve",
            "do not generate the final commit or patch until that approval is given",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet.lower(), combined, f"docs must mention {snippet!r}")

    def test_runtime_repro_requires_qemu_kasan_and_markdown_record(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        combined = skill_md + input_contract + workflow + guide
        required_snippets = [
            "configure the correct Linux build options",
            "run in QEMU",
            "password `root`",
            "record the complete reproducible process to a Markdown file",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")

    def test_config_file_exists_with_runtime_and_path_defaults(self):
        config_path = REPO_ROOT / "report2patch.yaml"
        self.assertTrue(config_path.exists(), "report2patch.yaml must exist")

        content = config_path.read_text(encoding="utf-8")
        required_snippets = [
            "patch_output_dir: \"$PWD/patch\"",
            "qemu_root_password: \"root\"",
            "require_kasan_report: true",
            "repro_markdown_path: \"${kasan_artifact_dir}/repro-steps.md\"",
            "require_commit_self_check: true",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, content, f"config must mention {snippet!r}")

    def test_commit_self_check_happens_before_patch_generation(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        output_bundle = (REPO_ROOT / "specs" / "output-bundle.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        combined = skill_md + workflow + output_bundle + guide
        required_snippets = [
            "self-check the commit content against common Linux patch submission conventions",
            "before generating the patch",
            "Subject line style",
            "Signed-off-by",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")

    def test_commit_draft_is_written_to_bug_specific_commit_md(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        input_contract = (REPO_ROOT / "specs" / "input-contract.md").read_text(encoding="utf-8")
        output_bundle = (REPO_ROOT / "specs" / "output-bundle.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "specs" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")
        config = (REPO_ROOT / "report2patch.yaml").read_text(encoding="utf-8")

        combined = skill_md + input_contract + output_bundle + workflow + guide + config
        required_snippets = [
            "tools/testing/report2patch/${work_branch}/commit.md",
            "write the commit draft",
            "Subject",
            "references/commit_example.txt",
            "Signed-off-by",
            "recipient list",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")


if __name__ == "__main__":
    unittest.main()
