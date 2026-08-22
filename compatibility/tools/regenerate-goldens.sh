#!/bin/sh
set -eu

tool_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH= cd -- "$tool_directory/../.." && pwd)

cd "$repository_directory"
exec ./gradlew regenerateCompatibilityGoldens "$@"
