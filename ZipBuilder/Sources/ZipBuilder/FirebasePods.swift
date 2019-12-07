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
  case auth = "FirebaseAuth"
  case core = "FirebaseCore"
  case database = "FirebaseDatabase"
  case dynamicLinks = "FirebaseDynamicLinks"
  case firebase = "Firebase"
  case firestore = "FirebaseFirestore"
  case functions = "FirebaseFunctions"
  case googleSignIn = "GoogleSignIn"
  case inAppMessaging = "FirebaseInAppMessaging"
  case inAppMessagingDisplay = "FirebaseInAppMessagingDisplay"
  case messaging = "FirebaseMessaging"
  case mlModelInterpreter = "FirebaseMLModelInterpreter"
  case mlNaturalLanguage = "FirebaseMLNaturalLanguage"
  case mlNLLanguageID = "FirebaseMLNLLanguageID"
  case mlNLSmartReply = "FirebaseMLNLSmartReply"
  case mlNLTranslate = "FirebaseMLNLTranslate"
  case mlVision = "FirebaseMLVision"
  case mlVisionAutoML = "FirebaseMLVisionAutoML"
  case mlVisionObjectDetection = "FirebaseMLVisionObjectDetection"
  case mlVisionBarcodeModel = "FirebaseMLVisionBarcodeModel"
  case mlVisionFaceModel = "FirebaseMLVisionFaceModel"
  case mlVisionLabelModel = "FirebaseMLVisionLabelModel"
  case mlVisionTextModel = "FirebaseMLVisionTextModel"
  case performance = "FirebasePerformance"
  case remoteConfig = "FirebaseRemoteConfig"
  case storage = "FirebaseStorage"

  /// Flag to explicitly exclude any Resources from being copied.
  var excludeResources: Bool {
    switch self {
    case .mlVision, .mlVisionBarcodeModel, .mlVisionLabelModel:
      return true
    default:
      return false
    }
  }

  /// Describes the dependency on other frameworks for the README file.
  static func readmeHeader(podName: String) -> String {
    var header = "## \(podName)"
    if !(podName == "FirebaseAnalytics" || podName == "GoogleSignIn") {
      header += " (~> FirebaseAnalytics)"
    }
    header += "\n"
    return header
  }

  // TODO: Evaluate if there's a way to do this that doesn't require the hardcoded values to be
  //   maintained. Likely looking at the `vendored_frameworks` from each Pod's Podspec.
  /// Returns folders to remove from the Zip file from a specific pod for de-duplication. This
  /// is necessary for the MLKit frameworks because of their unique structure, an unnecessary amount
  /// of frameworks get pulled in.
  static func duplicateFrameworksToRemove(pod: String) -> [String] {
    switch pod {
    case "FirebaseMLVisionBarcodeModel", "FirebaseMLVisionFaceModel", "FirebaseMLVisionLabelModel",
         "FirebaseMLVisionTextModel":
      return ["GTMSessionFetcher.framework", "Protobuf.framework"]
    default:
      return []
    }
  }
}
