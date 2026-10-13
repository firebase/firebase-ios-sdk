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
import PackageModel

/// Represents the minimum deployment target versions across supported Apple platforms.
public struct DeploymentTargets: Codable, Sendable, Equatable {
  /// The underlying mapping of platform to SwiftPM `SupportedPlatform`.
  public var targets: [PackageModel.Platform: SupportedPlatform]

  /// Initializes deployment targets from an array of `SupportedPlatform` items.
  public init(platforms: [SupportedPlatform] = []) {
    targets = Dictionary(uniqueKeysWithValues: platforms.map { ($0.platform, $0) })
  }

  /// Looks up the `SupportedPlatform` for a given `Common.Platform`.
  public subscript(platform: Platform) -> SupportedPlatform? {
    targets[platform.spmPlatform]
  }

  /// Looks up the `SupportedPlatform` for a SwiftPM `PackageModel.Platform`.
  public subscript(spmPlatform: PackageModel.Platform) -> SupportedPlatform? {
    targets[spmPlatform]
  }

  /// Returns the resolved `PlatformVersion` for a given platform, falling back to iOS for Catalyst,
  /// or the platform's default minimum version if not specified.
  public func version(for platform: Platform) -> PlatformVersion {
    if let supported = self[platform] {
      return supported.version
    }
    // if Catalyst is undeclared, fall back to the iOS deployment target
    if platform == .catalyst, let ios = self[.ios] {
      return ios.version
    }
    return platform.defaultDeploymentTarget
  }

  /// Generates the complete dictionary of Xcode build settings
  /// (e.g. `["IPHONEOS_DEPLOYMENT_TARGET": "15.0", "MACOSX_DEPLOYMENT_TARGET": "12.0", ...]`).
  public var xcodeBuildSettings: [String: String] {
    var settings: [String: String] = [:]
    for platform in Platform.allApplePlatforms {
      if let key = platform.deploymentTargetSettingKey {
        settings[key] = version(for: platform).versionString
      }
    }
    return settings
  }

  // MARK: - Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let dict = try container.decode([String: String].self)
    var resolved: [SupportedPlatform] = []
    for (platformName, versionString) in dict {
      let platform = Platform.from(platformName: platformName).spmPlatform
      let version = PlatformVersion(versionString)
      resolved.append(SupportedPlatform(platform: platform, version: version))
    }
    self.init(platforms: resolved)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    var dict: [String: String] = [:]
    for (platform, supported) in targets.sorted(by: { $0.key.name < $1.key.name }) {
      dict[Platform.from(model: platform).canonicalName] = supported.version.versionString
    }
    try container.encode(dict)
  }

  public init(dictionary: [String: String]) {
    var platforms: [SupportedPlatform] = []
    for (platformName, versionString) in dictionary {
      let platform = Platform.from(platformName: platformName).spmPlatform
      let version = PlatformVersion(versionString)
      platforms.append(SupportedPlatform(platform: platform, version: version))
    }
    self.init(platforms: platforms)
  }
}

// MARK: - ExpressibleByDictionaryLiteral

extension DeploymentTargets: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, String)...) {
    var dict: [String: String] = [:]
    for (key, value) in elements {
      dict[key] = value
    }
    self.init(dictionary: dict)
  }
}

// MARK: - SupportedPlatform Xcode Extension

public extension SupportedPlatform {
  /// Returns the corresponding Xcode build setting tuple (e.g. `("IPHONEOS_DEPLOYMENT_TARGET",
  /// "15.0")`).
  ///
  /// Returns `nil` for Catalyst because Catalyst shares the iOS setting.
  var xcodeDeploymentTargetSetting: (key: String, value: String)? {
    let domainPlatform = Platform.from(model: platform)
    guard let key = domainPlatform.deploymentTargetSettingKey else { return nil }
    return (key, version.versionString)
  }
}
