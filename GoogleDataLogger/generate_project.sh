#!/bin/bash

# From https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Remove the old generated project
echo "Removing $DIR/gen"
rm -rf "$DIR/gen/"

pod gen "$DIR/../GoogleDataLogger.podspec" --auto-open --gen-directory="$DIR/gen"
