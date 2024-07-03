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

/// The "createAuthUri" endpoint.
private let kCreateAuthURIEndpoint = "createAuthUri"

/// The key for the "providerId" value in the request.
private let kProviderIDKey = "providerId"

/// The key for the "identifier" value in the request.
private let kIdentifierKey = "identifier"

/// The key for the "continueUri" value in the request.
private let kContinueURIKey = "continueUri"

/// The key for the "openidRealm" value in the request.
private let kOpenIDRealmKey = "openidRealm"

/// The key for the "clientId" value in the request.
private let kClientIDKey = "clientId"

/// The key for the "context" value in the request.
private let kContextKey = "context"

/// The key for the "appId" value in the request.
private let kAppIDKey = "appId"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

/// Represents the parameters for the createAuthUri endpoint.
/// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/createAuthUri
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class CreateAuthURIRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = CreateAuthURIResponse

  /// The email or federated ID of the user.
  let identifier: String

  /// The URI to which the IDP redirects the user after the federated login flow.
  let continueURI: String

  /// Optional realm for OpenID protocol. The sub string "scheme://domain:port" of the param
  ///   "continueUri" is used if this is not set.
  var openIDRealm: String?

  /// The IdP ID. For white listed IdPs it's a short domain name e.g. google.com, aol.com,
  ///    live.net and yahoo.com. For other OpenID IdPs it's the OP identifier.
  var providerID: String?

  /// The relying party OAuth client ID.
  var clientID: String?

  /// The opaque value used by the client to maintain context info between the authentication
  ///   request and the IDP callback.
  var context: String?

  /// The iOS client application's bundle identifier.
  var appID: String?

  init(identifier: String, continueURI: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.identifier = identifier
    self.continueURI = continueURI
    super.init(endpoint: kCreateAuthURIEndpoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [
      kIdentifierKey: identifier,
      kContinueURIKey: continueURI,
    ]

    if let providerID = providerID {
      postBody[kProviderIDKey] = providerID
    }
    if let openIDRealm = openIDRealm {
      postBody[kOpenIDRealmKey] = openIDRealm
    }
    if let clientID = clientID {
      postBody[kClientIDKey] = clientID
    }
    if let context = context {
      postBody[kContextKey] = context
    }
    if let appID = appID {
      postBody[kAppIDKey] = appID
    }
    if let tenantID = tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
