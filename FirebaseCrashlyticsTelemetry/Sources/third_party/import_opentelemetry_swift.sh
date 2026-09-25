#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version of opentelemetry-swift to pull from https://github.com/open-telemetry/opentelemetry-swift/releases
# Defaults to 2.5.0, but can be overridden by passing a version as the first argument or setting OTEL_SWIFT_VERSION.
OTEL_SWIFT_VERSION="${1:-${OTEL_SWIFT_VERSION:-2.5.0}}"

# Override BASE_DIR if the source root is different.
BASE_DIR="${BASE_DIR:-$HOME/source}"

REPO_URL="https://github.com/open-telemetry/opentelemetry-swift.git"
LOCAL_MIRROR="$BASE_DIR/opentelemetry-swift"

SRC_BASE="$LOCAL_MIRROR/Sources/Instrumentation"
DEST_BASE="$DIR/opentelemetry-swift"

INSTRUMENTATION_BASE="$DEST_BASE/Sources/Instrumentation"

LICENSE_SRC="$LOCAL_MIRROR/LICENSE"
LICENSE_DEST="$DEST_BASE/LICENSE"
VERSION_DEST="$DEST_BASE/VERSION"

# These are the only instrumentation libraries that we support / need. Add more as needed.
INSTRUMENTATION_DIRS=("URLSession" "NetworkStatus")

echo "------------------------------------------------------------"
echo "Step 1: Verifying ${LOCAL_MIRROR} is at version ${OTEL_SWIFT_VERSION}..."
echo "------------------------------------------------------------"

if [ -d "$LOCAL_MIRROR/.git" ]; then
    echo "Repository found at $LOCAL_MIRROR. Fetching and checking out version $OTEL_SWIFT_VERSION..."
    git -C "$LOCAL_MIRROR" fetch --tags origin
    git -C "$LOCAL_MIRROR" checkout "$OTEL_SWIFT_VERSION"
else
    echo "Repository not found. Cloning into $LOCAL_MIRROR at version $OTEL_SWIFT_VERSION..."
    mkdir -p "$(dirname "$LOCAL_MIRROR")"
    git clone "$REPO_URL" "$LOCAL_MIRROR"
    git -C "$LOCAL_MIRROR" checkout "$OTEL_SWIFT_VERSION"
fi

echo ""
echo "------------------------------------------------------------"
echo "Step 2: Copying instrumentation modules to third_party..."
echo "------------------------------------------------------------"

# Ensure the destination base directory exists
mkdir -p "$DEST_BASE"

for dir in "${INSTRUMENTATION_DIRS[@]}"; do
    src_path="$SRC_BASE/$dir"
    dest_path="$INSTRUMENTATION_BASE/$dir"

    if [ -d "$src_path" ]; then
        echo "-> Copying $dir..."
        rm -rf "$dest_path"
        cp -R "$src_path" "$dest_path"
    else
        echo "⚠️ Warning: Source directory not found: $src_path" >&2
    fi
done

echo ""
echo "------------------------------------------------------------"
echo "Step 3: Copying LICENSE into third_party..."
echo "------------------------------------------------------------"


if [ -f "$LICENSE_SRC" ]; then
    echo "-> Copying LICENSE..."
    cp "$LICENSE_SRC" "$LICENSE_DEST"
else
    echo "⚠️ Warning: LICENSE file not found at $LICENSE_SRC" >&2
fi

echo ""
echo "------------------------------------------------------------"
echo "Step 4: Creating VERSION file in third_party..."
echo "------------------------------------------------------------"

echo "-> Writing VERSION..."
echo "$OTEL_SWIFT_VERSION" > "$VERSION_DEST"

echo ""
echo "✅ Successfully updated third-party instrumentation modules to version ${OTEL_SWIFT_VERSION}!"
