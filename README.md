# Report2Patch Skill

This repository packages a Codex skill for turning Linux kernel memory bug
reports into draft or submittable patch bundles.

Key files:

- `SKILL.md` defines trigger conditions, the main workflow, and downgrade policy.
- `ARCHITECTURE.md` explains the repository layout and where prompt text lives.
- `references/` holds the input contract, workflow state machine, output bundle rules, and runtime examples.
- `tests/test_skill_structure.py` validates that the skill metadata and required references are present.

Run the local validation suite with:

```bash
python3 -m unittest discover -s tests
```
