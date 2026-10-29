.. contents::

=====
About
=====

my dotfiles

============
Installation
============

Files are managed with `dotfiles <https://github.com/jbernard/dotfiles>`_ using the ``_`` prefix convention
(e.g. ``_bashrc`` → ``~/.bashrc``).

**Quick start** (fresh machine, one line):

.. code-block:: bash

    sudo apt install -y git curl && git clone git@github.com:non7top/dotfiles-personal.git ~/Dotfiles && cd ~/Dotfiles && ./bootstrap.sh

``bootstrap.sh`` will:

- install asdf (latest binary from GitHub releases)
- add asdf plugins and install all tools from ``_tool-versions`` (including ``uv``)
- ``uv tool install`` everything in ``_uv-tools`` (``dotfiles``, ``pre-commit``, ...)
- run ``dotfiles --sync``

The global git hooks in ``_git/hooks/`` are wired via ``core.hooksPath = ~/.git/hooks/``
(set in ``_gitconfig``). After syncing, hooks run automatically on every repo.

=====
Tests
=====

Everything runs in disposable, non-root containers through ``make``; nothing is installed on the
host and the real ``$HOME`` is never touched. ``make`` passes your uid/gid through
``DOCKER_UID``/``DOCKER_GID`` (default 1000).

:``make test``: ``test-hooks`` followed by the sync scenarios (``tests/test-sync.sh``)
:``make test-hooks``: the git hook tests (bats), see below
:``make test-hooks-mutation``: relaxes the hooks one rule at a time and requires the matching tests to fail
:``make test-bootstrap``: runs ``bootstrap.sh`` on a fresh Ubuntu container and checks everything it promises to install
:``make shell``: a shell in the test container
:``make destroy``: removes the images, volumes and containers

Hook tests (``tests/hooks/*.bats``)
***********************************

Each test gets its own world (``tests/hooks/helpers.bash``): scratch ``HOME`` and git config, a copy
of ``_git/hooks``, and stub ``gh``, ``git-lfs``, ``docker`` and ``pre-commit`` binaries first on
``PATH`` (``tests/hooks/stubs``). The ``gh`` scenario (open/closed/merged PRs, auth failure) is
declared per test with the ``gh_stub_*`` helpers.

:``integration.bats``: the installed hook set driven by real git: manifest, commits, pushes, and the contract that nothing lands on a closed or merged PR's branch
:``dispatchers.bats``: the pre-commit, commit-msg and pre-push dispatchers, against fake ``.d`` scripts
:``wrappers.bats``: the generated pre-commit framework wrappers
:``block-closed-pr-branch.bats``, ``block-closed-pr-push.bats``: the closed-PR hooks and their shared check
:``protect-default.bats``, ``run-local-hook.bats``, ``terraform-docs.bats``, ``lfs-stubs.bats``, ``check-committer.bats``: one file per remaining hook
:``global-config.bats``: ``_git/.pre-commit-config.yaml``, run through the real texthooks fixer: every Unicode dash becomes a single hyphen

To run one file or test, pass bats arguments to the runner directly:
``docker compose run --rm test /repo/tests/test-hooks.sh /repo/tests/hooks/<file>.bats --filter <regex>``.

The texthooks version in the ``Dockerfile`` must match the ``rev`` in ``_git/.pre-commit-config.yaml``;
a test fails when they drift.

To add a test: ``load helpers``, call ``common_setup`` from ``setup()``, declare the scenario with
the helpers, and keep writes under ``$BATS_TEST_TMPDIR``. ``HOOKS_SRC`` points the suite at another
hooks tree, which is how ``mutation-check.sh`` proves the tests fail on a weakened hook.


============
Misc
============

***
git
***

Some of the useful git shortcuts


:git new: will start a new branch and push it to remote
:git reset-master: prints commands you can use to reset your master to upstream master
:git cm: git checkout to default branch
:git uncommit: will undo last commit

My typical workflow:

.. code-block:: bash

    git stash # if needed
    git cm
    git pull upstream HEAD
    git new new-branch


***
vim
***

:F2: toggle paste
:F5: execute
:F6: highlight whitespaces
:F7: wrap long lines
