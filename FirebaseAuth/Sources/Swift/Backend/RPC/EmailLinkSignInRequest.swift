/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

/** @var kEmailLinkSigninEndpoint
    @brief The "EmailLinkSignin" endpoint.
 */
private let kEmailLinkSigninEndpoint = "emailLinkSignin";

/** @var kEmailKey
    @brief The key for the "identifier" value in the request.
 */
private let kEmailKey = "email";

/** @var kEmailLinkKey
    @brief The key for the "emailLink" value in the request.
 */
private let kOOBCodeKey = "oobCode";

/** @var kIDTokenKey
    @brief The key for the "IDToken" value in the request.
 */
private let kIDTokenKey = "idToken";

/** @var kPostBodyKey
    @brief The key for the "postBody" value in the request.
 */
private let kPostBodyKey = "postBody";

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
private let kTenantIDKey = "tenantId";



@objc(FIREmailLinkSignInRequest) public class EmailLinkSignInRequest: IdentityToolkitRequest, AuthRPCRequest {

    @objc public let email: String

    /** @property oobCode
        @brief The OOB code used to complete the email link sign-in flow.
     */
    @objc public let oobCode: String

    /** @property IDToken
        @brief The ID Token code potentially used to complete the email link sign-in flow.
     */

    @objc public var IDToken: String?

    @objc public init(email: String, oobCode: String, requestConfiguration: AuthRequestConfiguration) {
        self.email = email
        self.oobCode = oobCode
        super.init(endpoint: kEmailLinkSigninEndpoint, requestConfiguration: requestConfiguration)
    }

    public func unencodedHTTPRequestBody() throws -> Any {
        var postBody: [String: Any] = [
            kEmailKey: email,
            kOOBCodeKey: oobCode
        ]
        if let IDToken = IDToken {
            postBody[kIDTokenKey] = IDToken
        }
        if let tenantID = tenantID {
            postBody[kTenantIDKey] = tenantID
        }
        return postBody

    }
}
