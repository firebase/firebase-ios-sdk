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

/// Async API for interacting with web sockets.
///
/// Internally, this just wraps around a `URLSessionWebSocketTask`, and provides a more async
/// friendly interface for sending and consuming data from it.
///
/// Also surfaces a more fine-grained ``WebSocketClosedError`` for when the web socket is closed.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
final class AsyncWebSocket: Sendable {
  private let webSocketTask: URLSessionWebSocketTask
  private let stream: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
  private let continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation
  private let continuationFinished = UnfairLock<Bool>(false)
  private let closeError: UnfairLock<WebSocketClosedError?>

  init(urlSession: URLSession = GenAIURLSession.default, urlRequest: URLRequest) {
    webSocketTask = urlSession.webSocketTask(with: urlRequest)
    (stream, continuation) = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>
      .makeStream()
    closeError = UnfairLock(nil)
  }

  deinit {
    disconnect()
  }

  /// Starts a connection to the backend, returning a stream for the websocket responses.
  func connect() -> AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> {
    webSocketTask.resume()
    closeError.withLock { $0 = nil }
    startReceiving()
    return stream
  }

  /// Closes the websocket, if it's not already closed.
  func disconnect() {
    guard closeError.value() == nil else { return }

    close(code: .goingAway, reason: nil)
  }

  /// Sends a message to the server, through the websocket.
  ///
  /// If the web socket is closed, this method will throw the error it was closed with.
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
          if let error = webSocketTask.error as? NSError {
            close(
              code: webSocketTask.closeCode,
              reason: webSocketTask.closeReason,
              underlyingError: error
            )
          } else {
            close(code: webSocketTask.closeCode, reason: webSocketTask.closeReason)
          }
        }
      }
    }
  }

  private func close(code: URLSessionWebSocketTask.CloseCode,
                     reason: Data?,
                     underlyingError: Error? = nil) {
    let error = WebSocketClosedError(
      closeCode: code,
      closeReason: reason,
      underlyingError: underlyingError
    )
    closeError.withLock {
      $0 = error
    }

    webSocketTask.cancel(with: code, reason: reason)

    continuationFinished.withLock { isFinished in
      guard !isFinished else { return }
      self.continuation.finish(throwing: error)
      isFinished = true
    }
  }
}

private extension URLSessionWebSocketTask {
  var isOpen: Bool {
    return closeCode == .invalid
  }
}

/// The websocket was closed.
///
/// See the `closeReason` for why, or the `errorCode` for the corresponding
/// `URLSessionWebSocketTask.CloseCode`.
///
/// In some cases, the `NSUnderlyingErrorKey` key may be populated with an
/// error for additional context.
struct WebSocketClosedError: Error, Sendable, CustomNSError {
  let closeCode: URLSessionWebSocketTask.CloseCode
  let closeReason: String
  let underlyingError: Error?

  init(closeCode: URLSessionWebSocketTask.CloseCode, closeReason: Data?,
       underlyingError: Error? = nil) {
    self.closeCode = closeCode
    self.closeReason = closeReason
      .flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown reason."
    self.underlyingError = underlyingError
  }

  var errorCode: Int { closeCode.rawValue }

  var errorUserInfo: [String: Any] {
    var userInfo: [String: Any] = [
      NSLocalizedDescriptionKey: "WebSocket closed with code \(closeCode.rawValue). Reason: \(closeReason)",
    ]
    if let underlyingError {
      userInfo[NSUnderlyingErrorKey] = underlyingError
    }
    return userInfo
  }
}
