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
import Foundation
#if COCOAPODS
  @preconcurrency import GTMSessionFetcher
#else
  @preconcurrency import GTMSessionFetcherCore
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
final class AuthBackendRPCIssuer: AuthBackendRPCIssuerProtocol {
  let fetcherService: GTMSessionFetcherService

  init() {
    fetcherService = GTMSessionFetcherService()
    fetcherService.userAgent = AuthBackend.authUserAgent()
    fetcherService.callbackQueue = kAuthGlobalWorkQueue

    // Avoid reusing the session to prevent
    // https://github.com/firebase/firebase-ios-sdk/issues/1261
    fetcherService.reuseSession = false
  }

  func asyncCallToURL<T: AuthRPCRequest>(with request: T,
                                         body: Data?,
                                         contentType: String) async -> (Data?, Error?) {
    let requestConfiguration = request.requestConfiguration()
    let request = await AuthBackend.request(
      for: request.requestURL(),
      httpMethod: body == nil ? "GET" : "POST",
      contentType: contentType,
      requestConfiguration: requestConfiguration
    )
    let fetcher = fetcherService.fetcher(with: request)
    if let _ = requestConfiguration.emulatorHostAndPort {
      fetcher.allowLocalhostRequest = true
      fetcher.allowedInsecureSchemes = ["http"]
    }
    fetcher.bodyData = body

    return await withUnsafeContinuation { continuation in
      fetcher.beginFetch { data, error in
        continuation.resume(returning: (data, error))
      }
    }
  }
}
