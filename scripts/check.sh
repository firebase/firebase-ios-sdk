#!/bin/bash

# Copyright 2019 Google
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

# Checks that the current state of the tree is sane and optionally auto-fixes
# errors automatically. Meant for interactive use.

function usage() {
  cat <<EOF
USAGE: scripts/check.sh [--allow-dirty] [--commit] [<revision>]

Runs auto-formatting scripts, source-tree checks, and linters on any files that
have changed since origin/master.

By default, any changes are left as uncommited changes in the working tree. You
can review them with git diff. Pass --commit to automatically commit any changes.

Pass an alternate revision to use as the basis for checking changes.

OPTIONS:

  --allow-dirty
    By default, check.sh requires a clean working tree to keep any generated
    changes separate from logical changes.

  --commit
    Commit any auto-generated changes with a message indicating which tool made
    the changes.

  --amend
    Commit any auto-generated changes by amending the HEAD commit.

  --fixup
    Commit any auto-generated changes with a fixup! message for the HEAD
    commit. The next rebase will squash these fixup commits.

  --test-only
    Run all checks without making any changes to local files.

  <revision>
    Specifies a starting revision other than the default of origin/master.


EXAMPLES:

  check.sh
    Runs automated checks and formatters on all changed files since
    origin/master. Check for changes with git diff.

  check.sh --commit
    Runs automated checks and formatters on all changed files since
    origin/master and commits the results.

  check.sh --amend HEAD
    Runs automated checks and formatters on all changed files since the last
    commit and amends the last commit with the difference.

  check.sh --allow-dirty HEAD
    Runs automated checks and formatters on all changed files since the last
    commit and intermingles the changes with any pending changes. Useful for
    interactive use from an editor.

EOF
}
set -euo pipefail
unset CDPATH

# Change to the top-directory of the working tree
top_dir=$(git rev-parse --show-toplevel)
cd "${top_dir}"

ALLOW_DIRTY=false
COMMIT_METHOD="none"
CHECK_DIFF=true
START_REVISION="origin/master"
TEST_ONLY=false
VERBOSE=false

# Default to verbose operation if this isn't an interactive build.
if [[ ! -t 1 ]]; then
  VERBOSE=true
fi

# When travis clones a repo for building, it uses a shallow clone. After the
# first commit on a non-master branch, TRAVIS_COMMIT_RANGE is not set, master
# is not available and we need to compute the START_REVISION from the common
# ancestor of $TRAVIS_COMMIT and origin/master.
if [[ -n "${TRAVIS_COMMIT_RANGE:-}" ]] ; then
  CHECK_DIFF=true
  START_REVISION="$TRAVIS_COMMIT_RANGE"
elif [[ -n "${TRAVIS_COMMIT:-}" ]] ; then
  if ! git rev-parse origin/master >& /dev/null; then
    git remote set-branches --add origin master
    git fetch origin
  fi
  CHECK_DIFF=true
  START_REVISION=$(git merge-base origin/master "${TRAVIS_COMMIT}")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      # Do nothing: explicitly allow this, but ignore it
      ;;

    -h | --help)
      usage
      exit 1
      ;;

    --allow-dirty)
      ALLOW_DIRTY=true
      ;;

    --amend)
      COMMIT_METHOD=amend
      ;;

    --fixup)
      COMMIT_METHOD=fixup
      ;;

    --commit)
      COMMIT_METHOD=message
      ;;

    --verbose)
      VERBOSE=true
      ;;

    --test-only)
      # In test-only mode, no changes are made, so there's no reason to
      # require a clean source tree.
      ALLOW_DIRTY=true
      TEST_ONLY=true
      ;;

    *)
      START_REVISION="$1"
      shift
      break
      ;;
  esac
  shift
done

if [[ "${TEST_ONLY}" == true && "${COMMIT_METHOD}" != "none" ]]; then
  echo "--test-only cannot be combined with --amend, --fixup, or --commit"
  exit 1
fi

if [[ "${ALLOW_DIRTY}" == true && "${COMMIT_METHOD}" == "message" ]]; then
  echo "--allow-dirty and --commit are mutually exclusive"
  exit 1
fi

if ! git diff-index --quiet HEAD --; then
  if [[ "${ALLOW_DIRTY}" != true ]]; then
    echo "You have local changes that could be overwritten by this script."
    echo "Please commit your changes first or pass --allow-dirty."
    exit 2
  fi
