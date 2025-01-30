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

// ‼️ Changes should also be reflected in the ObjC/ObjC++ files if applicable.

#if !COCOAPODS
  // TODO(ncooke3): Figure out why this isn't working on CocoaPods.
  import Firebase
#endif // !COCOAPODS
#if SWIFT_PACKAGE
  import FirebaseAuthCombineSwift
#endif // SWIFT_PACKAGE
// NOTE(ncooke3): `FirebaseABTesting` is not listed as a library.
import FirebaseABTesting
import FirebaseAnalytics
import FirebaseAppCheck
import FirebaseAuth
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppDistribution
#endif
import FirebaseCore
import FirebaseCrashlytics
import FirebaseDatabase
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseDynamicLinks
#endif
import FirebaseFirestore
#if SWIFT_PACKAGE
  import FirebaseFirestoreCombineSwift
#endif // SWIFT_PACKAGE
import FirebaseFunctions
#if SWIFT_PACKAGE
  import FirebaseFunctionsCombineSwift
#endif // SWIFT_PACKAGE
import FirebaseInstallations
import FirebaseMessaging
import FirebaseMLModelDownloader
#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
  import FirebaseInAppMessaging
  import FirebasePerformance
#endif
import FirebaseRemoteConfig
import FirebaseStorage
#if SWIFT_PACKAGE
  import FirebaseStorageCombineSwift
#endif // SWIFT_PACKAGE
