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

/// Represents the response from the resetPassword endpoint.
///
/// Possible error codes:
/// * FIRAuthErrorCodeWeakPassword
/// * FIRAuthErrorCodeUserDisabled
/// * FIRAuthErrorCodeOperationNotAllowed
/// * FIRAuthErrorCodeExpiredActionCode
/// * FIRAuthErrorCodeInvalidActionCode
///
/// See https: // developers.google.com/identity/toolkit/web/reference/relyingparty/resetPassword
class ResetPasswordResponse: AuthRPCResponse {
  required init() {}

  /// The email address corresponding to the reset password request.
  var email: String?

  /// The verified email returned from the backend.
  var verifiedEmail: String?

  /// The type of request as returned by the backend.
  var requestType: String?

  func setFields(dictionary: [String: AnyHashable]) throws {
    email = dictionary["email"] as? String
    requestType = dictionary["requestType"] as? String
    verifiedEmail = dictionary["newEmail"] as? String
  }
}
