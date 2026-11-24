DOCKER_UID := $(shell id -u)
DOCKER_GID := $(shell id -g)
export DOCKER_UID DOCKER_GID

.PHONY: build test test-hooks test-statusline test-env-dropins test-docker-clean test-gcl test-hooks-mutation test-bootstrap act act-clean shell destroy

build:
	docker compose build

test: build test-hooks test-statusline test-env-dropins test-docker-clean test-gcl
	docker compose run --rm test

test-hooks: build
	docker compose run --rm test /repo/tests/test-hooks.sh

test-statusline: build
	docker compose run --rm test /repo/tests/test-statusline.sh

test-env-dropins: build
	docker compose run --rm test /repo/tests/test-env-dropins.sh

test-gcl: build
	docker compose run --rm test bats --print-output-on-failure /repo/tests/gcl

test-docker-clean: build
	docker compose run --rm test /repo/tests/test-docker-clean.sh

# Applies deliberate relaxations to the hooks; every one must make the hook tests fail.
test-hooks-mutation: build
	docker compose run --rm test /repo/tests/hooks/mutation-check.sh

test-bootstrap:
	docker compose build bootstrap
	docker compose run --rm bootstrap

# The tests workflow locally, as CI runs it (.actrc: --rm, image mapping).
act:
	act -W .github/workflows/tests.yml workflow_dispatch

# Removes this repo's leftover act containers and volumes (an interrupted run leaves them).
act-clean:
	docker ps -aq --filter name=act-tests-tests- | xargs -r docker rm -f
	docker volume ls -q --filter name=act-tests-tests- | xargs -r docker volume rm

shell: build
	docker compose run --rm test bash

destroy:
	docker compose down --rmi local -v --remove-orphans
