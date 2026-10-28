/*
 * Copyright 2026 Google LLC
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

/// A platform the zip ships for, spelled as in the config.
enum Platform: String, Codable, CodingKeyRepresentable, CaseIterable, Comparable, Sendable {
  case ios, catalyst, macos, tvos, watchos, visionos

  /// The destinations to archive for: device and simulator, or just one for the Mac platforms.
  var destinations: [Destination] {
    let device = Destination(platform: self, isSimulator: false)
    let hasSimulator = self != .catalyst && self != .macos // the Mac platforms have no simulator
    return hasSimulator ? [device, Destination(platform: self, isSimulator: true)] : [device]
  }

  /// The SDK names used in setting conditions (`KEY[sdk=<sdk>*]`). macOS and Mac Catalyst share
  /// `macosx`.
  var sdks: [String] {
    destinations.map(\.sdk)
  }

  /// The setting holding the deployment target. Mac Catalyst has no key of its own: Xcode derives
  /// its minimum macOS from `IPHONEOS_DEPLOYMENT_TARGET`, so its value goes on
  /// `IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]` (macOS builds ignore that key).
  var deploymentTargetKey: String {
    switch self {
    case .ios, .catalyst: "IPHONEOS_DEPLOYMENT_TARGET"
    case .macos: "MACOSX_DEPLOYMENT_TARGET"
    case .tvos: "TVOS_DEPLOYMENT_TARGET"
    case .watchos: "WATCHOS_DEPLOYMENT_TARGET"
    case .visionos: "XROS_DEPLOYMENT_TARGET"
    }
  }

  /// The name used in `platformFilters` of build files and target dependencies.
  var platformFilter: String {
    switch self {
    case .ios: "ios"
    case .catalyst: "maccatalyst"
    case .macos: "macos"
    case .tvos: "tvos"
    case .watchos: "watchos"
    case .visionos: "xros"
    }
  }

  static func < (lhs: Platform, rhs: Platform) -> Bool {
    allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
  }
}

extension KeyedEncodingContainer {
  /// Used by synthesized `Codable`: platform sets encode sorted, so `plan.json` is byte-stable.
  mutating func encode(_ value: Set<Platform>, forKey key: Key) throws {
    try encode(value.sorted(), forKey: key)
  }

  /// Same, for optional platform sets.
  mutating func encodeIfPresent(_ value: Set<Platform>?, forKey key: Key) throws {
    try encodeIfPresent(value?.sorted(), forKey: key)
  }
}

/// One `xcodebuild archive` destination, e.g. `ios-simulator`.
struct Destination: Codable, Hashable, Sendable {
  var platform: Platform
  var isSimulator: Bool

  /// Every destination of every platform, in platform order.
  static let all = Platform.allCases.flatMap(\.destinations)

  /// e.g. `ios`, `ios-simulator`, `catalyst`.
  var name: String {
    isSimulator ? "\(platform.rawValue)-simulator" : platform.rawValue
  }

  var sdk: String {
    switch platform {
    case .ios: isSimulator ? "iphonesimulator" : "iphoneos"
    case .catalyst, .macos: "macosx"
    case .tvos: isSimulator ? "appletvsimulator" : "appletvos"
    case .watchos: isSimulator ? "watchsimulator" : "watchos"
    case .visionos: isSimulator ? "xrsimulator" : "xros"
    }
  }

  /// The `-destination` argument for `xcodebuild`.
  var xcodebuildDestination: String {
    let name = switch platform {
    case .ios: "iOS"
    case .catalyst: "macOS,variant=Mac Catalyst"
    case .macos: "macOS"
    case .tvos: "tvOS"
    case .watchos: "watchOS"
    case .visionos: "visionOS"
    }
    return "generic/platform=\(name)\(isSimulator ? " Simulator" : "")"
  }
}
