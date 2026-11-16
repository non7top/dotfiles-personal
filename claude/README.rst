Claude Code config
==================

Files in this directory sync into ``~/.claude`` (``_statusline-command.sh`` becomes
``~/.claude/statusline-command.sh``, ``_skills`` becomes ``~/.claude/skills``).

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
