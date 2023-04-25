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

/** @class ActionCodeInfo
    @brief Manages information regarding action codes.
 */
@objc(FIRActionCodeInfo) public class ActionCodeInfo: NSObject {
  /**
      @brief The operation being performed.
   */
  @objc public let operation: ActionCodeOperation

  /** @property email
      @brief The email address to which the code was sent. The new email address in the case of
          `ActionCodeOperationRecoverEmail`.
   */
  @objc public let email: String

  /** @property previousEmail
      @brief The email that is being recovered in the case of `ActionCodeOperationRecoverEmail`.
   */
  @objc public let previousEmail: String?

  // TODO: Below here change to internal.

  @objc public init(withOperation operation: ActionCodeOperation, email: String,
                    newEmail: String?) {
    self.operation = operation
    if let newEmail {
      self.email = newEmail
      previousEmail = email
    } else {
      self.email = email
      previousEmail = nil
    }
  }

  /** @fn actionCodeOperationForRequestType:
      @brief Returns the corresponding operation type per provided request type string.
      @param requestType Request type returned in in the server response.
      @return The corresponding ActionCodeOperation for the supplied request type.
   */
  @objc public
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
