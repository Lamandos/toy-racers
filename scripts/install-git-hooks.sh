#!/bin/sh
set -eu

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks

configured_path=$(git config --get core.hooksPath)
test "$configured_path" = ".githooks"
echo "Git hooks installed from .githooks"
