// Copyright 2022 Google LLC
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

/** The Firebase Auth Exchange interop protocol. This is intended for use only by other Firebase SDKs. */
@objc(FIRAuthExchangeInterop) public protocol AuthExchangeInterop {
  /**
   * Returns the stored Auth Exchange token if valid and fetches a new token from the backend otherwise. This method is an interop
   * method and intended for use only by other Firebase SDKs.
   * - Parameters:
   *  - forceRefresh: Whether or not a new token should be fetched regardless of the validity of the stored token.
   * - Returns: A valid Auth Exchange token.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)
  func getToken(forceRefresh: Bool) async throws -> String

  /** See `getToken(forceRefresh:)`. */
  @objc(getTokenForcingRefresh:completion:)
  func getToken(forceRefresh: Bool, completion: (String?, Error?) -> Void)
}
