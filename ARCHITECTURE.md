# Report2Patch Architecture

This repository packages one Codex skill plus supporting spec, template, and reference material. The skill itself is documentation-driven: behavior is defined by prompt text in `SKILL.md`, narrowed by `specs/` and `templates/`, and sanity-checked by the local unit tests.

## File Layout

- `SKILL.md`
  The primary skill prompt. It defines when the skill should trigger, required inputs, the workflow, downgrade rules, and final deliverables.
- `agents/openai.yaml`
  UI-facing metadata for the skill. This includes the human display name, short description, and the default prompt snippet shown when the skill is invoked.
- `guide.md`
  Chinese quick guide. It is not the canonical spec, but it mirrors the main workflow and is useful for fast orientation.
- `report2patch.yaml`
  Centralized defaults for paths, git behavior, runtime expectations, and submission gates.
- `specs/input-contract.md`
  Input and environment contract, including the meaning of `kasan_artifact_dir` and the derived `${kasan_artifact_dir}/failure-notes.md`.
- `specs/workflow-state-machine.md`
  State-machine view of the workflow, including stop, downgrade, and artifact rules.
- `specs/output-bundle.md`
  Contract for final output status labels and required artifacts.
- `templates/failure-notes-template.md`
  Template for the runtime/build/environment failure record written to `${kasan_artifact_dir}/failure-notes.md`.
- `references/commit_example.txt`
  Commit-message style reference used as an output example for the generated patch email/commit text.
- `references/example/`
  Runtime repro examples and host/guest helper scripts. These are operational references, not prompt sources.
- `tests/test_skill_structure.py`
  Local regression checks for the documentation contract. These tests verify that the required files and key semantics remain present.

## Prompt Sources

The skill does not rely on one single prompt file. Its effective prompt is assembled from several layers:

1. `SKILL.md`
   This is the main prompt source. The frontmatter controls discovery, and the body controls agent behavior once the skill is loaded.
2. `agents/openai.yaml`
   The `default_prompt` field is the user-facing invocation snippet. It is not the full workflow, but it influences how the skill is started.
3. `guide.md`
   This is a secondary prompt aid for humans and future editors. It restates the flow in Chinese and helps keep the short explanation aligned with the canonical docs.
4. `specs/input-contract.md`
   Supplies the parameter contract and preflight assumptions the model is expected to follow.
5. `specs/workflow-state-machine.md`
   Supplies the state transitions and failure behavior that refine the high-level workflow in `SKILL.md`.
6. `specs/output-bundle.md`
   Supplies the output semantics, especially the meaning of `runtime-verified`, `build-only`, and `not-runtime-verified`.
7. `templates/failure-notes-template.md`
   Supplies the expected shape of `${kasan_artifact_dir}/failure-notes.md` so error records stay consistent.
8. `references/commit_example.txt`
   Supplies an example output style for commit text. It is a style reference, not a rule source.

## Prompt Boundaries

- Canonical prompt logic lives in `SKILL.md` plus the Markdown files under `specs/` and `templates/`.
- Default configuration values live in `report2patch.yaml`.
- UI/invocation prompt text lives in `agents/openai.yaml`.
- Human quick-start wording lives in `guide.md`.
- Example artifacts such as `references/commit_example.txt` and `references/example/` should guide output style and repro setup, but they should not silently override the rules in `SKILL.md`.

## Data and Artifact Flow

1. The user provides `bug_report_text` and explicit repository/output paths.
2. The skill reads the contract and validates the environment.
3. Runtime artifacts are written under `kasan_artifact_dir/pre-fix` and `kasan_artifact_dir/post-fix`.
4. The complete reproducible runtime flow is written to `${kasan_artifact_dir}/repro-steps.md`.
5. Blocking environment/build/runtime invocation problems are written to `${kasan_artifact_dir}/failure-notes.md`.
6. Patch artifacts are written under `patch_output_dir`.
7. Final status and maintainer routing are assembled from the state machine and output-bundle contract.

## Current Constraints

- This skill is scoped to Linux kernel memory-management or lifetime bugs.
- The current repository validates documentation structure, not full agent behavior under pressure scenarios.
- The real runtime workflow still depends on external kernel trees, build tools, and repro environments outside this repository.
