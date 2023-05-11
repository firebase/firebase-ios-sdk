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

/** @class FIRCreateAuthURIResponse
    @brief Represents the parameters for the createAuthUri endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/createAuthUri
 */

public class CreateAuthURIResponse: AuthRPCResponse {
  /** @property authUri
      @brief The URI used by the IDP to authenticate the user.
   */
  public var authURI: String?

  /** @property registered
      @brief Whether the user is registered if the identifier is an email.
   */
  public var registered: Bool = false

  /** @property providerId
      @brief The provider ID of the auth URI.
   */
  public var providerID: String?

  /** @property forExistingProvider
      @brief True if the authUri is for user's existing provider.
   */
  public var forExistingProvider: Bool = false

  /** @property allProviders
      @brief A list of provider IDs the passed @c identifier could use to sign in with.
   */
  public var allProviders: [String]?

  /** @property signinMethods
      @brief A list of sign-in methods available for the passed @c identifier.
   */
  public var signinMethods: [String]?

  public func setFields(dictionary: [String: AnyHashable]) throws {
    providerID = dictionary["providerId"] as? String
    authURI = dictionary["authUri"] as? String
    registered = dictionary["registered"] as? Bool ?? false
    forExistingProvider = dictionary["forExistingProvider"] as? Bool ?? false
    allProviders = dictionary["allProviders"] as? [String]
    signinMethods = dictionary["signinMethods"] as? [String]
  }
}
