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

@testable import FirebaseAuth
import Foundation

/// A fake object to replace a real `AuthAPNSTokenManager` in tests.
public class PhoneAuthProviderFake: PhoneAuthProvider {
  override init(auth: Auth) {
    super.init(auth: auth)
  }

  var verifyPhoneNumberHandler: (((String?, Error?) -> Void) -> Void)?

  override public func verifyPhoneNumber(_ phoneNumber: String,
                                         uiDelegate: AuthUIDelegate? = nil,
                                         completion: ((_: String?, _: Error?) -> Void)?) {
    if let verifyPhoneNumberHandler,
       let completion {
      verifyPhoneNumberHandler(completion)
    }
  }
}
