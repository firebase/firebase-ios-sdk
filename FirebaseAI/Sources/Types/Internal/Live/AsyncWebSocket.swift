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
private import FirebaseCoreInternal

final class AsyncWebSocket: NSObject, @unchecked Sendable, URLSessionWebSocketDelegate {
  private let webSocketTask: URLSessionWebSocketTask
  private let stream: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
  private let continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation
  private var continuationFinished = false
  private let continuationLock = NSLock()
  private var closeError: UnfairLock<WebSocketClosedError?>

  init(urlSession: URLSession = GenAIURLSession.default, urlRequest: URLRequest) {
    webSocketTask = urlSession.webSocketTask(with: urlRequest)
    (stream, continuation) = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
      .makeStream()
    closeError = UnfairLock(nil)
  }

  deinit {
    disconnect()
  }

  func connect() -> AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> {
    webSocketTask.resume()
    closeError.withLock { $0 = nil }
    startReceiving()
    return stream
  }

  func disconnect() {
    if closeError.value() != nil { return }

    close(code: .goingAway, reason: nil)
  }

  func send(_ message: URLSessionWebSocketTask.Message) async throws {
    if let closeError = closeError.value() {
      throw closeError
    }
    try await webSocketTask.send(message)
  }

  private func startReceiving() {
    Task {
      while !Task.isCancelled && self.webSocketTask.isOpen && self.closeError.value() == nil {
        do {
          let message = try await webSocketTask.receive()
          continuation.yield(message)
        } catch {
          close(code: webSocketTask.closeCode, reason: webSocketTask.closeReason)
        }
      }
    }
  }

  private func close(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
    let error = WebSocketClosedError(closeCode: code, closeReason: reason)
    closeError.withLock {
      $0 = error
    }

    webSocketTask.cancel(with: code, reason: reason)

    continuationLock.withLock {
      guard !continuationFinished else { return }
      self.continuation.finish(throwing: error)
      self.continuationFinished = true
    }
  }

  func urlSession(_ session: URLSession,
                  webSocketTask: URLSessionWebSocketTask,
                  didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                  reason: Data?) {
    close(code: closeCode, reason: reason)
  }
}

private extension URLSessionWebSocketTask {
  var isOpen: Bool {
    return closeCode == .invalid
  }
}

struct WebSocketClosedError: Error, Sendable, CustomNSError {
  let closeCode: URLSessionWebSocketTask.CloseCode
  let closeReason: String

  init(closeCode: URLSessionWebSocketTask.CloseCode, closeReason: Data?) {
    self.closeCode = closeCode
    self.closeReason = closeReason
      .flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown reason."
  }

  var errorCode: Int { closeCode.rawValue }

  var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "WebSocket closed with code \(closeCode.rawValue). Reason: \(closeReason)",
    ]
  }
}
