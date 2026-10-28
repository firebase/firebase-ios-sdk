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

public extension Platform {
  /// Defines a specific Apple operating system compile destination for `xcodebuild archive`.
  struct Destination: Sendable, Equatable, Hashable {
    /// The parent operating system platform.
    public let platform: Platform
    /// Target platform key (e.g. `ios`, `macos`, `catalyst`).
    public let name: String
    /// Destination specifier formatted for `xcodebuild -destination` (e.g. `generic/platform=iOS
    /// Simulator`).
    public let genericDestination: String
    /// Suffix appended to the archive bundle name (e.g. `ios-simulator`).
    public let archiveSuffix: String
    /// Whether this destination targets an Apple platform simulator.
    public let isSimulator: Bool

    /// Initializes a compile destination.
    public init(platform: Platform,
                name: String,
                genericDestination: String,
                archiveSuffix: String,
                isSimulator: Bool = false) {
      self.platform = platform
      self.name = name
      self.genericDestination = genericDestination
      self.archiveSuffix = archiveSuffix
      self.isSimulator = isSimulator
    }

    /// iOS Device destination (`generic/platform=iOS`).
    public static let iOS = Destination(
      platform: .ios,
      name: "ios",
      genericDestination: "generic/platform=iOS",
      archiveSuffix: "ios",
      isSimulator: false
    )
    /// iOS Simulator destination (`generic/platform=iOS Simulator`).
    public static let iOSSimulator = Destination(
      platform: .ios,
      name: "ios-simulator",
      genericDestination: "generic/platform=iOS Simulator",
      archiveSuffix: "ios-simulator",
      isSimulator: true
    )
    /// macOS destination (`generic/platform=macOS`).
    public static let macOS = Destination(
      platform: .macos,
      name: "macos",
      genericDestination: "generic/platform=macOS",
      archiveSuffix: "macos",
      isSimulator: false
    )
    /// Mac Catalyst destination (`generic/platform=macOS,variant=Mac Catalyst`).
    public static let macCatalyst = Destination(
      platform: .catalyst,
      name: "catalyst",
      genericDestination: "generic/platform=macOS,variant=Mac Catalyst",
      archiveSuffix: "catalyst",
      isSimulator: false
    )
    /// tvOS Device destination (`generic/platform=tvOS`).
    public static let tvOS = Destination(
      platform: .tvos,
      name: "tvos",
      genericDestination: "generic/platform=tvOS",
      archiveSuffix: "tvos",
      isSimulator: false
    )
    /// tvOS Simulator destination (`generic/platform=tvOS Simulator`).
    public static let tvOSSimulator = Destination(
      platform: .tvos,
      name: "tvos-simulator",
      genericDestination: "generic/platform=tvOS Simulator",
      archiveSuffix: "tvos-simulator",
      isSimulator: true
    )
    /// watchOS Device destination (`generic/platform=watchOS`).
    public static let watchOS = Destination(
      platform: .watchos,
      name: "watchos",
      genericDestination: "generic/platform=watchOS",
      archiveSuffix: "watchos",
      isSimulator: false
    )
    /// watchOS Simulator destination (`generic/platform=watchOS Simulator`).
    public static let watchOSSimulator = Destination(
      platform: .watchos,
      name: "watchos-simulator",
      genericDestination: "generic/platform=watchOS Simulator",
      archiveSuffix: "watchos-simulator",
      isSimulator: true
    )
    /// visionOS Device destination (`generic/platform=visionOS`).
    public static let visionOS = Destination(
      platform: .visionos,
      name: "visionos",
      genericDestination: "generic/platform=visionOS",
      archiveSuffix: "visionos",
      isSimulator: false
    )
    /// visionOS Simulator destination (`generic/platform=visionOS Simulator`).
    public static let visionOSSimulator = Destination(
      platform: .visionos,
      name: "visionos-simulator",
      genericDestination: "generic/platform=visionOS Simulator",
      archiveSuffix: "visionos-simulator",
      isSimulator: true
    )

    /// List of all 10 supported device and simulator platform destinations.
    public static let allPlatforms: [Destination] = [
      .iOS, .iOSSimulator,
      .macOS, .macCatalyst,
      .tvOS, .tvOSSimulator,
      .watchOS, .watchOSSimulator,
      .visionOS, .visionOSSimulator,
    ]

    /// Converts an array of `Platform` enum values into corresponding device and simulator
    /// `Destination` items.
    public static func destinations(for platforms: [Platform]) -> [Destination] {
      platforms.flatMap(\.destinations)
    }

    /// Converts an array of platform name strings into corresponding device and simulator
    /// `Destination` items.
    public static func destinations(for platformNames: [String]) -> [Destination] {
      let platforms = platformNames.map { Platform.from(platformName: $0) }
      return destinations(for: platforms)
    }
  }
}
