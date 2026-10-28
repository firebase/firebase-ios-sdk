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

# The steps of .github/workflows/infra.zip_diff.yml: builds the release zip for `main` (the
# baseline) and for a pull request's merge commit (the candidate), then diffs them.
#
# Usage: zip_diff.sh <step>
#   build-tools      Builds the candidate's zip builder, and main's for pull requests.
#   build-baseline   Builds main's zip.
#   build-candidate  Builds the candidate's zip.
#   prune-cache      Keeps only this run's framework cache subdirectories.
#   diff             Diffs the zips into a pull request comment; outputs `status` and, when both
#                    zips exist, `comment_file`.
#
# Runs from the repository root. The steps check out other commits, so the workflow runs a copy
# of this script from outside the checkout.
#
# This script is used on CI to provide some extra bootstrapping:
#   1. It builds the merge commit, not the PR branch. If main has moved since the branch was created,
#      building from the PR branch would also show everything that landed on main (as if the PR reverted those changes).
#      Building from the merge commit avoids this, and only shows the changes from this PR.
#   2. Each zip gets its own commit's version in every `Info.plist` and fingerprint. If the PR bumps it, every framework
#      changes, so `diff` reports the bump once as the release version change instead of per framework. (A bump on
#      main is already in the merge commit.)
#   3. Each side is built by its own tool. Main gets built from its zip builder, and the PR's by the PR's. If the PR's tool built both,
#      a PR that changes the zip builder would change both sides equally, and its effect would never show.
#   4. Caching. The fingerprints don't cover the tool's own code, so each tool build get its own cache subdirectory.
#      Only pushes to main save the cache; pull requests restore main's and rebuild only what they change.
#
# Environment: RUNNER_TEMP, CANDIDATE_SHA, BASE_SHA, GITHUB_EVENT_NAME, and for `diff`, TITLE (the
# comment's first line); GITHUB_OUTPUT receives the outputs (stdout when it's unset), and
# GITHUB_STEP_SUMMARY, when set, the comment.

set -euo pipefail

TEMP="${RUNNER_TEMP:?}"
CACHE="${TEMP}/zip-builder-cache"
OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

# Each tool directory holds a `zip-builder`, the `hash` of the sources it was built from, and,
# when it must build with a config other than the checkout's, a `zip_builder.jsonc`.
CANDIDATE_TOOL="${TEMP}/candidate-tool"
BASELINE_TOOL="${TEMP}/baseline-tool"

# Identifies a tool build. Fingerprints don't cover the tool's own code, so each tool build gets
# its own framework cache subdirectory.
tool_hash() { # <commit>
  git ls-tree -r "$1" -- scripts/zip_builder/Package.swift scripts/zip_builder/Package.resolved \
    scripts/zip_builder/Sources | git hash-object --stdin | cut -c1-12
}

build_tool() { # <commit> <tool directory>
  git checkout --force --quiet "$1"
  swift build --package-path scripts/zip_builder -c release --force-resolved-versions \
    --product zip-builder || return 1
  mkdir -p "$2"
  cp "$(swift build --package-path scripts/zip_builder -c release --show-bin-path)/zip-builder" "$2/"
  tool_hash "$1" > "$2/hash"
}

# Until the new zip builder is on main, main has the old one at the same path (another CLI and
# config). The candidate's tool and config then build the baseline too.
# TODO: delete once main has the new zip builder, with the config handling in `build_zip`.
main_has_new_tool() {
  git cat-file -e "${BASE_SHA}:scripts/zip_builder/Sources/ZipBuilder/Commands/ZipBuilderCommand.swift" 2>/dev/null
}

use_candidate_tool_for_baseline() {
  rm -rf "$BASELINE_TOOL"
  cp -R "$CANDIDATE_TOOL" "$BASELINE_TOOL"
  git show "${CANDIDATE_SHA}:zip_builder.jsonc" > "${BASELINE_TOOL}/zip_builder.jsonc"
}

