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

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript: Codable {
    /// The key of the format version, which is checked before anything else.
    enum CodingKeys: String, CodingKey {
      case version
    }

    /// The keys of the envelope that wraps the transcript.
    enum EnvelopeCodingKeys: String, CodingKey {
      case type
      case transcript
    }

    /// The keys that ``encode(to:)`` writes in the envelope.
    enum EncodingKeys: String, CodingKey {
      case type
      case version
      case transcript
    }

    /// The keys of the `transcript` object.
    enum TranscriptCodingKeys: String, CodingKey {
      case entries
    }

    /// The value of the envelope's `type` key.
    static let codableType = "FoundationModels.Transcript"

    /// The only supported value of the envelope's `version` key.
    static let codableVersion = "1.1"

    /// Creates a transcript by decoding it from a decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: An error if decoding fails or the transcript version is unsupported.
    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let version: String
      if let string = try? container.decode(String.self, forKey: .version) {
        version = string
      } else {
        // A missing key throws `keyNotFound`, and a non-integral number
        // throws `dataCorrupted`.
        version = String(try container.decode(Int.self, forKey: .version))
      }
      guard version == Self.codableVersion else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: container.codingPath,
            debugDescription: "The transcript version \(version) isn't supported."
          )
        )
      }
      let envelope = try decoder.container(keyedBy: EnvelopeCodingKeys.self)
      _ = try envelope.decode(String.self, forKey: .type)
      let transcript = try envelope.nestedContainer(
        keyedBy: TranscriptCodingKeys.self,
        forKey: .transcript
      )
      self.entries = try transcript.decode([TranscriptCodableEntry].self, forKey: .entries)
        .map(\.entry)
    }

    /// Encodes the transcript into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if encoding fails.
    public func encode(to encoder: any Encoder) throws {
      var envelope = encoder.container(keyedBy: EncodingKeys.self)
      try envelope.encode(Self.codableType, forKey: .type)
      try envelope.encode(Self.codableVersion, forKey: .version)
      var transcript = envelope.nestedContainer(
        keyedBy: TranscriptCodingKeys.self,
        forKey: .transcript
      )
      try transcript.encode(entries.map(TranscriptCodableEntry.init), forKey: .entries)
    }
  }
#endif  // compiler(>=6.4)
