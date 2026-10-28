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

// TODO(Swift 6 Breaking): This type is immutable. Consider removing `open` at
// breaking change so checked Sendable can be used.

/// Manages information regarding action codes.
@objc(FIRActionCodeInfo) open class ActionCodeInfo: NSObject, @unchecked Sendable {
  /// The operation being performed.
  @objc public let operation: ActionCodeOperation

  /// The email address to which the code was sent. The new email address in the case of
  /// `ActionCodeOperation.recoverEmail`. Empty in the case of `ActionCodeOperation.emailLink`,
  /// because the server doesn't return the email address for email sign-in codes.
  @objc public let email: String

  /// The email that is being recovered in the case of `ActionCodeOperation.recoverEmail`.
  @objc public let previousEmail: String?

  init(withOperation operation: ActionCodeOperation, email: String, newEmail: String?) {
    self.operation = operation
    if let newEmail {
      self.email = newEmail
      previousEmail = email
    } else {
      self.email = email
      previousEmail = nil
    }
  }

  /// Map a request type string to the corresponding operation type.
  ///
  /// The backend returns SCREAMING_SNAKE_CASE values (e.g. `VERIFY_EMAIL`). Out of band links use
  /// camelCase `mode` values instead; see `ActionCodeURL.actionCodeOperation(forMode:)`.
  /// - Parameter requestType: Request type returned in the server response.
  /// - Returns: The corresponding ActionCodeOperation for the supplied request type.
  class func actionCodeOperation(forRequestType requestType: String?) -> ActionCodeOperation {
    switch requestType {
    case "PASSWORD_RESET": return .passwordReset
    case "VERIFY_EMAIL": return .verifyEmail
    case "RECOVER_EMAIL": return .recoverEmail
    case "EMAIL_SIGNIN": return .emailLink
    case "VERIFY_AND_CHANGE_EMAIL": return .verifyAndChangeEmail
    case "REVERT_SECOND_FACTOR_ADDITION": return .revertSecondFactorAddition
    default: return .unknown
    }
  }
}
