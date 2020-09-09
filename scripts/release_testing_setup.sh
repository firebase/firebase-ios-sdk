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

set -x

if [ -f "${HOME}/.cocoapods/repos" ]; then
  find "${HOME}/.cocoapods/repos" -type d -maxdepth 1 -exec sh -c 'pod repo remove $(basename {})' \;
fi
git config --global user.email "google-oss-bot@example.com"
git config --global user.name "google-oss-bot"
mkdir -p /tmp/test/firebase-ios-sdk
git clone -b "${podspec_repo_branch}" https://"${BOT_TOKEN}"@github.com/firebase/firebase-ios-sdk.git "${local_sdk_repo_dir}"
cd  "${local_sdk_repo_dir}"
git tag -a "test" -m "release testing"
# git push origin test
# Update source and tag, e.g.  ":tag => 'CocoaPods-' + s.version.to_s" to
# ":tag => test"
sed  -i "" "s/\s*:tag.*/:tag => 'Firestore-1.17.1'/" *.podspec
cd "${GITHUB_WORKSPACE}/ZipBuilder"
swift build
# Update Pod versions.
./.build/debug/firebase-pod-updater --git-root "${local_sdk_repo_dir}" --releasing-pods "${GITHUB_WORKSPACE}/scripts/create_spec_repo/firebase_sdk.textproto"
