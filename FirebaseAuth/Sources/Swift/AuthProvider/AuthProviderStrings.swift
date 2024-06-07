// Copyright 2022 Google LLC
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

/// Enumeration of the available Auth Provider IDs.
public enum AuthProviderID: String, ExpressibleByStringLiteral {
  case apple = "apple.com"
  case email = "password"
  case facebook = "facebook.com"
  case gameCenter = "gc.apple.com"
  case gitHub = "github.com"
  case google = "google.com"
  case phone

  public init(stringLiteral: String) {
    self.init(rawValue: stringLiteral)! // Crash if string doesn't map to a valid case.

    // Could also create a catch-all catch to elicit errors
    // elsewhere in the SDK.
    // self.init(rawValue: stringLiteral) ?? Self.other
  }
}
