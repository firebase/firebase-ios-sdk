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

/// A chat session that allows for conversation with a model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class TemplateChatSession: Sendable {
  private let model: TemplateGenerativeModel
  private let template: String
  private let _history: History

  init(model: TemplateGenerativeModel, template: String, history: [ModelContent]) {
    self.model = model
    self.template = template
    _history = History(history: history)
  }

  public var history: [ModelContent] {
    get {
      return _history.history
    }
    set {
      _history.history = newValue
    }
  }

  /// Sends a message to the model and returns the response.
  public func sendMessage(_ message: any PartsRepresentable,
                          inputs: [String: Any],
                          options: RequestOptions = RequestOptions()) async throws
    -> GenerateContentResponse {
    let templateInputs = try inputs.mapValues { try TemplateInput(value: $0) }
    let newContent = populateContentRole(ModelContent(parts: message.partsValue))
    let response = try await model.generateContentWithHistory(
      history: _history.history + [newContent],
      template: template,
      inputs: templateInputs,
      options: options
    )
    _history.append(newContent)
    if let modelResponse = response.candidates.first {
      _history.append(modelResponse.content)
    }
    return response
  }

  public func sendMessageStream(_ message: any PartsRepresentable,
                                inputs: [String: Any],
                                options: RequestOptions = RequestOptions()) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    let templateInputs = try inputs.mapValues { try TemplateInput(value: $0) }
    let newContent = populateContentRole(ModelContent(parts: message.partsValue))
    let stream = try model.generateContentStreamWithHistory(
      history: _history.history + [newContent],
      template: template,
      inputs: templateInputs,
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
        _history.append(newContent)

        // Aggregate the content to add it to the history before we finish.
        let aggregated = _history.aggregatedChunks(aggregatedContent)
        _history.append(aggregated)
        continuation.finish()
      }
    }
  }

  private func populateContentRole(_ content: ModelContent) -> ModelContent {
    if content.role != nil {
      return content
    } else {
      return ModelContent(role: "user", parts: content.parts)
    }
  }
}
