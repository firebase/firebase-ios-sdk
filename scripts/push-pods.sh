#!/usr/bin/env bash

# Copyright 2018 Google
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

# Push all the io2018 pods

# When bootstrapping a repo, FirebaseCore must be pushed first, then
# FirebaseInstanceID, then FirebaseAnalytics, then the rest
# Most of the warnings are tvOS specific. The Firestore one needs
# investigation.

pod repo push io2018 FirebaseCore.podspec
pod repo push io2018 FirebaseAuth.podspec --allow-warnings
pod repo push io2018 FirebaseDatabase.podspec --allow-warnings
pod repo push io2018 FirebaseFirestore.podspec --allow-warnings
pod repo push io2018 FirebaseFunctions.podspec
pod repo push io2018 FirebaseMessaging.podspec
pod repo push io2018 FirebaseStorage.podspec

# FirebaseAuth warnings
#    https://github.com/firebase/firebase-ios-sdk/pull/1159
#    https://github.com/google/google-toolbox-for-mac/issues/162

# FirebaseDatabase warnings
#    https://github.com/firebase/firebase-ios-sdk/pull/1155

# FirebaseFirestore warning (no plan to fix)
#    https://github.com/firebase/firebase-ios-sdk/issues/1143
