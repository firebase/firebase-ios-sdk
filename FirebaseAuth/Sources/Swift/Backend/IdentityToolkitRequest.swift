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

import FirebaseCore
import Foundation

private let kHttpsProtocol = "https:"
private let kHttpProtocol = "http:"
// Legacy GCIP v1 hosts
private let kFirebaseAuthAPIHost = "www.googleapis.com"
private let kFirebaseAuthStagingAPIHost = "staging-www.sandbox.googleapis.com"
// Regional R-GCIP v2 hosts
private let kRegionalGCIPAPIHost = "identityplatform.googleapis.com"
private let kRegionalGCIPStagingAPIHost = "staging-identityplatform.sandbox.googleapis.com"
#if compiler(>=6)
  private nonisolated(unsafe) var gAPIHost = "www.googleapis.com"
#else
  private var gAPIHost = "www.googleapis.com"
#endif
/// Represents a request to an Identity Toolkit endpoint, routing either to
/// legacy GCIP v1 or regionalized R-GCIP v2 based on presence of tenantID.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class IdentityToolkitRequest {
  /// RPC endpoint name, e.g. "signInWithPassword" or full exchange path
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

  /// Optional local emulator host and port
  var emulatorHostAndPort: String? {
    return _requestConfiguration.emulatorHostAndPort
  }

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

  /// Override this if you need query parameters (default none)
  func queryParams() -> String {
    return ""
  }

  /// Provide the same configuration for AuthBackend
  func requestConfiguration() -> AuthRequestConfiguration {
    return _requestConfiguration
  }

  /// Build the full URL, branching on whether tenantID is set.
  func requestURL() -> URL {
    guard let auth = _requestConfiguration.auth else {
      fatalError("Internal Auth error: missing Auth on requestConfiguration")
    }
    let protocolScheme: String
    let hostPrefix: String
    let urlString: String
    // R-GCIP v2 if location is non-nil

    if let region = _requestConfiguration.location,
       let tenant = _requestConfiguration.tenantId,
       !region.isEmpty,
       !tenant.isEmpty {
      // Project identifier
      guard let project = auth.app?.options.projectID else {
        fatalError("Internal Auth error: missing projectID")
      }
      // Choose emulator, staging, or prod host
      if let emu = emulatorHostAndPort {
        protocolScheme = kHttpProtocol
        hostPrefix = "\(emu)/\(kRegionalGCIPAPIHost)"
      } else if useStaging {
        protocolScheme = kHttpsProtocol
        hostPrefix = kRegionalGCIPStagingAPIHost
      } else {
        protocolScheme = kHttpsProtocol
        hostPrefix = kRegionalGCIPAPIHost
      }
      // Regionalized v2 path
      urlString =
        "\(protocolScheme)//\(hostPrefix)/v2/projects/\(project)"
          + "/locations/\(region)/tenants/\(tenant)/idpConfigs/\(endpoint)?key=\(apiKey)"
    } else {
      // Legacy GCIP v1 branch
      if let emu = emulatorHostAndPort {
        protocolScheme = kHttpProtocol
        hostPrefix = "\(emu)/\(kFirebaseAuthAPIHost)"
      } else if useStaging {
        protocolScheme = kHttpsProtocol
        hostPrefix = kFirebaseAuthStagingAPIHost
      } else {
        protocolScheme = kHttpsProtocol
        hostPrefix = kFirebaseAuthAPIHost
      }
      urlString =
        "\(protocolScheme)//\(hostPrefix)" +
        "/identitytoolkit/v3/relyingparty/\(endpoint)?key=\(apiKey)"
    }
    guard let returnURL = URL(string: "\(urlString)\(queryParams())") else {
      fatalError("Internal Auth error: Failed to generate URL for \(urlString)")
    }
    return returnURL
  }

  // MARK: - Testing API

  /// For testing: override the global host for legacy flows
  static var host: String {
    get { gAPIHost }
    set { gAPIHost = newValue }
  }

  static func setHost(_ host: String) {
    gAPIHost = host
  }
}
