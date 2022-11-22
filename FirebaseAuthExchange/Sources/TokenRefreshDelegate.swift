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

@objc(FIRTokenRefreshDelegate) public protocol TokenRefreshDelegate {
  /** This method is invoked whenever a new Auth Exchange token is needed. Developers should implement this method to request a new token from an identity provider and then exchange it for a new Auth Exchange token. */
  @objc(refreshAuthExchangeTokenWithCompletion:)
  func refreshAuthExchangeToken(completion: @escaping (AuthExchangeToken?, Error?) -> Void)
}
