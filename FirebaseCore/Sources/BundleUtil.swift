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
import GoogleUtilities

/// A utility class for accessing resources in bundles.
/// Replaces the legacy `FIRBundleUtil` Objective-C class.
@objc(FIRBundleUtil)
@objcMembers
open class BundleUtil: NSObject {
  /// Finds all relevant bundles, starting with `Bundle.main`.
  /// - Returns: An array of relevant bundles.
  open class func relevantBundles() -> [Bundle] {
    return [Bundle.main, Bundle(for: self)]
  }

  /// Reads the options dictionary from one of the provided bundles.
  /// - Parameters:
  ///   - resourceName: The resource name, e.g. "GoogleService-Info".
  ///   - fileType: The file type (extension), e.g. "plist".
  ///   - bundles: The bundles to expect, in priority order.
  /// - Returns: The path to the options dictionary, or `nil` if not found.
  open class func optionsDictionaryPath(withResourceName resourceName: String,
                                        andFileType fileType: String,
                                        inBundles bundles: [Bundle]) -> String? {
    // Loop through all bundles to find the config dict.
    for bundle in bundles {
      if let path = bundle.path(forResource: resourceName, ofType: fileType) {
        return path
      }
    }
    return nil
  }

  /// Finds URL schemes defined in all relevant bundles, starting with those from `Bundle.main`.
  /// - Returns: An array of URL schemes.
  open class func relevantURLSchemes() -> [String] {
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

  /// Checks if any of the given bundles have a matching bundle identifier prefix (removing extension suffixes).
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier to check.
  ///   - bundles: The bundles to check against.
  /// - Returns: `true` if a match is found, otherwise `false`.
  open class func hasBundleIdentifierPrefix(_ bundleIdentifier: String,
                                            inBundles bundles: [Bundle]) -> Bool {
    for bundle in bundles {
      guard let currentBundleID = bundle.bundleIdentifier else { continue }
      if currentBundleID == bundleIdentifier {
        return true
      }

      if GULAppEnvironmentUtil.isAppExtension() {
        // A developer could be using the same `FIROptions` for both their app and extension. Since
        // extensions have a suffix added to the bundleID, we consider a matching prefix as valid.
        let appBundleIDFromExtension = bundleIdentifierByRemovingLastPart(from: currentBundleID)
        if appBundleIDFromExtension == bundleIdentifier {
          return true
        }
      }
    }
    return false
  }

  /// Removes the last part of a bundle identifier.
  /// - Parameter bundleIdentifier: The bundle identifier to process.
  /// - Returns: The bundle identifier with the last component removed.
  private class func bundleIdentifierByRemovingLastPart(from bundleIdentifier: String) -> String {
    var components = bundleIdentifier.components(separatedBy: ".")
    if !components.isEmpty {
      components.removeLast()
    }
    return components.joined(separator: ".")
  }
}
