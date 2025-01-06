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

private let kRecaptchaVersion = "RECAPTCHA_ENTERPRISE"

private let kGetOobConfirmationCodeEndpoint = "getOobConfirmationCode"

/// The name of the required "requestType" property in the request.
private let kRequestTypeKey = "requestType"

/// The name of the "email" property in the request.
private let kEmailKey = "email"

/// The name of the "newEmail" property in the request.
private let kNewEmailKey = "newEmail"

/// The key for the "idToken" value in the request. This is actually the STS Access Token,
/// despite its confusing (backwards compatible) parameter name.
private let kIDTokenKey = "idToken"

/// The "getRecaptchaConfig" endpoint.
private let kGetRecaptchaConfigEndpoint = "recaptchaConfig"

/// The key for the "clientType" value in the request.
private let kClientTypeKey = "clientType"

/// The key for the "version" value in the request.
private let kVersionKey = "version"

/// The key for the tenant id value in the request.
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetRecaptchaConfigRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = GetRecaptchaConfigResponse

  required init(requestConfiguration: AuthRequestConfiguration) {
    super.init(
      endpoint: kGetRecaptchaConfigEndpoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }

  var unencodedHTTPRequestBody: [String: AnyHashable]? {
    nil
  }

  override func queryParams() -> String {
    var queryParams = "&\(kClientTypeKey)=\(clientType)&\(kVersionKey)=\(kRecaptchaVersion)"
    if let tenantID {
      queryParams += "&\(kTenantIDKey)=\(tenantID)"
    }
    return queryParams
  }
}
