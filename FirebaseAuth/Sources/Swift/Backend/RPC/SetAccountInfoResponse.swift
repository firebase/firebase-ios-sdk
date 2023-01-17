//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 05/10/2022.
//

import Foundation

/** @class FIRSetAccountInfoResponseProviderUserInfo
    @brief Represents the provider user info part of the response from the setAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
 */
@objc(FIRSetAccountInfoResponseProviderUserInfo) public class SetAccountInfoResponseProviderUserInfo: NSObject {
    /** @property providerID
        @brief The ID of the identity provider.
     */
    @objc public var providerID: String?

    /** @property displayName
        @brief The user's display name at the identity provider.
     */
    @objc public var displayName: String?

    /** @property photoURL
        @brief The user's photo URL at the identity provider.
     */
    @objc public var photoURL: URL?

    /** @fn initWithAPIKey:
        @brief Designated initializer.
        @param dictionary The provider user info data from endpoint.
     */
    @objc public init(dictionary: [String: Any]) {
        self.providerID = dictionary["providerId"] as? String
        self.displayName = dictionary["displayName"] as? String
        if let photoURL = dictionary["photoUrl"] as? String {
            self.photoURL = URL(string: photoURL)
        }
    }
}

/** @class FIRSetAccountInfoResponse
    @brief Represents the response from the setAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/setAccountInfo
 */
@objc(FIRSetAccountInfoResponse) public class SetAccountInfoResponse: NSObject, AuthRPCResponse {
    /** @property email
        @brief The email or the user.
     */
    @objc public var email: String?

    /** @property displayName
        @brief The display name of the user.
     */
    @objc public var displayName: String?

    /** @property providerUserInfo
        @brief The user's profiles at the associated identity providers.
     */
    @objc public var providerUserInfo: [SetAccountInfoResponseProviderUserInfo]?

    /** @property IDToken
        @brief Either an authorization code suitable for performing an STS token exchange, or the
            access token from Secure Token Service, depending on whether @c returnSecureToken is set
            on the request.
     */
    @objc public var IDToken: String?

    /** @property approximateExpirationDate
        @brief The approximate expiration date of the access token.
     */
    @objc public var approximateExpirationDate: Date?

    /** @property refreshToken
        @brief The refresh token from Secure Token Service.
     */
    @objc public var refreshToken: String?

    public func setFields(dictionary: [String : Any]) throws {
        self.email = dictionary["email"] as? String
        self.displayName = dictionary["displayName"]  as? String
        self.IDToken = dictionary["idToken"]  as? String
        if let expiresIn = dictionary["expiresIn"] as? String {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString).doubleValue)
        }
        self.refreshToken = dictionary["refreshToken"] as? String
        if let providerUserInfoData = dictionary["providerUserInfo"] as? [[String: Any]] {
            self.providerUserInfo = providerUserInfoData.map { .init(dictionary: $0) }
        }
    }
}
