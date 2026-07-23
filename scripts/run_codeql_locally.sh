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

set -euo pipefail

# Ensure we are in the repository root so relative paths work correctly
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Make sure CodeQL CLI is installed and in your PATH
if ! command -v codeql &> /dev/null; then
    echo "CodeQL CLI could not be found."
    echo "Please download it from: https://github.com/github/codeql-cli-binaries/releases"
    echo "And add it to your PATH."
    exit 1
fi

DB_DIR="codeql-db-swift"
RESULTS_FILE="codeql-results.sarif"

echo "🧹 Cleaning up previous CodeQL databases..."
rm -rf "$DB_DIR"
rm -f "$RESULTS_FILE"

echo "🏗️ Initializing CodeQL database and running build..."
# We use the build command directly without the Travis retry script for faster local feedback
codeql database create "$DB_DIR" \
    --language=swift \
    --command="./scripts/build.sh Firebase-Package iOS-device spmbuildonly"

echo "🔍 Downloading Swift query pack..."
codeql pack download codeql/swift-queries || echo "⚠️ Warning: Failed to download/update Swift query pack. Proceeding with cached version if available..."

echo "🔍 Analyzing the database..."
# Run the standard default queries for Swift using the official query pack
codeql database analyze "$DB_DIR" codeql/swift-queries \
    --format=sarif-latest \
    --output="$RESULTS_FILE"

echo "✅ CodeQL analysis complete! Results have been saved to $RESULTS_FILE"
