# Failure Notes Template

Use this template when writing `${kasan_artifact_dir}/failure-notes.md`.

## When to write

Write or append a note when a blocking failure happens in environment setup, build execution, or runtime invocation.

Typical examples:

- KASAN mode or debug config is wrong for the intended repro
- The repro command cannot run as expected
- The repository state is damaged, such as an overwritten top-level `Makefile`
- The build fails before a final patch bundle can be assembled

## Entry Template

```md
### Failure <N>

- `Step:` Check environment | Attempt repro | Build/validate | Attempt repro after fix
- `Error:` Short description of what failed
- `Cause:` Known or suspected reason
- `Context:` KASAN mode, command used, paths, repo state, or other evidence needed to understand the failure
- `Outcome:` Stopped | Downgraded to `build-only` | Downgraded to `not-runtime-verified`
- `Related artifacts:` Optional paths to logs, screenshots, or saved command output
```

## Example Entry

```md
### Failure 1

- `Step:` Build/validate
- `Error:` Kernel build stopped before linking `vmlinux`
- `Cause:` The top-level `Makefile` had been overwritten by an unrelated local edit
- `Context:` `make -j$(nproc)` failed immediately after parsing the root `Makefile`; runtime validation was not attempted
- `Outcome:` Stopped
- `Related artifacts:` `/tmp/report2patch/build.log`
```

## Writing Rules

- Append new failures to the same file instead of replacing older entries.
- Keep the note human-readable; this is an execution record, not a machine format.
- Record concrete evidence, not guesses alone.
- If the workflow downgraded instead of stopping, make that explicit in `Outcome:`.
