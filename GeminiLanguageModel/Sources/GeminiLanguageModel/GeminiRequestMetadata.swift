// Copyright 2026 Google LLC
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

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels

  /// Metadata specifying Gemini-specific configuration options for generation requests.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiRequestMetadata: Sendable, Hashable, Equatable {
    /// The top-level metadata key used to store Gemini configuration in requests and prompt entries.
    public static let metadataKey = "gemini"

    /// Property key for the thinking summaries setting within `GeminiRequestMetadata`.
    private static let thinkingSummariesKey = "thinkingSummaries"

    /// The configuration mode for returning thought summaries from the model.
    public var thinkingSummaries: GeminiLanguageModel.Thinking.SummaryMode?

    /// Creates a new Gemini request metadata container.
    ///
    /// - Parameter thinkingSummaries: The mode for returning thought summaries. Defaults to `nil`.
    public init(
      thinkingSummaries: GeminiLanguageModel.Thinking.SummaryMode? = nil
    ) {
      self.thinkingSummaries = thinkingSummaries
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiRequestMetadata: ConvertibleToGeneratedContent {
    /// Converts this metadata into structured `GeneratedContent`.
    public var generatedContent: GeneratedContent {
      var properties: [String: GeneratedContent] = [:]
      var orderedKeys: [String] = []
      if let thinkingSummaries {
        properties[Self.thinkingSummariesKey] = GeneratedContent(thinkingSummaries.rawValue)
        orderedKeys.append(Self.thinkingSummariesKey)
      }
      return GeneratedContent(
        kind: .structure(properties: properties, orderedKeys: orderedKeys)
      )
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiRequestMetadata: ConvertibleFromGeneratedContent {
    /// Initializes this metadata from structured `GeneratedContent`.
    ///
    /// - Parameter content: The generated content to decode from.
    public init(_ content: GeneratedContent) {
      if case .structure(let properties, _) = content.kind {
        if let modeContent = properties[Self.thinkingSummariesKey] {
          if case .string(let rawValue) = modeContent.kind {
            self.thinkingSummaries = GeminiLanguageModel.Thinking.SummaryMode(rawValue: rawValue)
          } else if case .bool(let boolVal) = modeContent.kind {
            self.thinkingSummaries = boolVal ? .auto : .off
          } else {
            self.thinkingSummaries = nil
          }
        } else {
          self.thinkingSummaries = nil
        }
      } else if case .bool(let boolVal) = content.kind {
        self.thinkingSummaries = boolVal ? .auto : .off
      } else {
        self.thinkingSummaries = nil
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension Dictionary where Key == String, Value == any ConvertibleToGeneratedContent {
    /// Creates a metadata dictionary containing the specified Gemini request metadata.
    ///
    /// - Parameter thinkingSummaries: The configuration mode for returning thought summaries.
    /// - Returns: A metadata dictionary suitable for passing to `session.respond` or `session.streamResponse`.
    public static func gemini(
      thinkingSummaries: GeminiLanguageModel.Thinking.SummaryMode? = nil
    ) -> [String: any ConvertibleToGeneratedContent] {
      var dict: [String: any ConvertibleToGeneratedContent] = [:]
      dict[GeminiRequestMetadata.metadataKey] = GeminiRequestMetadata(
        thinkingSummaries: thinkingSummaries
      )
      return dict
    }

    /// Creates a metadata dictionary containing the given `GeminiRequestMetadata`.
    ///
    /// - Parameter metadata: The Gemini request metadata container.
    /// - Returns: A metadata dictionary suitable for passing to `session.respond` or `session.streamResponse`.
    public static func gemini(
      _ metadata: GeminiRequestMetadata
    ) -> [String: any ConvertibleToGeneratedContent] {
      [GeminiRequestMetadata.metadataKey: metadata]
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
