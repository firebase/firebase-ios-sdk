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
  case mlVision = "MLVision"
  case mlVisionBarcodeModel = "MLVisionBarcodeModel"
  case mlVisionFaceModel = "MLVisionFaceModel"
  case mlVisionLabelModel = "MLVisionLabelModel"
  case mlVisionTextModel = "MLVisionTextModel"
  case performance = "Performance"
  case remoteConfig = "RemoteConfig"
  case storage = "Storage"

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

  /// Describes the dependency on other frameworks for the README file.
  public func readmeHeader() -> String {
    var header = "## \(self.rawValue)"
    if self != .analytics {
      header += " (~> Analytics)"
    }
    header += "\n"
    return header
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
