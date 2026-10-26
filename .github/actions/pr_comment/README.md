# pr_comment

A composite action that keeps one pull request comment up to date. It edits the
comment that holds the given marker, or posts one when there's none, so a
workflow that runs on every push updates its comment instead of adding another.
Failing to comment is a warning, not an error, since pull requests from forks
get a read-only token.

```yaml
permissions:
  pull-requests: write

steps:
  - uses: ./.github/actions/pr_comment
    with:
      marker: my-report # unique per report, so workflows don't clash
      body-file: report.md # or `body: …`
      create: 'false' # optional: only edit an existing comment
```

The inputs and outputs (`result`, `comment-id`) are described in
[action.yml](action.yml). The logic is in [pr_comment.py](pr_comment.py), which
only uses Python's standard library.

A workflow that checks out other commits before this step should reference the
action by commit (`firebase/firebase-ios-sdk/.github/actions/pr_comment@<sha>`),
since a local path is read from whatever is checked out.

[infra.pr_comment.yml](../../workflows/infra.pr_comment.yml) runs the unit
tests and comments on the pull request whenever the action changes. To run the
tests locally:

```bash
python3 -m unittest discover -s .github/actions/pr_comment -v
```
