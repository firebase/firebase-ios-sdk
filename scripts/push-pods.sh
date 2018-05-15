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

# Push GitHub pods to cpdc-internal-spec.

# When bootstrapping a repo, FirebaseCore must be pushed first, then
# FirebaseInstanceID, then FirebaseAnalytics, then the rest
# Most of the warnings are tvOS specific. The Firestore one needs
# investigation.

pod cache clean FirebaseCore --all
#pod cache clean FirebaseAuth --all
#pod cache clean FirebaseDatabase --all
pod cache clean FirebaseFirestore --all
#pod cache clean FirebaseFunctions --all
#pod cache clean FirebaseMessaging --all
#pod cache clean FirebaseStorage --all

pod repo push cpdc-internal-spec FirebaseCore.podspec
#pod repo push cpdc-internal-spec FirebaseAuth.podspec
#pod repo push cpdc-internal-spec FirebaseDatabase.podspec
pod repo push cpdc-internal-spec FirebaseFirestore.podspec --allow-warnings
#pod repo push cpdc-internal-spec FirebaseFunctions.podspec
#pod repo push cpdc-internal-spec FirebaseMessaging.podspec
#pod repo push cpdc-internal-spec FirebaseStorage.podspec

# FirebaseFirestore warning (no plan to fix)
#    https://github.com/firebase/firebase-ios-sdk/issues/1143
