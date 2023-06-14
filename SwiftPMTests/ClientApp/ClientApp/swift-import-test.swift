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

import Firebase
// NOTE(ncooke3): `FirebaseABTesting` is not listed as a library.
import FirebaseABTesting
import FirebaseAnalytics
import FirebaseAnalyticsSwift
import FirebaseAppCheck
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseAppDistribution
#endif
import FirebaseAuth
import FirebaseAuthCombineSwift
import FirebaseCore
import FirebaseCrashlytics
import FirebaseDatabase
import FirebaseDatabaseSwift
#if os(iOS) && !targetEnvironment(macCatalyst)
  import FirebaseDynamicLinks
#endif
import FirebaseFirestore
import FirebaseFirestoreCombineSwift
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseFunctionsCombineSwift
#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
  import FirebaseInAppMessaging
  import FirebaseInAppMessagingSwift
#endif
import FirebaseInstallations
import FirebaseMessaging
import FirebaseMLModelDownloader
#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
  import FirebasePerformance
#endif
import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift
import FirebaseStorage
import FirebaseStorageCombineSwift
