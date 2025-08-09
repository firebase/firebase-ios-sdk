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

public class PasskeyInfo: AuthProto {
  /// The display name for this passkey.
  public let name: String
  /// The credential ID used by the server.
  public let credentialID: String

  public required init?(dictionary: [String: AnyHashable]) {
    guard
      let name = dictionary["name"] as? String,
      let credentialID = dictionary["credentialId"] as? String
    else { return nil }

    self.name = name
    self.credentialID = credentialID
  }
}
