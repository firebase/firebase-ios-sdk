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

// TODO: Extract most of this file into a service class similar to `GenerativeAIService`.
public final class LiveSession: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
  private enum State {
    case notConnected
    case connecting
    case setupSent
    case ready
    case closed
  }

  private enum WebSocketError: Error {
    case connectionClosed
  }

  let modelResourceName: String
  let generationConfig: LiveGenerationConfig?
  let webSocket: URLSessionWebSocketTask

  // TODO: Refactor this property, potentially returning responses after `connect`.
  public let responses: AsyncThrowingStream<BidiGenerateContentServerMessage, Error>

  private var state: State = .notConnected
  private var pendingMessages: [(String, CheckedContinuation<Void, Error>)] = []
  private let jsonEncoder = JSONEncoder()
  private let jsonDecoder = JSONDecoder()

  // TODO: Properly wrap callback code using `withCheckedContinuation` or similar.
  private let responseContinuation: AsyncThrowingStream<BidiGenerateContentServerMessage, Error>
    .Continuation

  init(modelResourceName: String,
       generationConfig: LiveGenerationConfig?,
       url: URL,
       urlSession: URLSession) {
    self.modelResourceName = modelResourceName
    self.generationConfig = generationConfig
    webSocket = urlSession.webSocketTask(with: url)
    (responses, responseContinuation) = AsyncThrowingStream.makeStream()
  }

  func open() async throws {
    guard state == .notConnected else {
      print("Web socket is not in a valid state to be opened: \(state)")
      return
    }

    state = .connecting
    webSocket.delegate = self
    webSocket.resume()

    print("Opening websocket")
  }

  private func failPendingMessages(with error: Error) {
    for (_, continuation) in pendingMessages {
      continuation.resume(throwing: error)
    }
    pendingMessages.removeAll()
    responseContinuation.finish(throwing: error)
  }

  private func processPendingMessages() {
    for (message, continuation) in pendingMessages {
      Task {
        do {
          try await send(message)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
    pendingMessages.removeAll()
  }

  private func send(_ message: String) async throws {
    let content = ModelContent(role: "user", parts: [message])
    let clientContent = BidiGenerateContentClientContent(turns: [content], turnComplete: true)
    let clientMessage = BidiGenerateContentClientMessage.clientContent(clientContent)
    let clientMessageData = try jsonEncoder.encode(clientMessage)
    let clientMessageJSON = String(data: clientMessageData, encoding: .utf8)
    print("Client Message JSON: \(clientMessageJSON)")
    try await webSocket.send(.data(clientMessageData))
    setReceiveHandler()
  }

  public func sendMessage(_ message: String) async throws {
    if state == .ready {
      try await send(message)
    } else {
      try await withCheckedThrowingContinuation { continuation in
        pendingMessages.append((message, continuation))
      }
    }
  }

  public func urlSession(_ session: URLSession,
                         webSocketTask: URLSessionWebSocketTask,
                         didOpenWithProtocol protocol: String?) {
    print("Web Socket opened.")

    guard state == .connecting else {
      print("Web socket is not in a valid state to be opened: \(state)")
      return
    }

    do {
      let setup = BidiGenerateContentSetup(
        model: modelResourceName, generationConfig: generationConfig
      )
      let message = BidiGenerateContentClientMessage.setup(setup)
      let messageData = try jsonEncoder.encode(message)
      let messageJSON = String(data: messageData, encoding: .utf8)
      print("JSON: \(messageJSON)")
      webSocketTask.send(.data(messageData)) { error in
        if let error {
          print("Send Error: \(error)")
          self.state = .closed
          self.failPendingMessages(with: error)
          return
        }

        self.state = .setupSent
        self.setReceiveHandler()
      }
    } catch {
      print(error)
      state = .closed
      failPendingMessages(with: error)
    }
  }

  public func urlSession(_ session: URLSession,
                         webSocketTask: URLSessionWebSocketTask,
                         didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                         reason: Data?) {
    print("Web Socket closed.")
    state = .closed
    failPendingMessages(with: WebSocketError.connectionClosed)
    responseContinuation.finish()
  }

  func setReceiveHandler() {
    guard state == .setupSent || state == .ready else {
      print("Web socket is not in a valid state to receive messages: \(state)")
      return
    }

    webSocket.receive { result in
      do {
        let message = try result.get()
        switch message {
        case let .string(string):
          print("Unexpected string response: \(string)")
          self.setReceiveHandler()
        case let .data(data):
          let response = try self.jsonDecoder.decode(
            BidiGenerateContentServerMessage.self,
            from: data
          )
          let responseJSON = String(data: data, encoding: .utf8)

          switch response.messageType {
          case .setupComplete:
            print("Setup Complete: \(responseJSON)")
            self.state = .ready
            self.processPendingMessages()
          case .serverContent:
            print("Server Content: \(responseJSON)")
          case .toolCall:
            // TODO: Tool calls not yet implemented
            print("Tool Call: \(responseJSON)")
          case .toolCallCancellation:
            // TODO: Tool call cancellation not yet implemented
            print("Tool Call Cancellation: \(responseJSON)")
          case let .goAway(goAway):
            if let timeLeft = goAway.timeLeft {
              print("Server will disconnect in \(timeLeft) seconds.")
            } else {
              print("Server will disconnect soon.")
            }
          }

          self.responseContinuation.yield(response)

          if self.state == .closed {
            print("Web socket is closed, not listening for more messages.")
          } else {
            self.setReceiveHandler()
          }
        @unknown default:
          print("Unknown message received")
          self.setReceiveHandler()
        }
      } catch {
        // handle the error
        print(error)
        self.state = .closed
        self.responseContinuation.finish(throwing: error)
      }
    }
  }
}
