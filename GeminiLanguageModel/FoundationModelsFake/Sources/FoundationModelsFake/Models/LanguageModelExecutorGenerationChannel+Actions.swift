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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  #if canImport(UniformTypeIdentifiers)
    #if compiler(>=6.4.2)
      public import UniformTypeIdentifiers
    #else
      import UniformTypeIdentifiers
    #endif
  #endif

  extension LanguageModelExecutorGenerationChannel.Response.Action {
    /// Creates an action that appends text to a response entry.
    ///
    /// - Parameters:
    ///   - text: The text string to append.
    ///   - segmentID: The identifier of the segment to append to, or `nil` for default placement.
    ///   - tokenCount: The number of tokens in `text`.
    /// - Returns: A response action.
    public static func appendText(
      _ text: String,
      segmentID: String? = nil,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(kind: .appendText(.init(content: text, segmentID: segmentID, tokenCount: tokenCount)))
    }

    /// Creates an action that replaces the text in a response entry segment.
    ///
    /// - Parameters:
    ///   - text: The replacement text string.
    ///   - segmentID: The identifier of the segment to replace, or `nil` for default placement.
    ///   - tokenCount: The number of tokens in `text`.
    /// - Returns: A response action.
    public static func replaceTextSegment(
      _ text: String,
      segmentID: String? = nil,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(
        kind: .replaceTextSegment(
          .init(content: text, segmentID: segmentID, tokenCount: tokenCount)))
    }

    /// Creates an action that appends an attachment segment to a response entry.
    ///
    /// - Parameter segment: The attachment segment to add.
    /// - Returns: A response action.
    public static func addAttachmentSegment(
      _ segment: Transcript.AttachmentSegment
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(kind: .addAttachmentSegment(segment))
    }

    /// Creates an action that removes attachment segments matching an identifier.
    ///
    /// - Parameter id: The identifier of the attachment segments to remove.
    /// - Returns: A response action.
    public static func removeAttachmentSegment(
      id: String
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(kind: .removeAttachmentSegment(id: id))
    }

    /// Creates an action that updates the metadata of a response entry.
    ///
    /// - Parameter values: The metadata key-value pairs to set.
    /// - Returns: A response action.
    public static func updateMetadata(
      _ values: [String: any ConvertibleToGeneratedContent]
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(kind: .updateMetadata(.init(values: values.mapValues(\.generatedContent))))
    }

    /// Creates an action that updates the token usage totals for the turn.
    ///
    /// - Parameters:
    ///   - input: The input token counts.
    ///   - output: The output token counts.
    ///   - metadata: Additional metadata associated with token usage.
    /// - Returns: A response action.
    public static func updateUsage(
      input: LanguageModelExecutorGenerationChannel.Usage.Input,
      output: LanguageModelExecutorGenerationChannel.Usage.Output,
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> LanguageModelExecutorGenerationChannel.Response.Action {
      .init(kind: .updateUsage(.init(input: input, output: output, metadata: metadata)))
    }
  }

  extension LanguageModelExecutorGenerationChannel.ToolCalls.Action {
    /// Creates an action that updates an individual tool call.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the tool call.
    ///   - name: The name of the tool.
    ///   - action: The action to perform on the tool call.
    /// - Returns: A tool-calls action.
    public static func toolCall(
      id: String,
      name: String,
      action: LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.Action {
      .init(kind: .toolCall(.init(id: id, name: name, action: action)))
    }

    /// Creates an action that removes a tool call matching an identifier.
    ///
    /// - Parameter id: The identifier of the tool call to remove.
    /// - Returns: A tool-calls action.
    public static func removeToolCall(
      id: String
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.Action {
      .init(kind: .removeToolCall(id: id))
    }

    /// Creates an action that updates the metadata of a tool-calls entry.
    ///
    /// - Parameter values: The metadata key-value pairs to set.
    /// - Returns: A tool-calls action.
    public static func updateMetadata(
      _ values: [String: any ConvertibleToGeneratedContent]
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.Action {
      .init(kind: .updateMetadata(.init(values: values.mapValues(\.generatedContent))))
    }

    /// Creates an action that updates the token usage totals for the turn.
    ///
    /// - Parameters:
    ///   - input: The input token counts.
    ///   - output: The output token counts.
    ///   - metadata: Additional metadata associated with token usage.
    /// - Returns: A tool-calls action.
    public static func updateUsage(
      input: LanguageModelExecutorGenerationChannel.Usage.Input,
      output: LanguageModelExecutorGenerationChannel.Usage.Output,
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.Action {
      .init(kind: .updateUsage(.init(input: input, output: output, metadata: metadata)))
    }
  }

  extension LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action {
    /// Creates an action that appends serialized arguments to a tool call.
    ///
    /// - Parameters:
    ///   - content: The argument string fragment to append.
    ///   - tokenCount: The number of tokens in `content`.
    /// - Returns: A tool call action.
    public static func appendArguments(
      _ content: String,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action {
      .init(kind: .appendArguments(.init(content: content, tokenCount: tokenCount)))
    }

    /// Creates an action that updates the metadata of a tool call.
    ///
    /// - Parameter values: The metadata key-value pairs to set.
    /// - Returns: A tool call action.
    public static func updateMetadata(
      _ values: [String: any ConvertibleToGeneratedContent]
    ) -> LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action {
      .init(kind: .updateMetadata(.init(values: values.mapValues(\.generatedContent))))
    }
  }

  extension LanguageModelExecutorGenerationChannel.Reasoning.Action {
    /// Creates an action that appends text to a reasoning entry.
    ///
    /// - Parameters:
    ///   - text: The text string to append.
    ///   - segmentID: The identifier of the segment to append to, or `nil` for default placement.
    ///   - tokenCount: The number of tokens in `text`.
    /// - Returns: A reasoning action.
    public static func appendText(
      _ text: String,
      segmentID: String? = nil,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.Reasoning.Action {
      .init(kind: .appendText(.init(content: text, segmentID: segmentID, tokenCount: tokenCount)))
    }

    /// Creates an action that replaces the text in a reasoning entry segment.
    ///
    /// - Parameters:
    ///   - text: The replacement text string.
    ///   - segmentID: The identifier of the segment to replace, or `nil` for default placement.
    ///   - tokenCount: The number of tokens in `text`.
    /// - Returns: A reasoning action.
    public static func replaceTextSegment(
      _ text: String,
      segmentID: String? = nil,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.Reasoning.Action {
      .init(
        kind: .replaceTextSegment(
          .init(content: text, segmentID: segmentID, tokenCount: tokenCount)))
    }

    /// Creates an action that updates the signature of a reasoning entry.
    ///
    /// - Parameters:
    ///   - signature: The raw bytes of the reasoning signature.
    ///   - tokenCount: The number of tokens consumed by `signature`.
    /// - Returns: A reasoning action.
    public static func updateSignature(
      _ signature: Data,
      tokenCount: Int
    ) -> LanguageModelExecutorGenerationChannel.Reasoning.Action {
      .init(kind: .updateSignature(.init(signature: signature, tokenCount: tokenCount)))
    }

    /// Creates an action that updates the metadata of a reasoning entry.
    ///
    /// - Parameter values: The metadata key-value pairs to set.
    /// - Returns: A reasoning action.
    public static func updateMetadata(
      _ values: [String: any ConvertibleToGeneratedContent]
    ) -> LanguageModelExecutorGenerationChannel.Reasoning.Action {
      .init(kind: .updateMetadata(.init(values: values.mapValues(\.generatedContent))))
    }

    /// Creates an action that updates the token usage totals for the turn.
    ///
    /// - Parameters:
    ///   - input: The input token counts.
    ///   - output: The output token counts.
    ///   - metadata: Additional metadata associated with token usage.
    /// - Returns: A reasoning action.
    public static func updateUsage(
      input: LanguageModelExecutorGenerationChannel.Usage.Input,
      output: LanguageModelExecutorGenerationChannel.Usage.Output,
      metadata: [String: any ConvertibleToGeneratedContent] = [:]
    ) -> LanguageModelExecutorGenerationChannel.Reasoning.Action {
      .init(kind: .updateUsage(.init(input: input, output: output, metadata: metadata)))
    }
  }

  #if compiler(>=6.4.2)
    extension LanguageModelExecutorGenerationChannel.DataEntry.Action {
      /// Creates an action that updates the content and metadata of a data entry.
      ///
      /// - Parameters:
      ///   - contentType: The uniform type identifier of `content`.
      ///   - content: The raw binary data content.
      ///   - metadata: The metadata associated with the data entry.
      /// - Returns: A data entry action.
      public static func update(
        contentType: UTType,
        content: Data,
        metadata: GeneratedContent = GeneratedContent(properties: [:])
      ) -> LanguageModelExecutorGenerationChannel.DataEntry.Action {
        .init(kind: .update(.init(contentType: contentType, content: content, metadata: metadata)))
      }
    }
  #endif  // compiler(>=6.4.2)
#endif  // compiler(>=6.4)
