FROM python:3.13-slim

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Same patched fork that bootstrap.sh installs on the host
# (upstream PyPI has the prefix-stripping bug, see #24).
RUN pip install --no-cache-dir "git+https://github.com/non7top/dotfiles.git"
