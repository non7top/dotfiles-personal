DOCKER_UID := $(shell id -u)
DOCKER_GID := $(shell id -g)
export DOCKER_UID DOCKER_GID

.PHONY: build test test-bootstrap shell destroy

build:
	docker compose build

test: build
	docker compose run --rm test

test-bootstrap:
	docker compose build bootstrap
	docker compose run --rm bootstrap

shell: build
	docker compose run --rm test bash

destroy:
	docker compose down --rmi local -v --remove-orphans
