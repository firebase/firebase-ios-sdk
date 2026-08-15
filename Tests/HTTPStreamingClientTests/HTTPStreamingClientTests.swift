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
  private func makeClient() -> HTTPStreamingClient {
    MockHTTPURLProtocol.reset()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockHTTPURLProtocol.self]
    return HTTPStreamingClient(configuration: configuration)
  }

  @Test
  func bytesMethodStreamsRawBytesAndLines() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/bytes-api"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("ABC\nDEF\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var lines: [String] = []
    for try await line in bytes.lines {
      lines.append(line)
    }

    #expect(response.statusCode == 200)
    #expect(lines == ["ABC", "DEF"])
    #expect(bytes.task != nil)
  }

  @Test
  func bytesIteratingRawBytes() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/raw-bytes"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data([0x01, 0x02]))
      proto.client?.urlProtocol(proto, didLoad: Data([0x03, 0x04]))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var receivedBytes: [UInt8] = []
    for try await byte in bytes {
      receivedBytes.append(byte)
    }

    #expect(response.statusCode == 200)
    #expect(receivedBytes == [0x01, 0x02, 0x03, 0x04])
  }

  @Test
  func bytesCollectBuffersEntireData() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/collect-bytes"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("Hello, ".utf8))
      proto.client?.urlProtocol(proto, didLoad: Data("World!".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    let data = try await bytes.collect()

    #expect(response.statusCode == 200)
    #expect(String(decoding: data, as: UTF8.self) == "Hello, World!")
  }

  @Test
  func streamSingleChunkMultipleLines() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-single-chunk"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "text/plain"]
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("line1\nline2\nline3\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var collectedLines: [String] = []
    for try await line in bytes.lines {
      collectedLines.append(line)
    }

    #expect(response.statusCode == 200)
    #expect(collectedLines == ["line1", "line2", "line3"])
  }

  @Test
  func linesSplitAcrossMultipleChunks() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-split-chunks"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("data: chunk1 ".utf8))
      proto.client?.urlProtocol(proto, didLoad: Data("part2\ndata: ".utf8))
      proto.client?.urlProtocol(proto, didLoad: Data("chunk2\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var collectedLines: [String] = []
    for try await line in bytes.lines {
      collectedLines.append(line)
    }

    #expect(response.statusCode == 200)
    #expect(collectedLines == ["data: chunk1 part2", "data: chunk2"])
  }

  @Test
  func streamSplitCRLFAndUTF8() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-crlf-utf8"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    let emojiBytes: [UInt8] = [0xF0, 0x9F, 0x8E, 0x89]  // 🎉
    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("Greeting\r".utf8))
      proto.client?.urlProtocol(proto, didLoad: Data("\nParty ".utf8) + Data(emojiBytes[0..<2]))
      proto.client?.urlProtocol(proto, didLoad: Data(emojiBytes[2..<4]) + Data(" Time\r\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var collectedLines: [String] = []
    for try await line in bytes.lines {
      collectedLines.append(line)
    }

    #expect(response.statusCode == 200)
    #expect(collectedLines == ["Greeting", "Party 🎉 Time"])
  }

  @Test
  func streamPreservesBlankLines() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/stream-blank-lines"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(
        proto,
        didLoad: Data("event: message\ndata: hello\n\nevent: done\n".utf8)
      )
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var collectedLines: [String] = []
    for try await line in bytes.lines {
      collectedLines.append(line)
    }

    #expect(response.statusCode == 200)
    #expect(collectedLines == ["event: message", "data: hello", "", "event: done"])
  }

  @Test
  func streamNon2xxResponseReturnsStatusCodeAndBody() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/error-404"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 404,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("{\n  \"error\": \"not found\"\n}".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
    var collectedLines: [String] = []
    for try await line in bytes.lines {
      collectedLines.append(line)
    }

    #expect(response.statusCode == 404)
    #expect(collectedLines == ["{", "  \"error\": \"not found\"", "}"])
  }

  @Test
  func networkErrorBeforeResponseThrows() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/fail-before-response"))

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didFailWithError: URLError(.cannotConnectToHost))
    }

    do {
      _ = try await client.bytes(for: URLRequest(url: testURL))
      Issue.record("Expected request to throw network error")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .cannotConnectToHost)
    }
  }

  @Test
  func networkErrorDuringStreamThrows() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/fail-during-stream"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("first line\n".utf8))
      proto.client?.urlProtocol(proto, didFailWithError: URLError(.networkConnectionLost))
    }

    do {
      let (bytes, response) = try await client.bytes(for: URLRequest(url: testURL))
      #expect(response.statusCode == 200)
      for try await _ in bytes.lines {}
      Issue.record("Expected stream to throw network error")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .networkConnectionLost)
    }
  }

  @Test
  func earlyTerminationCancelsStream() async throws {
    let client = makeClient()
    let testURL = try #require(URL(string: "https://example.com/early-termination"))
    let testResponse = try #require(
      HTTPURLResponse(
        url: testURL,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: nil
      )
    )

    MockHTTPURLProtocol.setHandler(for: testURL) { _, proto in
      proto.client?.urlProtocol(proto, didReceive: testResponse, cacheStoragePolicy: .notAllowed)
      proto.client?.urlProtocol(proto, didLoad: Data("line1\nline2\nline3\nline4\n".utf8))
      proto.client?.urlProtocolDidFinishLoading(proto)
    }

    let (bytes, _) = try await client.bytes(for: URLRequest(url: testURL))
    var receivedCount = 0
    for try await _ in bytes.lines {
      receivedCount += 1
      if receivedCount == 2 {
        break
      }
    }

    #expect(receivedCount == 2)
  }

  @Test
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
      _ = try await client.bytes(for: URLRequest(url: testURL))
      Issue.record("Expected non-HTTP response to throw error")
    } catch {
      let urlError = try #require(error as? URLError)
      #expect(urlError.code == .badServerResponse)
    }
  }

  @Test
  func sessionInvalidationMethods() {
    let client = makeClient()

    client.finishTasksAndInvalidate()
    client.invalidateAndCancel()
  }

  @Test
  func requestHttpBodyDataFromBufferAndStream() throws {
    let bufferURL = try #require(URL(string: "https://example.com/body"))
    var bufferRequest = URLRequest(url: bufferURL)
    bufferRequest.httpBody = Data("buffer-payload".utf8)

    #expect(bufferRequest.httpBodyData == Data("buffer-payload".utf8))

    let streamURL = try #require(URL(string: "https://example.com/stream"))
    var streamRequest = URLRequest(url: streamURL)
    streamRequest.httpBodyStream = InputStream(data: Data("stream-payload".utf8))

    #expect(streamRequest.httpBodyData == Data("stream-payload".utf8))
  }
}
