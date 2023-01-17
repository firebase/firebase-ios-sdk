//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/06/2022.
//

import Foundation

private let kHttpsProtocol = "https:"
private let kHttpProtocol = "http:"

private let kEmulatorHostAndPrefixFormat = "%@/%@"

private let gAPIHost = "www.googleapis.com"

private let kFirebaseAuthAPIHost = "www.googleapis.com"
private let kIdentityPlatformAPIHost = "identitytoolkit.googleapis.com"

private let kFirebaseAuthStagingAPIHost = "staging-www.sandbox.googleapis.com"
private let kIdentityPlatformStagingAPIHost =
"staging-identitytoolkit.sandbox.googleapis.com"


/** @class FIRIdentityToolkitRequest
 @brief Represents a request to an identity toolkit endpoint.
 */
@objc(FIRIdentityToolkitRequest) open class IdentityToolkitRequest: NSObject {

    /** @property endpoint
     @brief Gets the RPC's endpoint.
     */
    let endpoint: String

    /** @property APIKey
     @brief Gets the client's API key used for the request.
     */
    var APIKey: String

    /** @property tenantID
     @brief The tenant ID of the request. nil if none is available.
     */
    var tenantID: String?

    let _requestConfiguration: AuthRequestConfiguration

    let _useIdentityPlatform: Bool

    let _useStaging: Bool


    /** @fn initWithEndpoint:APIKey:
     @brief Designated initializer.
     @param endpoint The endpoint name.
     @param requestConfiguration An object containing configurations to be added to the request.
     */
    @objc public init(endpoint: String, requestConfiguration: AuthRequestConfiguration) {
        self.endpoint = endpoint
        self.APIKey = requestConfiguration.APIKey
        self._requestConfiguration = requestConfiguration
        self._useIdentityPlatform = false
        self._useStaging = false

        // Automatically set the tenant ID. If the request is initialized before FIRAuth is configured,
        // set tenant ID to nil.
        self.tenantID = Auth.auth().tenantID
    }

    @objc public init(endpoint: String, requestConfiguration: AuthRequestConfiguration, useIdentityPlatform: Bool, useStaging: Bool) {
        self.endpoint = endpoint
        self.APIKey = requestConfiguration.APIKey
        self._requestConfiguration = requestConfiguration
        self._useIdentityPlatform = useIdentityPlatform
        self._useStaging = useStaging

        // Automatically set the tenant ID. If the request is initialized before FIRAuth is configured,
        // set tenant ID to nil.
        self.tenantID = Auth.auth().tenantID
    }

    @objc public func containsPostBody() -> Bool {
        true
    }

    /** @fn requestURL
     @brief Gets the request's full URL.
     */
    @objc public func requestURL() -> URL {

        let apiProtocol: String
        let apiHostAndPathPrefix: String
        let urlString: String
        let emulatorHostAndPort = _requestConfiguration.emulatorHostAndPort
        if _useIdentityPlatform {
            if let emulatorHostAndPort = emulatorHostAndPort {
                apiProtocol = kHttpProtocol
                apiHostAndPathPrefix = "\(emulatorHostAndPort)/\(kIdentityPlatformAPIHost)"
            } else if _useStaging {
                apiHostAndPathPrefix = kIdentityPlatformStagingAPIHost
                apiProtocol = kHttpsProtocol
            } else {
                apiHostAndPathPrefix = kIdentityPlatformAPIHost
                apiProtocol = kHttpsProtocol
            }
            urlString = "\(apiProtocol)//\(apiHostAndPathPrefix)/v2/\(endpoint)?key=\(APIKey)"
            
        } else {
            if let emulatorHostAndPort = emulatorHostAndPort {
                apiProtocol = kHttpProtocol
                apiHostAndPathPrefix = "\(emulatorHostAndPort)/\(kFirebaseAuthAPIHost)"
            } else if _useStaging {
                apiProtocol = kHttpsProtocol
                apiHostAndPathPrefix = kFirebaseAuthStagingAPIHost
            } else {
                apiProtocol = kHttpsProtocol
                apiHostAndPathPrefix = kFirebaseAuthAPIHost
            }
            urlString = "\(apiProtocol)//\(apiHostAndPathPrefix)/identitytoolkit/v3/relyingparty/\(endpoint)?key=\(APIKey)"
        }
        return URL(string: urlString)!
    }

    /** @fn requestConfiguration
     @brief Gets the request's configuration.
     */
    @objc public func requestConfiguration() -> AuthRequestConfiguration {
        _requestConfiguration
    }
}
