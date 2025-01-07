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

/// The generic interface for an RPC request needed by AuthBackend.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
protocol AuthRPCRequest {
  associatedtype Response: AuthRPCResponse

  /// Gets the request's full URL.
  func requestURL() -> URL

  /// Creates unencoded HTTP body representing the request.
  /// - Returns: The HTTP body data representing the request before any encoding.
  /// - Note: Requests with a post body are POST requests. Requests without a
  /// post body are GET requests.
  var unencodedHTTPRequestBody: [String: AnyHashable]? { get }

  /// The request configuration.
  func requestConfiguration() -> AuthRequestConfiguration

  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String)
}

// Default implementation of AuthRPCRequests. This produces similar behaviour to an optional method
// in Obj-C.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension AuthRPCRequest {
  func injectRecaptchaFields(recaptchaResponse: String?, recaptchaVersion: String) {
    fatalError("Internal FirebaseAuth Error: unimplemented injectRecaptchaFields")
  }
}
