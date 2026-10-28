#!/bin/sh
# Proxy to the upstream uv installer; always installs the latest release.
# (Previously vendored astral-sh installer pinned at 0.8.8.)
# Shell configs already put ~/.local/bin on PATH; don't let it edit tracked rc files.
curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh -s -- "$@"
