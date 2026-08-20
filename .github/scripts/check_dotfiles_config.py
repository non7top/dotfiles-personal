#!/usr/bin/env python3
"""Verify every top-level entry in this dotfiles repo is either ignored,
a declared package, or conforms to the configured prefix.

The `dotfiles` tool (jbernard/dotfiles) reinterprets any top-level repo
entry that isn't ignored or a declared package as a home-directory
dotfile target -- including entries that were never meant to sync at
all (e.g. this repo's own project-local `.claude/` folder, which almost
got silently mapped onto the real `~/.claude`). This check catches that
class of mistake before it reaches `.dotfilesrc`, regardless of whether
the installed `dotfiles` build has the upstream prefix-stripping bug
fixed or not -- an already-dotted name like `.claude` passes through
unchanged even under the fixed logic, so this is not redundant with
that fix. See non7top/dotfiles-personal#24 for the full history.
"""
import configparser
import fnmatch
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_IGNORE = {'.dotfilesrc'}


def parse_dotfilesrc(path):
    parser = configparser.ConfigParser()
    parser.read(path)

    prefix = ''
    ignore = set(DEFAULT_IGNORE)
    packages = set()

    if parser.has_section('dotfiles'):
        if parser.has_option('dotfiles', 'prefix'):
            prefix = parser.get('dotfiles', 'prefix')
        if parser.has_option('dotfiles', 'ignore'):
            ignore |= set(eval(parser.get('dotfiles', 'ignore')))
        if parser.has_option('dotfiles', 'packages'):
            packages |= set(eval(parser.get('dotfiles', 'packages')))

    return prefix, ignore, packages


def is_ignored(name, ignore_patterns):
    return any(fnmatch.fnmatch(name, pat) for pat in ignore_patterns)


def check_dir(dir_path, sub_dir, prefix, ignore_patterns, packages, errors):
    for name in sorted(os.listdir(dir_path)):
        if is_ignored(name, ignore_patterns):
            continue

        pkg_path = f"{sub_dir}/{name}" if sub_dir else name

        if pkg_path in packages:
            check_dir(os.path.join(dir_path, name), pkg_path,
                      prefix, ignore_patterns, packages, errors)
            continue

        if prefix and not name.startswith(prefix):
            errors.append(
                f"{pkg_path!r} (inside {sub_dir or '.'!r}) doesn't start "
                f"with prefix {prefix!r}, and isn't ignored or a declared "
                "package -- `dotfiles` will treat it as a home-directory "
                "sync target."
            )


def main():
    dotfilesrc = REPO_ROOT / '.dotfilesrc'
    if not dotfilesrc.exists():
        print("No .dotfilesrc found, nothing to check.")
        return 0

    prefix, ignore_patterns, packages = parse_dotfilesrc(str(dotfilesrc))

    errors = []
    check_dir(str(REPO_ROOT), '', prefix, ignore_patterns, packages, errors)

    if errors:
        print("dotfiles config check FAILED:")
        for error in errors:
            print(f"  - {error}")
        print()
        print("Fix by either prefixing the entry with the configured "
              "prefix, adding it to the `ignore` list in .dotfilesrc, or "
              "declaring its parent directory in `packages` if it should "
              "sync file-by-file.")
        return 1

    print("dotfiles config check OK: every top-level entry is prefixed, "
          "ignored, or a declared package.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
