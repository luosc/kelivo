# Rebase Conflict Co-pilot Rule

## Purpose
During `git rebase` / `git pull --rebase`, act as a persistent conflict-resolution copilot.
The user manages rebase state in a Git GUI (for example GitKraken); focus on resolving code conflicts at the current paused step.

## Core Principles
- Keep user in the loop: stop after each minimal step and wait for confirmation.
- Process one conflict file at a time for reviewability.
- Keep changes minimal and conflict-scoped; avoid unrelated refactors.
- Let the user own rebase progression in GUI (staging, continue rebase, etc.).

## Collaboration Contract
- Identify whether there are unresolved conflicts at the current paused state.
- If conflicts exist, pick one file (usually the first unresolved file).
- Before editing, provide a structured diagnosis table.
- Resolve conflicts and remove all conflict markers.
- Do basic validation (at least conflict-marker cleanup and obvious syntax sanity).
- Stop and ask user to review before proceeding.

## Required Analysis Format (Before Editing)
| File & Lines | Local Intent (replayed commit) | Base Intent (upstream changes) | Conflict Cause | Resolution Strategy |
| :--- | :--- | :--- | :--- | :--- |
| `path/to/file:line-range` | ... | ... | ... | ... |

## Interaction States

### Active Conflict State
When unresolved files exist:
1. Select one conflict file.
2. Output diagnosis table.
3. Apply minimal conflict fix and remove markers.
4. Stop and prompt review:
   - "I fixed `<file>`. Please review in your GUI. If correct, reply `next file`."

### Commit-Level Done State
When current paused step has no unresolved files:
- Announce current commit conflict resolution is complete.
- Ask user to review/stage/continue rebase in GUI.
- Enter standby until user says `proceed` / `next commit`.

### Rebase Finished State
When no rebase is in progress:
- Announce the conflict-assist workflow is complete.

## Scope Guardrails
- Do not expand scope beyond current conflict intent.
- Avoid formatting-only churn on unrelated code.
- Preserve existing behavior/contracts unless conflict resolution requires a deliberate change.
