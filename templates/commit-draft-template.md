# Commit Draft Template

Use this template when writing `${kernel_tree}/tools/testing/report2patch/${work_branch}/commit.md`.

## Required Sections

```md
# Subject

<subsystem>: <short summary>

# Description

<Body text modeled after references/commit_example.txt. Explain bug cause, fix rationale, and any runtime validation result.>

# Signed-off-by

<Exact Signed-off-by: line, if provided or required>

# Recipients

To:
- <primary recipient chosen from get_maintainer output>

Cc:
- <all remaining recipients from get_maintainer output>
```

## Writing Rules

- Start the draft from the commit `Subject` line, not from mail envelope headers.
- Model the description section after `references/commit_example.txt`.
- Keep only one primary `To:` recipient.
- Put every other recipient under `Cc:`.
