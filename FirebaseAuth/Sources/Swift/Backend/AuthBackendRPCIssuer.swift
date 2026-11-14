// Copyright 2024 Google LLC
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
import FirebaseCoreExtension
import FirebaseCoreInternal
import Foundation

protocol AuthBackendRPCIssuerProtocol: Sendable {
  /// Asynchronously send a HTTP request.
  /// - Parameter request: The request to be made.
  /// - Parameter body: Request body.
  /// - Parameter contentType: Content type of the body.
  /// - Parameter completionHandler: Handles HTTP response. Invoked asynchronously
  ///  on the auth global  work queue in the future.
  func asyncCallToURL<T: AuthRPCRequest>(with request: T,
                                         body: Data?,
                                         contentType: String) async -> (Data?, Error?)
}

final class AuthBackendRPCIssuer: AuthBackendRPCIssuerProtocol {
  /// The client that sends the requests. The shared client's session is never invalidated, so
  /// requests can't hit the invalidated-session crash of
  /// https://github.com/firebase/firebase-ios-sdk/issues/1261.
  private let httpClient: FirebaseHTTPClient

  /// Creates an issuer that sends requests with `httpClient`. Tests pass a client with a test
  /// transport.
  init(httpClient: FirebaseHTTPClient = .shared) {
    self.httpClient = httpClient
  }

  func asyncCallToURL<T: AuthRPCRequest>(with request: T,
                                         body: Data?,
                                         contentType: String) async -> (Data?, Error?) {
    let requestConfiguration = request.requestConfiguration()
    var urlRequest = await AuthBackend.request(
      for: request.requestURL(),
      httpMethod: body == nil ? "GET" : "POST",
      contentType: contentType,
      requestConfiguration: requestConfiguration
    )
    urlRequest.httpBody = body
    urlRequest.setValue(AuthBackend.authUserAgent(), forHTTPHeaderField: "User-Agent")
    // The emulator can be reached over `http`.
    let usesEmulator = requestConfiguration.emulatorHostAndPort != nil
    let policy = HTTPRequestPolicy(allowsInsecureHTTP: usesEmulator,
                                   allowsLoopbackHTTP: usesEmulator)
    do {
      let (data, response) = try await httpClient.data(for: urlRequest, policy: policy)
      guard let statusError = HTTPStatusError.error(for: response, body: data) else {
        return (data, nil)
      }
      // `AuthBackend` decodes the server's error message from the body, and reports an error
      // without a body as a network error.
      return (data.isEmpty ? nil : data, statusError)
    } catch {
      return (nil, error)
    }
  }
}
