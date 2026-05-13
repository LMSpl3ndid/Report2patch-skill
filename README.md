# Report2Patch Skill

This repository packages a Codex skill for turning Linux kernel memory bug
reports into draft or submittable patch bundles.

Key files:

- `SKILL.md` defines trigger conditions, the main workflow, and downgrade policy.
- `report2patch.yaml` centralizes default path and runtime settings.
- `ARCHITECTURE.md` explains the repository layout and where prompt text lives.
- `specs/` holds the normative input, workflow, and output contracts.
- `templates/` holds reusable output templates such as failure notes.
- `references/` holds style examples and runtime reproducer material.
- `tests/test_skill_structure.py` validates that the skill metadata and required references are present.

Run the local validation suite with:

```bash
python3 -m unittest discover -s tests
```
