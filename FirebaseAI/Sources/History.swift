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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class History: Sendable {
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

  init(history: [ModelContent]) {
    self.history = history
  }

  func append(contentsOf: [ModelContent]) {
    historyLock.withLock {
      _history.append(contentsOf: contentsOf)
    }
  }

  func append(_ newElement: ModelContent) {
    historyLock.withLock {
      _history.append(newElement)
    }
  }

  func aggregatedChunks(_ chunks: [ModelContent]) -> ModelContent {
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
