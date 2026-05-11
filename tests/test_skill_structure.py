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
            "references/input-contract.md": [
                "Required fields",
                "Optional fields",
                "Environment prerequisites",
            ],
            "references/workflow-state-machine.md": [
                "Parse report",
                "Wait for user confirmation",
                "Assemble final bundle",
            ],
            "references/output-bundle.md": [
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
        output_bundle = (REPO_ROOT / "references" / "output-bundle.md").read_text(encoding="utf-8")

        self.assertIn("runtime reproduction or runtime re-validation was attempted and failed", output_bundle)
        self.assertIn("runtime validation was intentionally skipped or explicitly not recommended", output_bundle)
        self.assertIn("failure-notes.md", output_bundle)

    def test_failure_notes_are_defined_under_kasan_artifact_dir(self):
        input_contract = (REPO_ROOT / "references" / "input-contract.md").read_text(encoding="utf-8")
        workflow = (REPO_ROOT / "references" / "workflow-state-machine.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")

        required_snippets = [
            "`${kasan_artifact_dir}/failure-notes.md`",
            "blocking failures",
            "step, cause, and context",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, input_contract + workflow + guide, f"docs must mention {snippet!r}")

    def test_failure_note_template_exists_with_required_fields(self):
        template = REPO_ROOT / "references" / "failure-notes-template.md"
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
            "`references/commit_example.txt`",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, content, f"architecture doc must mention {snippet!r}")

    def test_commit_generation_starts_from_subject(self):
        skill_md = (REPO_ROOT / "SKILL.md").read_text(encoding="utf-8")
        output_bundle = (REPO_ROOT / "references" / "output-bundle.md").read_text(encoding="utf-8")
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
        input_contract = (REPO_ROOT / "references" / "input-contract.md").read_text(encoding="utf-8")
        guide = (REPO_ROOT / "guide.md").read_text(encoding="utf-8")
        example_readme = (REPO_ROOT / "references" / "example" / "README.md").read_text(encoding="utf-8")

        combined = skill_md + input_contract + guide + example_readme
        required_snippets = [
            "/home/gzl/linux/patch",
            "/tmp/<function-or-bug-tag>",
            "kasan_artifact_dir/pre-fix",
            "kasan_artifact_dir/post-fix",
        ]
        for snippet in required_snippets:
            self.assertIn(snippet, combined, f"docs must mention {snippet!r}")


if __name__ == "__main__":
    unittest.main()
