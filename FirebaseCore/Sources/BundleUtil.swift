/*
 * Copyright 2024 Google LLC
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

/// Utilities for accessing resources in bundles.
@objc(FIRBundleUtil)
@objcMembers
class BundleUtil: NSObject {
  /// Finds all relevant bundles, starting with `Bundle.main`.
  ///
  /// - Returns: An array of bundles including the main bundle and the bundle for this class.
  @objc
  static func relevantBundles() -> [Bundle] {
    return [Bundle.main, Bundle(for: BundleUtil.self)]
  }

  /// Reads the options dictionary from one of the provided bundles.
  ///
  /// - Parameters:
  ///   - resourceName: The resource name, e.g. "GoogleService-Info".
  ///   - fileType: The file type (extension), e.g. "plist".
  ///   - bundles: The bundles to expect, in priority order.
  /// - Returns: The path to the options dictionary, or `nil` if not found.
  @objc(optionsDictionaryPathWithResourceName:andFileType:inBundles:)
  static func optionsDictionaryPath(resourceName: String, fileType: String, bundles: [Bundle])
    -> String? {
    for bundle in bundles {
      if let path = bundle.path(forResource: resourceName, ofType: fileType) {
        return path
      }
    }
    return nil
  }

  /// Finds URL schemes defined in all relevant bundles, starting with those from `Bundle.main`.
  ///
  /// - Returns: An array of URL schemes found in the bundles.
  @objc
  static func relevantURLSchemes() -> [String] {
    var result: [String] = []
    for bundle in relevantBundles() {
      if let urlTypes = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
        for urlType in urlTypes {
          if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
            result.append(contentsOf: schemes)
          }
        }
      }
    }
    return result
  }

  /// Checks if any of the given bundles have a matching bundle identifier prefix (removing extension
  /// suffixes).
  ///
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier to check for.
  ///   - bundles: The bundles to check against.
  /// - Returns: `true` if a match is found, `false` otherwise.
  @objc(hasBundleIdentifierPrefix:inBundles:)
  static func hasBundleIdentifierPrefix(_ bundleIdentifier: String, inBundles bundles: [Bundle])
    -> Bool {
    for bundle in bundles {
      if let id = bundle.bundleIdentifier, id == bundleIdentifier {
        return true
      }

      if isAppExtension() {
        // A developer could be using the same `FIROptions` for both their app and extension. Since
        // extensions have a suffix added to the bundleID, we consider a matching prefix as valid.
        if let id = bundle.bundleIdentifier {
          let appBundleIDFromExtension = bundleIdentifierByRemovingLastPart(from: id)
          if appBundleIDFromExtension == bundleIdentifier {
            return true
          }
        }
      }
    }
    return false
  }

  /// Checks if the current application is an app extension.
  private static func isAppExtension() -> Bool {
    return Bundle.main.bundleURL.pathExtension == "appex"
  }

  /// Removes the last part of the bundle identifier (separated by dot).
  private static func bundleIdentifierByRemovingLastPart(from bundleIdentifier: String) -> String {
    var components = bundleIdentifier.components(separatedBy: ".")
    if !components.isEmpty {
      components.removeLast()
    }
    return components.joined(separator: ".")
  }
}
