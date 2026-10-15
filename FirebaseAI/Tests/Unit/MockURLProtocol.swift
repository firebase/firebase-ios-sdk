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
import XCTest

@available(macOS 12.0, watchOS 8.0, *)
class MockURLProtocol: URLProtocol {
  typealias MockURLRequestHandler = (URLRequest) throws -> (
    URLResponse,
    Data?
  )

  private nonisolated(unsafe) static var _requestHandlers = [MockURLRequestHandler]()

  nonisolated(unsafe) static var errorToThrowMidStream: Error?
  nonisolated(unsafe) static var stopLoadingExpectation: XCTestExpectation?
  nonisolated(unsafe) static var neverFinishes: Bool = false
  nonisolated(unsafe) static var chunkSize: Int?

  nonisolated(unsafe) static var requestHandler: MockURLRequestHandler? {
    get {
      assert(
        _requestHandlers.count <= 1,
        "More than one request handler is configured; use `requestHandlers` instead."
      )
      return _requestHandlers.first
    }
    set {
      _requestHandlers = newValue.map { [$0] } ?? []
    }
  }

  nonisolated(unsafe) static var requestHandlersQueue: [MockURLRequestHandler] {
    get { _requestHandlers }
    set { _requestHandlers = newValue }
  }

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

    guard !MockURLProtocol.requestHandlersQueue.isEmpty else {
      fatalError("No request handlers left in the queue. Unexpected network call.")
    }
    let requestHandler = MockURLProtocol.requestHandlersQueue.removeFirst()

    let (response, data): (URLResponse, Data?)
    do {
      (response, data) = try requestHandler(request)
    } catch {
      client.urlProtocol(self, didFailWithError: error)
      XCTFail("Unexpected failure calling request handler: \(error.localizedDescription)")
      return
    }

    client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    if let data {
      if let chunkSize = MockURLProtocol.chunkSize, chunkSize > 0 {
        var offset = data.startIndex
        while offset < data.endIndex {
          let end =
            data.index(offset, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
          client.urlProtocol(self, didLoad: Data(data[offset ..< end]))
          offset = end
        }
      } else {
        var searchStart = data.startIndex
        while searchStart < data.endIndex {
          if let newlineIndex = data[searchStart...].firstIndex(of: 0x0A) {
            let nextIndex = data.index(after: newlineIndex)
            client.urlProtocol(self, didLoad: Data(data[searchStart ..< nextIndex]))
            searchStart = nextIndex
          } else {
            client.urlProtocol(self, didLoad: Data(data[searchStart...]))
            break
          }
        }
      }
    }
    if let errorToThrow = MockURLProtocol.errorToThrowMidStream {
      // Sleep guarantees the error is thrown mid-stream (after URLSession yields the stream to
      // the consumer) rather than pre-stream, preventing test coupling to undocumented URLSession
      // internal buffer sizes.
      let urlProtocol = UncheckedSendable(self)
      Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        client.urlProtocol(urlProtocol.value, didFailWithError: errorToThrow)
      }
    } else if !MockURLProtocol.neverFinishes {
      client.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {
    MockURLProtocol.stopLoadingExpectation?.fulfill()
  }
}

/// Wraps a non-`Sendable` value so it can be captured by a concurrently executing closure.
///
/// Foundation does not declare `URLProtocol` as `Sendable` (only `URLProtocolClient` is
/// `NS_SWIFT_SENDABLE`), yet `URLSession` itself messages protocol instances from its own threads
/// and client callbacks may be made from any thread, so handing the mock to the delayed
/// error-delivery `Task` is safe.
private struct UncheckedSendable<Value>: @unchecked Sendable {
  /// The wrapped value.
  let value: Value

  /// Wraps `value`.
  init(_ value: Value) {
    self.value = value
  }
}
