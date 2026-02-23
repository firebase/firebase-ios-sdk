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

  var generationConfig: GenerationConfig? { model.generationConfig }

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
  public func sendMessage(_ content: [ModelContent]) async throws -> GenerateContentResponse {
      return try await sendMessage(content, generationConfig: model.generationConfig)
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

    // Send the history alongside the new message as context.
    let request = history + newContent
    let stream = try model.generateContentStream(request)
    return AsyncThrowingStream { continuation in
      Task {
        var aggregatedContent: [ModelContent] = []

        do {
          for try await chunk in stream {
            // Capture any content that's streaming. This should be populated if there's no error.
            if let chunkContent = chunk.candidates.first?.content {
              aggregatedContent.append(chunkContent)
            }

            // Pass along the chunk.
            continuation.yield(chunk)
          }
        } catch {
          // Rethrow the error that the underlying stream threw. Don't add anything to history.
          continuation.finish(throwing: error)
          return
        }

        // Save the request.
        _history.append(contentsOf: newContent)

        // Aggregate the content to add it to the history before we finish.
        let aggregated = self._history.aggregatedChunks(aggregatedContent)
        self._history.append(aggregated)
        continuation.finish()
      }
    }
  }

  // MARK: - Internal

  func sendMessage(_ content: [ModelContent],
                   generationConfig: GenerationConfig?) async throws -> GenerateContentResponse {
    // Ensure that the new content has the role set.
    let newContent = content.map(populateContentRole(_:))

    // Send the history alongside the new message as context.
    let request = history + newContent
    let result = try await model.generateContent(request, generationConfig: generationConfig)
    guard let reply = result.candidates.first?.content else {
      let error = NSError(domain: "com.google.generative-ai",
                          code: -1,
                          userInfo: [
                            NSLocalizedDescriptionKey: "No candidates with content available.",
                          ])
      throw GenerateContentError.internalError(underlying: error)
    }

    // Make sure we inject the role into the content received.
    let toAdd = ModelContent(role: "model", parts: reply.parts)

    // Append the request and successful result to history, then return the value.
    _history.append(contentsOf: newContent)
    _history.append(toAdd)
    return result
  }

  /// Populates the `role` field with `user` if it doesn't exist. Required in chat sessions.
  private func populateContentRole(_ content: ModelContent) -> ModelContent {
    if content.role != nil {
      return content
    } else {
      return ModelContent(role: "user", parts: content.parts)
    }
  }
}
