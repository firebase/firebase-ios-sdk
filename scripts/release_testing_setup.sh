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

# This script will `git clone` the SDK repo to local and look for the latest
# release branch
set -xe

TESTINGMODE=${1-}

if [ -f "${HOME}/.cocoapods/repos" ]; then
  find "${HOME}/.cocoapods/repos" -type d -maxdepth 1 -exec sh -c 'pod repo remove $(basename {})' \;
fi

mkdir -p "${local_sdk_repo_dir}"
echo "git clone from github.com/firebase/firebase-ios-sdk.git to ${local_sdk_repo_dir}"
set +x
# Using token here to update tags later.
git clone -q https://"${BOT_TOKEN}"@github.com/firebase/firebase-ios-sdk.git "${local_sdk_repo_dir}"
set -x

cd  "${local_sdk_repo_dir}"
# The chunk below is to determine the latest version by searching
# Get the latest released tag Cocoapods-X.Y.Z for release and prerelease testing, beta version will be excluded.
test_version=$(git tag -l --sort=-version:refname CocoaPods-*[0-9] | head -n 1)

git config --global user.email "google-oss-bot@example.com"
git config --global user.name "google-oss-bot"
git checkout "${podspec_repo_branch}"
# Ensure the tag version including pod version to avoid warnings.
# https://github.com/CocoaPods/Core/blob/e6451e172c33f3aa77a3f8baa7b6b5b8c3b5da14/lib/cocoapods-core/specification/linter.rb#L372-L374
pod_testing_version=`echo "${test_version}" | sed "s/CocoaPods-//"`
if [ "$TESTINGMODE" = "release_testing" ]; then
  git checkout "${test_version}"
  echo "Podspecs tags of Nightly release testing will be updated to ${test_version}."
  # Update source and tag, e.g.  ":tag => 'CocoaPods-' + s.version.to_s" to
  # ":tag => 'CocoaPods-7.9.0'"
  sed -i "" "s/\s*:tag.*/:tag => '${test_version}'/" *.podspec
  sed -i "" "s/s\.version[[:space:]]*=.*/s\.version='${pod_testing_version}'/" *.podspec
elif [ "$TESTINGMODE" = "prerelease_testing" ]; then
  tag_version="${test_version}.nightly"
  echo "A new tag, ${tag_version},for prerelease testing will be created."
  set +e
  # If tag_version is new to the remote, remote cannot delete a non-existent
  # tag, so error is allowed here.
  git push origin --delete "${tag_version}"
  set -e
  git tag -f -a "${tag_version}" -m "release testing"
  git push origin "${tag_version}"
  # Update source and tag, e.g.  ":tag => 'CocoaPods-' + s.version.to_s" to
  # ":tag => ${test_version}.nightly"
  sed -i "" "s/\s*:tag.*/:tag => '${tag_version}'/" *.podspec
  sed -i "" "s/s\.version[[:space:]]*=.*/s\.version='${pod_testing_version}'/" *.podspec
fi
