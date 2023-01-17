//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2022.
//

import Foundation

/** @class FIRCreateAuthURIResponse
    @brief Represents the parameters for the createAuthUri endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/createAuthUri
 */

@objc(FIRCreateAuthURIResponse) public class CreateAuthURIResponse: NSObject, AuthRPCResponse {

    /** @property authUri
        @brief The URI used by the IDP to authenticate the user.
     */
    @objc public var authURI: String?

    /** @property registered
        @brief Whether the user is registered if the identifier is an email.
     */
    @objc public var registered: Bool = false

    /** @property providerId
        @brief The provider ID of the auth URI.
     */
    @objc public var providerID: String?

    /** @property forExistingProvider
        @brief True if the authUri is for user's existing provider.
     */
    @objc public var forExistingProvider: Bool = false

    /** @property allProviders
        @brief A list of provider IDs the passed @c identifier could use to sign in with.
     */
    @objc public var allProviders: [String]?

    /** @property signinMethods
        @brief A list of sign-in methods available for the passed @c identifier.
     */
    @objc public var signinMethods: [String]?

    public func setFields(dictionary: [String: Any]) throws {
        self.providerID = dictionary["providerId"] as? String
        self.authURI = dictionary["authUri"] as? String
        self.registered = dictionary["registered"] as? Bool ?? false
        self.forExistingProvider = dictionary["forExistingProvider"] as? Bool ?? false
        self.allProviders = dictionary["allProviders"] as? [String]
        self.signinMethods = dictionary["signinMethods"] as? [String]
    }
}
