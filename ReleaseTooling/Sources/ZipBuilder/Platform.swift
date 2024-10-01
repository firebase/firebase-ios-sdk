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
  case watchOS

  var platformTargets: [TargetPlatform] {
    switch self {
    case .iOS: return [.iOSDevice, .iOSSimulator] + (SkipCatalyst.skip ? [] : [.catalyst])
    case .macOS: return [.macOS]
    case .tvOS: return [.tvOSDevice, .tvOSSimulator]
    case .watchOS: return [.watchOSDevice, .watchOSSimulator]
    }
  }

  /// Name of the platform as used in Podfiles.
  var name: String {
    switch self {
    case .iOS: return "ios"
    case .macOS: return "macos"
    case .tvOS: return "tvos"
    case .watchOS: return "watchos"
    }
  }

  /// Minimum supported version
  var minimumVersion: String {
    switch self {
    case .iOS: return PlatformMinimum.minimumIOSVersion
    case .macOS: return PlatformMinimum.minimumMacOSVersion
    case .tvOS: return PlatformMinimum.minimumTVOSVersion
    case .watchOS: return PlatformMinimum.minimumWatchOSVersion
    }
  }
}

enum PlatformMinimum {
  fileprivate static var minimumIOSVersion = ""
  fileprivate static var minimumMacOSVersion = ""
  fileprivate static var minimumTVOSVersion = ""
  fileprivate static var minimumWatchOSVersion = ""
  static func initialize(ios: String, macos: String, tvos: String, watchos: String) {
    minimumIOSVersion = ios
    minimumMacOSVersion = macos
    minimumTVOSVersion = tvos
    minimumWatchOSVersion = watchos
  }

  /// Useful to disable minimum version checking on pod installation. Pods still get built with
  /// for the minimum version specified in the podspec.
  static func useRecentVersions() {
    minimumIOSVersion = "15.0"
    minimumMacOSVersion = "12.0"
    minimumTVOSVersion = "15.0"
    minimumWatchOSVersion = "8.0"
  }
}

enum SkipCatalyst {
  fileprivate static var skip = false
  static func set() {
    skip = true
  }
}
