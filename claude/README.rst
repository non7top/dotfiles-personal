Claude Code config
==================

Files in this directory sync into ``~/.claude`` (``_statusline-command.sh`` becomes
``~/.claude/statusline-command.sh``, ``_skills`` becomes ``~/.claude/skills``).

Global instructions
-------------------

``_CLAUDE.md`` is the global agent instructions file (``~/.claude/CLAUDE.md``; ``~/.claude/AGENTS.md`` is a
symlink to it). It keeps the rules that apply to every task. Rules for one kind of task live in
skills, loaded on demand and pointed to from the matching section:

:``docker``: running tools in throwaway non-root containers; naming, labels and lifecycle of Docker objects
:``gh-release``: release.yml after release-please: per-platform builds, provenance, cosign, apt repo, PyPI, and ``check.sh`` to audit repos
:``git-workflow``: commits, branches, PRs, merging, GitHub Actions workflows
:``new-repo``: standard setup for a new GitHub repo (gh-repo-config, Dependabot, release-please and the forecast, conventional commits) and ``check.sh`` to audit repos
:``ops-safety``: remote hosts, service databases, PHP web roots

It is public: no hostnames, repo names, addresses or identifiers.

Environment file
----------------

Claude's env file is ``~/.env.d/claude.env`` (repo source: ``_env.d/claude.env``,
one level up from this directory).

``_bashrc`` sources ``~/.env.d/*.env`` and then ``~/.env_local.d/*.env``, so the
same variable set in ``~/.env_local.d`` overrides the shared one.
``~/.env_local.d`` is machine-local and is not part of this repo.

Values there can use ``$HOME``. Claude inherits them from the shell that starts
it, so start it from a shell that read ``~/.bashrc``.

Why not ``settings.json``: its ``env`` values do not get variable or tilde
expansion, so ``"$HOME/..."`` or ``"~/..."`` there stays literal. This is a known
bug, observed by the repo owner and not retested here. Variables that do not need
``$HOME`` can stay in the ``env`` block of ``~/.claude/settings.json``, which this
repo does not manage.
