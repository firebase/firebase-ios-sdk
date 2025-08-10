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
public final class LiveSession: Sendable {
  let modelResourceName: String
  let generationConfig: LiveGenerationConfig?
  let webSocket: URLSessionWebSocketTask

  public let responses: AsyncThrowingStream<BidiGenerateContentServerMessage, Error>
  private let responseContinuation: AsyncThrowingStream<BidiGenerateContentServerMessage, Error>
    .Continuation

  private let jsonEncoder = JSONEncoder()
  private let jsonDecoder = JSONDecoder()

  init(modelResourceName: String,
       generationConfig: LiveGenerationConfig?,
       url: URL,
       urlSession: URLSession) {
    self.modelResourceName = modelResourceName
    self.generationConfig = generationConfig
    webSocket = urlSession.webSocketTask(with: url)
    (responses, responseContinuation) = AsyncThrowingStream.makeStream()
  }

  deinit {
    webSocket.cancel(with: .goingAway, reason: nil)
  }

  public func sendMessage(_ message: String) async throws {
    let content = ModelContent(role: "user", parts: [message])
    let clientContent = BidiGenerateContentClientContent(turns: [content], turnComplete: true)
    let clientMessage = BidiGenerateContentClientMessage.clientContent(clientContent)
    let clientMessageData = try jsonEncoder.encode(clientMessage)
    try await webSocket.send(.data(clientMessageData))
  }

  func openConnection() {
    webSocket.resume()
    // TODO: Verify that this task gets cancelled on deinit
    Task {
      await startEventLoop()
    }
  }

  private func startEventLoop() async {
    defer {
      webSocket.cancel(with: .goingAway, reason: nil)
    }

    do {
      try await sendSetupMessage()

      while !Task.isCancelled {
        let message = try await webSocket.receive()
        switch message {
        case let .string(string):
          print("Unexpected string response: \(string)")
        case let .data(data):
          let response = try jsonDecoder.decode(
            BidiGenerateContentServerMessage.self,
            from: data
          )
          responseContinuation.yield(response)
        @unknown default:
          print("Unknown message received")
        }
      }
    } catch {
      responseContinuation.finish(throwing: error)
    }
    responseContinuation.finish()
  }

  private func sendSetupMessage() async throws {
    let setup = BidiGenerateContentSetup(
      model: modelResourceName, generationConfig: generationConfig
    )
    let message = BidiGenerateContentClientMessage.setup(setup)
    let messageData = try jsonEncoder.encode(message)
    try await webSocket.send(.data(messageData))
  }
}
