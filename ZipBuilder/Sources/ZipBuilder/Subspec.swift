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

/// All the subspecs available in the Firebase pod.
public enum Subspec: String {
  case abTesting = "ABTesting"
  case adMob = "AdMob"
  case analytics = "Analytics"
  case auth = "Auth"
  case core = "Core"
  case crash = "Crash"
  case database = "Database"
  case dynamicLinks = "DynamicLinks"
  case firestore = "Firestore"
  case functions = "Functions"
  case inAppMessaging = "InAppMessaging"
  case inAppMessagingDisplay = "InAppMessagingDisplay"
  case invites = "Invites"
  case messaging = "Messaging"
  case mlModelInterpreter = "MLModelInterpreter"
  case mlNaturalLanguage = "MLNaturalLanguage"
  case mlNLLanguageID = "MLNLLanguageID"
  case mlVision = "MLVision"
  case mlVisionBarcodeModel = "MLVisionBarcodeModel"
  case mlVisionFaceModel = "MLVisionFaceModel"
  case mlVisionLabelModel = "MLVisionLabelModel"
  case mlVisionTextModel = "MLVisionTextModel"
  case performance = "Performance"
  case remoteConfig = "RemoteConfig"
  case storage = "Storage"

  /// Flag to explicitly exclude any Resources from being copied.
  public var excludeResources: Bool {
    switch self {
    case .mlVision, .mlVisionBarcodeModel, .mlVisionLabelModel:
      return true
    default:
      return false
    }
  }

  // TODO: Once we default to Swift 4.2 (in Xcode 10) we can conform to "CaseIterable" protocol to
  //       automatically generate this method.
  /// All the subspecs to parse.
  public static func allCases() -> [Subspec] {
    return [
      .abTesting,
      .adMob,
      .analytics,
      .auth,
      .core,
      .crash,
      .database,
      .dynamicLinks,
      .firestore,
      .functions,
      .inAppMessaging,
      .inAppMessagingDisplay,
      .invites,
      .messaging,
      .mlModelInterpreter,
      .mlNaturalLanguage,
      .mlNLLanguageID,
      .mlVision,
      .mlVisionBarcodeModel,
      .mlVisionFaceModel,
      .mlVisionLabelModel,
      .mlVisionTextModel,
      .performance,
      .remoteConfig,
      .storage
    ]
  }

  /// The minimum supported iOS version.
  public func minSupportedIOSVersion() -> OperatingSystemVersion {
    // All ML pods have a minimum iOS version of 9.0.
    if rawValue.hasPrefix("ML") {
      return OperatingSystemVersion(majorVersion: 9, minorVersion: 0, patchVersion: 0)
    } else {
      return OperatingSystemVersion(majorVersion: 8, minorVersion: 0, patchVersion: 0)
    }
  }

  /// Describes the dependency on other frameworks for the README file.
  public func readmeHeader() -> String {
    var header = "## \(self.rawValue)"
    if self != .analytics {
      header += " (~> Analytics)"
    }
    header += "\n"
    return header
  }

  // TODO: Evaluate if there's a way to do this that doesn't require the hardcoded values to be
  //   maintained.
  /// Returns folders to remove from the Zip file from a specific subspec for de-duplication. This
  /// is necessary for the MLKit frameworks because of their unique structure, an unnecessary amount
  /// of frameworks get pulled in.
  public func duplicateFrameworksToRemove() -> [String] {
    switch self {
    case .mlVision:
      return ["BarcodeDetector.framework",
              "FaceDetector.framework",
              "LabelDetector.framework",
              "TextDetector.framework"]
    case .mlVisionBarcodeModel:
      return ["FaceDetector.framework",
              "GTMSessionFetcher.framework",
              "GoogleMobileVision.framework",
              "LabelDetector.framework",
              "Protobuf.framework",
              "TextDetector.framework"]
    case .mlVisionFaceModel:
      return ["BarcodeDetector.framework",
              "GTMSessionFetcher.framework",
              "GoogleMobileVision.framework",
              "LabelDetector.framework",
              "Protobuf.framework",
              "TextDetector.framework"]
    case .mlVisionLabelModel:
      return ["BarcodeDetector.framework",
              "FaceDetector.framework",
              "GTMSessionFetcher.framework",
              "GoogleMobileVision.framework",
              "Protobuf.framework",
              "TextDetector.framework"]
    case .mlVisionTextModel:
      return ["BarcodeDetector.framework",
              "FaceDetector.framework",
              "GTMSessionFetcher.framework",
              "GoogleMobileVision.framework",
              "LabelDetector.framework",
              "Protobuf.framework"]
    default:
      // By default, no folders need to be removed.
      return []
    }
  }

  /// Returns a group of duplicate Resources that should be removed, if any.
  public func duplicateResourcesToRemove() -> [String] {
    switch self {
    case .mlVisionFaceModel:
      return ["GoogleMVTextDetectorResources.bundle"]
    case .mlVisionTextModel:
      return ["GoogleMVFaceDetectorResources.bundle"]
    default:
      // By default, no resources should be removed.
      return []
    }
  }
}

/// Add comparitor for OperatingSystemVersion. We only need the `>` since we don't care about equals
/// or anything else, we just need to find the largest value between two structs.
extension OperatingSystemVersion: Comparable, Equatable {
  public static func < (lhs: OperatingSystemVersion, rhs: OperatingSystemVersion) -> Bool {
    // The priority is major.minor.patch, only keep searching to lower importance if the higher
    // levels are equal.
    if lhs.majorVersion < rhs.majorVersion { return true }
    if lhs.majorVersion > rhs.majorVersion { return false }

    // Major version must be equal, continue to minor.
    if lhs.minorVersion < rhs.minorVersion { return true }
    if lhs.minorVersion > rhs.minorVersion { return false }

    // Down to patch, just return the comparison since there are no more levels.
    return lhs.minorVersion < rhs.minorVersion
  }

  public static func >(lhs: OperatingSystemVersion, rhs: OperatingSystemVersion) -> Bool {
    // The priority is major.minor.patch, only keep searching to lower importance if the higher
    // levels are equal.
    if lhs.majorVersion > rhs.majorVersion { return true }
    if lhs.majorVersion < rhs.majorVersion { return false }

    // Major version must be equal, continue to minor.
    if lhs.minorVersion > rhs.minorVersion { return true }
    if lhs.minorVersion < rhs.minorVersion { return false }

    // Down to patch, just return the comparison since there are no more levels.
    return lhs.minorVersion > rhs.minorVersion
  }

  public static func ==(lhs: OperatingSystemVersion, rhs: OperatingSystemVersion) -> Bool {
    return lhs.majorVersion == rhs.majorVersion &&
           lhs.minorVersion == rhs.minorVersion &&
           lhs.patchVersion == rhs.patchVersion
  }
}

extension OperatingSystemVersion {
  /// The string to define this operating system in a Podfile. In the form "MAJOR.MINOR"
  public func podVersion() -> String {
    return "\(majorVersion).\(minorVersion)"
  }
}
