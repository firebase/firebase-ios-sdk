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
have changed since master.

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

  <revision>
    Specifies a starting revision other than the default of master.


EXAMPLES:

  check.sh
    Runs automated checks and formatters on all changed files since master.
    Check for changes with git diff.

  check.sh --commit
    Runs automated checks and formatters on all changed files since master and
    commits the results.

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
COMMIT_METHOD=none
START_REVISION="master"

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

    *)
      if git rev-parse "$1" >& /dev/null; then
        START_REVISION="$1"
        break
      fi
      ;;
  esac
  shift
done

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

# Record actual start
START_SHA=$(git rev-parse "${START_REVISION}")
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

# Restyle and commit any changes
"${top_dir}/scripts/style.sh" "${START_SHA}"
if ! git diff --quiet; then
  maybe_commit "style.sh generated changes"
fi

# If there are changes to the Firestore project, ensure they're ordered
# correctly to minimize conflicts.
if ! git diff --quiet -- Firestore/Example/Firestore.xcodeproj; then
  "${top_dir}/scripts/sync_project.rb"
  if ! git diff --quiet; then
    maybe_commit "sync_project.rb generated changes"
  fi
fi

# Check lint errors
(
  scripts/lint.sh "${START_SHA}"
  scripts/check_copyright.sh
  scripts/check_no_module_imports.sh
  scripts/check_test_inclusion.py
  scripts/check_whitespace.sh
) 2>&1 | sed "s,^\\([^:]*:[0-9]*: \\),${top_dir}/\\1,"
