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
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  @Suite("Transcript Codable")
  struct TranscriptCodableTests {
    // MARK: - Encoding constructed transcripts

    @Test
    func toolCallArgumentsEncodeAsJSONString() throws {
      let arguments = GeneratedContent(properties: ["city": "Paris", "units": "celsius"])
      let call = Transcript.ToolCall(id: "call-1", toolName: "getWeather", arguments: arguments)
      let transcript = Transcript(entries: [.toolCalls(Transcript.ToolCalls(id: "c", [call]))])

      let encoded = try Self.encode(transcript)

      let object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
      )
      let entries = try #require(
        (object["transcript"] as? [String: Any])?["entries"] as? [[String: Any]]
      )
      let calls = try #require(entries.first?["toolCalls"] as? [[String: Any]])
      #expect(calls.first?["arguments"] as? String == #"{"city": "Paris", "units": "celsius"}"#)
      #expect(calls.first?["metadata"] == nil)
    }

    @Test
    func structuredContentIsEmbeddedAsJSON() throws {
      let content = GeneratedContent(properties: ["title": "Headline", "rank": 1])
      let segment = Transcript.Segment.structure(
        Transcript.StructuredSegment(id: "s", schemaName: "SearchResult", content: content)
      )
      let transcript = Transcript(entries: [
        .toolOutput(Transcript.ToolOutput(id: "call-2", toolName: "search", segments: [segment]))
      ])
      let expected = try Self.canonical(
        Data(
          #"""
          {"type":"FoundationModels.Transcript","version":"1.1","transcript":{"entries":[
          {"role":"tool","id":"call-2","toolCallID":"call-2","toolName":"search","contents":[
          {"type":"structure","id":"s","structure":{"source":"SearchResult",
          "content":{"title":"Headline","rank":1}}}]}]}}
          """#.utf8
        )
      )

      let encoded = try Self.encode(transcript)

      #expect(try Self.canonical(encoded) == expected)
    }

    // MARK: - Decoded and constructed equality

    @Test
    func decodedStructuredSegmentDoesNotEqualConstructedOne() throws {
      let constructed = Transcript(entries: [
        .response(
          Transcript.Response(
            id: "r",
            segments: [
              .structure(
                Transcript.StructuredSegment(
                  id: "s",
                  schemaName: "SearchResult",
                  content: GeneratedContent(properties: ["title": "Headline"])
                )
              )
            ]
          )
        )
      ])

      let decoded = try JSONDecoder().decode(
        Transcript.self,
        from: Self.encode(constructed)
      )

      #expect(decoded != constructed)
      #expect(try Self.encode(decoded) == Self.encode(constructed))
    }

    // MARK: - Decoding errors

    @Test
    func rejectsUnknownEntryRole() throws {
      let input = #"""
        {"type":"FoundationModels.Transcript","version":"1.1",
        "transcript":{"entries":[{"role":"mystery","id":"x"}]}}
        """#

      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Transcript.self, from: Data(input.utf8))
      }
    }

    // MARK: - Helpers

    /// Encodes a transcript with sorted keys.
    ///
    /// - Parameter transcript: The transcript to encode.
    /// - Returns: The encoded JSON.
    static func encode(_ transcript: Transcript) throws -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return try encoder.encode(transcript)
    }

    /// Re-serializes JSON with sorted keys so that two encodings can be compared.
    ///
    /// - Parameter data: The JSON to canonicalize.
    /// - Returns: The JSON with sorted keys.
    static func canonical(_ data: Data) throws -> Data {
      let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
      return try JSONSerialization.data(
        withJSONObject: object,
        options: [.sortedKeys, .fragmentsAllowed]
      )
    }
  }
#endif  // compiler(>=6.4)
