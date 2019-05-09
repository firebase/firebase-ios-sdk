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

  --test-only
    Run all checks without making any changes to local files.

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

set -x
unset CDPATH

# Change to the top-directory of the working tree
top_dir=$(git rev-parse --show-toplevel)
cd "${top_dir}"

ALLOW_DIRTY=false
COMMIT_METHOD="none"
START_REVISION="master"
TEST_ONLY=false

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

    --test-only)
      # In test-only mode, no changes are made, so there's no reason to
      # require a clean source tree.
      ALLOW_DIRTY=true
      TEST_ONLY=true
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

# Record actual start, but only if the revision is specified as a single
# commit. Ranges specified with .. or ... are left alone.
if [[ "${START_REVISION}" == *..* ]]; then
  START_SHA="${START_REVISION}"
else
  START_SHA=$(git rev-parse "${START_REVISION}")
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
style_cmd+=("${START_SHA}")

# Restyle and commit any changes
"${style_cmd[@]}"
if ! git diff --quiet; then
  maybe_commit "style.sh generated changes"
fi

# If there are changes to the Firestore project, ensure they're ordered
# correctly to minimize conflicts.
if ! git diff --quiet "${START_SHA}" -- Firestore; then
  "${top_dir}/scripts/sync_project.rb"
  if ! git diff --quiet; then
    maybe_commit "sync_project.rb generated changes"
  fi
fi

# Check lint errors.
"${top_dir}/scripts/check_whitespace.sh"
"${top_dir}/scripts/check_filename_spaces.sh"
"${top_dir}/scripts/check_copyright.sh"
"${top_dir}/scripts/check_no_module_imports.sh"
"${top_dir}/scripts/check_test_inclusion.py"

# Google C++ style
"${top_dir}/scripts/lint.sh" "${START_SHA}"
