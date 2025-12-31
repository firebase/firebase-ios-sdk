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

/// An object that represents a back-and-forth chat with a model, capturing the history and saving
/// the context in memory between each message sent.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class Chat: Sendable {
  private let model: GenerativeModel
  private let _history: History

  private static let maxFunctionCalls = 10

  private static var maxTurnsError: Error {
    GenerateContentError.internalError(underlying: NSError(
      domain: "FirebaseAI",
      code: -1,
      userInfo: [
        NSLocalizedDescriptionKey: "Max automatic function calling turns reached.",
      ]
    ))
  }

  init(model: GenerativeModel, history: [ModelContent]) {
    self.model = model
    _history = History(history: history)
  }

  /// The previous content from the chat that has been successfully sent and received from the
  /// model. This will be provided to the model for each message sent as context for the discussion.
  public var history: [ModelContent] {
    get {
      return _history.history
    }
    set {
      _history.history = newValue
    }
  }

  /// Sends a message using the existing history of this chat as context. If successful, the message
  /// and response will be added to the history. If unsuccessful, history will remain unchanged.
  /// - Parameter parts: The new content to send as a single chat message.
  /// - Returns: The model's response if no error occurred.
  /// - Throws: A ``GenerateContentError`` if an error occurred.
  public func sendMessage(_ parts: any PartsRepresentable...) async throws
    -> GenerateContentResponse {
    return try await sendMessage([ModelContent(parts: parts)])
  }

  /// Sends a message using the existing history of this chat as context. If successful, the message
  /// and response will be added to the history. If unsuccessful, history will remain unchanged.
  /// - Parameter content: The new content to send as a single chat message.
  /// - Returns: The model's response if no error occurred.
  /// - Throws: A ``GenerateContentError`` if an error occurred.
  public func sendMessage(_ content: [ModelContent]) async throws
    -> GenerateContentResponse {
    // Ensure that the new content has the role set.
    let newContent = content.map(populateContentRole(_:))

    var response: GenerateContentResponse
    var functionCallCount = 0
    var userContentCommitted = false

    while true {
      // Send the history as context.
      // If we haven't committed the user content yet, send it as part of the request
      // but don't add it to the official history until we get a successful response.
      let requestContent = userContentCommitted ? history : history + newContent
      response = try await model.generateContent(requestContent)

      guard let candidate = response.candidates.first else {
        let error = NSError(domain: "com.google.generative-ai",
                            code: -1,
                            userInfo: [
                              NSLocalizedDescriptionKey: "No candidates with content available.",
                            ])
        throw GenerateContentError.internalError(underlying: error)
      }

      // Commit user content if not yet done.
      if !userContentCommitted {
        _history.append(contentsOf: newContent)
        userContentCommitted = true
      }

      // Append model response
      let modelContent = ModelContent(role: "model", parts: candidate.content.parts)
      _history.append(modelContent)

      if let responseContent = try await executeFunctionCalls(from: modelContent) {
        _history.append(responseContent)
        functionCallCount += 1
        if functionCallCount >= Chat.maxFunctionCalls {
          throw Chat.maxTurnsError
        }
      } else {
        break
      }
    }
    return response
  }

  /// Sends a message using the existing history of this chat as context. If successful, the message
  /// and response will be added to the history. If unsuccessful, history will remain unchanged.
  /// - Parameter parts: The new content to send as a single chat message.
  /// - Returns: A stream containing the model's response or an error if an error occurred.
  @available(macOS 12.0, *)
  public func sendMessageStream(_ parts: any PartsRepresentable...) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    return try sendMessageStream([ModelContent(parts: parts)])
  }

  /// Sends a message using the existing history of this chat as context. If successful, the message
  /// and response will be added to the history. If unsuccessful, history will remain unchanged.
  /// - Parameter content: The new content to send as a single chat message.
  /// - Returns: A stream containing the model's response or an error if an error occurred.
  @available(macOS 12.0, *)
  public func sendMessageStream(_ content: [ModelContent]) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    // Ensure that the new content has the role set.
    let newContent: [ModelContent] = content.map(populateContentRole(_:))

    return AsyncThrowingStream { continuation in
      Task {
        var functionCallCount = 0
        var userContentCommitted = false

        do {
          while true {
            // If we haven't committed the user content yet, send it as part of the request
            // but don't add it to the official history until we get a successful response start.
            let requestContent = userContentCommitted ? history : history + newContent
            let stream = try model.generateContentStream(requestContent)
            var aggregatedContent: [ModelContent] = []

            for try await chunk in stream {
              // Capture any content that's streaming. This should be populated if there's no error.
              if let chunkContent = chunk.candidates.first?.content {
                aggregatedContent.append(chunkContent)
              }

              // Pass along the chunk.
              continuation.yield(chunk)
            }

            // Stream finished successfully.
            // Commit user content if not yet done.
            if !userContentCommitted {
              _history.append(contentsOf: newContent)
              userContentCommitted = true
            }

            // Aggregate the content to add it to the history.
            let aggregated = _history.aggregatedChunks(aggregatedContent)
            _history.append(aggregated)

            if let responseContent = try await self.executeFunctionCalls(from: aggregated) {
              _history.append(responseContent)
              functionCallCount += 1
              if functionCallCount >= Chat.maxFunctionCalls {
                throw Chat.maxTurnsError
              }
            } else {
              break
            }
          }
          continuation.finish()
        } catch {
          // Rethrow the error that the underlying stream threw. Don't add anything to history.
          continuation.finish(throwing: error)
          return
        }
      }
    }
  }

  /// Populates the `role` field with `user` if it doesn't exist. Required in chat sessions.
  private func populateContentRole(_ content: ModelContent) -> ModelContent {
    if content.role != nil {
      return content
    } else {
      return ModelContent(role: "user", parts: content.parts)
    }
  }

  private func executeFunctionCalls(from content: ModelContent) async throws -> ModelContent? {
    let functionCalls = content.parts.compactMap { ($0 as? FunctionCallPart)?.functionCall }

    if functionCalls.isEmpty {
      return nil
    }

    let handlers = model.functionHandlers
    if handlers.isEmpty {
      return nil
    }

    let callsToHandle = functionCalls.compactMap {
      call -> (FunctionCall, @Sendable ([String: JSONValue]) async throws -> JSONObject)? in
      if let handler = handlers[call.name] {
        return (call, handler)
      }
      return nil
    }

    if callsToHandle.isEmpty {
      return nil
    }

    let functionResponses = try await withThrowingTaskGroup(
      of: FunctionResponsePart.self,
      returning: [FunctionResponsePart].self
    ) { group in
      for (call, handler) in callsToHandle {
        group.addTask {
          let result = try await handler(call.args)
          return FunctionResponsePart(name: call.name, response: result)
        }
      }

      var responses: [FunctionResponsePart] = []
      responses.reserveCapacity(callsToHandle.count)
      for try await part in group {
        responses.append(part)
      }
      return responses
    }

    return ModelContent(role: "function", parts: functionResponses)
  }
}
