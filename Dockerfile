FROM python:3.13-slim

RUN rm -rf /var/lib/apt/lists/* \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends git jq bats bats-assert bats-support bats-file \
    && rm -rf /var/lib/apt/lists/*

# Same patched fork that bootstrap.sh installs on the host
# (upstream PyPI has the prefix-stripping bug, see #24).
RUN pip install --no-cache-dir "git+https://github.com/non7top/dotfiles.git"

# The texthooks version must match the rev in _git/.pre-commit-config.yaml (tests/hooks/global-config.bats).
RUN pip install --no-cache-dir pyyaml texthooks==1.0.0
