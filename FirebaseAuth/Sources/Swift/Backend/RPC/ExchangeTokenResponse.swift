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

/// Response containing the new Firebase STS token.
@available(iOS 13, *)
struct ExchangeTokenResponse: AuthRPCResponse {
  let firebaseToken: String
  init(dictionary: [String: AnyHashable]) throws {
    guard let token = dictionary["idToken"] as? String else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    firebaseToken = token
  }
}
