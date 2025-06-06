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

#if os(watchOS)
#else
/// Represents information about a Passkey.
public struct PasskeyInfo: Codable, AuthProto {
    /// The name of the Passkey.
    public let name: String?
    
    /// The credential ID of the Passkey.
    public let credentialID: String?

    /// Creates a `PasskeyInfo` instance from a dictionary.
    ///
    /// - Parameter dictionary: A dictionary containing the Passkey info.
    public init(dictionary: [String: AnyHashable]) {
        self.name = dictionary["name"] as? String
        self.credentialID = dictionary["credentialId"] as? String
    }
    
    // MARK: - AuthProto conformance
    
    public func toDictionary() -> [String: AnyHashable] {
        var dictionary: [String: AnyHashable] = [:]
        if let name = name {
          dictionary["name"] = name
        }
        if let credentialID = credentialID {
          dictionary["credentialId"] = credentialID
        }
        return dictionary
    }
}
#endif
