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

For the current workspace, prefer `patch_output_dir=/home/gzl/linux/patch`.
Choose `kasan_artifact_dir` per bug so artifacts do not collide between reports, for example `/tmp/<function-or-bug-tag>`.

Optional inputs:

- `signed_off`
- `repro_scripts_dir`
- `commit_template_path`
- `extra_context_files`

Read [references/input-contract.md](references/input-contract.md) for field definitions, preflight checks, and early-stop conditions.
Use [references/failure-notes-template.md](references/failure-notes-template.md) when writing `${kasan_artifact_dir}/failure-notes.md`.

## Workflow

Follow this flow in order:

1. Validate scope and inputs.
2. Read the report and identify the failing path, affected subsystem, and likely fix shape.
3. Run the environment preflight for the kernel tree, required scripts, build toolchain, and optional runtime environment.
4. Sync or create `work_branch`. Never edit on `main` or `master`.
5. Attempt a runtime reproduction when it is feasible and justified. Store pre-fix artifacts without overwriting older logs.
6. Draft the fix plan and full commit message.
7. Stop once for user review after the fix plan and commit draft are ready.
8. After approval, implement the fix, build, and re-run runtime validation when feasible.
9. Generate the commit, patch, checkpatch summary, maintainer list, and final status bundle.

When generating commit information from a mail-style example, start from `Subject:` and then generate the commit title and body from there.
Do not include the leading mail headers such as `From:`, `Date:`, or the `From <sha> Mon Sep 17 00:00:00 2001` envelope line.

Read [references/workflow-state-machine.md](references/workflow-state-machine.md) for per-state transitions and required outputs.

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

Read [references/output-bundle.md](references/output-bundle.md) for the exact downgrade rules and delivery format.

## Final deliverables

The successful output bundle must include:

- The final commit message.
- The generated `git format-patch` path.
- A validation summary with one of the approved runtime status labels.
- The `checkpatch.pl` result summary.
- The maintainer and recipient list from `get_maintainer.pl`.
- Paths to pre-fix and post-fix artifacts when runtime validation was attempted.
- The `${kasan_artifact_dir}/failure-notes.md` path when blocking failures were recorded.

Use [references/commit_example.txt](references/commit_example.txt) as a style reference, but start from `Subject:` when generating commit information and skip the leading mail headers.
Use [references/failure-notes-template.md](references/failure-notes-template.md) for blocking failure notes, and use the scripts under [references/example](references/example) when a real runtime workflow is needed.
