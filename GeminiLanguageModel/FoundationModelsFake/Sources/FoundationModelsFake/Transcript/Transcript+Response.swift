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

  extension Transcript {
    /// A model response recorded in a transcript.
    ///
    /// - SeeAlso: [`Transcript.Response`](https://developer.apple.com/documentation/foundationmodels/transcript/response)
    public struct Response: Sendable, Identifiable, Equatable {
      /// The unique identifier of the response.
      public var id: String

      /// The identifiers of assets used to generate the response.
      public var assetIDs: [String]

      /// The storage that backs ``metadata``.
      var storedMetadata: [String: GeneratedContent]

      /// The segments that compose the response.
      public var segments: [Transcript.Segment]

      /// The identifier type for a response.
      public typealias ID = String
    }
  }

  extension Transcript.Response {
    /// Additional metadata associated with the response.
    public var metadata: [String: GeneratedContent] {
      storedMetadata
    }

    /// Creates a response with an identifier, asset identifiers, and segments.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the response.
    ///   - assetIDs: Identifiers for assets used to generate the response.
    ///   - segments: The segments composing the response.
    public init(id: String = UUID().uuidString, assetIDs: [String], segments: [Transcript.Segment])
    {
      self.id = id
      self.assetIDs = assetIDs
      self.storedMetadata = ["assetIDs": GeneratedContent(assetIDs)]
      self.segments = segments
    }

    /// Creates a response with every stored property, as decoded from a serialized transcript.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the response.
    ///   - assetIDs: A list of identifiers for the assets used to generate the response.
    ///   - metadata: Additional information associated with the response, keyed by name.
    ///   - segments: The segments of the response, in order.
    init(
      id: String,
      assetIDs: [String],
      metadata: [String: GeneratedContent],
      segments: [Transcript.Segment]
    ) {
      self.id = id
      self.assetIDs = assetIDs
      self.storedMetadata = metadata
      self.segments = segments
    }

    /// Creates a response with an identifier, metadata, and segments.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the response.
    ///   - metadata: Metadata associated with the response.
    ///   - segments: The segments composing the response.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public init(
      id: String = UUID().uuidString,
      metadata: [String: any ConvertibleToGeneratedContent] = [:],
      segments: [Transcript.Segment]
    ) {
      self.id = id
      self.assetIDs = []
      self.storedMetadata = metadata.mapValues(\.generatedContent)
      self.segments = segments
    }

    /// Returns a Boolean value indicating whether two responses are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first response to compare.
    ///   - rhs: The second response to compare.
    /// - Returns: `true` if both responses are equal.
    public static func == (lhs: Transcript.Response, rhs: Transcript.Response) -> Bool {
      lhs.id == rhs.id
        && lhs.assetIDs == rhs.assetIDs
        && lhs.storedMetadata == rhs.storedMetadata
        && lhs.segments == rhs.segments
    }
  }

  extension Transcript {
    /// A model reasoning record within a transcript.
    ///
    /// - SeeAlso: [`Transcript.Reasoning`](https://developer.apple.com/documentation/foundationmodels/transcript/reasoning)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct Reasoning: Sendable, Identifiable, Equatable {
      /// The unique identifier of the reasoning entry.
      public var id: String

      /// The segments that compose the reasoning content.
      public var segments: [Transcript.Segment]

      /// An optional cryptographic signature verifying the reasoning.
      public var signature: Data?

      /// Metadata associated with the reasoning entry.
      public var metadata: [String: GeneratedContent]

      /// Creates a reasoning record with an identifier, metadata, segments, and signature.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the reasoning entry.
      ///   - metadata: Metadata associated with the reasoning.
      ///   - segments: The segments composing the reasoning.
      ///   - signature: An optional cryptographic signature.
      public init(
        id: String = UUID().uuidString,
        metadata: [String: any ConvertibleToGeneratedContent] = [:],
        segments: [Transcript.Segment],
        signature: Data? = nil
      ) {
        self.id = id
        self.metadata = metadata.mapValues(\.generatedContent)
        self.segments = segments
        self.signature = signature
      }

      /// The identifier type for a reasoning entry.
      public typealias ID = String
    }
  }

  extension Transcript.Reasoning {
    /// Returns a Boolean value indicating whether two reasoning records are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first reasoning record to compare.
    ///   - rhs: The second reasoning record to compare.
    /// - Returns: `true` if both reasoning records are equal.
    public static func == (lhs: Transcript.Reasoning, rhs: Transcript.Reasoning) -> Bool {
      lhs.id == rhs.id
        && lhs.segments == rhs.segments
        && lhs.signature == rhs.signature
        && lhs.metadata == rhs.metadata
    }
  }
#endif  // compiler(>=6.4)
