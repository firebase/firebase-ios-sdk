//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 04/10/2022.
//

import Foundation

private let kExpiresInKey = "expires_in"

/** @var kRefreshTokenKey
    @brief The key for the refresh token.
 */
private let kRefreshTokenKey = "refresh_token"

/** @var kAccessTokenKey
    @brief The key for the access token.
 */
private let kAccessTokenKey = "access_token"

/** @var kIDTokenKey
    @brief The key for the "id_token" value in the response.
 */
private let kIDTokenKey = "id_token"



@objc(FIRSecureTokenResponse) public class SecureTokenResponse: NSObject, AuthRPCResponse {
    @objc public var approximateExpirationDate: Date?
    @objc public var refreshToken: String?
    @objc public var accessToken: String?
    @objc public var IDToken: String?

    var expectedKind: String? { nil }

    public func setFields(dictionary: [String : Any]) throws {
        self.refreshToken = dictionary[kRefreshTokenKey] as? String
        self.accessToken = dictionary[kAccessTokenKey] as? String
        self.IDToken = dictionary[kIDTokenKey] as? String

        guard let accessToken = self.accessToken else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        guard !accessToken.isEmpty else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        if let expiresIn = dictionary[kExpiresInKey] as? String {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: (expiresIn as NSString).doubleValue)
        }
    }
}
