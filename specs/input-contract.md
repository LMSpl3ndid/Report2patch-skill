# Input Contract

This skill expects the bug report itself to be provided in the conversation, then combines it with explicit repository and artifact parameters.

## Required fields

- `bug_report_text`
  The raw report text or a faithful copy of the relevant report excerpt.
- `kernel_tree`
  Absolute path to the Linux kernel git checkout that will be modified.
- `base_branch`
  Branch or ref that defines the baseline for rebasing and review.
- `work_branch`
  Branch name reserved for the patch work. For a new bug, create a new branch in `kernel_tree` named after the bug function and use that function name as `work_branch`. Create or reset it from the chosen base before editing.
  Use that function name as `work_branch` consistently through patch generation and validation.
- `patch_output_dir`
  Absolute host path where `git format-patch` output and related mail artifacts will be stored. In the current workspace, prefer `$PWD/patch`.
- `kasan_artifact_dir`
  Absolute host path where pre-fix and post-fix runtime logs will be saved. This directory also owns the derived failure note path `${kasan_artifact_dir}/failure-notes.md`. Name this directory per bug so runs do not collide, for example `/tmp/<function-or-bug-tag>`.

Derived output paths:

- `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`
  Bug-specific commit draft path. `work_branch` is the bug-function name for new bugs, so this path changes per bug.

Default values are centralized in `report2patch.yaml`. User-provided inputs override those defaults.

## Optional fields

- `signed_off`
  Exact `Signed-off-by:` line to append to the commit message.
- `repro_scripts_dir`
  Absolute directory containing repro helpers or host/guest scripts. If this is not provided, prefer a matching directory under `kernel_tree` when it exists; otherwise fall back to skill-bundled examples.
- `commit_template_path`
  Absolute file path used as a local style or structure hint for the commit body.
- `extra_context_files`
  Additional absolute paths to report files, traces, or notes that sharpen the diagnosis.

## Environment prerequisites

- `kernel_tree` must be a Linux kernel git repository.
- `base_branch` must resolve in that repository.
- Before creating or switching to `work_branch`, switch to `base_branch` first and update it with `git pull --ff-only`.
- Create `patch_output_dir` and `kasan_artifact_dir` with `mkdir -p` when they do not already exist.
- Create `${kernel_tree}/tools/testing/report2patch/${work_branch}` when it does not already exist.
- `scripts/checkpatch.pl` and `scripts/get_maintainer.pl` should exist if final submission artifacts are expected.
- A working build environment must exist if the skill is expected to claim `build-only` or `runtime-verified`.
- When runtime validation is attempted, configure the correct Linux build options first.
- A runtime environment such as QEMU or another targeted test rig is optional, but required for `runtime-verified`.
- When QEMU is used for runtime validation, the guest must be reachable with password `root`.
- When runtime validation is attempted, record the complete reproducible process to a Markdown file at `${kasan_artifact_dir}/repro-steps.md`.

## Failure note artifact

- Use `${kasan_artifact_dir}/failure-notes.md` for blocking failures tied to environment setup, build execution, or runtime invocation.
- Record concrete failures such as a broken KASAN setup, invalid repro command, or repository damage like an overwritten top-level `Makefile`.
- Each entry must capture the step, cause, and context needed to explain what failed and why.
- Append later failures to the same file instead of creating per-step note files.

## Early-stop conditions

Stop before editing when any of these are true:

- The report is not a Linux kernel memory-management issue.
- The report clearly needs multiple unrelated fixes.
- `kernel_tree`, `base_branch`, or `work_branch` is missing.
- The user only wants diagnosis and not a patch bundle.

## Normalization rules

- Keep the original report text intact in working notes.
- Normalize derived KASAN excerpts later, not at intake time.
- Prefer explicit paths over guesses. Do not infer `kernel_tree` or branch names from the report.
- Treat `patch_output_dir`, `kasan_artifact_dir`, `repro_scripts_dir`, `commit_template_path`, and `extra_context_files` as host paths, not guest paths.
- In the current workspace, use `$PWD/patch` as the default `patch_output_dir` unless the user overrides it.
- When handling a new bug, derive `work_branch` from the primary bug function identified in the report and create that branch in `kernel_tree` before editing.
- Rebase `work_branch` onto the updated `base_branch` before making code changes.
- When runtime artifacts are needed, choose a bug-specific `kasan_artifact_dir` such as `/tmp/rbd_add_disk_uaf` and then store logs under its `pre-fix` and `post-fix` subdirectories.
- When runtime validation is attempted, save the reproducible host/guest flow in `${kasan_artifact_dir}/repro-steps.md`.
- Write the commit draft to `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`.
