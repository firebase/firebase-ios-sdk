// Copyright 2020 Google LLC
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
@testable import FirebaseAuth

let expectationTimeout: TimeInterval = 2
let kAccessTokenTimeToLive: TimeInterval = 60 * 60
let kRefreshToken = "REFRESH_TOKEN"
let kAccessToken = "ACCESS_TOKEN"

class MockSignUpNewUserResponse: FIRSignUpNewUserResponse {
  override var idToken: String { return kAccessToken }
  override var refreshToken: String { return kRefreshToken }
  override var approximateExpirationDate: Date { Date(timeIntervalSinceNow: kAccessTokenTimeToLive)
  }
}

class MockVerifyPasswordResponse: FIRVerifyPasswordResponse {
  override var localID: String { return "" }
  override var email: String { return "" }
  override var displayName: String { return "" }
  override var idToken: String { return "" }
  override var approximateExpirationDate: Date { return Date() }
  override var refreshToken: String { return "" }
}

class MockSecureTokenResponse: FIRSecureTokenResponse {
  override var accessToken: String { return kAccessToken }
  override var approximateExpirationDate: Date { Date(timeIntervalSinceNow: kAccessTokenTimeToLive)
  }
}

class MockGetAccountInfoResponse: FIRGetAccountInfoResponse {
  var user: FIRGetAccountInfoResponseUser

  init(withLocalId localId: String, displayName: String, email: String, passwordHash: String) {
    user = FIRGetAccountInfoResponseUser(
      dictionary: [
        "localId": localId,
        "displayName": displayName,
        "email": email,
        "passwordHash": passwordHash,
      ]
    )
  }

  override var users: [FIRGetAccountInfoResponseUser] {
    return [user]
  }
}

class AuthBackendImplementationMock: NSObject, FIRAuthBackendImplementation {}

extension AuthBackendImplementationMock /*: AuthBackendMockForUserTests */ {
  func createAuthURI(_ request: FIRCreateAuthURIRequest,
                     callback: @escaping FIRCreateAuthURIResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func getAccountInfo(_ request: FIRGetAccountInfoRequest,
                      callback: @escaping FIRGetAccountInfoResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func getProjectConfig(_ request: FIRGetProjectConfigRequest,
                        callback: @escaping FIRGetProjectConfigResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func setAccountInfo(_ request: FIRSetAccountInfoRequest,
                      callback: @escaping FIRSetAccountInfoResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func verifyAssertion(_ request: FIRVerifyAssertionRequest,
                       callback: @escaping FIRVerifyAssertionResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func verifyCustomToken(_ request: FIRVerifyCustomTokenRequest,
                         callback: @escaping FIRVerifyCustomTokenResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func verifyPassword(_ request: FIRVerifyPasswordRequest,
                      callback: @escaping FIRVerifyPasswordResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func emailLinkSignin(_ request: FIREmailLinkSignInRequest,
                       callback: @escaping FIREmailLinkSigninResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func secureToken(_ request: FIRSecureTokenRequest,
                   callback: @escaping FIRSecureTokenResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func getOOBConfirmationCode(_ request: FIRGetOOBConfirmationCodeRequest,
                              callback: @escaping FIRGetOOBConfirmationCodeResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func signUpNewUser(_ request: FIRSignUpNewUserRequest,
                     callback: @escaping FIRSignupNewUserCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func deleteAccount(_ request: FIRDeleteAccountRequest, callback: @escaping FIRDeleteCallBack) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func sendVerificationCode(_ request: FIRSendVerificationCodeRequest,
                            callback: @escaping FIRSendVerificationCodeResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func verifyPhoneNumber(_ request: FIRVerifyPhoneNumberRequest,
                         callback: @escaping FIRVerifyPhoneNumberResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func verifyClient(_ request: FIRVerifyClientRequest,
                    callback: @escaping FIRVerifyClientResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func signIn(withGameCenter request: FIRSignInWithGameCenterRequest,
              callback: @escaping FIRSignInWithGameCenterResponseCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func resetPassword(_ request: FIRResetPasswordRequest,
                     callback: @escaping FIRResetPasswordCallback) {
    fatalError("You need to implement \(#function) in your mock.")
  }

  func post(with request: FIRAuthRPCRequest, response: FIRAuthRPCResponse,
            callback: @escaping (Error?) -> Void) {
    fatalError("You need to implement \(#function) in your mock.")
  }
}
