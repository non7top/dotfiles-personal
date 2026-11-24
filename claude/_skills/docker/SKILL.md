---
name: docker
description: Use whenever running tools, tests or builds in containers, and whenever creating, naming, labelling, auditing or cleaning up Docker images, containers, volumes, networks or compose stacks, and before any docker prune or volume removal. Containers are throwaway and non-root, every object maps to a repo and is classed as state, cache or disposable, so nothing irreplaceable is removed and nothing temporary lingers.
---

# Docker: containers, traceable and classified objects

Anyone looking at `docker ps`, `docker volume ls` or `docker image ls` must be able to tell which repo an object belongs to, what it is for, and whether it may be deleted.

## Running containers

Run tooling and builds (linters, test runners, compilers, package managers, one-off scripts) in throwaway containers, not on the host. Don't install runtimes or CLI tools on the host, and don't use a host binary just because it's there.

- Use `docker compose run --rm`, not a long-lived container or bare `docker run`.
- Use named volumes for caches. A missing cache is slow, not broken.
- Wrap compose in a `Makefile` (`make build`, `test`, `run`, `lint`, ...) as the documented entry point.
- Docker is pruned regularly: everything must rebuild from the committed compose file, Dockerfile, and Makefile with no manual setup.

### Tear down what a run started

Test harnesses are not permanent. Anything a test, check or one-off run starts (compose dependency services like a database or FTP server, helper containers, temp worktrees, scratch files) must be removed when that run ends, by the same target or script that started it (`docker compose down -v`, an exit trap), and by the agent at the end of a session if a run left it behind.

- `depends_on` services started by `docker compose run --rm` outlive the run; the `--rm` only removes the one-off container. Tear the stack down explicitly.
- No `restart: unless-stopped` or `always` on test-only services: it turns a workaround for one run into a container that survives forever and across daemon restarts. A restart policy is for services that are meant to stay up.
- Compose project names default to the directory, so each git worktree makes its own stack. Removing a worktree means taking its stack down first.
- Before ending a session in which containers were started, list them (`docker ps`) and stop the ones you started.

### Non-root

Containers run as non-root unless genuinely impossible. State the reason if falling back to root. A root container writing to a bind mount leaves root-owned host files the host user can't rewrite.

- Match the container uid/gid to the host's: `user: "${DOCKER_UID}:${DOCKER_GID}"`. Don't assume the image default.
- A named volume takes ownership from the image's contents at that path. Create the directory mode-1777 in the Dockerfile so an arbitrary uid can write; otherwise the volume is root-owned and first use fails.

### apt in containers

Start every container that runs apt with `rm -rf /var/lib/apt/lists/*`, before the first `apt-get update` (Dockerfile `RUN`, `docker run` command, or script). apt keeps a local `InRelease` with a later `Date` than the one the mirror serves, without re-verifying it or saying so, so a pre-populated or tampered lists directory can pin the index. Put it first in the same `RUN` as the `update`, not only as the final cleanup.

## Rules

1. **Name = repo + purpose.** Images and containers: `<repo>-<purpose>` (never bare `test`, `dev`, `tmp`). Compose: top-level `name:` is the repo name; a second git worktree of the same repo appends `-<branch-slug>`, otherwise both share one project.
2. **Three labels on everything you create** (images, containers, volumes, networks):
   - `local.repo`: `<owner>/<repo>` from `git remote get-url origin`, or the directory name if there is no remote
   - `local.purpose`: a short phrase, for example `mariadb data for integration tests`
   - `local.lifecycle`: `state`, `cache` or `disposable`
3. **Lifecycle decides what may happen to it.** If unsure, treat it as `state` and ask.
   - `state`: irreplaceable or costly to recreate (database data, uploads, keys, user home dirs). Never pruned. Removed only when the user names it in this conversation. In compose declare it `external: true` and create it with `docker volume create --label ...`: in a test, `docker compose down -v` removed a non-external state volume and kept the external one.
   - `cache`: regenerable and kept between runs (package, build and tool caches). Cleaned periodically, and only when asked.
   - `disposable`: exists for one run, branch or experiment (test images, one-off containers, scratch networks and volumes). Removed by the same script or target that created it.
4. **Volume names carry the lifecycle**, because `docker volume ls` does not show labels: `<repo>_<what>-state`, `-cache` or `-tmp` (compose adds the `<project>_` prefix to the key).
5. **No anonymous volumes.** They cannot be labelled or traced. An image that declares `VOLUME` (database images, `docker:dind`) still gets a named volume or `--tmpfs`.
6. **Temporary volumes: `--rm` or clean up afterwards.** Checked in a throwaway docker-in-docker daemon:
   - `docker run --rm` removes the container's anonymous volumes when it exits; without `--rm` they stay, and plain `docker rm` and `docker rm -f` leave them behind. Use `docker rm -fv`.
   - A named volume is not removed by `--rm`. Remove it in the creating script (exit trap) or with `docker compose down -v`.
   - Scratch space that needs no name: `--tmpfs /path`, which leaves no volume.
7. **Pulled third-party images** cannot carry our labels and are exempt. Keep the ones worth keeping in `~/.docker-pinned-images` (see `docker-clean`). Images we build get the labels.

## Applying the labels

Dockerfile and `docker build`:

```
LABEL local.repo="acme/widgets" local.purpose="test runner" local.lifecycle="disposable"
docker build --label local.lifecycle=disposable -t widgets-test .
```

Compose (service labels apply to containers; volumes carry their own):

```
name: widgets
x-labels: &labels
  local.repo: acme/widgets
  local.purpose: integration db
services:
  db:
    image: mariadb:11
    labels: {<<: *labels, local.lifecycle: disposable}
    volumes: [db:/var/lib/mysql]
volumes:
  db:
    name: widgets_db-state
    external: true
```

`docker run`, `docker create`, `docker volume create` and `docker network create` take `--label key=value`. In `--format`, read a label with `{{.Label "local.lifecycle"}}` (volumes, containers, networks).

## Audit

```
~/.claude/skills/docker/audit.sh
```

Read-only. Per kind it prints counts per lifecycle, the unlabelled objects and any invalid lifecycle value. Report grouped by repo and lifecycle. Existing unlabelled objects are not deleted on that basis alone: work out the repo from the name, creation date and contents, ask the user, and label what stays.

## Cleaning

Filters were checked on volume and image prune; `label=key=value` selects, and `label!=` is accepted by prune but not by `volume ls`.

| What | Command |
|---|---|
| disposable images | `docker image prune -a -f --filter label=local.lifecycle=disposable` |
| disposable volumes | `docker volume prune -a -f --filter label=local.lifecycle=disposable` |
| caches, only on request | `docker volume prune -a -f --filter label=local.lifecycle=cache` |
| unused images and containers | `docker-clean` (keeps the pinned images) |
| state | never in bulk |

`docker volume prune` without `-a` removes only anonymous volumes, and `docker system prune --volumes` (with or without `-a`) left named volumes alone in the same test. `docker volume prune -a` removes every unused named volume, state included, so it always takes a `label=local.lifecycle=...` filter. Before removing anything, list it and show sizes.
