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

/** @var kRequestTypeKey
    @brief The name of the required "requestType" property in the request.
 */
private let kRequestTypeKey = "requestType"

/** @var kEmailKey
    @brief The name of the "email" property in the request.
 */
private let kEmailKey = "email"

/** @var kNewEmailKey
    @brief The name of the "newEmail" property in the request.
 */
private let kNewEmailKey = "newEmail"

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
private let kIDTokenKey = "idToken"

/** @var kGetRecaptchaConfigEndpoint
    @brief The "getRecaptchaConfig" endpoint.
 */
private let kGetRecaptchaConfigEndpoint = "recaptchaConfig"

/** @var kClientType
    @brief The key for the "clientType" value in the request.
 */
private let kClientTypeKey = "clientType"

/** @var kVersionKey
    @brief The key for the "version" value in the request.
 */
private let kVersionKey = "version"

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId"

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetRecaptchaConfigRequest: IdentityToolkitRequest, AuthRPCRequest {
  typealias Response = GetRecaptchaConfigResponse

  required init(requestConfiguration: AuthRequestConfiguration) {
    requestConfiguration.httpMethod = "GET"
    super.init(
      endpoint: kGetRecaptchaConfigEndpoint,
      requestConfiguration: requestConfiguration,
      useIdentityPlatform: true
    )
  }

  func unencodedHTTPRequestBody() throws -> [String: AnyHashable] {
    return [:]
  }

  override func containsPostBody() -> Bool {
    false
  }

  override func queryParams() -> String {
    var queryParams = "&\(kClientTypeKey)=\(clientType)&\(kVersionKey)=\(kRecaptchaVersion)"
    if let tenantID {
      queryParams += "&\(kTenantIDKey)=\(tenantID)"
    }
    return queryParams
  }
}
