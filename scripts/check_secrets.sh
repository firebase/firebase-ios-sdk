#!/bin/sh

# Copyright 2020 Google LLC
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


# Check if secrets are available for multiple CI's

set -x
echo "GITHUB_BASE_REF: ${GITHUB_BASE_REF:-}"
echo "GITHUB_HEAD_REF: ${GITHUB_HEAD_REF:-}"

check_secrets()
{
  # Travis: Secrets are available if we're not running on a fork.
  if [[ -n "${TRAVIS_PULL_REQUEST:-}" ]]; then
    if [[ "$TRAVIS_PULL_REQUEST" == "false" ||
        "$TRAVIS_PULL_REQUEST_SLUG" == "$TRAVIS_REPO_SLUG" ]]; then
          return 0
    fi
  fi
  # GitHub Actions: Secrets are available if we're not running on a fork.
  # See https://help.github.com/en/actions/automating-your-workflow-with-github-actions/using-environment-variables
  # TODO- Both GITHUB_BASE_REF and GITHUB_HEAD_REF are set in main repo
  # PRs even thought the docs say otherwise. They are not set in cron jobs on main.
  # Investigate how do to distinguish fork PRs from main repo PRs.
  if [[ -n "${GITHUB_WORKFLOW:-}" ]]; then
    return 0
  fi
  return 1
}