build_tools() {
  build_tool "$CANDIDATE_SHA" "$CANDIDATE_TOOL"
  if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
    # main's tool builds the baseline, so a pull request that changes the tool shows its effect.
    if ! main_has_new_tool; then
      use_candidate_tool_for_baseline
    elif ! build_tool "$BASE_SHA" "$BASELINE_TOOL"; then
      echo "::warning::main's zip builder doesn't build; the candidate's builds the baseline too."
      use_candidate_tool_for_baseline
    fi
  fi
  git checkout --force --quiet "$CANDIDATE_SHA"
}

release_version() { # <commit>
  git show "$1:Package.swift" | sed -nE 's/^let firebaseVersion = "([^"]+)".*/\1/p'
}

build_zip() { # <commit> <tool directory> <work directory>
  local tool="$2"
  local config=()
  if [[ -f "${tool}/zip_builder.jsonc" ]]; then
    config=(--config "${tool}/zip_builder.jsonc")
  fi
  git checkout --force --quiet "$1"
  # Keep the flags to the stable core: main's tool builds the baseline. (The `+` form expands an
  # empty array under `set -u` in macOS's bash 3.2.) Each zip gets its own commit's version;
  # `diff` reports a bump once, as the release version change.
  "${tool}/zip-builder" release --package-path . ${config[@]+"${config[@]}"} --work-dir "$3" \
    --cache-dir "${CACHE}/$(cat "${tool}/hash")" --version "$(release_version "$1")"
}

build_baseline() {
  # A broken baseline shouldn't block the pull request: the diff uses whatever it packaged.
  build_zip "$BASE_SHA" "$BASELINE_TOOL" "${TEMP}/baseline" \
    || echo "::warning::The baseline release failed; the diff uses what it packaged, if anything."
}

build_candidate() {
  build_zip "$CANDIDATE_SHA" "$CANDIDATE_TOOL" "${TEMP}/candidate"
}

prune_cache() {
  local keep=("$(cat "${CANDIDATE_TOOL}/hash")")
  if [[ -f "${BASELINE_TOOL}/hash" ]]; then
    keep+=("$(cat "${BASELINE_TOOL}/hash")")
  fi
  mkdir -p "$CACHE"
  for directory in "$CACHE"/*/; do
    [[ -d "$directory" ]] || continue # no subdirectories: the pattern stays unexpanded
    local name
    name="$(basename "$directory")"
    if [[ " ${keep[*]} " != *" ${name} "* ]]; then
      rm -rf "$directory"
    fi
  done
}

diff_zips() {
  # Relative paths, so the report doesn't show the runner's temp directory.
  cd "$TEMP"
  if [[ ! -d candidate/dist/Firebase ]]; then
    echo "status=no-candidate" >> "$OUTPUT"
    return
  fi
  if [[ ! -d baseline/dist/Firebase ]]; then
    echo "status=no-baseline" >> "$OUTPUT"
    return
  fi
  local comment=diff-output/comment.md
  mkdir -p diff-output
  rm -f "$comment"
  # --exit-code exits 1 after writing the comment; errors exit before writing it.
  local code=0
  candidate-tool/zip-builder diff baseline/dist/Firebase candidate/dist/Firebase \
    --format github-comment --title "${TITLE:?}" --output "$comment" --exit-code || code=$?
  if [[ $code -eq 0 ]]; then
    echo "status=same" >> "$OUTPUT"
  elif [[ $code -eq 1 && -s "$comment" ]]; then
    echo "status=changed" >> "$OUTPUT"
  else
    exit "$code"
  fi
  echo "comment_file=${TEMP}/${comment}" >> "$OUTPUT"
  # Shows the comment in the log and, on CI, in the job summary.
  tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}" < "$comment"
}

case "${1:-}" in
  build-tools) build_tools ;;
  build-baseline) build_baseline ;;
  build-candidate) build_candidate ;;
  prune-cache) prune_cache ;;
  diff) diff_zips ;;
  *)
    echo "Usage: $0 build-tools|build-baseline|build-candidate|prune-cache|diff" >&2
    exit 2
    ;;
esac
