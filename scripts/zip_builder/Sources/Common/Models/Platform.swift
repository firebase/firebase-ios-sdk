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
@_exported import PackageModel

/// Represents an operating system platform targeted by the zip builder.
public enum Platform: Hashable, Codable, Sendable, Comparable, CaseIterable, RawRepresentable {
  case ios
  case macos
  case tvos
  case watchos
  case catalyst
  case visionos
  case custom(String)

  /// All standard supported Apple platforms.
  public static let allApplePlatforms: [Platform] = [
    .ios, .macos, .tvos, .watchos, .catalyst, .visionos,
  ]

  /// Preferred deterministic sorting order for platform slices and schemes.
  public static let preferredPlatformOrder: [Platform] = [
    .ios, .macos, .tvos, .watchos, .catalyst, .visionos,
  ]

  /// Default set of platforms targeted when no conditions are declared.
  public static let defaultPlatforms: [Platform] = [
    .ios, .macos, .tvos, .watchos, .catalyst,
  ]

  /// All cases conforming to `CaseIterable`.
  public static var allCases: [Platform] {
    allApplePlatforms
  }

  /// Raw string representation matching CLI argument names and directory keys (e.g. `ios`,
  /// `macos`).
  public var rawValue: String {
    switch self {
    case .ios: return "ios"
    case .macos: return "macos"
    case .tvos: return "tvos"
    case .watchos: return "watchos"
    case .catalyst: return "catalyst"
    case .visionos: return "visionos"
    case let .custom(name): return name.lowercased()
    }
  }

  /// Initializes a platform from a string representation.
  public init(rawValue: String) {
    self = Platform.from(platformName: rawValue)
  }

