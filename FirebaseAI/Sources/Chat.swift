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

  /// Initializes a new chat representing a 1:1 conversation between model and user.
  init(model: GenerativeModel, history: [ModelContent]) {
    self.model = model
    self.history = history
  }

  private let historyLock = NSLock()
  private nonisolated(unsafe) var _history: [ModelContent] = []
  /// The previous content from the chat that has been successfully sent and received from the
  /// model. This will be provided to the model for each message sent as context for the discussion.
  public var history: [ModelContent] {
    get {
      historyLock.withLock { _history }
    }
    set {
      historyLock.withLock { _history = newValue }
    }
  }

  private func appendHistory(contentsOf: [ModelContent]) {
    historyLock.withLock {
      _history.append(contentsOf: contentsOf)
    }
  }

  private func appendHistory(_ newElement: ModelContent) {
    historyLock.withLock {
      _history.append(newElement)
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

    // Send the history alongside the new message as context.
    let request = history + newContent
    let result = try await model.generateContent(request)
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
    appendHistory(contentsOf: newContent)
    appendHistory(toAdd)
    return result
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
        appendHistory(contentsOf: newContent)

        // Aggregate the content to add it to the history before we finish.
        let aggregated = self.aggregatedChunks(aggregatedContent)
        self.appendHistory(aggregated)
        continuation.finish()
      }
    }
  }

  private func aggregatedChunks(_ chunks: [ModelContent]) -> ModelContent {
    var parts: [InternalPart] = []
    var combinedText = ""
    var combinedThoughts = ""

    func flush() {
      if !combinedThoughts.isEmpty {
        parts.append(InternalPart(.text(combinedThoughts), isThought: true, thoughtSignature: nil))
        combinedThoughts = ""
      }
      if !combinedText.isEmpty {
        parts.append(InternalPart(.text(combinedText), isThought: nil, thoughtSignature: nil))
        combinedText = ""
      }
    }

    // Loop through all the parts, aggregating the text.
    for part in chunks.flatMap({ $0.internalParts }) {
      // Only text parts may be combined.
      if case let .text(text) = part.data, part.thoughtSignature == nil {
        // Thought summaries must not be combined with regular text.
        if part.isThought ?? false {
          // If we were combining regular text, flush it before handling "thoughts".
          if !combinedText.isEmpty {
            flush()
          }
          combinedThoughts += text
        } else {
          // If we were combining "thoughts", flush it before handling regular text.
          if !combinedThoughts.isEmpty {
            flush()
          }
          combinedText += text
        }
      } else {
        // This is a non-combinable part (not text), flush any pending text.
        flush()
        parts.append(part)
      }
    }

    // Flush any remaining text.
    flush()

    return ModelContent(role: "model", parts: parts)
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
