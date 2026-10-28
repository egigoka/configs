#!/bin/sh
# Proxy to the upstream uv installer; always installs the latest release.
# (Previously vendored astral-sh installer pinned at 0.8.8.)
curl -LsSf https://astral.sh/uv/install.sh | sh -s -- "$@"