  /// Decodes a platform from a single string container.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    self = Platform.from(platformName: raw)
  }

  /// Encodes a platform as its raw string value.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  /// Compares two platform instances alphabetically by their raw string values.
  public static func < (lhs: Platform, rhs: Platform) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  // MARK: - Identification & Canonical Naming

  /// Canonical Apple platform name (e.g. `iOS`, `macOS`, `tvOS`, `watchOS`, `visionOS`,
  /// `macCatalyst`).
  public var canonicalName: String {
    switch self {
    case .ios: return "iOS"
    case .macos: return "macOS"
    case .tvos: return "tvOS"
    case .watchos: return "watchOS"
    case .visionos: return "visionOS"
    case .catalyst: return "macCatalyst"
    case let .custom(name): return name
    }
  }

  // MARK: - Xcode Build Settings & Target Device Families

  /// The Xcode project build setting key for this platform's deployment target.
  /// Note: Catalyst returns nil because it inherits IPHONEOS_DEPLOYMENT_TARGET.
  public var deploymentTargetSettingKey: String? {
    switch self {
    case .ios: return "IPHONEOS_DEPLOYMENT_TARGET"
    case .macos: return "MACOSX_DEPLOYMENT_TARGET"
    case .tvos: return "TVOS_DEPLOYMENT_TARGET"
    case .watchos: return "WATCHOS_DEPLOYMENT_TARGET"
    case .visionos: return "XROS_DEPLOYMENT_TARGET"
    case .catalyst, .custom: return nil
    }
  }

  /// Default fallback deployment target version if not specified in Package.swift or configuration.
  public var defaultDeploymentTarget: PlatformVersion {
    switch self {
    case .ios, .catalyst, .tvos: return "15.0"
    case .macos: return "12.0"
    case .watchos: return "9.0"
    case .visionos: return "1.0"
    case .custom: return "1.0"
    }
  }

  /// Numeric values for Xcode's `TARGETED_DEVICE_FAMILY` setting.
  ///
  /// 1 = iPhone, 2 = iPad, 3 = Apple TV, 4 = Apple Watch, 7 = Apple Vision Pro.
  public var targetedDeviceFamily: [Int] {
    switch self {
    case .ios, .catalyst: return [1, 2]
    case .tvos: return [3]
    case .watchos: return [4]
    case .visionos: return [7]
    case .macos, .custom: return []
    }
  }

  /// Xcode SDK identifier names for `SUPPORTED_PLATFORMS`.
  public var supportedPlatformSDKs: [String] {
    switch self {
    case .ios: return ["iphoneos", "iphonesimulator"]
    case .macos, .catalyst: return ["macosx"]
    case .tvos: return ["appletvos", "appletvsimulator"]
    case .watchos: return ["watchos", "watchsimulator"]
    case .visionos: return ["xros", "xrsimulator"]
    case .custom: return []
    }
  }

  // MARK: - Compilation & Slicing (Platform.Destination)

  /// Whether this platform requires a separate simulator compile slice.
  public var requiresSimulatorSlice: Bool {
    switch self {
    case .ios, .tvos, .watchos, .visionos:
      return true
    case .macos, .catalyst, .custom:
      return false
    }
  }

  /// Expands this platform into its required concrete xcodebuild compile destinations.
  public var destinations: [Destination] {
    switch self {
    case .ios: return [.iOS, .iOSSimulator]
    case .macos: return [.macOS]
    case .catalyst: return [.macCatalyst]
    case .tvos: return [.tvOS, .tvOSSimulator]
    case .watchos: return [.watchOS, .watchOSSimulator]
    case .visionos: return [.visionOS, .visionOSSimulator]
    case .custom: return []
    }
  }

  // MARK: - Framework Bundle Layout (Deep vs Shallow)

  /// Indicates whether this platform requires macOS-style versioned directory layout
  /// (with `Versions/A/` and symlinks) versus iOS-style shallow flat bundles.
  public var isVersionedBundle: Bool {
    switch self {
    case .macos, .catalyst: return true
    case .ios, .tvos, .watchos, .visionos, .custom: return false
    }
  }

  /// The Info.plist key used to audit the minimum operating system version.
  ///
  /// macOS uses `LSMinimumSystemVersion`; iOS/tvOS/watchOS/visionOS use `MinimumOSVersion`.
  public var minVersionPlistKey: String {
    self == .macos ? "LSMinimumSystemVersion" : "MinimumOSVersion"
  }

  // MARK: - PBXBuildFile Platform Filtering

  /// Platform filters applied to PBXBuildFile for targets or resources scoped only to this
  /// platform.
  public var pbxPlatformFilters: [String] {
    switch self {
    case .ios, .catalyst: return ["ios", "maccatalyst"]
    case .macos: return ["macos"]
    case .tvos: return ["tvos"]
    case .watchos: return ["watchos"]
    case .visionos: return ["visionos"]
    case let .custom(name): return [name]
    }
  }

  // MARK: - SPM Interoperability

  /// Converts a platform name string to a `Platform`.
  public static func from(platformName: String) -> Platform {
    switch platformName.lowercased() {
    case "ios": return .ios
    case "macos": return .macos
    case "tvos": return .tvos
    case "watchos": return .watchos
    case "visionos", "xros": return .visionos
    case "catalyst", "maccatalyst": return .catalyst
    default: return .custom(platformName)
    }
  }

  /// Converts a SwiftPM `PlatformDescription` to a `Platform`.
  public static func from(platformDescription: PlatformDescription) -> Platform {
    from(platformName: platformDescription.platformName)
  }

  /// Converts a SwiftPM `PackageModel.Platform` to a `Platform`.
  public static func from(model: PackageModel.Platform) -> Platform {
    from(platformName: model.name)
  }

  /// Converts to SPM's `PackageModel.Platform`.
  public var spmPlatform: PackageModel.Platform {
    switch self {
    case .ios: return .iOS
    case .macos: return .macOS
    case .tvos: return .tvOS
    case .watchos: return .watchOS
    case .visionos: return .visionOS
    case .catalyst: return .macCatalyst
    case let .custom(name):
      return PackageModel.PlatformRegistry.default.platformByName[name]
        ?? .custom(name: name, oldestSupportedVersion: .unknown)
    }
  }
}
