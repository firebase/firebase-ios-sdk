// Copyright 2025 Google LLC
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

/// A utility class for accessing resources and configuration in bundles.
/// This class replaces the legacy `FIRBundleUtil` Objective-C class.
@objc(FIRBundleUtil)
@objcMembers
open class BundleUtil: NSObject {
  /// Internal testing override for isAppExtension
  internal static var isAppExtensionOverride: Bool?

  /// Checks if the current environment is an app extension.
  private static var isAppExtension: Bool {
    if let override = isAppExtensionOverride {
      return override
    }
    // Simple check for app extension environment by looking at the bundle path extension.
    return Bundle.main.bundlePath.hasSuffix(".appex")
  }

  /// Finds all relevant bundles, starting with the main bundle.
  ///
  /// - Returns: An array of `Bundle` objects, typically containing `Bundle.main` and the bundle containing this class.
  @objc
  public static func relevantBundles() -> [Bundle] {
    return [Bundle.main, Bundle(for: self)]
  }

  /// Reads the path to the options dictionary (plist) from one of the provided bundles.
  ///
  /// - Parameters:
  ///   - resourceName: The name of the resource (e.g., "GoogleService-Info").
  ///   - fileType: The file extension (e.g., "plist").
  ///   - bundles: The list of bundles to search, in priority order.
  /// - Returns: The full path to the file if found, otherwise `nil`.
  @objc(optionsDictionaryPathWithResourceName:andFileType:inBundles:)
  public static func optionsDictionaryPath(resourceName: String,
                                           fileType: String,
                                           inBundles bundles: [Bundle]) -> String? {
    for bundle in bundles {
      if let path = bundle.path(forResource: resourceName, ofType: fileType) {
        return path
      }
    }
    return nil
  }

  /// Finds all URL schemes defined in the relevant bundles.
  ///
  /// This method inspects the `CFBundleURLTypes` key in the `Info.plist` of relevant bundles.
  ///
  /// - Returns: An array of URL schemes found.
  @objc
  public static func relevantURLSchemes() -> [Any] {
    var result: [Any] = []
    for bundle in relevantBundles() {
      if let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
        for urlType in urlTypes {
          if let schemes = urlType["CFBundleURLSchemes"] as? [Any] {
            result.append(contentsOf: schemes)
          }
        }
      }
    }
    return result
  }

  /// Checks if any of the given bundles have a matching bundle identifier prefix.
  ///
  /// This method checks for exact matches or matches where the bundle ID is a prefix of an app extension's bundle ID.
  ///
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier to check for.
  ///   - bundles: The bundles to check against.
  /// - Returns: `true` if a match is found, `false` otherwise.
  @objc(hasBundleIdentifierPrefix:inBundles:)
  public static func hasBundleIdentifierPrefix(_ bundleIdentifier: String,
                                               inBundles bundles: [Bundle]) -> Bool {
    for bundle in bundles {
      if let actualBundleID = bundle.bundleIdentifier, actualBundleID == bundleIdentifier {
        return true
      }

      if isAppExtension {
        if let actualBundleID = bundle.bundleIdentifier {
          let appBundleIDFromExtension = bundleIdentifierByRemovingLastPart(from: actualBundleID)
          if appBundleIDFromExtension == bundleIdentifier {
            return true
          }
        }
      }
    }
    return false
  }

  /// Removes the last component of a dot-separated bundle identifier.
  ///
  /// - Parameter bundleIdentifier: The bundle identifier string.
  /// - Returns: The bundle identifier with the last component removed.
  private static func bundleIdentifierByRemovingLastPart(from bundleIdentifier: String) -> String {
    var components = bundleIdentifier.components(separatedBy: ".")
    if !components.isEmpty {
      components.removeLast()
    }
    return components.joined(separator: ".")
  }
}
