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
public struct AuthProviderID: Equatable {
  public let rawValue: String
  private init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public extension AuthProviderID {
  static var apple: Self {
    Self(rawValue: "apple.com")
  }

  static var email: Self {
    Self(rawValue: "password")
  }

  static var facebook: Self {
    Self(rawValue: "facebook.com")
  }

  static var gameCenter: Self {
    Self(rawValue: "gc.apple.com")
  }

  static var gitHub: Self {
    Self(rawValue: "github.com")
  }

  static var google: Self {
    Self(rawValue: "google.com")
  }

  static var phone: Self {
    Self(rawValue: "phone")
  }

  static func custom(_ value: String) -> Self {
    Self(rawValue: value)
  }
}
