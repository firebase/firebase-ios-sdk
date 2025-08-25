/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
struct FinalizePasskeySignInResponse: AuthRPCResponse {
  /// The user raw access token.
  let idToken: String
  /// Refresh token for the authenticated user.
  let refreshToken: String

  init(dictionary: [String: AnyHashable]) throws {
    guard
      let idToken = dictionary["idToken"] as? String,
      let refreshToken = dictionary["refreshToken"] as? String
    else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    self.idToken = idToken
    self.refreshToken = refreshToken
  }
}
