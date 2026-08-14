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

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A custom `URLProtocol` for mocking network responses in Gemini API client tests.
final class MockGeminiURLProtocol: URLProtocol {
  typealias Handler = @Sendable (URLRequest, MockGeminiURLProtocol) throws -> Void

  private static let lock = NSLock()
  nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

  static func setHandler(for url: URL, _ handler: @escaping Handler) {
    lock.lock()
    defer { lock.unlock() }
    handlers[url.absoluteString] = handler
  }

  static func reset() {
    lock.lock()
    defer { lock.unlock() }
    handlers.removeAll()
  }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    MockGeminiURLProtocol.lock.lock()
    let handler: Handler?
    if let urlString = request.url?.absoluteString {
      handler = MockGeminiURLProtocol.handlers[urlString]
    } else {
      handler = nil
    }
    MockGeminiURLProtocol.lock.unlock()

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

  override func stopLoading() {}
}
