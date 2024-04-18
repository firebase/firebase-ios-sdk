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
QS_SCRIPTS="${REPO}"/quickstart-ios/scripts
cd quickstart-ios/"${SAMPLE}"

if [[ ! -z "$LEGACY" ]]; then
  cd "Legacy${SAMPLE}Quickstart"
fi

# Make sure the Xcode project has at least one Swift file.
# See https://forums.swift.org/t/using-binary-swift-sdks-from-non-swift-apps/55989
touch foo.swift
"${REPO}"/scripts/update_xcode_target.rb "${SAMPLE}Example.xcodeproj" "${SAMPLE}Example" foo.swift

mkdir -p Firebase/
# Create non Firebase Frameworks and move to Firebase/ dir.
if [[ ! -z "$NON_FIREBASE_SDKS" ]]; then
  REPO="${REPO}" NON_FIREBASE_SDKS="${NON_FIREBASE_SDKS}" "${REPO}"/scripts/build_non_firebase_sdks.sh
fi
if [ ! -f "Firebase/Firebase.h" ]; then
  cp "${HOME}"/ios_frameworks/Firebase/Firebase.h Firebase/
fi
if [ ! -f "Firebase/module.modulemap" ]; then
  cp "${HOME}"/ios_frameworks/Firebase/module.modulemap Firebase/
fi
for file in "$@"
do
  if [ ! -d "Firebase/$(basename ${file})" ]; then
    rsync -a ${file} Firebase/
  fi
done

if [[ "${SAMPLE}" == "Authentication" ]]; then
  "${QS_SCRIPTS}"/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path usr/lib/libc++.dylib
  "${QS_SCRIPTS}"/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path accelerate.framework --source_tree DEVELOPER_FRAMEWORKS_DIR
fi

if [[ "${SAMPLE}" == "Firestore" ]]; then
  "${QS_SCRIPTS}"/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/FirebaseAuthUI.xcframework/Resources/FirebaseAuthUI.bundle
  "${QS_SCRIPTS}"/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/FirebaseEmailAuthUI.xcframework/Resources/FirebaseEmailAuthUI.bundle
fi

"${QS_SCRIPTS}"/add_framework_script.rb --sdk "${SAMPLE}" --target "${TARGET}" --framework_path Firebase/
