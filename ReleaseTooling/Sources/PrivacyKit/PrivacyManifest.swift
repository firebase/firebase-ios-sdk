// Copyright 2023 Google LLC
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

/// Represents a Privacy Manifest as described in
/// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
///
/// A Privacy Manifest is represented by a XML dictionary with four, top-level keys:
/// 1. `NSPrivacyTracking` – maps to a boolean that represents whether or not data is collected for
/// the purpose of tracking.
/// 2. `NSPrivacyTrackingDomains` – maps to an array of strings that represents each internet
/// domains that the SDK connects to for the purpose of tracking.
/// 3. `NSPrivacyCollectedDataTypes` – maps to an array of dictionaries where each dictionary
/// represents a type of data (e.g. device ID) collected, the reason(s) it is collected (e.g. app
/// functionality), whether it is linked to the user, and whether it is used for tracking.
/// 4. `NSPrivacyAccessedAPITypes` – maps to an array of dictionaries where each dictionary
/// represents a category of protected API used by the SDK (e.g. user defaults) and the reason(s)
/// the API is used (e.g. CA92.1*).
///
/// * Refer to Apple's documentation for a glossary of all of the available string values that may
/// be used in a Privacy Manifest. Apart from the `NSPrivacyTrackingDomains` section, the Privacy
/// Manifest may not contains custom strings (e.g. a custom reason to explain why a protected API
/// is used).
///
/// ```
/// <?xml version="1.0" encoding="UTF-8"?>
/// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
/// "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
/// <plist version="1.0">
/// <dict>
///   <key>NSPrivacyTracking</key>
///   <true/>
///   <key>NSPrivacyTrackingDomains</key>
///   <array>
///   <string>tracking.example.com</string>
///   </array>
///   <key>NSPrivacyCollectedDataTypes</key>
///   <array>
///     <dict>
///       <key>NSPrivacyCollectedDataType</key>
///       <string>NSPrivacyCollectedDataTypeDeviceID</string>
///       <key>NSPrivacyCollectedDataTypeLinked</key>
///       <true/>
///       <key>NSPrivacyCollectedDataTypeTracking</key>
///       <true/>
///       <key>NSPrivacyCollectedDataTypePurposes</key>
///       <array>
///         <string>App functionality</string>
///       </array>
///     </dict>
///   </array>
///   <key>NSPrivacyAccessedAPITypes</key>
///   <array>
///     <dict>
///       <key>NSPrivacyAccessedAPIType</key>
///       <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
///       <key>NSPrivacyAccessedAPITypeReasons</key>
///       <array>
///         <string>CA92.1</string>
///       </array>
///     </dict>
///   </array>
/// </dict>
/// </plist>
/// ```
///
public struct PrivacyManifest: Encodable {
  /// These coding keys map to the values defined at
  /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files#4284009
  private enum CodingKeys: String, CodingKey {
    case usesDataForTracking = "NSPrivacyTracking"
    case trackingDomains = "NSPrivacyTrackingDomains"
    case collectedDataTypes = "NSPrivacyCollectedDataTypes"
    case accessedAPITypes = "NSPrivacyAccessedAPITypes"
  }

  public let usesDataForTracking: Bool
  public let trackingDomains: [String]
  public let collectedDataTypes: [CollectedDataType]
  public let accessedAPITypes: [AccessedAPIType]

  public class Builder {
    public init() {}
    // TODO(ncooke3): Either provide default values or throw an error.
    public func build() -> PrivacyManifest? {
      // TODO(ncooke3): Implement.
      nil
    }
  }
}
