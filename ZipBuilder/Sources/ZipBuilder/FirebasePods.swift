/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

// TODO: Auto generate this list from the Firebase.podspec and others, probably with a script.
/// All the CocoaPods related to packaging and distributing Firebase.
enum FirebasePods: String, CaseIterable {
  case abTesting = "FirebaseABTesting"
  case adMob = "Google-Mobile-Ads-SDK"
  case analytics = "FirebaseAnalytics"
  case appdistribution = "FirebaseAppDistribution"
  case auth = "FirebaseAuth"
  case core = "FirebaseCore"
  case crashlytics = "FirebaseCrashlytics"
  case database = "FirebaseDatabase"
  case dynamicLinks = "FirebaseDynamicLinks"
  case firebase = "Firebase"
  case firestore = "FirebaseFirestore"
  case functions = "FirebaseFunctions"
  case googleSignIn = "GoogleSignIn"
  case inAppMessaging = "FirebaseInAppMessaging"
  case messaging = "FirebaseMessaging"
  case mlModelInterpreter = "FirebaseMLModelInterpreter"
  case mlVision = "FirebaseMLVision"
  case performance = "FirebasePerformance"
  case remoteConfig = "FirebaseRemoteConfig"
  case storage = "FirebaseStorage"

  /// Describes the dependency on other frameworks for the README file.
  static func readmeHeader(podName: String) -> String {
    var header = "## \(podName)"
    if !(podName == "FirebaseAnalytics" || podName == "GoogleSignIn") {
      header += " (~> FirebaseAnalytics)"
    }
    header += "\n"
    return header
  }
}
