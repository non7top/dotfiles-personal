DOCKER_UID := $(shell id -u)
DOCKER_GID := $(shell id -g)
export DOCKER_UID DOCKER_GID

.PHONY: build test test-hooks test-gcl test-hooks-mutation test-bootstrap shell destroy

build:
	docker compose build

test: build test-hooks test-gcl
	docker compose run --rm test

test-hooks: build
	docker compose run --rm test /repo/tests/test-hooks.sh

test-gcl: build
	docker compose run --rm test bats --print-output-on-failure /repo/tests/gcl

# Applies deliberate relaxations to the hooks; every one must make the hook tests fail.
test-hooks-mutation: build
	docker compose run --rm test /repo/tests/hooks/mutation-check.sh

test-bootstrap:
	docker compose build bootstrap
	docker compose run --rm bootstrap

shell: build
	docker compose run --rm test bash

destroy:
	docker compose down --rmi local -v --remove-orphans
