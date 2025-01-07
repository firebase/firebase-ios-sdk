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

import FirebaseVertexAI
import Foundation
import UIKit

@MainActor
class FunctionCallingViewModel: ObservableObject {
  /// This array holds both the user's and the system's chat messages
  @Published var messages = [ChatMessage]()

  /// Indicates we're waiting for the model to finish
  @Published var busy = false

  @Published var error: Error?
  var hasError: Bool {
    return error != nil
  }

  /// Function calls pending processing
  private var functionCalls = [FunctionCallPart]()

  private var model: GenerativeModel
  private var chat: Chat

  private var chatTask: Task<Void, Never>?

  init() {
    model = VertexAI.vertexAI().generativeModel(
      modelName: "gemini-1.5-flash",
      tools: [.functionDeclarations([
        FunctionDeclaration(
          name: "get_exchange_rate",
          description: "Get the exchange rate for currencies between countries",
          parameters: [
            "currency_from": .enumeration(
              values: ["USD", "EUR", "JPY", "GBP", "AUD", "CAD"],
              description: "The currency to convert from in ISO 4217 format"
            ),
            "currency_to": .enumeration(
              values: ["USD", "EUR", "JPY", "GBP", "AUD", "CAD"],
              description: "The currency to convert to in ISO 4217 format"
            ),
          ]
        ),
      ])]
    )
    chat = model.startChat()
  }

  func sendMessage(_ text: String, streaming: Bool = true) async {
    error = nil
    chatTask?.cancel()

    chatTask = Task {
      busy = true
      defer {
        busy = false
      }

      // first, add the user's message to the chat
      let userMessage = ChatMessage(message: text, participant: .user)
      messages.append(userMessage)

      // add a pending message while we're waiting for a response from the backend
      let systemMessage = ChatMessage.pending(participant: .system)
      messages.append(systemMessage)

      print(messages)
      do {
        repeat {
          if streaming {
            try await internalSendMessageStreaming(text)
          } else {
            try await internalSendMessage(text)
          }
        } while !functionCalls.isEmpty
      } catch {
        self.error = error
        print(error.localizedDescription)
        messages.removeLast()
      }
    }
  }

  func startNewChat() {
    stop()
    error = nil
    chat = model.startChat()
    messages.removeAll()
  }

  func stop() {
    chatTask?.cancel()
    error = nil
  }

  private func internalSendMessageStreaming(_ text: String) async throws {
    let functionResponses = try await processFunctionCalls()
    let responseStream: AsyncThrowingStream<GenerateContentResponse, Error>
    if functionResponses.isEmpty {
      responseStream = try chat.sendMessageStream(text)
    } else {
      for functionResponse in functionResponses {
        messages.insert(functionResponse.chatMessage(), at: messages.count - 1)
      }
      responseStream = try chat.sendMessageStream([functionResponses.modelContent()])
    }
    for try await chunk in responseStream {
      processResponseContent(content: chunk)
    }
  }

  private func internalSendMessage(_ text: String) async throws {
    let functionResponses = try await processFunctionCalls()
    let response: GenerateContentResponse
    if functionResponses.isEmpty {
      response = try await chat.sendMessage(text)
    } else {
      for functionResponse in functionResponses {
        messages.insert(functionResponse.chatMessage(), at: messages.count - 1)
      }
      response = try await chat.sendMessage([functionResponses.modelContent()])
    }
    processResponseContent(content: response)
  }

  func processResponseContent(content: GenerateContentResponse) {
    guard let candidate = content.candidates.first else {
      fatalError("No candidate.")
    }

    for part in candidate.content.parts {
      switch part {
      case let textPart as TextPart:
        // replace pending message with backend response
        messages[messages.count - 1].message += textPart.text
        messages[messages.count - 1].pending = false
      case let functionCallPart as FunctionCallPart:
        messages.insert(functionCallPart.chatMessage(), at: messages.count - 1)
        functionCalls.append(functionCallPart)
      default:
        fatalError("Unsupported response part: \(part)")
      }
    }
  }

  func processFunctionCalls() async throws -> [FunctionResponsePart] {
    var functionResponses = [FunctionResponsePart]()
    for functionCall in functionCalls {
      switch functionCall.name {
      case "get_exchange_rate":
        let exchangeRates = getExchangeRate(args: functionCall.args)
        functionResponses.append(FunctionResponsePart(
          name: "get_exchange_rate",
          response: exchangeRates
        ))
      default:
        fatalError("Unknown function named \"\(functionCall.name)\".")
      }
    }
    functionCalls = []

    return functionResponses
  }

  // MARK: - Callable Functions

  func getExchangeRate(args: JSONObject) -> JSONObject {
    // 1. Validate and extract the parameters provided by the model (from a `FunctionCall`)
    guard case let .string(from) = args["currency_from"] else {
      fatalError("Missing `currency_from` parameter.")
    }
    guard case let .string(to) = args["currency_to"] else {
      fatalError("Missing `currency_to` parameter.")
    }

    // 2. Get the exchange rate
    let allRates: [String: [String: Double]] = [
      "AUD": ["CAD": 0.89265, "EUR": 0.6072, "GBP": 0.51714, "JPY": 97.75, "USD": 0.66379],
      "CAD": ["AUD": 1.1203, "EUR": 0.68023, "GBP": 0.57933, "JPY": 109.51, "USD": 0.74362],
      "EUR": ["AUD": 1.6469, "CAD": 1.4701, "GBP": 0.85168, "JPY": 160.99, "USD": 1.0932],
      "GBP": ["AUD": 1.9337, "CAD": 1.7261, "EUR": 1.1741, "JPY": 189.03, "USD": 1.2836],
      "JPY": ["AUD": 0.01023, "CAD": 0.00913, "EUR": 0.00621, "GBP": 0.00529, "USD": 0.00679],
      "USD": ["AUD": 1.5065, "CAD": 1.3448, "EUR": 0.91475, "GBP": 0.77907, "JPY": 147.26],
    ]
    guard let fromRates = allRates[from] else {
      return ["error": .string("No data for currency \(from).")]
    }
    guard let toRate = fromRates[to] else {
      return ["error": .string("No data for currency \(to).")]
    }

    // 3. Return the exchange rates as a JSON object (returned to the model in a `FunctionResponse`)
    return ["rates": .number(toRate)]
  }
}

private extension FunctionCallPart {
  func chatMessage() -> ChatMessage {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let jsonData: Data
    do {
      jsonData = try encoder.encode(self)
    } catch {
      fatalError("JSON Encoding Failed: \(error.localizedDescription)")
    }
    guard let json = String(data: jsonData, encoding: .utf8) else {
      fatalError("Failed to convert JSON data to a String.")
    }
    let messageText = "Function call requested by model:\n```\n\(json)\n```"

    return ChatMessage(message: messageText, participant: .system)
  }
}

private extension FunctionResponsePart {
  func chatMessage() -> ChatMessage {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let jsonData: Data
    do {
      jsonData = try encoder.encode(self)
    } catch {
      fatalError("JSON Encoding Failed: \(error.localizedDescription)")
    }
    guard let json = String(data: jsonData, encoding: .utf8) else {
      fatalError("Failed to convert JSON data to a String.")
    }
    let messageText = "Function response returned by app:\n```\n\(json)\n```"

    return ChatMessage(message: messageText, participant: .user)
  }
}

private extension [FunctionResponsePart] {
  func modelContent() -> ModelContent {
    return ModelContent(role: "function", parts: self)
  }
}
