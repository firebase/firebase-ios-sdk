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

#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseAuth)
  import Foundation

  import Combine
  import FirebaseAuth

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  extension PhoneAuthProvider {
    
    /// Verify ownership of the second factor phone number by the current user.
    ///
    /// The publisher will emit events on the **main** thread.
    /// 
    /// - Parameters:
    ///   - phoneNumber: The phone number to be verified.
    ///   - UIDelegate: An object used to present the SFSafariViewController. The object is retained
    ///   by this method until the completion block is executed.
    ///   - multiFactorSession: session A session to identify the MFA flow. For enrollment, this identifies the user
    ///   trying to enroll. For sign-in, this identifies that the user already passed the first factor challenge.
    /// - Returns: A publisher that emits an `CerificationID` when the sign-in flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    @discardableResult
    func verifyPhoneNumber(withMultiFactorInfo phoneMultiFactorInfo: PhoneMultiFactorInfo,
                           uiDelegate: AuthUIDelegate? = nil,
                           multiFactorSession: MultiFactorSession?) -> Future<String, Error> {
        Future<String, Error> { promise in
            self.verifyPhoneNumber(with: phoneMultiFactorInfo, uiDelegate: uiDelegate,
                                   multiFactorSession: multiFactorSession) { verificationID, error in
                if let error = error {
                  promise(.failure(error))
                } else if let verificationID = verificationID {
                  promise(.success(verificationID))
                }
            }
        }
    }
}
#endif
