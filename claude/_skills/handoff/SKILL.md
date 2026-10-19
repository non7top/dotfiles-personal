---
name: handoff
description: Write HANDOFF.md at the repo root so the next session can resume cold. Use when the user says "handoff", "write the handoff", "update the handoff", "wrap up this session", or is closing out or pausing work. Not for reading a handoff; that is `recall`.
---

# Handoff

The next session starts with zero memory of this one. HANDOFF.md carries only what git and the code cannot: dead ends, decisions, and the next step. Point at commits, paths and issues instead of restating them.

## 1. Ground truth first

Run these before writing; never paraphrase them from memory:

- `git log --oneline` since the previous handoff's stamped commit (or the last ~10 if none)
- `git status --short`, `git branch --show-current`, `git rev-parse --short HEAD`
- whether HEAD is ahead of its upstream
- the existing `HANDOFF.md`, to carry forward what is still open

No commits, detached HEAD or no previous file: say so in the file. Don't invent history.

## 2. Write `HANDOFF.md` at the repo root

First line is the stamp the SessionStart hook and `recall` read:

```
<!-- handoff head=<short sha> branch=<branch> date=<YYYY-MM-DD> -->
```

Then these sections, in order, each only as long as it needs to be:

- **Headline**: one line, what the session was about, and why it is being handed off.
- **Done**: commits as `sha subject` from the real log; anything deployed or changed outside git.
- **Dead ends**: what was tried and rejected, and why. The section that saves the most time.
- **Open decisions**: what is decided vs. still waiting on someone.
- **State**: branch, pushed or dirty, anything running or half-applied.
- **Next**: one primary task as numbered steps, runnable without asking for direction. Never a menu.

Match the project's commit-message voice. No secrets, tokens or private URLs. No file dumps; give `path:line`.

## 3. Keep it out of git

It is rewritten every session. Ensure `HANDOFF.md` is listed in `.git/info/exclude` (local, so no repo gets a `.gitignore` change); append it if missing.

## 4. Prune

On rewrite, drop everything from earlier sessions that is done and no longer load-bearing. A handoff that only grows becomes noise.

## Gotchas

- Durable facts (a standing rule, a constraint true next month) belong in memory or the project docs, not here.
- Only write when the user asks. Don't write one because a conversation merely mentions handoffs.
- Finish or explicitly defer in-flight work (background tasks, uncommitted edits) before writing; the note must match disk.
