/*
 * Copyright 2025 Google LLC
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

#if SWIFT_PACKAGE
  internal import GoogleUtilities_Environment
#else
  internal import GoogleUtilities
#endif // SWIFT_PACKAGE

/// Utilities for accessing resources in bundles.
@objc(FIRBundleUtil)
public class BundleUtil: NSObject {
  /// Finds all relevant bundles, starting with `Bundle.main`, `Bundle(for: BundleUtil.self)`, and optionally an additional bundle.
  /// - Parameter additionalBundle: An optional bundle to include in the search.
  /// - Returns: An array of relevant bundles.
  @objc(relevantBundlesIncludingBundle:)
  public static func relevantBundles(including additionalBundle: Bundle?) -> [Bundle] {
    var bundles = [Bundle.main, Bundle(for: BundleUtil.self)]
    if let additionalBundle = additionalBundle, !bundles.contains(additionalBundle) {
      bundles.append(additionalBundle)
    }
    return bundles
  }

  /// Reads the options dictionary from one of the provided bundles.
  /// - Parameters:
  ///   - resourceName: The resource name, e.g. "GoogleService-Info".
  ///   - fileType: The file type (extension), e.g. "plist".
  ///   - bundles: The bundles to expect, in priority order.
  /// - Returns: The path to the options dictionary, or nil if not found.
  @objc(optionsDictionaryPathWithResourceName:andFileType:inBundles:)
  public static func optionsDictionaryPath(resourceName: String,
                                           andFileType fileType: String,
                                           inBundles bundles: [Bundle]) -> String? {
    for bundle in bundles {
      if let path = bundle.path(forResource: resourceName, ofType: fileType) {
        return path
      }
    }
    return nil
  }

  /// Finds URL schemes defined in all relevant bundles, starting with those from `Bundle.main`.
  /// - Returns: An array of URL schemes.
  @objc
  public static func relevantURLSchemes() -> [String] {
    var result: [String] = []
    for bundle in relevantBundles(including: nil) {
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
  /// - Returns: True if a match is found.
  @objc(hasBundleIdentifierPrefix:inBundles:)
  public static func hasBundleIdentifierPrefix(_ bundleIdentifier: String,
                                               inBundles bundles: [Bundle]) -> Bool {
    for bundle in bundles {
      if bundle.bundleIdentifier == bundleIdentifier {
        return true
      }

      if GULAppEnvironmentUtil.isAppExtension() {
        if let bundleID = bundle.bundleIdentifier {
          let appBundleIDFromExtension = bundleIdentifierByRemovingLastPart(from: bundleID)
          if appBundleIDFromExtension == bundleIdentifier {
            return true
          }
        }
      }
    }
    return false
  }

  private static func bundleIdentifierByRemovingLastPart(from bundleIdentifier: String) -> String {
    let separator = "."
    var components = bundleIdentifier.components(separatedBy: separator)
    if !components.isEmpty {
      components.removeLast()
    }
    return components.joined(separator: separator)
  }
}
