---
name: docker
description: Use whenever creating, naming, labelling, auditing or cleaning up Docker images, containers, volumes, networks or compose stacks, and before any docker prune or volume removal. Every object maps to a repo and is classed as state, cache or disposable, so nothing irreplaceable is removed and nothing temporary lingers.
---

# Docker objects: traceable and classified

Anyone looking at `docker ps`, `docker volume ls` or `docker image ls` must be able to tell which repo an object belongs to, what it is for, and whether it may be deleted.

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
