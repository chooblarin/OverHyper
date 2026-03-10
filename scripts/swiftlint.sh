#!/bin/sh

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH="$REPO_ROOT/.swiftlint.yml"
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "warning: SwiftLint is not installed. Install it with: brew install swiftlint"
  exit 0
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "warning: SwiftLint config not found at $CONFIG_PATH"
  exit 0
fi

swiftlint lint --config "$CONFIG_PATH" --reporter xcode "$@"
LINT_EXIT_CODE=$?

if [ "$LINT_EXIT_CODE" -ne 0 ]; then
  echo "warning: SwiftLint reported violations. Treating them as warnings during initial rollout."
fi

exit 0
