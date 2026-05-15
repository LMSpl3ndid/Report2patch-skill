# Output Bundle

## Runtime verification states

Use exactly one of these labels in the final summary:

- `runtime-verified`
  The pre-fix symptom was reproduced, the fix was applied, and the post-fix run removed the targeted symptom.
- `build-only`
  The patch built successfully, but runtime reproduction or runtime re-validation was attempted and failed.
- `not-runtime-verified`
  This status applies when runtime validation was intentionally skipped or explicitly not recommended.

Never upgrade the status without fresh evidence.
Do not use a successful final runtime status when the build itself failed.

## Patch bundle

The final bundle should include:

- Final commit message text.
- The `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md` path.
- The `git format-patch` output path or paths.
- A short validation summary with the runtime status label.
- A short `checkpatch.pl` result summary.
- Paths to pre-fix and post-fix artifacts when they exist.
- The `${kasan_artifact_dir}/repro-steps.md` path when runtime validation was attempted.
- The `${kasan_artifact_dir}/failure-notes.md` path when blocking failures were recorded.

The commit message should cover:

- Start from `Subject:` when deriving the commit title and body from a mail-style example.
- Do not include the leading mail headers such as `From:`, `Date:`, or the `From <sha> Mon Sep 17 00:00:00 2001` envelope line.
- The direct bug cause.
- The fix strategy.
- The detection source or tool statement.
- The runtime validation result.
- Any `Fixes:` tag that can be justified.
- Whether `Cc: stable@vger.kernel.org` is recommended.
- The chosen `Signed-off-by:` line when one was provided.
- The recipient list for the bug, with one `To:` recipient and all remaining recipients under `Cc:`.

The bug-specific `commit.md` draft should include:

- Subject
- Description modeled after `references/commit_example.txt`
- Configurable `Signed-off-by`
- Recipient list for the bug

Before generating the patch, self-check the commit content against common Linux patch submission conventions:

- Subject line style is patch-like and subsystem-scoped
- Leading mail headers are excluded
- The body explains the bug cause and fix rationale
- `Signed-off-by:` is present when provided or required by workflow
- `Fixes:` and `Cc: stable@vger.kernel.org` are included only when justified

## KASAN excerpt rules

- Remove timestamp prefixes such as bracketed clock values.
- Keep the relevant warning and stack context intact.
- Do not reduce the report to a single line if the stack is important to understanding the bug.
- Make it clear whether the quoted excerpt came from the pre-fix reproduction or from another saved artifact.

## Maintainer list

The maintainer section should include:

- Primary maintainers from `scripts/get_maintainer.pl`.
- Mailing lists returned by that script.
- Any explicit note about missing maintainer tooling or ambiguous touched paths.

## Failure notes

Use `${kasan_artifact_dir}/failure-notes.md` for blocking failures tied to environment setup, build execution, or runtime invocation.

Each note entry should include:

- Failed step name
- Short error description
- Known or suspected cause
- Relevant context such as KASAN mode, invocation command, or damaged repository state
- Whether the workflow stopped or downgraded

## Stable-routing guidance

Recommend `Cc: stable@vger.kernel.org` only when the bug affects released kernels and the patch is small and backportable enough to justify stable submission.
