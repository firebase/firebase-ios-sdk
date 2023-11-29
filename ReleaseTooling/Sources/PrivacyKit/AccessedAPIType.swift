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

import Foundation

/// A structure containing metadata about the usage of API that requires justification for use.
/// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api
public struct AccessedAPIType: Encodable {
  public enum Category: String, Encodable {
    case fileTimestamp = "NSPrivacyAccessedAPICategoryFileTimestamp"
    case systemBootTime = "NSPrivacyAccessedAPICategorySystemBootTime"
    case diskSpace = "NSPrivacyAccessedAPICategoryDiskSpace"
    case activeKeyboards = "NSPrivacyAccessedAPICategoryActiveKeyboards"
    case userDefaults = "NSPrivacyAccessedAPICategoryUserDefaults"

    /// The possible reasons that this category of API may be accessed.
    public var possibleReasons: [Reason] {
      // TODO(ncooke3): It would be nice if reasons were scoped to categories
      // in a type-safe way.
      switch self {
      case .fileTimestamp: return [._DDA9_1, ._C617_1, ._3B52_1]
      case .systemBootTime: return [._35F9_1]
      case .diskSpace: return [._85F4_1, ._E174_1]
      case .activeKeyboards: return [._3EC4_1, ._54BD_1]
      case .userDefaults: return [._CA92_1]
      }
    }
  }

  public enum Reason: String, Encodable {
    // File timestamp APIs
    case _DDA9_1 = "DDA9.1"
    case _C617_1 = "C617.1"
    case _3B52_1 = "3B52.1"
    // System boot time APIs
    case _35F9_1 = "35F9.1"
    // Disk space APIs
    case _85F4_1 = "85F4.1"
    case _E174_1 = "E174.1"
    // Active keyboard APIs
    case _3EC4_1 = "3EC4.1"
    case _54BD_1 = "54BD.1"
    // User defaults APIs
    case _CA92_1 = "CA92.1"

    public var description: String {
      switch self {
      case ._DDA9_1:
        return "Declare this reason to display file timestamps to the person " +
          "using the device. Information accessed for this reason, or any " +
          "derived information, may not be sent off-device."
      case ._C617_1:
        return "Declare this reason to access the timestamps of files inside " +
          "the app container, app group container, or the app’s CloudKit " +
          "container."
      case ._3B52_1:
        return "Declare this reason to access the timestamps of files or " +
          "directories that the user specifically granted access to, such " +
          "as using a document picker view controller."
      case ._35F9_1:
        return "Declare this reason to access the system boot time in order " +
          "to measure the amount of time that has elapsed between events " +
          "that occurred within the app or to perform calculations to enable " +
          "timers. Information accessed for this reason, or any derived " +
          "information, may not be sent off-device. There is an exception " +
          "for information about the amount of time that has elapsed " +
          "between events that occurred within the app, which may be sent " +
          "off-device."
      case ._85F4_1:
        return "Declare this reason to display disk space information to the " +
          "person using the device. Disk space may be displayed in units of " +
          "information (such as bytes) or units of time combined with a " +
          "media type (such as minutes of HD video). Information accessed " +
          "for this reason, or any derived information, may not be sent " +
          "off-device."
      case ._E174_1:
        return "Declare this reason to check whether there is sufficient " +
          "disk space to write files, or to check whether the disk space is " +
          "low so that the app can delete files when the disk space is low. " +
          "The app must behave differently based on disk space in a way that " +
          "is observable to users. Information accessed for this reason, or " +
          "any derived information, may not be sent off-device. There is an " +
          "exception that allows the app to avoid downloading files from a " +
          "server when disk space is insufficient."
      case ._3EC4_1:
        return "Declare this reason if your app is a custom keyboard app, " +
          "and you access this API category to determine the keyboards that " +
          "are active on the device. Providing a systemwide custom keyboard " +
          "to the user must be the primary functionality of the app. " +
          "Information accessed for this reason, or any derived " +
          "information, may not be sent off-device."
      case ._54BD_1:
        return "Declare this reason to access active keyboard information to " +
          "present the correct customized user interface to the person " +
          "using the device. The app must have text fields for entering or " +
          "editing text and must behave differently based on active " +
          "keyboards in a way that is observable to users. Information " +
          "accessed for this reason, or any derived information, may not be " +
          "sent off-device."
      case ._CA92_1:
        return "Declare this reason to access user defaults to read and " +
          "write information that is only accessible to the app itself. This " +
          "reason does not permit reading information that was written by " +
          "other apps or the system, or writing information that can be " +
          "accessed by other apps."
      }
    }
  }

  public let type: Category
  public let reasons: [Reason]

  private enum CodingKeys: String, CodingKey {
    case type = "NSPrivacyAccessedAPIType"
    case reasons = "NSPrivacyAccessedAPITypeReasons"
  }
}
