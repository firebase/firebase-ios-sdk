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

set -ex

REPO=`pwd`
if [ ! -d "quickstart-ios" ]; then
  git clone https://github.com/firebase/quickstart-ios.git
fi
cd quickstart-ios/"${SAMPLE}"
chmod +x ../scripts/info_script.rb
ruby ../scripts/info_script.rb "${SAMPLE}"

mkdir -p Firebase/
# Create non Firebase Frameworks and move to Firebase/ dir.
if [[ ! -z "$NON_FIREBASE_SDKS" ]]; then
  REPO="${REPO}" NON_FIREBASE_SDKS="${NON_FIREBASE_SDKS}" "${REPO}"/scripts/build_non_firebase_sdks.sh
fi
if [ ! -f "Firebase/Firebase.h" ]; then
  mv "${HOME}"/ios_frameworks/Firebase/Firebase.h Firebase/
fi
if [ ! -f "Firebase/module.modulemap" ]; then
  mv "${HOME}"/ios_frameworks/Firebase/module.modulemap Firebase/
fi
for file in "$@"
do
  if [ ! -f "Firebase/${file}" ]; then
    mv -n ${file} Firebase/
  fi
done

if [[ "${SAMPLE}" == "Authentication" ]]; then
../scripts/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path usr/lib/libc++.dylib
../scripts/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path accelerate.framework --source_tree DEVELOPER_FRAMEWORKS_DIR
fi

if [[ "${SAMPLE}" == "Firestore" ]]; then
../scripts/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/FirebaseUI.xcframework/Resources/FirebaseAuthUI.bundle
../scripts/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/FirebaseUI.xcframework/Resources/FirebaseEmailAuthUI.bundle
fi

../scripts/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/
