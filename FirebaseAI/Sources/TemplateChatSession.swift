// Copyright 2024 Google LLC
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

/// A chat session that allows for conversation with a model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class TemplateChatSession: Sendable {
  private let model: TemplateGenerativeModel
  private let template: String

  private let historyLock = NSLock()
  private nonisolated(unsafe) var _history: [ModelContent] = []
  public var history: [ModelContent] {
    get {
      historyLock.withLock { _history }
    }
    set {
      historyLock.withLock { _history = newValue }
    }
  }

  init(model: TemplateGenerativeModel, template: String, history: [ModelContent]) {
    self.model = model
    self.template = template
    self.history = history
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

  /// Sends a message to the model and returns the response.
  public func sendMessage(_ message: any PartsRepresentable,
                          variables: [String: Any],
                          options: RequestOptions = RequestOptions()) async throws
    -> GenerateContentResponse {
    let templateVariables = try variables.mapValues { try TemplateVariable(value: $0) }
    let response = try await model.generateContentWithHistory(
      history: history,
      template: template,
      variables: templateVariables,
      options: options
    )
    appendHistory(ModelContent(role: "user", parts: message.partsValue))
    if let modelResponse = response.candidates.first {
      appendHistory(modelResponse.content)
    }
    return response
  }

  public func sendMessageStream(_ message: any PartsRepresentable,
                                variables: [String: Any],
                                options: RequestOptions = RequestOptions()) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    let templateVariables = try variables.mapValues { try TemplateVariable(value: $0) }
    let newContent = [ModelContent(role: "user", parts: message.partsValue)]
    let stream = try model.generateContentStreamWithHistory(
      history: history,
      template: template,
      variables: templateVariables,
      options: options
    )
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
        let aggregated = aggregatedChunks(aggregatedContent)
        appendHistory(aggregated)
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
}
