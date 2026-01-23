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

/// A utility for accessing resources in bundles.
@objc(FIRBundleUtil)
open class BundleUtil: NSObject {
    /// Finds all relevant bundles, starting with `Bundle.main`.
    @objc
    public static func relevantBundles() -> [Bundle] {
        return [Bundle.main, Bundle(for: BundleUtil.self)]
    }

    /// Reads the options dictionary from one of the provided bundles.
    @objc(optionsDictionaryPathWithResourceName:andFileType:inBundles:)
    public static func optionsDictionaryPath(resourceName: String,
                                             fileType: String,
                                             in bundles: [Bundle]) -> String? {
        for bundle in bundles {
            if let path = bundle.path(forResource: resourceName, ofType: fileType) {
                return path
            }
        }
        return nil
    }

    /// Finds URL schemes defined in all relevant bundles.
    @objc
    public static func relevantURLSchemes() -> [String] {
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

    /// Checks if any of the given bundles have a matching bundle identifier prefix.
    @objc(hasBundleIdentifierPrefix:inBundles:)
    public static func hasBundleIdentifierPrefix(_ bundleIdentifier: String,
                                                 in bundles: [Bundle]) -> Bool {
        for bundle in bundles {
            guard let bundleID = bundle.bundleIdentifier else { continue }

            if bundleID == bundleIdentifier {
                return true
            }

            if isAppExtension {
                let appBundleID = bundleIdentifierByRemovingLastPart(from: bundleID)
                if appBundleID == bundleIdentifier {
                    return true
                }
            }
        }
        return false
    }

    private static func bundleIdentifierByRemovingLastPart(from bundleIdentifier: String) -> String {
        let components = bundleIdentifier.components(separatedBy: ".")
        guard components.count > 1 else { return bundleIdentifier }
        return components.dropLast().joined(separator: ".")
    }

    private static var isAppExtension: Bool {
        // A simple check for app extension environments.
        // This avoids a dependency on GoogleUtilities.
        return Bundle.main.bundlePath.hasSuffix(".appex")
    }
}
