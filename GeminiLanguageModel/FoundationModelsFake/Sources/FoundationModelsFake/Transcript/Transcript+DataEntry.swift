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
    #if compiler(>=6.4.2)
      public import FoundationEssentials
    #else
      import FoundationEssentials
    #endif
  #else
    #if compiler(>=6.4.2)
      public import Foundation
    #else
      import Foundation
    #endif
  #endif

  #if canImport(UniformTypeIdentifiers)
    #if compiler(>=6.4.2)
      public import UniformTypeIdentifiers
    #else
      import UniformTypeIdentifiers
    #endif
  #endif

  extension Transcript {
    #if compiler(>=6.4.2)
      /// A transcript entry that contains arbitrary binary data and a uniform type identifier.
      ///
      /// - SeeAlso: [`Transcript.DataEntry`](https://developer.apple.com/documentation/foundationmodels/transcript/dataentry)
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      public struct DataEntry: Sendable, Identifiable, Equatable, CustomStringConvertible {
        /// The unique identifier of the data entry.
        public var id: String

        /// The uniform type identifier describing the data.
        public var contentType: UTType

        /// The binary payload of the data entry.
        public var content: Data

        /// Metadata associated with the data entry.
        public var metadata: GeneratedContent

        /// Creates a data entry with the given type, binary content, and metadata.
        ///
        /// - Parameters:
        ///   - id: The entry's unique identifier.
        ///   - contentType: The uniform type identifier of the content.
        ///   - content: The raw data of the entry.
        ///   - metadata: Metadata associated with the data entry.
        public init(
          id: String = UUID().uuidString,
          contentType: UTType,
          content: Data,
          metadata: GeneratedContent = GeneratedContent(properties: [:])
        ) {
          self.id = id
          self.contentType = contentType
          self.content = content
          self.metadata = metadata
        }

        /// A textual description of the data entry.
        public var description: String {
          "[data \(contentType.identifier), \(content.count) bytes]"
        }

        /// Returns a Boolean value indicating whether two data entries are equal.
        ///
        /// - Parameters:
        ///   - lhs: The first data entry to compare.
        ///   - rhs: The second data entry to compare.
        /// - Returns: `true` if both data entries are equal.
        public static func == (lhs: Transcript.DataEntry, rhs: Transcript.DataEntry) -> Bool {
          lhs.id == rhs.id
            && lhs.contentType == rhs.contentType
            && lhs.content == rhs.content
            && metadataEquals(lhs.metadata, rhs.metadata)
        }
      }
    #endif  // compiler(>=6.4.2)
  }

  #if compiler(>=6.4.2)
    /// A type that can convert to and from a transcript data entry.
    ///
    /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
    /// > only. For the production API, see
    /// > [`DataEntryRepresentable`](https://developer.apple.com/documentation/foundationmodels/dataentryrepresentable).
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    @available(tvOS, unavailable)
    public protocol DataEntryRepresentable: Sendable {
      /// Creates an instance from a transcript data entry.
      ///
      /// - Parameter entry: The data entry to convert from.
      /// - Throws: An error if conversion fails.
      init(_ entry: Transcript.DataEntry) throws

      /// The data entry representation of this instance.
      var transcriptRepresentation: Transcript.DataEntry { get }
    }
  #endif  // compiler(>=6.4.2)

  /// Compares two `GeneratedContent` metadata values for structural equality,
  /// ignoring key ordering differences introduced by JSON round-tripping.
  internal func metadataEquals(_ lhs: GeneratedContent, _ rhs: GeneratedContent) -> Bool {
    if lhs == rhs {
      return true
    }
    return lhs.id == rhs.id && metadataKindEquals(lhs.kind, rhs.kind)
  }

  /// Compares two `GeneratedContent` kinds for structural equality, ignoring key order.
  ///
  /// - Parameters:
  ///   - lhs: The first kind to compare.
  ///   - rhs: The second kind to compare.
  /// - Returns: `true` if the kinds hold the same values.
  private func metadataKindEquals(
    _ lhs: GeneratedContent.Kind,
    _ rhs: GeneratedContent.Kind
  ) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
      return true
    case (.bool(let a), .bool(let b)):
      return a == b
    case (.number(let a), .number(let b)):
      return a == b
    case (.string(let a), .string(let b)):
      return a == b
    case (.array(let a), .array(let b)):
      guard a.count == b.count else { return false }
      return zip(a, b).allSatisfy { metadataEquals($0, $1) }
    case (.structure(let propsA, _), .structure(let propsB, _)):
      guard propsA.count == propsB.count else { return false }
      for (key, valA) in propsA {
        guard let valB = propsB[key], metadataEquals(valA, valB) else {
          return false
        }
      }
      return true
    default:
      return false
    }
  }
#endif  // compiler(>=6.4)
