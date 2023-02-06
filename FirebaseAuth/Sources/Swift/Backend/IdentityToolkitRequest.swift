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
@_implementationOnly import FirebaseCore

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
  @objc public let endpoint: String

  /** @property APIKey
   @brief Gets the client's API key used for the request.
   */
  @objc public var APIKey: String

  /** @property tenantID
   @brief The tenant ID of the request. nil if none is available.
   */
  var tenantID: String?

  let _requestConfiguration: AuthRequestConfiguration

  let _useIdentityPlatform: Bool

  let _useStaging: Bool

  @objc public init(endpoint: String, requestConfiguration: AuthRequestConfiguration,
                    useIdentityPlatform: Bool = false, useStaging: Bool = false) {
    self.endpoint = endpoint
    APIKey = requestConfiguration.APIKey
    _requestConfiguration = requestConfiguration
    _useIdentityPlatform = useIdentityPlatform
    _useStaging = useStaging

    // TODO: tenantID should be set via a parameter, since it might not be the default app (#10748)
    // TODO: remove FirebaseCore import when #10748 is fixed.
    // Automatically set the tenant ID. If the request is initialized before FIRAuth is configured,
    // set tenant ID to nil.
    if FirebaseApp.app() == nil {
      tenantID = nil
    } else {
      tenantID = Auth.auth().tenantID
    }
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
      urlString =
        "\(apiProtocol)//\(apiHostAndPathPrefix)/identitytoolkit/v3/relyingparty/\(endpoint)?key=\(APIKey)"
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
