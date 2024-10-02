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

/// The "EmailLinkSignin" endpoint.
private let kEmailLinkSigninEndpoint = "emailLinkSignin"

/// The key for the "identifier" value in the request.
private let kEmailKey = "email"

/// The key for the "emailLink" value in the request.
private let kOOBCodeKey = "oobCode"

/// The key for the "IDToken" value in the request.
private let kIDTokenKey = "idToken"

/// The key for the "postBody" value in the request.
private let kPostBodyKey = "postBody"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class EmailLinkSignInRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = EmailLinkSignInResponse

  let email: String

  /// The OOB code used to complete the email link sign-in flow.
  let oobCode: String

  /// The ID Token code potentially used to complete the email link sign-in flow.
  var idToken: String?

  init(email: String, oobCode: String,
       requestConfiguration: AuthRequestConfiguration) {
    self.email = email
    self.oobCode = oobCode
    super.init(endpoint: kEmailLinkSigninEndpoint, requestConfiguration: requestConfiguration)
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    var postBody: [String: AnyHashable] = [
      kEmailKey: email,
      kOOBCodeKey: oobCode,
    ]
    if let idToken = idToken {
      postBody[kIDTokenKey] = idToken
    }
    if let tenantID = tenantID {
      postBody[kTenantIDKey] = tenantID
    }
    return postBody
  }
}
