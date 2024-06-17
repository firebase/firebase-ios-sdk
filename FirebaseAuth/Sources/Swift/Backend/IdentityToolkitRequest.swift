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

private let kHttpsProtocol = "https:"
private let kHttpProtocol = "http:"

private let kEmulatorHostAndPrefixFormat = "%@/%@"

private var gAPIHost = "www.googleapis.com"

private let kFirebaseAuthAPIHost = "www.googleapis.com"
private let kIdentityPlatformAPIHost = "identitytoolkit.googleapis.com"

private let kFirebaseAuthStagingAPIHost = "staging-www.sandbox.googleapis.com"
private let kIdentityPlatformStagingAPIHost =
  "staging-identitytoolkit.sandbox.googleapis.com"

/// Represents a request to an identity toolkit endpoint.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class IdentityToolkitRequest {
  /// Gets the RPC's endpoint.
  let endpoint: String

  /// Gets the client's API key used for the request.
  var apiKey: String

  /// The tenant ID of the request. nil if none is available.
  let tenantID: String?

  /// The toggle of using Identity Platform endpoints.
  let useIdentityPlatform: Bool

  /// The toggle of using staging endpoints.
  let useStaging: Bool

  /// The type of the client that the request sent from, which should be CLIENT_TYPE_IOS;
  var clientType: String

  private let _requestConfiguration: AuthRequestConfiguration

  init(endpoint: String, requestConfiguration: AuthRequestConfiguration,
       useIdentityPlatform: Bool = false, useStaging: Bool = false) {
    self.endpoint = endpoint
    apiKey = requestConfiguration.apiKey
    _requestConfiguration = requestConfiguration
    self.useIdentityPlatform = useIdentityPlatform
    self.useStaging = useStaging
    clientType = "CLIENT_TYPE_IOS"
    tenantID = requestConfiguration.auth?.tenantID
  }

  var containsPostBody: Bool { return true }

  func queryParams() -> String {
    return ""
  }

  /// Returns the request's full URL.
  func requestURL() -> URL {
    let apiProtocol: String
    let apiHostAndPathPrefix: String
    let urlString: String
    let emulatorHostAndPort = _requestConfiguration.emulatorHostAndPort
    if useIdentityPlatform {
      if let emulatorHostAndPort = emulatorHostAndPort {
        apiProtocol = kHttpProtocol
        apiHostAndPathPrefix = "\(emulatorHostAndPort)/\(kIdentityPlatformAPIHost)"
      } else if useStaging {
        apiHostAndPathPrefix = kIdentityPlatformStagingAPIHost
        apiProtocol = kHttpsProtocol
      } else {
        apiHostAndPathPrefix = kIdentityPlatformAPIHost
        apiProtocol = kHttpsProtocol
      }
      urlString = "\(apiProtocol)//\(apiHostAndPathPrefix)/v2/\(endpoint)?key=\(apiKey)"

    } else {
      if let emulatorHostAndPort = emulatorHostAndPort {
        apiProtocol = kHttpProtocol
        apiHostAndPathPrefix = "\(emulatorHostAndPort)/\(kFirebaseAuthAPIHost)"
      } else if useStaging {
        apiProtocol = kHttpsProtocol
        apiHostAndPathPrefix = kFirebaseAuthStagingAPIHost
      } else {
        apiProtocol = kHttpsProtocol
        apiHostAndPathPrefix = kFirebaseAuthAPIHost
      }
      urlString =
        "\(apiProtocol)//\(apiHostAndPathPrefix)/identitytoolkit/v3/relyingparty/\(endpoint)?key=\(apiKey)"
    }
    guard let returnURL = URL(string: "\(urlString)\(queryParams())") else {
      fatalError("Internal Auth error: Failed to generate URL for \(urlString)")
    }
    return returnURL
  }

  /// Returns the request's configuration.
  func requestConfiguration() -> AuthRequestConfiguration {
    _requestConfiguration
  }

  // MARK: Internal API for development

  static var host: String { gAPIHost }
  static func setHost(_ host: String) {
    gAPIHost = host
  }
}
