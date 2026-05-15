---
name: report2patch
description: Use when you need to turn a Linux kernel memory-management bug report into a draft or submittable patch bundle with a proposed fix, commit text, validation status, checkpatch output, and maintainer routing.
---

# Report2Patch

## When to use this skill

Use this skill when all of the following are true:

- The target codebase is the Linux kernel.
- The report describes a memory-management bug or nearby lifetime issue.
- The initial signal comes from static analysis, even if runtime validation is attempted later.
- The goal is a patch bundle, not just a diagnosis.

Do not use this skill for generic bug triage, non-kernel projects, or multi-bug reports that need multiple unrelated patches.

## Required inputs

Require these inputs before doing any patch work:

- `bug_report_text`
- `kernel_tree`
- `base_branch`
- `work_branch`
- `patch_output_dir`
- `kasan_artifact_dir`

For the current workspace, prefer `patch_output_dir=$PWD/patch`.
Choose `kasan_artifact_dir` per bug so artifacts do not collide between reports, for example `/tmp/<function-or-bug-tag>`.
Centralize default values in [report2patch.yaml](report2patch.yaml).

Optional inputs:

- `signed_off`
- `repro_scripts_dir`
- `commit_template_path`
- `extra_context_files`

Read [specs/input-contract.md](specs/input-contract.md) for field definitions, preflight checks, and early-stop conditions.
Use [templates/failure-notes-template.md](templates/failure-notes-template.md) when writing `${kasan_artifact_dir}/failure-notes.md`.
Use [templates/commit-draft-template.md](templates/commit-draft-template.md) when writing `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`.

## Workflow

Follow this flow in order:

1. Validate scope and inputs.
2. Read the report and identify the failing path, affected subsystem, and likely fix shape.
3. Run the environment preflight for the kernel tree, required scripts, build toolchain, and optional runtime environment.
4. Before patch work, switch to `base_branch` first and update it with `git pull --ff-only`.
5. For a new bug, create a new branch in `kernel_tree` named after the bug function and use that function name as `work_branch`. Never edit on `main` or `master`.
6. Rebase `work_branch` onto the updated `base_branch` before editing.
7. When runtime validation is attempted, configure the correct Linux build options, run in QEMU with password `root` to obtain a KASAN report, and record the complete reproducible process to a Markdown file at `${kasan_artifact_dir}/repro-steps.md`. Store pre-fix artifacts without overwriting older logs.
8. Draft the fix plan and full commit message, and write the commit draft to `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`.
9. The commit draft file must include the Subject, a description modeled after `references/commit_example.txt`, the configurable `Signed-off-by`, and the recipient list for the bug.
10. Show the user the code modification plan and commit draft.
11. The user must explicitly approve before any final commit or patch generation.
12. After approval, implement the fix, build, and re-run runtime validation when feasible.
13. Generate the commit information.
14. Self-check the commit content against common Linux patch submission conventions before generating the patch.
15. Generate the patch, checkpatch summary, maintainer list, and final status bundle.

When generating commit information from a mail-style example, start from `Subject:` and then generate the commit title and body from there.
Do not include the leading mail headers such as `From:`, `Date:`, or the `From <sha> Mon Sep 17 00:00:00 2001` envelope line.

Read [specs/workflow-state-machine.md](specs/workflow-state-machine.md) for per-state transitions and required outputs.

## Failure and downgrade policy

- If required inputs are missing, stop and ask for them before touching the tree.
- If the report is out of scope, say so explicitly and do not force the workflow.
- If runtime reproduction or runtime re-validation was attempted and failed after a successful build, continue only with `build-only`.
- If runtime validation was intentionally skipped or explicitly not recommended, continue only with `not-runtime-verified`.
- If build, `checkpatch.pl`, or `get_maintainer.pl` cannot run, report the exact missing dependency or tool path.
- Record blocking environment, build, or runtime-invocation failures in `${kasan_artifact_dir}/failure-notes.md`.
- Never present a patch as runtime-verified unless the pre-fix symptom was reproduced and the post-fix run removed that symptom.

Use these final status labels:

- `runtime-verified` for successful pre-fix and post-fix runtime evidence
- `build-only` for successful builds where runtime reproduction or re-validation was attempted and failed
- `not-runtime-verified` for cases where runtime validation was intentionally skipped or explicitly not recommended

Read [specs/output-bundle.md](specs/output-bundle.md) for the exact downgrade rules and delivery format.

## Final deliverables

The successful output bundle must include:

- The final commit message.
- The `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md` path.
- The generated `git format-patch` path.
- A validation summary with one of the approved runtime status labels.
- The `checkpatch.pl` result summary.
- The maintainer and recipient list from `get_maintainer.pl`.
- Paths to pre-fix and post-fix artifacts when runtime validation was attempted.
- The `${kasan_artifact_dir}/repro-steps.md` path when runtime validation was attempted.
- The `${kasan_artifact_dir}/failure-notes.md` path when blocking failures were recorded.

Use [references/commit_example.txt](references/commit_example.txt) as a style reference, but start from `Subject:` when generating commit information and skip the leading mail headers.
Use [templates/commit-draft-template.md](templates/commit-draft-template.md) for the bug-specific commit draft, use [templates/failure-notes-template.md](templates/failure-notes-template.md) for blocking failure notes, and use the scripts under [references/example](references/example) when a real runtime workflow is needed.
