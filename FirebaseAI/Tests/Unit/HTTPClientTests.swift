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

import FirebaseCoreInternal
import Foundation
import Testing

@testable import FirebaseAILogic

#if !os(watchOS)
  @Suite("HTTPClient Tests")
  struct HTTPClientTests {
    private let testID = UUID().uuidString

    private func makeClient() -> HTTPClient {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [StreamingTestURLProtocol.self]
      return HTTPClient(configuration: configuration)
    }

    private func makeTestURL(_ path: String) throws -> URL {
      try #require(URL(string: "https://example.com/\(testID)/\(path)"))
    }

    private func makeResponse(url: URL, statusCode: Int = 200,
                              headerFields: [String: String]? = nil) throws -> HTTPURLResponse {
      try #require(
        HTTPURLResponse(
          url: url,
          statusCode: statusCode,
          httpVersion: "HTTP/1.1",
          headerFields: headerFields
        )
      )
    }

    private func collectLines(from sequence: HTTPAsyncLineSequence) async throws -> [String] {
      var lines: [String] = []
      for try await line in sequence {
        lines.append(line)
      }
      return lines
    }

    @Test
    func accumulatesDataAcrossChunks() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("data-api")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("Hello, ".utf8))
        proto.client?.urlProtocol(proto, didLoad: Data("world!".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (data, response) = try await client.data(for: URLRequest(url: testURL))

      #expect(response.statusCode == 200)
      #expect(String(decoding: data, as: UTF8.self) == "Hello, world!")
    }

    @Test
    func dataNonHTTPResponseThrowsBadServerResponse() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("data-non-http")
      let nonHTTPResponse = try #require(
        URLResponse(
          url: testURL,
          mimeType: "text/plain",
          expectedContentLength: 0,
          textEncodingName: nil
        )
      )

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(
          proto,
          didReceive: nonHTTPResponse,
          cacheStoragePolicy: .notAllowed
        )
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      do {
        _ = try await client.data(for: URLRequest(url: testURL))
        Issue.record("Expected non-HTTP response to throw error")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .badServerResponse)
        #expect(urlError.localizedDescription == "Response was not an HTTP response.")
      }
    }

    @Test
    func streamsLinesAndReturnsTask() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("bytes-api")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("ABC\nDEF\n".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["ABC", "DEF"])
    }

    @Test
    func streamSingleChunkMultipleLines() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("stream-single-chunk")
      let testResponse = try makeResponse(
        url: testURL, statusCode: 200, headerFields: ["Content-Type": "text/plain"]
      )

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("line1\nline2\nline3\n".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["line1", "line2", "line3"])
    }

    @Test
    func linesSplitAcrossMultipleChunks() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("stream-split-chunks")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("data: chunk1 ".utf8))
        proto.client?.urlProtocol(proto, didLoad: Data("part2\ndata: ".utf8))
        proto.client?.urlProtocol(proto, didLoad: Data("chunk2\n".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["data: chunk1 part2", "data: chunk2"])
    }

    @Test
    func streamSplitCRLFAndUTF8() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("stream-crlf-utf8")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      let emojiBytes: [UInt8] = [0xF0, 0x9F, 0x8E, 0x89] // 🎉
      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("Greeting\r".utf8))
        proto.client?.urlProtocol(proto, didLoad: Data("\nParty ".utf8) + Data(emojiBytes[0 ..< 2]))
        proto.client?.urlProtocol(
          proto,
          didLoad: Data(emojiBytes[2 ..< 4]) + Data(" Time\r\n".utf8)
        )
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["Greeting", "Party 🎉 Time"])
    }

    @Test
    func streamPreservesBlankLines() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("stream-blank-lines")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(
          proto,
          didLoad: Data("event: message\ndata: hello\n\nevent: done\n".utf8)
        )
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["event: message", "data: hello", "", "event: done"])
    }

    @Test
    func streamNon2xxResponseReturnsStatusCodeAndBody() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("error-404")
      let testResponse = try makeResponse(url: testURL, statusCode: 404, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("{\n  \"error\": \"not found\"\n}".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 404)
      #expect(collectedLines == ["{", "  \"error\": \"not found\"", "}"])
    }

    @Test
    func networkErrorBeforeResponseThrows() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("fail-before-response")

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didFailWithError: URLError(.cannotConnectToHost))
      }

      do {
        _ = try await client.lines(for: URLRequest(url: testURL))
        Issue.record("Expected request to throw network error")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .cannotConnectToHost)
      }
    }

    @Test
    func networkErrorDuringStreamThrows() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("fail-during-stream")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("first line\n".utf8))
        proto.client?.urlProtocol(proto, didFailWithError: URLError(.networkConnectionLost))
      }

      do {
        let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
        #expect(response.statusCode == 200)
        for try await _ in linesSequence {}
        Issue.record("Expected stream to throw network error")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .networkConnectionLost)
      }
    }

    @Test(.timeLimit(.minutes(1)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func earlyTerminationCancelsStream() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("early-termination")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)
      let (stopStream, stopContinuation) = AsyncStream<Void>.makeStream()

      StreamingTestURLProtocol.setStopHandler(for: testURL) {
        stopContinuation.yield()
        stopContinuation.finish()
      }
      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        let payload = String(repeating: "line\n", count: 2000)
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      }

      var receivedCount = 0
      // Scope `linesSequence` to a `do` block so it deallocates immediately after `break`,
      // triggering `onTermination` and cancelling the underlying `URLSessionDataTask`.
      do {
        let (linesSequence, _) = try await client.lines(for: URLRequest(url: testURL))
        for try await _ in linesSequence {
          receivedCount += 1
          if receivedCount == 2 {
            break
          }
        }
      }

      var stopIterator = stopStream.makeAsyncIterator()
      await stopIterator.next()

      #expect(receivedCount == 2)
    }

    @Test
    func ignores1xxInformationalResponseBefore200() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("informational-100")
      let continueResponse = try makeResponse(url: testURL, statusCode: 100, headerFields: nil)
      let okResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(
          proto,
          didReceive: continueResponse,
          cacheStoragePolicy: .notAllowed
        )
        proto.client?.urlProtocol(proto, didReceive: okResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("ok\n".utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
      let collectedLines = try await collectLines(from: linesSequence)

      #expect(response.statusCode == 200)
      #expect(collectedLines == ["ok"])
    }

    @Test(.timeLimit(.minutes(1)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func cancelledDataRequestAfterHeadersThrowsCancelledError() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("cancel-data-mid-body")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)
      let (loadedStream, loadedContinuation) = AsyncStream<Void>.makeStream()

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data("partial body".utf8))
        loadedContinuation.yield()
        loadedContinuation.finish()
      }

      let requestTask = Task {
        try await client.data(for: URLRequest(url: testURL))
      }

      var loadedIterator = loadedStream.makeAsyncIterator()
      await loadedIterator.next()
      requestTask.cancel()

      do {
        _ = try await requestTask.value
        Issue.record("Expected cancelled data(for:) request to throw URLError(.cancelled)")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .cancelled)
      }
    }

    @Test(.timeLimit(.minutes(1)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func cancelledLineStreamWithPartialLineThrowsCancelledError() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("cancel-lines-mid-line")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        let payload = "complete line\n" + String(repeating: "x", count: 8192)
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      }

      let (linesSequence, _) = try await client.lines(for: URLRequest(url: testURL))
      let consumeTask = Task { () -> [String] in
        var lines: [String] = []
        var iterator = linesSequence.makeAsyncIterator()
        if let first = try await iterator.next() {
          lines.append(first)
        }
        withUnsafeCurrentTask { $0?.cancel() }
        if let second = try await iterator.next() {
          lines.append(second)
        }
        return lines
      }

      do {
        let lines = try await consumeTask.value
        Issue.record("Expected cancelled stream to throw, but returned \(lines)")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .cancelled)
      }
    }

    @Test
    func nonHTTPResponseThrowsBadServerResponse() async throws {
      let client = makeClient()
      let testURL = try makeTestURL("non-http")
      let nonHTTPResponse = try #require(
        URLResponse(
          url: testURL,
          mimeType: "text/plain",
          expectedContentLength: 0,
          textEncodingName: nil
        )
      )

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(
          proto,
          didReceive: nonHTTPResponse,
          cacheStoragePolicy: .notAllowed
        )
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      do {
        _ = try await client.lines(for: URLRequest(url: testURL))
        Issue.record("Expected non-HTTP response to throw error")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .badServerResponse)
        #expect(urlError.localizedDescription == "Response was not an HTTP response.")
      }
    }

    @Test(.timeLimit(.minutes(1)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func sessionInvalidationMethods() async throws {
      let finishingClient = makeClient()
      finishingClient.finishTasksAndInvalidate()

      let cancellingClient = makeClient()
      let testURL = try makeTestURL("invalidate-and-cancel")
      let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

      StreamingTestURLProtocol.setHandler(for: testURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
        let payload = String(repeating: "line\n", count: 2000)
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
      }

      let (linesSequence, _) = try await cancellingClient.lines(for: URLRequest(url: testURL))
      cancellingClient.invalidateAndCancel()

      do {
        for try await _ in linesSequence {}
        Issue.record("Expected invalidated session stream to throw URLError(.cancelled)")
      } catch {
        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .cancelled)
      }
    }
  }

  // MARK: - Streaming Test URLProtocol

  /// A custom `URLProtocol` for intercepting and mocking streaming HTTP requests in unit tests.
  private final class StreamingTestURLProtocol: URLProtocol {
    /// A closure that handles a mocked `URLRequest` using the provided `StreamingTestURLProtocol`.
    typealias Handler = @Sendable (URLRequest, StreamingTestURLProtocol) throws -> Void

    private static let handlers = UnfairLock<[String: Handler]>([:])
    private static let stopHandlers = UnfairLock<[String: @Sendable () -> Void]>([:])

    /// Registers a mock response handler for the specified URL.
    static func setHandler(for url: URL, _ handler: @escaping Handler) {
      let urlString = url.absoluteString
      handlers.withLock { $0[urlString] = handler }
    }

    /// Registers a callback invoked when `stopLoading()` is called for the specified URL.
    static func setStopHandler(for url: URL, _ handler: @escaping @Sendable () -> Void) {
      let urlString = url.absoluteString
      stopHandlers.withLock { $0[urlString] = handler }
    }

    /// Determines whether this protocol can handle the given request.
    override class func canInit(with request: URLRequest) -> Bool {
      guard let urlString = request.url?.absoluteString else { return false }
      return handlers.withLock { $0[urlString] != nil }
    }

    /// Returns the canonical version of the given request.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      request
    }

    /// Starts loading the mocked request by invoking its registered handler.
    override func startLoading() {
      let handler: Handler? = {
        guard let urlString = request.url?.absoluteString else { return nil }
        return Self.handlers.withLock { $0.removeValue(forKey: urlString) }
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

    /// Stops loading the mocked request and notifies any registered stop handler.
    override func stopLoading() {
      if let urlString = request.url?.absoluteString {
        let stopHandler = Self.stopHandlers.withLock { $0.removeValue(forKey: urlString) }
        stopHandler?()
      }
      client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
  }
#endif // !os(watchOS)
