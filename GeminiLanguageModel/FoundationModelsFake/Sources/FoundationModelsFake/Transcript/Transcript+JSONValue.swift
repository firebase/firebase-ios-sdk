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

  // Transcript JSON embeds structured segment content and metadata values as plain JSON values.
  // `GeneratedContent` isn't `Codable`, so these helpers go through the internal
  // `CodableGeneratedContent` bridge: encoding writes every property (including keys hidden from
  // `orderedKeys`), and decoding produces content with no explicit key order, complete
  // nodes, and no generation ID.

  extension KeyedDecodingContainer {
    /// Decodes generated content from an embedded JSON value.
    ///
    /// - Parameter key: The key of the JSON value.
    /// - Returns: The decoded content.
    /// - Throws: An error if the value is missing or isn't valid JSON.
    func decodeTranscriptContent(forKey key: Key) throws -> GeneratedContent {
      try decode(CodableGeneratedContent.self, forKey: key).content
    }

    /// Decodes a dictionary of generated content values, if present.
    ///
    /// - Parameter key: The key of the JSON object to decode.
    /// - Returns: The decoded metadata, or an empty dictionary if the key is absent.
    /// - Throws: An error if the value isn't a JSON object of valid JSON values.
    func decodeTranscriptMetadata(forKey key: Key) throws -> [String: GeneratedContent] {
      try decodeIfPresent([String: CodableGeneratedContent].self, forKey: key)?
        .mapValues(\.content) ?? [:]
    }
  }

  extension KeyedEncodingContainer {
    /// Encodes generated content as an embedded JSON value.
    ///
    /// - Parameters:
    ///   - content: The content to encode.
    ///   - key: The key to encode the JSON value under.
    /// - Throws: An error if the content can't be encoded, for example a non-finite number.
    mutating func encodeTranscriptContent(_ content: GeneratedContent, forKey key: Key) throws {
      try encode(CodableGeneratedContent(content), forKey: key)
    }

    /// Encodes a dictionary of generated content values as a JSON object, unless it's empty.
    ///
    /// - Parameters:
    ///   - metadata: The metadata to encode.
    ///   - key: The key to encode the JSON object under.
    /// - Throws: An error if a value can't be encoded.
    mutating func encodeTranscriptMetadata(
      _ metadata: [String: GeneratedContent],
      forKey key: Key
    ) throws {
      guard !metadata.isEmpty else {
        return
      }
      try encode(metadata.mapValues(CodableGeneratedContent.init), forKey: key)
    }
  }
#endif  // compiler(>=6.4)