fi

# Show Travis-related environment variables, to help with debuging failures.
if [[ "${VERBOSE}" == true ]]; then
  env | egrep '^TRAVIS_(BRANCH|COMMIT|PULL|REPO)' | sort || true
fi

if [[ "${START_REVISION}" == *..* ]]; then
  RANGE_START="${START_REVISION/..*/}"
  RANGE_END="${START_REVISION/*../}"

  # Figure out if we have access to master. If not add it to the repo.
  if ! git rev-parse origin/master >& /dev/null; then
    git remote set-branches --add origin master
    git fetch origin
  fi

  # Try to come up with a more accurate representation of the merge, so that
  # checks will operate on just the differences the PR would merge into master.
  # The start of the revision range that Travis supplies can sometimes be a
  # seemingly random value.
  NEW_RANGE_START=$(git merge-base origin/master "${RANGE_END}" || echo "")
  if [[ -n "$NEW_RANGE_START" ]]; then
    START_REVISION="${NEW_RANGE_START}..${RANGE_END}"
    START_SHA="${START_REVISION}"
  else
    # In the shallow clone that Travis has created there's no merge base
    # between the PR and master. In this case just fall back on checking
    # everything.
    echo "Unable to detect base commit for change detection."
    echo "Falling back on just checking everything."
    CHECK_DIFF=false
    START_REVISION="origin/master"
    START_SHA="origin/master"
  fi

else
  START_SHA=$(git rev-parse "${START_REVISION}")
fi

if [[ "${VERBOSE}" == true ]]; then
  echo "START_REVISION=$START_REVISION"
  echo "START_SHA=$START_SHA"
fi

# If committing --fixup, avoid messages with fixup! fixup! that might come from
# multiple fixup commits.
HEAD_SHA=$(git rev-parse HEAD)

function maybe_commit() {
  local message="$1"

  if [[ "${COMMIT_METHOD}" == "none" ]]; then
    return
  fi

  echo "${message}"
  case "${COMMIT_METHOD}" in
    amend)
      git commit -a --amend -C "${HEAD_SHA}"
      ;;

    fixup)
      git commit -a --fixup="${HEAD_SHA}"
      ;;

    message)
      git commit -a -m "${message}"
      ;;

    *)
      echo "Unknown commit method ${COMMIT_METHOD}" 1>&2
      exit 2
      ;;
  esac
}

style_cmd=("${top_dir}/scripts/style.sh")
if [[ "${TEST_ONLY}" == true ]]; then
  style_cmd+=(test-only)
fi
if [[ "$CHECK_DIFF" == true ]]; then
  style_cmd+=("${START_SHA}")
fi

# Restyle and commit any changes
"${style_cmd[@]}"
if ! git diff --quiet; then
  maybe_commit "style.sh generated changes"
fi

# If there are changes to the Firestore project, ensure they're ordered
# correctly to minimize conflicts.
if [ -z "${GITHUB_WORKFLOW-}" ]; then
  if [[ "$CHECK_DIFF" == "false" ]] || \
      ! git diff --quiet "${START_SHA}" -- Firestore; then

    sync_project_cmd=("${top_dir}/scripts/sync_project.rb")
    if [[ "${TEST_ONLY}" == true ]]; then
      sync_project_cmd+=(--test-only)
    fi
    "${sync_project_cmd[@]}"
    if ! git diff --quiet; then
      maybe_commit "sync_project.rb generated changes"
    fi
  fi
fi

set -x

# Print the versions of tools being used.
python --version

# Check lint errors.
"${top_dir}/scripts/check_whitespace.sh"
"${top_dir}/scripts/check_filename_spaces.sh"
"${top_dir}/scripts/check_copyright.sh"
"${top_dir}/scripts/check_no_module_imports.sh"
"${top_dir}/scripts/check_test_inclusion.py"
"${top_dir}/scripts/check_imports.swift"
"${top_dir}/scripts/check_firestore_core_api_absl.py"

# Google C++ style
lint_cmd=("${top_dir}/scripts/check_lint.py")
if [[ "$CHECK_DIFF" == true ]]; then
  lint_cmd+=("${START_SHA}")
fi
"${lint_cmd[@]}"
