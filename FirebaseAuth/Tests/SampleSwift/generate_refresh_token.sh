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

# Generates a refresh token for a Google account, associated with a Firebase
# project. Requires curl, xmllint and jq.
#
# To revoke the refresh token, go to myaccount.google.com/permissions, find the
# Firebase project, and click 'remove access'.
#
# Usage:
#   ./generate_refresh_token.sh path/to/GoogleService-Info.plist

set -o nounset
set -o errexit

# Redirect uri must be consistent across all calls in the oauth flow. This
# special value indicates an out-of-band uri, which the user will be expected
# to copy+paste into their browser.
readonly REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"

main() {
  if [[ $# != 1 ]] ; then
    echo "Usage:" >&2
    echo "  $0 path/to/GoogleService-Info.plist" >&2
    exit 1
  fi
  declare -r PLIST_PATH="$1"

  declare -r client_id=$(parse_plist "${PLIST_PATH}" "CLIENT_ID")
  declare -r reversed_client_id=$(parse_plist "${PLIST_PATH}" "REVERSED_CLIENT_ID")

  declare -r location=$(get_location "${client_id}")

  echo "Go to the following URL and complete the login flow:"
  echo "${location}"
  echo ""

  declare code=""
  read -p "Paste the resulting code here: " code
  echo ""

  echo "Refresh token: " $(get_refresh_token "${client_id}" "${code}")
}

# Parse a plist file (specifically, a GoogleService-Info.plist file) are return
# the value for the indicated key.
#
# Arguments:
#   plist: String. Path to the plist file.
#   key: String. Key value to lookup in the dictionary of the plist file.
parse_plist() {
  local plist="$1"
  local key="$2"

  readonly XPATH_TEMPLATE="/plist/dict/key[.='%s']/following-sibling::string[1]/text()"
  xmllint --xpath $(printf "${XPATH_TEMPLATE}" "${key}") "${plist}"
}

# Fetches the uri location used to generate a login code. The user will be
# expected to copy+paste this into the url bar in their browser.
#
# Arguments:
#   client_id: String. The id of the app to authenticate against. In the case
#       of firebase apps, this probably looks like
#       "1234567890-alpha123numeric456.apps.googleusercontent.com"
get_location() {
  declare -r client_id="$1"

  curl --silent --show-error --include --get \
      --data-urlencode "client_id=${client_id}" \
      --data-urlencode "redirect_uri=${REDIRECT_URI}" \
      --data-urlencode "response_type=code" \
      --data-urlencode "scope=openid profile email" \
      "https://accounts.google.com/o/oauth2/v2/auth" \
      | grep '^location: ' \
      | sed -e 's/^location: //'
}

# Fetches the refresh token based on the oauth code generated in the browser.
# Note that the code generated in the browser is only valid for a short period
# of time; this function will fail if the code is expired.
#
# Arguments:
#   client_id: String. The id of the app to authenticate against. In the case
#       of firebase apps, this probably looks like
#       "1234567890-alpha123numeric456.apps.googleusercontent.com"
#   code: String. The oauth code generated in the browser by the user.
get_refresh_token() {
  declare -r client_id="$1"
  declare -r code="$2"

  curl --silent --show-error -X POST \
      --data-urlencode "client_id=${client_id}" \
      --data-urlencode "code=${code}" \
      --data-urlencode "redirect_uri=${REDIRECT_URI}" \
      --data-urlencode "grant_type=authorization_code" \
      "https://www.googleapis.com/oauth2/v4/token" \
      | jq -r ".refresh_token"
}

main "$@"
