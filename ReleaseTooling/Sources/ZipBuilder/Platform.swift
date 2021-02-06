/*
 * Copyright 2020 Google LLC
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

// The supported platforms.
enum Platform: CaseIterable {
  case iOS
  case macOS
  case tvOS

  var platformTargets: [TargetPlatform] {
    switch self {
    case .iOS: return [.iOSDevice, .iOSSimulator] + (SkipCatalyst.skip ? [] : [.catalyst])
    case .macOS: return [.macOS]
    case .tvOS: return [.tvOSDevice, .tvOSSimulator]
    }
  }

  /// Name of the platform as used in Podfiles.
  var name: String {
    switch self {
    case .iOS: return "ios"
    case .macOS: return "macos"
    case .tvOS: return "tvos"
    }
  }

  /// Minimum supported version
  var minimumVersion: String {
    switch self {
    case .iOS: return PlatformMinimum.minimumIOSVersion
    case .macOS: return PlatformMinimum.minimumMacOSVersion
    case .tvOS: return PlatformMinimum.minimumTVOSVersion
    }
  }
}

class PlatformMinimum {
  fileprivate static var minimumIOSVersion = ""
  fileprivate static var minimumMacOSVersion = ""
  fileprivate static var minimumTVOSVersion = ""
  static func initialize(ios: String, macos: String, tvos: String) {
    minimumIOSVersion = ios
    minimumMacOSVersion = macos
    minimumTVOSVersion = tvos
  }
}

class SkipCatalyst {
  fileprivate static var skip = false
  static func set() {
    skip = true
  }
}
