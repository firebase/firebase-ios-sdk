// Copyright 2024 Google LLC
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

import FirebaseAuthInterop
import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
class AuthInteropFake: NSObject, AuthInterop {
  let token: String?
  let error: Error?

  func getToken(forcingRefresh forceRefresh: Bool) async throws -> String? {
    if let error {
      throw error
    }

    return token
  }

  func getUserID() -> String? {
    fatalError("\(#function) not implemented.")
  }

  private init(token: String?, error: Error?) {
    self.token = token
    self.error = error
  }

  convenience init(error: Error) {
    self.init(token: nil, error: error)
  }

  convenience init(token: String?) {
    self.init(token: token, error: nil)
  }
}

struct AuthErrorFake: Error {}
