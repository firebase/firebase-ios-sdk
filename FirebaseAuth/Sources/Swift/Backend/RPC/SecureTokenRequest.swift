//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 04/10/2022.
//

import Foundation

@objc(FIRSecureTokenRequestGrantType) enum SecureTokenRequestGrantType: Int {
    case authorizationCode
    case refreshToken

    var value: String {
        switch self {
        case .refreshToken:
            return kFIRSecureTokenServiceGrantTypeRefreshToken;
        case .authorizationCode:
            return kFIRSecureTokenServiceGrantTypeAuthorizationCode
        }
    }
}

/** @var kFIRSecureTokenServiceGetTokenURLFormat
    @brief The format of the secure token service URLs. Requires string format substitution with
        the client's API Key.
 */
private let kFIRSecureTokenServiceGetTokenURLFormat = "https://%@/v1/token?key=%@"

/** @var kFIREmulatorURLFormat
    @brief The format of the emulated secure token service URLs. Requires string format substitution
   with the emulator host, the gAPIHost, and the client's API Key.
 */
private let kFIREmulatorURLFormat = "http://%@/%@/v1/token?key=%@"

/** @var kFIRSecureTokenServiceGrantTypeRefreshToken
    @brief The string value of the @c FIRSecureTokenRequestGrantTypeRefreshToken request type.
 */
private let kFIRSecureTokenServiceGrantTypeRefreshToken = "refresh_token"

/** @var kFIRSecureTokenServiceGrantTypeAuthorizationCode
    @brief The string value of the @c FIRSecureTokenRequestGrantTypeAuthorizationCode request type.
 */
private let kFIRSecureTokenServiceGrantTypeAuthorizationCode = "authorization_code"

/** @var kGrantTypeKey
    @brief The key for the "grantType" parameter in the request.
 */
private let kGrantTypeKey = "grantType"

/** @var kScopeKey
    @brief The key for the "scope" parameter in the request.
 */
private let kScopeKey = "scope"

/** @var kRefreshTokenKey
    @brief The key for the "refreshToken" parameter in the request.
 */
private let kRefreshTokenKey = "refreshToken"

/** @var kCodeKey
    @brief The key for the "code" parameter in the request.
 */
private let kCodeKey = "code"

/** @var gAPIHost
 @brief Host for server API calls.
 */
private var gAPIHost = "securetoken.googleapis.com"


/** @class FIRSecureTokenRequest
    @brief Represents the parameters for the token endpoint.
 */
@objc(FIRSecureTokenRequest) public class SecureTokenRequest: NSObject, AuthRPCRequest {

    /** @property grantType
        @brief The type of grant requested.
        @see FIRSecureTokenRequestGrantType
     */
    var grantType: SecureTokenRequestGrantType

    /** @property scope
        @brief The scopes requested (a comma-delimited list of scope strings.)
     */
    var scope: String?

    /** @property refreshToken
        @brief The client's refresh token.
     */
    var refreshToken: String?

    /** @property code
        @brief The client's authorization code (legacy Gitkit "ID Token").
     */
    var code: String?

    /** @property APIKey
        @brief The client's API Key.
     */
    let APIKey: String

    let _requestConfiguration: AuthRequestConfiguration
    public func requestConfiguration() -> AuthRequestConfiguration {
        _requestConfiguration
    }

    @objc public static func authCodeRequest(code: String, requestConfiguration: AuthRequestConfiguration) -> SecureTokenRequest {
        SecureTokenRequest(grantType: .authorizationCode, scope: nil, refreshToken: nil, code: code, requestConfiguration: requestConfiguration)
    }

    @objc public static func refreshRequest(refreshToken: String, requestConfiguration: AuthRequestConfiguration) -> SecureTokenRequest {
        SecureTokenRequest(grantType: .refreshToken, scope: nil, refreshToken: refreshToken, code: nil, requestConfiguration: requestConfiguration)
    }


    init(grantType: SecureTokenRequestGrantType, scope: String?, refreshToken: String?, code: String?, requestConfiguration: AuthRequestConfiguration) {
        self.grantType = grantType
        self.scope = scope
        self.refreshToken = refreshToken
        self.code = code
        self.APIKey = requestConfiguration.APIKey
        self._requestConfiguration = requestConfiguration
    }

    public func requestURL() -> URL {

        let urlString: String
        if let emulatorHostAndPort = _requestConfiguration.emulatorHostAndPort {
            urlString = "http://\(emulatorHostAndPort)/\(gAPIHost)/v1/token?key=\(APIKey)"
        } else {
            urlString = "https://\(gAPIHost)/v1/token?key=\(APIKey)"
        }
        return URL(string: urlString)!
    }

    var containsPostBody: Bool { true }

    public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [
            kGrantTypeKey: grantType.value
        ]
        if let scope = scope {
            postBody[kScopeKey] = scope
        }
        if let refreshToken = refreshToken {
            postBody[kRefreshTokenKey] = refreshToken
        }
        if let code = code {
            postBody[kCodeKey] = code
        }
        return postBody
    }

    // MARK: Internal API for development
    static var host: String { gAPIHost }
    static func setHost(_ host: String) {
        gAPIHost = host
    }
}
