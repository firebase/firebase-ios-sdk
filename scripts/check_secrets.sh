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

echo "GITHUB_BASE_REF: ${GITHUB_BASE_REF:-}"
echo "GITHUB_HEAD_REF: ${GITHUB_HEAD_REF:-}"

check_secrets()
{
  # 1. Prioritize explicit workflow signal (FIREBASECI_SECRETS_PRESENT).
  if [[ -n "${FIREBASECI_SECRETS_PRESENT:-}" ]]; then
    if [[ "${FIREBASECI_SECRETS_PRESENT:-}" == "true" || "${FIREBASECI_IS_TRUSTED_ENV:-}" == "true" ]]; then
      return 0 # Secrets are available, or it's a trusted env where they might be.
    fi
    return 1 # We don't expect secrets (e.g., fork PR). Skip gracefully.
  fi

  # 2. Fallback for un-migrated/legacy workflows: assume secrets if in GHA.
  #    - This maintains original behavior for workflows not yet updated with FIREBASECI_SECRETS_PRESENT.
  if [[ -n "$GITHUB_WORKFLOW" ]]; then
    return 0 # Assume secrets if running in GHA (legacy behavior).
  fi

  # 3. Default: No secrets available.
  return 1
}
