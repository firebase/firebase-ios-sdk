// Copyright 2025 Google LLC
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
#if os(Linux)
import FoundationNetworking
#endif

/// Callback for requests when using ``MockURLRequest``.
typealias URLProtocolRequestHandler = ((URLRequest) throws -> (
  URLResponse,
  Data
))

/// Helper function for creating a ``MockURLProtocol`` routed through a ``URLSession``.
///
/// - Parameters:
///   - requestHandler: Callback to invoke whenever a request comes through the session.
///
/// Example Usage:
/// ```swift
/// let urlSession: URLSession = mockURLSession { request in
///   let data = """
///   {
///     "status": "SERVER_DOWN"
///   }
///   """.data(using: .utf8)!
///
///   guard
///     let url = request.url,
///     let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
///   else {
///     fatalError("Failed to create HTTP response")
///   }
///
///   return (response, rpcErrorData)
/// }
/// ```
func mockURLSession(_ requestHandler: @escaping URLProtocolRequestHandler) -> URLSession {
  let config = URLSessionConfiguration.default
  config.protocolClasses = [MockURLProtocol.self]

  let mockSession = URLSession(configuration: config)
  MockURLProtocol.requestHandler = requestHandler

  return mockSession
}

/// Implementation of a ``URLProtocol``, which allows tests to setup a callback for requests.
class MockURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var requestHandler: URLProtocolRequestHandler?

  override class func canInit(with request: URLRequest) -> Bool {
    #if os(watchOS)
      print("MockURLProtocol cannot be used on watchOS.")
      return false
    #else
      return true
    #endif // os(watchOS)
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }

  override func startLoading() {
    guard let client = client else {
      fatalError("`client` is nil.")
    }

    guard let requestHandler = MockURLProtocol.requestHandler else {
      fatalError("No request handler set.")
    }

    do {
      let (response, data) = try requestHandler(request)
      client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client.urlProtocol(self, didLoad: data)
      client.urlProtocolDidFinishLoading(self)
    } catch {
      client.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

struct URLRequestData: Codable {
  let url: URL
  let body: Data?
  let headers: [String: String]

  init(from: URLRequest) {
    guard let url = from.url else {
      fatalError("URLRequest without URL")
    }
    self.url = url
    self.body = from.httpBody
    self.headers = from.allHTTPHeaderFields ?? [:]
  }
}

/// Empty object when requests don't need to send data.
struct EmptyRequest: Codable {}
