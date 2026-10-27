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

import Foundation
import GeminiAPIDataModels
import Testing

@Suite("Part Tests")
struct PartTests {
  @Test
  func decodePartWithToolCall() throws {
    let json = """
      {
        "thought": true,
        "thoughtSignature": "sig123",
        "toolCall": {
          "id": "call-1",
          "toolName": "google_search",
          "toolType": "GOOGLE_SEARCH_WEB",
          "args": {
            "query": "Swift Testing"
          }
        }
      }
      """

    let part = try JSONDecoder().decode(Part.self, from: Data(json.utf8))

    #expect(part.thought == true)
    #expect(part.thoughtSignature == "sig123")
    guard case .toolCall(let toolCall) = part.data else {
      Issue.record("Expected part.data to be .toolCall, but was \(String(describing: part.data))")
      return
    }
    #expect(toolCall.id == "call-1")
    #expect(toolCall.toolName == "google_search")
    #expect(toolCall.toolType == .googleSearchWeb)
    #expect(toolCall.args?["query"] == .string("Swift Testing"))
  }

  @Test
  func decodePartWithToolResponse() throws {
    let json = """
      {
        "toolResponse": {
          "id": "call-1",
          "toolType": "GOOGLE_SEARCH_WEB",
          "response": {
            "result": "Success"
          }
        }
      }
      """

    let part = try JSONDecoder().decode(Part.self, from: Data(json.utf8))

    guard case .toolResponse(let toolResponse) = part.data else {
      Issue.record(
        "Expected part.data to be .toolResponse, but was \(String(describing: part.data))")
      return
    }
    #expect(toolResponse.id == "call-1")
    #expect(toolResponse.toolType == .googleSearchWeb)
    #expect(toolResponse.response?["result"] == .string("Success"))
  }

  @Test
  func roundTripToolCall() throws {
    var original = Part()
    var toolCall = ToolCall()
    toolCall.id = "call-42"
    toolCall.toolName = "google_search"
    toolCall.toolType = .googleSearchWeb
    original.data = .toolCall(toolCall)
    original.thoughtSignature = "sig-abc"

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Part.self, from: data)

    #expect(decoded == original)
  }

  @Test
  func roundTripToolResponse() throws {
    var original = Part()
    var toolResponse = ToolResponse()
    toolResponse.id = "call-42"
    toolResponse.toolType = .googleSearchWeb
    toolResponse.response = ["output": .string("42")]
    original.data = .toolResponse(toolResponse)

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Part.self, from: data)

    #expect(decoded == original)
  }

  @Test
  func roundTripCandidateContinuation() throws {
    let json = """
      {
        "finishReason": "CONTINUATION",
        "continuationToken": "opaque_url-safe_unpadded_token"
      }
      """

    let candidate = try JSONDecoder().decode(Candidate.self, from: Data(json.utf8))
    let encodedData = try JSONEncoder().encode(candidate)
    let roundTripped = try JSONDecoder().decode(Candidate.self, from: encodedData)

    #expect(candidate.finishReason == .continuation)
    #expect(candidate.finishReason?.rawValue == "CONTINUATION")
    #expect(candidate.continuationToken == "opaque_url-safe_unpadded_token")
    #expect(roundTripped == candidate)
  }

  @Test
  func encodeGenerateContentRequestWithContinuationAndOutputConfig() throws {
    var request = GenerateContentRequest()
    request.continuationToken = "opaque_url-safe_unpadded_token"
    var outputConfig = GenerateContentRequestOutputConfig()
    outputConfig.outputURIPrefix = "gs://my-bucket/outputs/"
    request.outputConfig = outputConfig

    let encodedData = try JSONEncoder().encode(request)
    let jsonObject = try JSONDecoder().decode([String: JSONValue].self, from: encodedData)
    let decoded = try JSONDecoder().decode(GenerateContentRequest.self, from: encodedData)

    #expect(jsonObject["continuationToken"] == .string("opaque_url-safe_unpadded_token"))
    #expect(
      jsonObject["outputConfig"]
        == .object(["outputUriPrefix": .string("gs://my-bucket/outputs/")]))
    #expect(decoded == request)
  }
}
