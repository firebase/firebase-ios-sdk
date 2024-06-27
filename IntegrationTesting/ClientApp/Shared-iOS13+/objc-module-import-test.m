// Copyright 2023 Google LLC
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

// ‼️ NOTE: Changes should also be reflected in `objcxx-module-import-test.m`.

#if !COCOAPODS
// TODO(ncooke3): Figure out why this isn't working on CocoaPods.
@import Firebase;
#endif  // !COCOAPODS
@import FirebaseABTesting;
@import FirebaseAnalytics;
@import FirebaseAuth;
@import FirebaseCore;
#if (TARGET_OS_IOS && !TARGET_OS_MACCATALYST) || TARGET_OS_TV
@import FirebaseInAppMessaging;
#endif
@import FirebaseStorage;
