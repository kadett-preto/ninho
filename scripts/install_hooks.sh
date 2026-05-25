#!/usr/bin/env bash
# Instala git hooks compartilhados (.githooks/).
# Roda uma vez por checkout: scripts/install_hooks.sh

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

chmod +x .githooks/*
git config core.hooksPath .githooks

echo "✅ core.hooksPath = .githooks"
echo "Hooks ativos:"
ls .githooks
