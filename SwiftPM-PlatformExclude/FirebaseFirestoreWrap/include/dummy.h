// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <TargetConditionals.h>
#if TARGET_OS_WATCH
#warning "Firebase Firestore does not support watchOS"
#endif

#if (defined(TARGET_OS_VISION) && TARGET_OS_VISION) && FIREBASE_BINARY_FIRESTORE
#warning "Firebase Firestore's binary SPM distribution does not support \
          visionOS. See workaround documented in the 10.12.0 release notes: \
          https://firebase.google.com/support/release-notes/ios#version_10120_-_july_11_2023"
#endif
