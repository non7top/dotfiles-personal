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

**1. Clone the repo**

.. code-block:: bash

    git clone https://github.com/non7top/dotfiles.git ~/dotfiles

**2. Install the dotfiles tool and sync**

.. code-block:: bash

    pipx install dotfiles
    cd ~/dotfiles
    dotfiles --sync

**3. Install asdf and tools**

.. code-block:: bash

    # Install asdf: https://asdf-vm.com/guide/getting-started.html
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf
    # Re-source your shell, then:
    asdf plugin add <name>   # for each tool in _tool-versions
    asdf install

**4. Install pre-commit**

.. code-block:: bash

    pipx install pre-commit

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
