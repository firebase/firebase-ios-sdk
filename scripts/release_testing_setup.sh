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

if [ -f "${HOME}/.cocoapods/repos" ]; then
  find  "${HOME}/.cocoapods/repos" -type d -maxdepth 1 -exec sh -c 'pod repo remove $(basename {})' \;
fi
git config --global user.email "google-oss-bot@example.com"
git config --global user.name "google-oss-bot"
mkdir -p /tmp/test/firebase-ios-sdk
git clone -b "${podspec_repo_branch}" https://github.com/firebase/firebase-ios-sdk.git /tmp/test/firebase-ios-sdk
cd /tmp/test/firebase-ios-sdk
git tag -a "test" -m "release testing"
sed  -i "" "s/\s*:git.*/:git => '\/tmp\/test\/firebase-ios-sdk',/; s/\s*:tag.*/:tag => 'test'/" *.podspec
cd "${GITHUB_WORKSPACE}/ZipBuilder"
swift build
./.build/debug/firebase-pod-updater --git-root "/tmp/test/firebase-ios-sdk" --releasing-pods "${GITHUB_WORKSPACE}/scripts/create_spec_repo/firebase_sdk.textproto"
