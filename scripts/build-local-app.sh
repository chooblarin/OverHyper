#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/OverHyper.xcodeproj"
SCHEME="OverHyper"
DERIVED_DATA_PATH="/tmp/OverHyperDerivedRelease"
PACKAGE_CACHE_PATH="/tmp/OverHyperPackages"
PRODUCT_PATH="$DERIVED_DATA_PATH/Build/Products/Release/OverHyper.app"
DIST_PATH="$ROOT_DIR/dist/OverHyper.app"

rm -rf "$DIST_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$PACKAGE_CACHE_PATH" \
  build

if [[ ! -d "$PRODUCT_PATH" ]]; then
  echo "Build succeeded but product was not found: $PRODUCT_PATH" >&2
  exit 1
fi

ditto "$PRODUCT_PATH" "$DIST_PATH"

echo "Built app: $DIST_PATH"
echo "You can launch it with: open '$DIST_PATH'"
