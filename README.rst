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

    sudo apt install -y git curl && git clone git@github.com:non7top/dotfiles.git ~/dotfiles && cd ~/dotfiles && ./bootstrap.sh

``bootstrap.sh`` will:

- install pipx and asdf (latest binary from GitHub releases)
- add asdf plugins and install all tools from ``_tool-versions``
- ``pipx install dotfiles pre-commit``
- run ``dotfiles --sync``

The global git hooks in ``_git/hooks/`` are wired via ``core.hooksPath = ~/.git/hooks/``
(set in ``_gitconfig``). After syncing, hooks run automatically on every repo.


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
