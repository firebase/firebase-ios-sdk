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

  /// A reference to an image attachment in a transcript.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`ImageReference`](https://developer.apple.com/documentation/foundationmodels/imagereference).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ImageReference: Sendable, Equatable, Generable {
    /// The label of the referenced image attachment.
    public let attachmentLabel: String

    /// Creates an image reference for the given attachment label.
    ///
    /// - Parameter attachmentLabel: The label of the image attachment.
    internal init(attachmentLabel: String) {
      self.attachmentLabel = attachmentLabel
    }

    /// A partially generated image reference.
    ///
    /// - SeeAlso: [`ImageReference.PartiallyGenerated`](https://developer.apple.com/documentation/foundationmodels/imagereference/partiallygenerated)
    public struct PartiallyGenerated: Identifiable, ConvertibleFromGeneratedContent, Equatable {
      /// The identifier type for a partially generated image reference.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public typealias ID = GenerationID

      /// The identifier of the partially generated value.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var id: GenerationID

      /// The partially generated attachment label.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var attachmentLabel: String.PartiallyGenerated?

      /// Creates a partially generated image reference from generated content.
      ///
      /// - Parameter content: The generated content to decode from.
      /// - Throws: An error if property decoding fails.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public init(_ content: GeneratedContent) throws {
        self.id = content.id ?? GenerationID()
        self.attachmentLabel = try content.value(
          String.PartiallyGenerated?.self,
          forProperty: "attachmentLabel"
        )
      }
    }

    /// A schema describing an image reference for structured generation.
    public static var generationSchema: GenerationSchema {
      GenerationSchema(
        type: Self.self,
        description: "A reference for an image in the transcript.",
        properties: [
          GenerationSchema.Property(
            name: "attachmentLabel",
            description: nil,
            type: String.self
          )
        ]
      )
    }

    /// The generated content representation of the image reference.
    public var generatedContent: GeneratedContent {
      GeneratedContent(properties: ["attachmentLabel": attachmentLabel])
    }

    /// Creates an image reference from generated content.
    ///
    /// - Parameter content: The generated content to decode from.
    /// - Throws: An error if decoding the attachment label fails.
    public init(_ content: GeneratedContent) throws {
      self.attachmentLabel = try content.value(String.self, forProperty: "attachmentLabel")
    }

    /// Finds the matching image attachment for this reference in a transcript.
    ///
    /// - Parameter transcript: The sequence of transcript entries to search.
    /// - Returns: The latest matching image attachment, or `nil` if none is found.
    public func resolved(
      in transcript: some Sequence<Transcript.Entry>
    ) -> Transcript.ImageAttachment? {
      var latestMatch: Transcript.ImageAttachment?
      for entry in transcript {
        let segments: [Transcript.Segment]
        switch entry {
        case .instructions(let instructions):
          segments = instructions.segments
        case .prompt(let prompt):
          segments = prompt.segments
        case .toolOutput(let toolOutput):
          segments = toolOutput.segments
        default:
          continue
        }
        for segment in segments {
          if case .attachment(let attachmentSegment) = segment,
            attachmentSegment.label == attachmentLabel,
            case .image(let imageAttachment) = attachmentSegment.content
          {
            latestMatch = imageAttachment
            break
          }
        }
      }
      return latestMatch
    }
  }
#endif  // compiler(>=6.4)
