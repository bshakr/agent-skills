# bin

Command-line tools the skills in this repo call by name. Dependencies: `bash`, `python3`, `gh`,
`jq`, `git`, `linear`; Pillow is optional and detected at runtime by `rp-gallery`.

```bash
for s in pr-ci-wait pr-append-section rp-gallery linear-start; do
  ln -sfn ~/code/agent-skills/bin/$s ~/.local/bin/$s
done
```

## `pr-ci-wait`

```
pr-ci-wait <pr-number|pr-url> [--repo owner/name] [--timeout 1800] [--interval 30]
```

Waits for a check to register (GitHub takes 30 to 90 s after a push), then for nothing to be pending,
then prints a `RESULT / CHECK / STATE / URL` table. Repo: the URL, `--repo`, then the cwd origin. One
stderr progress line per poll, so `Monitor` can watch it. Never `--watch`: it re-reads the head SHA each
poll and restarts on a push, so it cannot pass on a stale run. A **required** check reporting `skipped`
is red and named. Reads `gh pr checks --json name,state,bucket,link,workflow`, falling back to
`gh pr view --json statusCheckRollup`; on a failure it prints names, URLs and 40 lines of `--log-failed`.

Exit: **0** green, **1** failing/cancelled or skipped-required, **2** timeout, **3** PR not found or not
open, **64** usage.

## `pr-append-section`

```
pr-append-section <pr|url> --title "## Screenshots" (--file f.md | --text "...")
                  [--replace] [--repo owner/name] [--top] [--dry-run]
```

Adds or replaces one section and leaves every other byte alone, re-fetching the live body immediately
before writing. Heading match is exact on the heading line; a section runs to the next heading of the
same or higher level. Existing section: `--replace` swaps its content, else the text is appended, and
appending the same text twice is a no-op. New section: after Summary, at the top with `--top`, else at
the end. Writes `gh api -X PATCH -F body=@tmpfile`, never `gh pr edit`, never through a shell, so
backticks and `$(...)` stay literal; CRLF survives. Then compares the whole live body byte-for-byte.

Exit: **0** written or already present, **1** write or verify failed (prints a diff), **3** PR not found, **64** usage.

## `rp-gallery`

```
rp-gallery <manifest.json> --out <gallery.html> [--max-mb 15]
```

One self-contained page: PR and ticket links as real anchors at the top (`PR: pending` when `pr_url` is
empty), intro, then each pair side by side with the label above each image, route/state/viewport, a note,
and a "byte-identical, no change" badge on `identical: true` pairs; `solos` render single. `<title>` from
the manifest, images inlined as data URIs, zero external resources, Artifact theme tokens, safe at 400px,
paths relative to the manifest. With Pillow it converts to JPEG q85 and walks a scale/quality ladder until
the page fits `--max-mb`, printing per-image sizes. It cannot publish; the coordinator does that.

Exit: **0** built, **1** cannot fit `--max-mb`, **2** manifest invalid or an image is missing (every
missing path listed), **64** usage.

## `linear-start`

```
linear-start <TICKET-ID>
```

Runs `linear issue start`, which lands the ticket in "In Review" because it picks the first workflow state
of type `started`, then forces `--state "In Progress"`, then re-reads with `linear issue show` and fails if
the state did not stick. Prints the branch name on stdout (everything else on stderr) plus the worktree
command. It does **not** run `linear branch <id>`: that does a real `git checkout -b` in the current repo,
so the name is derived from the title with the CLI's own slug rule instead (verified to match).

Exit: **0** In Progress, **1** state did not stick or a CLI call failed, **3** ticket not found, **4** CLI
unauthenticated (prints `linear login`), **64** usage.
