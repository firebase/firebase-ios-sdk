#!/bin/bash
set -euo pipefail

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
