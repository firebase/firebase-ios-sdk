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
    import FoundationEssentials
  #else
    import Foundation
  #endif

  extension Transcript {
    /// A content segment within a transcript entry.
    ///
    /// - SeeAlso: [`Transcript.Segment`](https://developer.apple.com/documentation/foundationmodels/transcript/segment)
    @nonexhaustive
    public enum Segment: Sendable, Identifiable, Equatable {
      /// A plain-text segment.
      case text(Transcript.TextSegment)

      /// A structured data segment matching a schema.
      case structure(Transcript.StructuredSegment)

      /// An attachment segment such as an image or file.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      case attachment(Transcript.AttachmentSegment)

      /// The identifier type for a segment.
      public typealias ID = String
    }
  }

  extension Transcript.Segment {
    /// The unique identifier of the segment.
    public var id: String {
      switch self {
      case .text(let text):
        text.id
      case .structure(let structure):
        structure.id
      case .attachment(let attachment):
        attachment.id
      }
    }

    /// Returns a Boolean value indicating whether two segments are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first segment to compare.
    ///   - rhs: The second segment to compare.
    /// - Returns: `true` if both segments are equal.
    public static func == (lhs: Transcript.Segment, rhs: Transcript.Segment) -> Bool {
      switch (lhs, rhs) {
      case (.text(let lhs), .text(let rhs)):
        lhs == rhs
      case (.structure(let lhs), .structure(let rhs)):
        lhs == rhs
      case (.attachment(let lhs), .attachment(let rhs)):
        lhs == rhs
      default:
        false
      }
    }
  }

  extension Transcript {
    /// A text-based transcript segment.
    ///
    /// - SeeAlso: [`Transcript.TextSegment`](https://developer.apple.com/documentation/foundationmodels/transcript/textsegment)
    public struct TextSegment: Sendable, Identifiable, Equatable {
      /// The unique identifier of the text segment.
      public var id: String

      /// The textual content of the segment.
      public var content: String

      /// Creates a text segment with an identifier and content.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the segment.
      ///   - content: The textual content of the segment.
      public init(id: String = UUID().uuidString, content: String) {
        self.id = id
        self.content = content
      }

      /// The identifier type for a text segment.
      public typealias ID = String
    }
  }

  extension Transcript {
    /// A structured data segment in a transcript.
    ///
    /// - SeeAlso: [`Transcript.StructuredSegment`](https://developer.apple.com/documentation/foundationmodels/transcript/structuredsegment)
    public struct StructuredSegment: Sendable, Identifiable, Equatable {
      /// The unique identifier of the structured segment.
      public var id: String

      /// The name of the schema that describes the structured content.
      public var schemaName: String

      /// The generated content held by this structured segment.
      public var content: GeneratedContent

      /// Creates a structured segment with an identifier, schema name, and content.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the segment.
      ///   - schemaName: The name of the schema for the content.
      ///   - content: The generated content of the segment.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public init(id: String = UUID().uuidString, schemaName: String, content: GeneratedContent) {
        self.id = id
        self.schemaName = schemaName
        self.content = content
      }

      /// The identifier type for a structured segment.
      public typealias ID = String
    }
  }

  extension Transcript {
    /// A transcript segment containing an attachment.
    ///
    /// - SeeAlso: [`Transcript.AttachmentSegment`](https://developer.apple.com/documentation/foundationmodels/transcript/attachmentsegment)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct AttachmentSegment: Sendable, Identifiable, Equatable {
      /// The unique identifier of the attachment segment.
      public var id: String

      /// The attachment payload contained in this segment.
      public var content: Transcript.Attachment

      /// An optional label identifying the attachment.
      public var label: String?

      /// Creates an attachment segment with an identifier, content, and optional label.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the segment.
      ///   - content: The attachment payload.
      ///   - label: An optional label for the attachment.
      public init(
        id: String = UUID().uuidString,
        content: Transcript.Attachment,
        label: String? = nil
      ) {
        self.id = id
        self.content = content
        self.label = label
      }

      /// The identifier type for an attachment segment.
      public typealias ID = String
    }
  }

  extension Transcript.TextSegment {
    /// Returns a Boolean value indicating whether two text segments are equal.
    ///
    /// - Parameters:
    ///   - a: The first text segment to compare.
    ///   - b: The second text segment to compare.
    /// - Returns: `true` if both text segments are equal.
    public static func == (a: Transcript.TextSegment, b: Transcript.TextSegment) -> Bool {
      a.id == b.id && a.content == b.content
    }
  }

  extension Transcript.StructuredSegment {
    /// Returns a Boolean value indicating whether two structured segments are equal.
    ///
    /// - Parameters:
    ///   - a: The first structured segment to compare.
    ///   - b: The second structured segment to compare.
    /// - Returns: `true` if both structured segments are equal.
    public static func == (a: Transcript.StructuredSegment, b: Transcript.StructuredSegment) -> Bool
    {
      a.id == b.id && a.schemaName == b.schemaName && a.content == b.content
    }
  }

  extension Transcript.AttachmentSegment {
    /// Returns a Boolean value indicating whether two attachment segments are equal.
    ///
    /// - Parameters:
    ///   - a: The first attachment segment to compare.
    ///   - b: The second attachment segment to compare.
    /// - Returns: `true` if both attachment segments are equal.
    public static func == (a: Transcript.AttachmentSegment, b: Transcript.AttachmentSegment) -> Bool
    {
      a.id == b.id && a.content == b.content && a.label == b.label
    }
  }
#endif  // compiler(>=6.4)
