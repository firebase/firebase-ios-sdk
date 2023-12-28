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
import XCTest

import FirebaseAuth

/// Tests globals defined in Objective C sources.  These globals are for backward compatibility and
/// should not be used in new code.
class SwiftGlobalTests: XCTestCase {
  func GlobalSymbolBuildTest() {
    let _ = NSNotification.Name.AuthStateDidChange
    let _: String = AuthErrorDomain
    let _: String = AuthErrorUserInfoNameKey
    let _: String = AuthErrorUserInfoEmailKey
    let _: String = AuthErrorUserInfoUpdatedCredentialKey
    let _: String = AuthErrorUserInfoMultiFactorResolverKey
    let _: String = EmailAuthProviderID
    let _: String = EmailLinkAuthSignInMethod
    let _: String = EmailPasswordAuthSignInMethod
    let _: String = FacebookAuthProviderID
    let _: String = FacebookAuthSignInMethod
    let _: String = GameCenterAuthProviderID
    let _: String = GameCenterAuthSignInMethod
    let _: String = GitHubAuthProviderID
    let _: String = GitHubAuthSignInMethod
    let _: String = GoogleAuthProviderID
    let _: String = GoogleAuthSignInMethod
    #if os(iOS)
      let _: String = PhoneMultiFactorID
      let _: String = TOTPMultiFactorID
      let _: String = PhoneAuthProviderID
      let _: String = PhoneAuthSignInMethod
    #endif
    let _: String = TwitterAuthProviderID
    let _: String = TwitterAuthSignInMethod
  }
}
