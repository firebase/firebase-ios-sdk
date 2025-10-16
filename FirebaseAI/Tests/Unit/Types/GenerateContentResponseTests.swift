// Copyright 2025 Google LLC
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

@testable import FirebaseAILogic
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerateContentResponseTests: XCTestCase {
  let jsonDecoder = JSONDecoder()

  // MARK: - GenerateContentResponse Computed Properties

  func testGenerateContentResponse_inlineDataParts_success() throws {
    let imageData = Data("sample image data".utf8)
    let inlineDataPart = InlineDataPart(data: imageData, mimeType: "image/png")
    let textPart = TextPart("This is the text part.")
    let modelContent = ModelContent(parts: [textPart, inlineDataPart])
    let candidate = Candidate(
      content: modelContent,
      safetyRatings: [],
      finishReason: nil,
      citationMetadata: nil
    )
    let response = GenerateContentResponse(candidates: [candidate])

    let inlineParts = response.inlineDataParts

    XCTAssertFalse(inlineParts.isEmpty, "inlineDataParts should not be empty.")
    XCTAssertEqual(inlineParts.count, 1, "There should be exactly one InlineDataPart.")
    let firstInlinePart = try XCTUnwrap(inlineParts.first, "Could not get the first inline part.")
    XCTAssertEqual(firstInlinePart.mimeType, inlineDataPart.mimeType, "MimeType should match.")
    XCTAssertEqual(firstInlinePart.data, imageData)
    XCTAssertEqual(response.text, textPart.text)
    XCTAssertTrue(response.functionCalls.isEmpty, "functionCalls should be empty.")
  }

  func testGenerateContentResponse_inlineDataParts_multipleInlineDataParts_success() throws {
    let imageData1 = Data("sample image data 1".utf8)
    let inlineDataPart1 = InlineDataPart(data: imageData1, mimeType: "image/png")
    let imageData2 = Data("sample image data 2".utf8)
    let inlineDataPart2 = InlineDataPart(data: imageData2, mimeType: "image/jpeg")
    let modelContent = ModelContent(parts: [inlineDataPart1, inlineDataPart2])
    let candidate = Candidate(
      content: modelContent,
      safetyRatings: [],
      finishReason: nil,
      citationMetadata: nil
    )
    let response = GenerateContentResponse(candidates: [candidate])

    let inlineParts = response.inlineDataParts

    XCTAssertFalse(inlineParts.isEmpty, "inlineDataParts should not be empty.")
    XCTAssertEqual(inlineParts.count, 2, "There should be exactly two InlineDataParts.")
    let firstInlinePart = try XCTUnwrap(inlineParts.first, "Could not get the first inline part.")
    XCTAssertEqual(firstInlinePart.mimeType, inlineDataPart1.mimeType, "MimeType should match.")
    XCTAssertEqual(firstInlinePart.data, imageData1)
    let secondInlinePart = try XCTUnwrap(inlineParts.last, "Could not get the second inline part.")
    XCTAssertEqual(secondInlinePart.mimeType, inlineDataPart2.mimeType, "MimeType should match.")
    XCTAssertEqual(secondInlinePart.data, imageData2)
    XCTAssertNil(response.text)
    XCTAssertTrue(response.functionCalls.isEmpty, "functionCalls should be empty.")
  }

  func testGenerateContentResponse_inlineDataParts_noInlineData() throws {
    let textPart = TextPart("This is the text part.")
    let functionCallPart = FunctionCallPart(name: "testFunc", args: [:])
    let modelContent = ModelContent(parts: [textPart, functionCallPart])
    let candidate = Candidate(
      content: modelContent,
      safetyRatings: [],
      finishReason: nil,
      citationMetadata: nil
    )
    let response = GenerateContentResponse(candidates: [candidate])

    let inlineParts = response.inlineDataParts

    XCTAssertTrue(inlineParts.isEmpty, "inlineDataParts should be empty.")
    XCTAssertEqual(response.text, "This is the text part.")
    XCTAssertEqual(response.functionCalls.count, 1)
    XCTAssertEqual(response.functionCalls.first?.name, "testFunc")
  }

  func testGenerateContentResponse_inlineDataParts_noCandidates() throws {
    let response = GenerateContentResponse(candidates: [])

    let inlineParts = response.inlineDataParts

    XCTAssertTrue(
      inlineParts.isEmpty,
      "inlineDataParts should be empty when there are no candidates."
    )
    XCTAssertNil(response.text, "Text should be nil when there are no candidates.")
    XCTAssertTrue(
      response.functionCalls.isEmpty,
      "functionCalls should be empty when there are no candidates."
    )
  }

  // MARK: - Decoding Tests

  func testDecodeCandidate_emptyURLMetadata_urlContextMetadataIsNil() throws {
    let json = """
    {
      "content": { "role": "model", "parts": [ { "text": "Some text." } ] },
      "finishReason": "STOP",
      "urlContextMetadata": { "urlMetadata": [] }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let candidate = try jsonDecoder.decode(Candidate.self, from: jsonData)

    XCTAssertNil(
      candidate.urlContextMetadata,
      "urlContextMetadata should be nil if the `urlMetadata` array is empty in the candidate."
    )
    XCTAssertEqual(candidate.content.role, "model")
    let part = try XCTUnwrap(candidate.content.parts.first)
    let textPart = try XCTUnwrap(part as? TextPart)
    XCTAssertEqual(textPart.text, "Some text.")
    XCTAssertFalse(textPart.isThought)
    XCTAssertEqual(candidate.finishReason, .stop)
  }

  func testDecodeCandidate_missingURLMetadata_urlContextMetadataIsNil() throws {
    let json = """
    {
      "content": { "role": "model", "parts": [ { "text": "Some text." } ] },
      "finishReason": "STOP"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let candidate = try jsonDecoder.decode(Candidate.self, from: jsonData)

    XCTAssertNil(
      candidate.urlContextMetadata,
      "urlContextMetadata should be nil if `urlMetadata` is not provided in the candidate."
    )
    XCTAssertEqual(candidate.content.role, "model")
    let part = try XCTUnwrap(candidate.content.parts.first)
    let textPart = try XCTUnwrap(part as? TextPart)
    XCTAssertEqual(textPart.text, "Some text.")
    XCTAssertFalse(textPart.isThought)
    XCTAssertEqual(candidate.finishReason, .stop)
  }

  // MARK: - Candidate.isEmpty

  func testCandidateIsEmpty_allEmpty_isTrue() throws {
    let candidate = Candidate(
      content: ModelContent(parts: []),
      safetyRatings: [],
      finishReason: nil,
      citationMetadata: nil,
      groundingMetadata: nil,
      urlContextMetadata: nil
    )

    XCTAssertTrue(candidate.isEmpty, "A candidate with no content should be empty.")
  }

  func testCandidateIsEmpty_withURLContextMetadata_isFalse() throws {
    let urlMetadata = try URLMetadata(
      retrievedURL: XCTUnwrap(URL(string: "https://google.com")),
      retrievalStatus: .success
    )
    let urlContextMetadata = URLContextMetadata(urlMetadata: [urlMetadata])
    let candidate = Candidate(
      content: ModelContent(parts: []),
      safetyRatings: [],
      finishReason: nil,
      citationMetadata: nil,
      groundingMetadata: nil,
      urlContextMetadata: urlContextMetadata
    )

    XCTAssertFalse(
      candidate.isEmpty,
      "A candidate with only `urlContextMetadata` should not be empty."
    )
  }
}
