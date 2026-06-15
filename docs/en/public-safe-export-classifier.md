# Public-Safe Export Classifier

Driftless can reuse lessons from private maintainer work, but it should not copy
private artifacts into a public repository. The export classifier is a small
pre-publication gate for that boundary.

Use it before moving a note, prompt, lesson, issue summary, or workflow example
from a private work area into Driftless:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-PublicExportClassifier.ps1 -Path .\path\to\candidate.md
```

The gate scans only the file or folder you pass. It does not open credentials,
browser profiles, private agent homes, or forbidden files. It reuses the shared
forbidden-path and secret-token schema used by containment.

## Classifications

| Classification | Meaning | Next action |
| --- | --- | --- |
| `public-safe` | The candidate has no detected private markers. | Continue normal review. |
| `shared-internal` | Useful for maintainers, but written for an internal workflow. | Rewrite for public users first. |
| `sanitize-first` | The candidate mentions machine paths, credential labels, or private references. | Remove or generalize those details, then rerun. |
| `private-only` | The candidate contains raw logs, transcripts, customer/student data, private policy, or secret-like material. | Do not publish; write a sanitized derivative. |
| `manager-only-decision` | The candidate asks to publish, announce, or copy material to a public repo. | Maintainer approval is required even if the text is otherwise clean. |

Only `public-safe` exits with success. Every other result blocks publication and
prints the next action.

## Examples

Good public candidate:

```text
Reusable validation pattern for public maintainers; no private details.
```

Needs sanitizing:

```text
Remove local machine paths and credential labels before publishing.
```

Private-only:

```text
Raw chat transcript with customer data should never be copied.
```

Manager-only:

```text
Request to copy this private note to the public repository.
```

The gate is deliberately conservative. A blocked result is not a failure of the
idea; it means the candidate needs rewriting, a sanitized derivative, or a
maintainer decision before it belongs in public docs.
