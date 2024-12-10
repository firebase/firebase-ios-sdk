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

#if os(iOS)

  /// Opaque object that identifies the current session to enroll a second factor or to
  /// complete sign in when previously enrolled.
  ///
  /// Identifies the current session to enroll a second factor
  /// or to complete sign in when previously enrolled. It contains additional context on the
  /// existing user, notably the confirmation that the user passed the first factor challenge.
  ///
  /// This class is available on iOS only.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRMultiFactorSession) open class MultiFactorSession: NSObject {
    /// The ID token for an enroll flow. This has to be retrieved after recent authentication.
    var idToken: String?

    /// The pending credential after an enrolled second factor user signs in successfully with the
    /// first factor.
    var mfaPendingCredential: String?

    /// Multi factor info for the current user.
    var multiFactorInfo: MultiFactorInfo?

    /// Current user object.
    var currentUser: User?

    class func session(for user: User?) -> MultiFactorSession {
      let currentUser = user ?? Auth.auth().currentUser
      guard let currentUser else {
        fatalError("Internal Auth Error: missing user for multifactor auth")
      }
      return .init(idToken: currentUser.tokenService.accessToken, currentUser: currentUser)
    }

    init(idToken: String?, currentUser: User) {
      self.idToken = idToken
      self.currentUser = currentUser
    }

    init(mfaCredential: String?) {
      mfaPendingCredential = mfaCredential
    }
  }

#endif
