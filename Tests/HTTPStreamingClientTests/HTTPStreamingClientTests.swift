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
import HTTPStreamingClient
import SharedTestUtilities
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - HTTPStreamingClient Integration Tests

@Suite("HTTPStreamingClient Integration Tests", .serialized)
struct HTTPStreamingClientTests {
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  private func makeClient() -> HTTPStreamingClient {
    MockHTTPURLProtocol.reset()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockHTTPURLProtocol.self]
    return HTTPStreamingClient(configuration: configuration)
  }

  private func makeResponse(url: URL, statusCode: Int = 200, headerFields: [String: String]? = nil)
    throws -> HTTPURLResponse
  {
    try #require(
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headerFields
      )
    )
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  private func collectLines(from sequence: HTTPAsyncLineSequence) async throws -> [String] {
    var lines: [String] = []
    for try await line in sequence {
      lines.append(line)
    }
    return lines
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamsLinesAndReturnsTask() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/bytes-api"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamSingleChunkMultipleLines() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-single-chunk"))
    let testResponse = try makeResponse(
      url: testURL, statusCode: 200, headerFields: ["Content-Type": "text/plain"]
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func linesSplitAcrossMultipleChunks() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-split-chunks"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamSplitCRLFAndUTF8() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-crlf-utf8"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    let emojiBytes: [UInt8] = [0xF0, 0x9F, 0x8E, 0x89]  // 🎉
    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("Greeting\r".utf8))
      proto.client?.urlProtocol(proto, didLoad: Data("\nParty ".utf8) + Data(emojiBytes[0..<2]))
      proto.client?.urlProtocol(proto, didLoad: Data(emojiBytes[2..<4]) + Data(" Time\r\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (linesSequence, response) = try await client.lines(for: URLRequest(url: testURL))
    let collectedLines = try await collectLines(from: linesSequence)

    #expect(response.statusCode == 200)
    #expect(collectedLines == ["Greeting", "Party 🎉 Time"])
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamPreservesBlankLines() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-blank-lines"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func streamNon2xxResponseReturnsStatusCodeAndBody() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/error-404"))
    let testResponse = try makeResponse(url: testURL, statusCode: 404, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func networkErrorBeforeResponseThrows() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/fail-before-response"))

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func networkErrorDuringStreamThrows() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/fail-during-stream"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
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

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func earlyTerminationCancelsStream() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/early-termination"))
    let testResponse = try makeResponse(url: testURL, statusCode: 200, headerFields: nil)

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("line1\nline2\nline3\nline4\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (linesSequence, _) = try await client.lines(for: URLRequest(url: testURL))
    var receivedCount = 0
    for try await _ in linesSequence {
      receivedCount += 1
      if receivedCount == 2 {
        break
      }
    }

    #expect(receivedCount == 2)
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func nonHTTPResponseThrowsBadServerResponse() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/non-http"))
    let nonHTTPResponse = try #require(
      URLResponse(
        url: testURL,
        mimeType: "text/plain",
        expectedContentLength: 0,
        textEncodingName: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: nonHTTPResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    do {
      _ = try await client.lines(for: URLRequest(url: testURL))
      Issue.record("Expected non-HTTP response to throw error")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .badServerResponse)
    }
  }

  @Test
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
  func sessionInvalidationMethods() {
    let client = makeClient()

    client.finishTasksAndInvalidate()
    client.invalidateAndCancel()
  }
}
