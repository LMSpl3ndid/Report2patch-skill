# Workflow State Machine

Use this state machine to keep the skill deterministic and to avoid pretending success when a step downgraded.

| State | Required action | Success transition | Failure or downgrade |
| --- | --- | --- | --- |
| Parse report | Identify subsystem, bug class, failing path, and whether the report is in scope. | Move to `Check environment`. | Stop if out of scope or the report is too incomplete to reason about. |
| Check environment | Verify `kernel_tree`, branch refs, build prerequisites, and submission tools. | Move to `Sync branch`. | Stop on missing required inputs and record blocking failures in `${kasan_artifact_dir}/failure-notes.md` when environment context is available. Mark later outputs partial if optional tools are missing. |
| Sync branch | Switch to `base_branch` first, update it with `git pull --ff-only`, then for a new bug create a new branch in `kernel_tree` named after the bug function and use that function name as `work_branch`. Rebase `work_branch` onto the updated `base_branch`. Never keep work on `main` or `master`. | Move to `Attempt repro`. | Stop if the repository state is unsafe, the bug function cannot be identified, the base branch cannot be updated cleanly, or the branch cannot be prepared cleanly. |
| Attempt repro | Configure the correct Linux build options, run in QEMU with password `root` to obtain a KASAN report, record the complete reproducible process to `${kasan_artifact_dir}/repro-steps.md`, and save the pre-fix logs under `kasan_artifact_dir/pre-fix`. | Move to `Draft fix plan`. | If runtime validation was intentionally skipped or explicitly not recommended, continue on a `not-runtime-verified` path. If runtime invocation was attempted and failed, record the step, cause, and context in `${kasan_artifact_dir}/failure-notes.md` and continue on a potential `build-only` path. |
| Draft fix plan | Write the root-cause summary, candidate code change, risk notes, and full commit draft. Write the commit draft to `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`. The draft must include Subject, a description modeled after `references/commit_example.txt`, configurable `Signed-off-by`, and the bug recipient list. | Move to `Implement fix`. | Stop if the likely fix is still ambiguous. |
| Implement fix | Apply the smallest viable change that matches the approved plan. | Move to `Build/validate`. | Stop if the implementation invalidates the approved plan. |
| Build/validate | Build the kernel or relevant target to confirm the patch is at least compilable. | Move to `Attempt repro after fix`. | Stop if the build cannot succeed, and record the blocking failure in `${kasan_artifact_dir}/failure-notes.md`. A build failure is not a successful final runtime state. |
| Attempt repro after fix | Re-run the runtime workflow in QEMU, update `${kasan_artifact_dir}/repro-steps.md` with the post-fix path, and save logs under `kasan_artifact_dir/post-fix` without overwriting pre-fix logs. | Move to `Generate commit`. | If runtime re-validation was attempted and failed after a successful build, record the step, cause, and context in `${kasan_artifact_dir}/failure-notes.md` and use `build-only`. If runtime re-validation was intentionally skipped or explicitly not recommended, use `not-runtime-verified`. |
| Generate commit | Create the final commit message and commit object, including verification wording that matches the evidence. | Move to `Commit self-check`. | Stop if the message cannot honestly describe the validation state. |
| Commit self-check | Self-check the commit content against common Linux patch submission conventions before generating the patch. Check Subject line style, mail-header exclusion, body rationale, `Signed-off-by`, and any justified `Fixes:` or `Cc: stable@vger.kernel.org`. | Move to `Generate patch`. | Stop and revise the commit draft if the self-check fails. |
| Generate patch | Run `git format-patch` into `patch_output_dir`. | Move to `Run checkpatch`. | Stop if patch generation fails. |
| Run checkpatch | Run `scripts/checkpatch.pl` on the patch files and save a summary. | Move to `Collect maintainers`. | Continue with a partial bundle if the script is unavailable, but say so explicitly. |
| Collect maintainers | Run `scripts/get_maintainer.pl` for the touched files and capture recipients. Select one primary `To:` recipient and place every other recipient under `Cc:` for `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`. | Move to `Assemble final bundle`. | Continue with a partial bundle if the script is unavailable, but say so explicitly. |
| Assemble final bundle | Present patch paths, final commit text, `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`, validation state, checkpatch summary, maintainer list, artifact paths, and `${kasan_artifact_dir}/failure-notes.md` when it exists. | Done. | Never omit degraded or missing pieces. |

## User Interaction

The default flow does not require a mandatory user-approval gate before commit or patch generation. The generated `commit.md` draft remains available for optional inspection.

## Artifact handling

- Save pre-fix runtime artifacts under `kasan_artifact_dir/pre-fix`.
- Save post-fix runtime artifacts under `kasan_artifact_dir/post-fix`.
- Save the complete reproducible runtime flow under `${kasan_artifact_dir}/repro-steps.md`.
- Save blocking failure notes under `${kasan_artifact_dir}/failure-notes.md`.
- Each failure note entry must include the step, cause, and context for the failure.
- Never overwrite pre-fix logs with post-fix data.
