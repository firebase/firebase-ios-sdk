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

set -xe

TESTINGMODE=${1-}

if [ -f "${HOME}/.cocoapods/repos" ]; then
  find "${HOME}/.cocoapods/repos" -type d -maxdepth 1 -exec sh -c 'pod repo remove $(basename {})' \;
fi
git config --global user.email "google-oss-bot@example.com"
git config --global user.name "google-oss-bot"
mkdir -p /tmp/test/firebase-ios-sdk
git clone -q -b "${podspec_repo_branch}" https://"${BOT_TOKEN}"@github.com/firebase/firebase-ios-sdk.git "${local_sdk_repo_dir}"
cd  "${local_sdk_repo_dir}"

if [ "$TESTINGMODE" = "nightly_testing" ]; then
  tag_version="nightly-test-${nightly_test_version}"
  echo "A new tag, ${tag_version},for nightly release testing will be created."
fi
if [ "$TESTINGMODE" = "RC_testing" ]; then
  tag_version="CocoaPods-${nightly_test_version}.nightly"
  echo "A new tag, ${tag_version},for prerelease testing will be created."
fi
if [ -n "$tag_version" ]; then
  # Update a tag.
  set +e
  # If tag_version is new to the remote, remote cannot delete an unexisted tag,
  # so error is allowed here.
  git push origin --delete "${tag_version}"
  set -e
  git tag -f -a "${tag_version}" -m "release testing"
  git push origin "${tag_version}"
  # Update source and tag, e.g.  ":tag => 'CocoaPods-' + s.version.to_s" to
  # ":tag => test"
  sed  -i "" "s/\s*:tag.*/:tag => '${tag_version}'/" *.podspec
fi
cd "${GITHUB_WORKSPACE}/ZipBuilder"
swift build
# Update Pod versions.
./.build/debug/firebase-pod-updater --git-root "${local_sdk_repo_dir}" --releasing-pods "${GITHUB_WORKSPACE}/scripts/create_spec_repo/firebase_sdk.textproto"
