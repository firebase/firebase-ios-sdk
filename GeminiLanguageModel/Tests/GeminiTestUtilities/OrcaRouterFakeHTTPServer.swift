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

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

// MARK: - Fake HTTP Server

/// A loopback HTTP server used to exercise the OrcaRouter authorization flow for real.
///
/// The PKCE flow is verified by driving the adapter end to end: a genuine authorize request, a
/// genuine callback delivery, and a genuine code exchange, all over HTTP against this server. No
/// part of the exchange path is stubbed out.
package final class OrcaRouterFakeHTTPServer: @unchecked Sendable {
  /// A request the server received.
  package struct ReceivedRequest: Sendable {
    /// The HTTP method.
    package let method: String
    /// The request path, without the query.
    package let path: String
    /// The parsed query parameters.
    package let query: [String: String]
    /// The request headers, lower-cased.
    package let headers: [String: String]
    /// The request body.
    package let body: Data
  }

  /// A response the server should send.
  package struct Response: Sendable {
    package var status: Int = 200
    package var headers: [String: String] = ["Content-Type": "application/json"]
    package var body: Data = Data()

    /// A JSON response.
    package static func json(_ object: [String: Any], status: Int = 200) -> Response {
      Response(
        status: status,
        headers: ["Content-Type": "application/json"],
        body: (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
      )
    }

    /// An HTML response.
    package static func html(_ markup: String, status: Int = 200) -> Response {
      Response(
        status: status,
        headers: ["Content-Type": "text/html; charset=utf-8"],
        body: Data(markup.utf8)
      )
    }
  }

  /// Handles one request.
  package typealias Handler = @Sendable (ReceivedRequest) -> Response

  private let handler: Handler
  private let listenSocket: Int32
  private let lock = NSLock()
  private var requests: [ReceivedRequest] = []
  private var thread: Thread?
  private var isRunning = false

  /// The ephemeral port the server bound to.
  package let port: UInt16

  /// The base URL of this server.
  package var baseURL: URL {
    URL(string: "http://127.0.0.1:\(port)")!
  }

  /// Creates and starts a server.
  ///
  /// - Parameter handler: The handler that produces the response for each request.
  /// - Throws: `OrcaRouterFakeServerError` if the socket cannot be created or bound.
  package init(handler: @escaping Handler) throws {
    self.handler = handler

    #if canImport(Darwin)
      let streamType = SOCK_STREAM
    #else
      let streamType = Int32(SOCK_STREAM.rawValue)
    #endif

    let socketFD = socket(AF_INET, streamType, 0)
    guard socketFD >= 0 else { throw OrcaRouterFakeServerError.socketUnavailable }

    var reuse: Int32 = 1
    setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0
    address.sin_addr.s_addr = inet_addr("127.0.0.1")

    let bound = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        bind(socketFD, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bound == 0 else {
      close(socketFD)
      throw OrcaRouterFakeServerError.bindFailed
    }
    guard listen(socketFD, 16) == 0 else {
      close(socketFD)
      throw OrcaRouterFakeServerError.listenFailed
    }

    var resolved = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let named = withUnsafeMutablePointer(to: &resolved) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        getsockname(socketFD, socketAddress, &length)
      }
    }
    guard named == 0 else {
      close(socketFD)
      throw OrcaRouterFakeServerError.bindFailed
    }

    self.listenSocket = socketFD
    self.port = UInt16(bigEndian: resolved.sin_port)
  }

  deinit {
    stop()
  }

  /// Serves requests until ``stop()`` is called.
  package func start() {
    lock.lock()
    guard !isRunning else {
      lock.unlock()
      return
    }
    isRunning = true
    lock.unlock()

    let thread = Thread { [weak self] in
      self?.serve()
    }
    thread.stackSize = 512 * 1024
    self.thread = thread
    thread.start()
  }

  /// Stops serving and closes the listening socket.
  package func stop() {
    lock.lock()
    let wasRunning = isRunning
    isRunning = false
    lock.unlock()
    guard wasRunning else { return }
    close(listenSocket)
    thread = nil
  }

  /// Every request the server has handled, in order.
  package var receivedRequests: [ReceivedRequest] {
    lock.lock()
    defer { lock.unlock() }
    return requests
  }

  /// The most recent request that was sent to a path.
  ///
  /// - Parameter path: The path to look for.
  package func lastRequest(to path: String) -> ReceivedRequest? {
    receivedRequests.last { $0.path == path }
  }

  private func serve() {
    while true {
      let clientFD = accept(listenSocket, nil, nil)
      guard clientFD >= 0 else { return }

      let request = readRequest(from: clientFD)
      if let request {
        lock.lock()
        requests.append(request)
        lock.unlock()
        let response = handler(request)
        write(response, to: clientFD)
      }
      close(clientFD)
    }
  }

  private func readRequest(from clientFD: Int32) -> ReceivedRequest? {
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    var headerEnd: Range<Data.Index>?

    // Read until the header terminator arrives.
    while headerEnd == nil {
      let count = read(clientFD, &chunk, chunk.count)
      guard count > 0 else { return nil }
      buffer.append(contentsOf: chunk[0..<count])
      if buffer.count > 1_048_576 { return nil }
      headerEnd = buffer.range(of: Data("\r\n\r\n".utf8))
    }

    guard let headerEnd else { return nil }
    let headerText = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
    var lines = headerText.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else { return nil }
    lines.removeFirst()

    let requestParts = requestLine.split(separator: " ")
    guard requestParts.count >= 2 else { return nil }
    let method = String(requestParts[0])
    let target = String(requestParts[1])

    var headers: [String: String] = [:]
    for line in lines {
      guard let separator = line.firstIndex(of: ":") else { continue }
      let name = line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces)
      let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      headers[name.lowercased()] = value
    }

    var body = Data(buffer[headerEnd.upperBound...])
    let expectedLength = Int(headers["content-length"] ?? "0") ?? 0
    while body.count < expectedLength {
      let count = read(clientFD, &chunk, chunk.count)
      guard count > 0 else { break }
      body.append(contentsOf: chunk[0..<count])
    }

    let pathAndQuery = target.split(separator: "?", maxSplits: 1)
    let path = String(pathAndQuery.first ?? "/")
    var query: [String: String] = [:]
    if pathAndQuery.count > 1 {
      for pair in pathAndQuery[1].split(separator: "&") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        guard let name = parts.first else { continue }
        let rawValue = parts.count > 1 ? String(parts[1]) : ""
        let decodedName =
          String(name).removingPercentEncoding ?? String(name)
        let decodedValue =
          rawValue.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") ?? rawValue
        query[decodedName] = decodedValue
      }
    }

    return ReceivedRequest(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body
    )
  }

  private func write(_ response: Response, to clientFD: Int32) {
    var head = "HTTP/1.1 \(response.status) \(Self.reason(for: response.status))\r\n"
    var headers = response.headers
    headers["Content-Length"] = "\(response.body.count)"
    headers["Connection"] = "close"
    for (name, value) in headers {
      head += "\(name): \(value)\r\n"
    }
    head += "\r\n"

    var payload = Data(head.utf8)
    payload.append(response.body)
    payload.withUnsafeBytes { raw in
      var offset = 0
      while offset < raw.count {
        let written = send(clientFD, raw.baseAddress!.advanced(by: offset), raw.count - offset, 0)
        guard written > 0 else { return }
        offset += written
      }
    }
  }

  private static func reason(for status: Int) -> String {
    switch status {
    case 200: return "OK"
    case 302: return "Found"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 429: return "Too Many Requests"
    default: return "Error"
    }
  }
}

/// Errors raised while starting the fake server.
package enum OrcaRouterFakeServerError: Error, Sendable {
  case socketUnavailable
  case bindFailed
  case listenFailed
}
