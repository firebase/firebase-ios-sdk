// Copyright 2026 Google LLC
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

package import Foundation
import Synchronization

#if canImport(FoundationNetworking)
  package import FoundationNetworking
#endif

// MARK: - Mock HTTP URL Protocol

/// A custom `URLProtocol` for mocking network responses across package test targets.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
package final class MockHTTPURLProtocol: URLProtocol {
  /// The closure signature for handling intercepted requests.
  package typealias Handler = @Sendable (URLRequest, MockHTTPURLProtocol) throws -> Void

  private static let handlers = Mutex<[String: Handler]>([:])

  /// Registers a mock response handler for the specified URL.
  ///
  /// - Parameters:
  ///   - url: The target URL to intercept.
  ///   - handler: The closure executed when a request matches the URL.
  package static func setHandler(for url: URL, _ handler: @escaping Handler) {
    setHandler(for: url.absoluteString, handler)
  }

  /// Registers a mock response handler for the specified URL string.
  ///
  /// - Parameters:
  ///   - urlString: The target URL string to intercept.
  ///   - handler: The closure executed when a request matches the URL string.
  package static func setHandler(for urlString: String, _ handler: @escaping Handler) {
    handlers.withLock { $0[urlString] = handler }
  }

  /// Clears all registered request handlers.
  package static func reset() {
    handlers.withLock { $0.removeAll() }
  }

  /// Determines whether this protocol can handle the given request.
  ///
  /// - Parameter request: The proposed request.
  /// - Returns: `true` if a handler is registered for this request's URL, otherwise `false`.
  override package class func canInit(with request: URLRequest) -> Bool {
    guard let urlString = request.url?.absoluteString else { return false }
    return handlers.withLock { $0[urlString] != nil }
  }

  /// Returns the canonical version of the given request.
  ///
  /// - Parameter request: The request to canonicalize.
  /// - Returns: The unmodified request.
  override package class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  /// Starts loading the mocked request using the registered handler.
  override package func startLoading() {
    let handler: Handler? = {
      guard let urlString = request.url?.absoluteString else { return nil }
      return MockHTTPURLProtocol.handlers.withLock { $0[urlString] }
    }()

    guard let handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    do {
      try handler(request, self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  /// Stops loading the mocked request.
  override package func stopLoading() {
    client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
  }
}
