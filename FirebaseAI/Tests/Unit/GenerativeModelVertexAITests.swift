// Copyright 2023 Google LLC
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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerativeModelVertexAITests: XCTestCase {
  let testPrompt = "What sorts of questions can I ask you?"
  let safetyRatingsNegligible: [SafetyRating] = [
    .init(
      category: .sexuallyExplicit,
      probability: .negligible,
      probabilityScore: 0.1431877,
      severity: .negligible,
      severityScore: 0.11027937,
      blocked: false
    ),
    .init(
      category: .hateSpeech,
      probability: .negligible,
      probabilityScore: 0.029035643,
      severity: .negligible,
      severityScore: 0.05613278,
      blocked: false
    ),
    .init(
      category: .harassment,
      probability: .negligible,
      probabilityScore: 0.087252244,
      severity: .negligible,
      severityScore: 0.04509957,
      blocked: false
    ),
    .init(
      category: .dangerousContent,
      probability: .negligible,
      probabilityScore: 0.2641685,
      severity: .negligible,
      severityScore: 0.082253955,
      blocked: false
    ),
  ].sorted()
  let safetyRatingsInvalidIgnored = [
    SafetyRating(
      category: .hateSpeech,
      probability: .negligible,
      probabilityScore: 0.00039444832,
      severity: .negligible,
      severityScore: 0.0,
      blocked: false
    ),
    SafetyRating(
      category: .dangerousContent,
      probability: .negligible,
      probabilityScore: 0.0010654529,
      severity: .negligible,
      severityScore: 0.0049325973,
      blocked: false
    ),
    SafetyRating(
      category: .harassment,
      probability: .negligible,
      probabilityScore: 0.00026658305,
      severity: .negligible,
      severityScore: 0.0,
      blocked: false
    ),
    SafetyRating(
      category: .sexuallyExplicit,
      probability: .negligible,
      probabilityScore: 0.0013701695,
      severity: .negligible,
      severityScore: 0.07626295,
      blocked: false
    ),
    // Ignored Invalid Safety Ratings: {},{},{},{}
  ].sorted()
  let testModelName = "test-model"
  let testModelResourceName =
    "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

  let vertexSubdirectory = "mock-responses/vertexai"

  var urlSession: URLSession!
  var model: GenerativeModel!

  override func setUp() async throws {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = try XCTUnwrap(URLSession(configuration: configuration))
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  // MARK: - Generate Content

  func testGenerateContent_success_basicReplyLong() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-long",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let finishReason = try XCTUnwrap(candidate.finishReason)
    XCTAssertEqual(finishReason, .stop)
    XCTAssertEqual(candidate.safetyRatings.count, 4)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    let partText = try XCTUnwrap(part as? TextPart).text
    XCTAssertTrue(partText.hasPrefix("1. **Use Freshly Ground Coffee**:"))
    XCTAssertEqual(response.text, partText)
    XCTAssertEqual(response.functionCalls, [])
    XCTAssertEqual(response.inlineDataParts, [])
  }

  func testGenerateContent_success_basicReplyShort() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let finishReason = try XCTUnwrap(candidate.finishReason)
    XCTAssertEqual(finishReason, .stop)
    XCTAssertEqual(candidate.safetyRatings.sorted(), safetyRatingsNegligible)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    let textPart = try XCTUnwrap(part as? TextPart)
    XCTAssertEqual(textPart.text, "Mountain View, California")
    XCTAssertEqual(response.text, textPart.text)
    XCTAssertEqual(response.functionCalls, [])
  }

  func testGenerateContent_success_basicReplyFullUsageMetadata() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-response-long-usage-metadata",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let finishReason = try XCTUnwrap(candidate.finishReason)
    XCTAssertEqual(finishReason, .stop)
    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokensDetails.count, 2)
    XCTAssertEqual(usageMetadata.promptTokensDetails[0].modality, .image)
    XCTAssertEqual(usageMetadata.promptTokensDetails[0].tokenCount, 1806)
    XCTAssertEqual(usageMetadata.promptTokensDetails[1].modality, .text)
    XCTAssertEqual(usageMetadata.promptTokensDetails[1].tokenCount, 76)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails.count, 1)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails[0].modality, .text)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails[0].tokenCount, 76)
  }

  func testGenerateContent_success_citations() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-citations",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )
    let expectedPublicationDate = DateComponents(
      calendar: Calendar(identifier: .gregorian),
      year: 2019,
      month: 5,
      day: 10
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    XCTAssertEqual(response.text, "Some information cited from an external source")
    let citationMetadata = try XCTUnwrap(candidate.citationMetadata)
    XCTAssertEqual(citationMetadata.citations.count, 3)
    let citationSource1 = try XCTUnwrap(citationMetadata.citations[0])
    XCTAssertEqual(citationSource1.uri, "https://www.example.com/some-citation-1")
    XCTAssertEqual(citationSource1.startIndex, 0)
    XCTAssertEqual(citationSource1.endIndex, 128)
    XCTAssertNil(citationSource1.title)
    XCTAssertNil(citationSource1.license)
    XCTAssertNil(citationSource1.publicationDate)
    let citationSource2 = try XCTUnwrap(citationMetadata.citations[1])
    XCTAssertEqual(citationSource2.title, "some-citation-2")
    XCTAssertEqual(citationSource2.publicationDate, expectedPublicationDate)
    XCTAssertEqual(citationSource2.startIndex, 130)
    XCTAssertEqual(citationSource2.endIndex, 265)
    XCTAssertNil(citationSource2.uri)
    XCTAssertNil(citationSource2.license)
    let citationSource3 = try XCTUnwrap(citationMetadata.citations[2])
    XCTAssertEqual(citationSource3.uri, "https://www.example.com/some-citation-3")
    XCTAssertEqual(citationSource3.startIndex, 272)
    XCTAssertEqual(citationSource3.endIndex, 431)
    XCTAssertEqual(citationSource3.license, "mit")
    XCTAssertNil(citationSource3.title)
    XCTAssertNil(citationSource3.publicationDate)
  }

  func testGenerateContent_success_quoteReply() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-quote-reply",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let finishReason = try XCTUnwrap(candidate.finishReason)
    XCTAssertEqual(finishReason, .stop)
    XCTAssertEqual(candidate.safetyRatings.count, 4)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    let textPart = try XCTUnwrap(part as? TextPart)
    XCTAssertTrue(textPart.text.hasPrefix("Google"))
    XCTAssertEqual(response.text, textPart.text)
    let promptFeedback = try XCTUnwrap(response.promptFeedback)
    XCTAssertNil(promptFeedback.blockReason)
    XCTAssertEqual(promptFeedback.safetyRatings.count, 4)
  }

  func testGenerateContent_success_unknownEnum_safetyRatings() async throws {
    let expectedSafetyRatings = [
      SafetyRating(
        category: .harassment,
        probability: .medium,
        probabilityScore: 0.0,
        severity: .init(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
        severityScore: 0.0,
        blocked: false
      ),
      SafetyRating(
        category: .dangerousContent,
        probability: SafetyRating.HarmProbability(rawValue: "FAKE_NEW_HARM_PROBABILITY"),
        probabilityScore: 0.0,
        severity: .init(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
        severityScore: 0.0,
        blocked: false
      ),
      SafetyRating(
        category: HarmCategory(rawValue: "FAKE_NEW_HARM_CATEGORY"),
        probability: .high,
        probabilityScore: 0.0,
        severity: .init(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
        severityScore: 0.0,
        blocked: false
      ),
    ]
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-unknown-enum-safety-ratings",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.text, "Some text")
    XCTAssertEqual(response.candidates.first?.safetyRatings, expectedSafetyRatings)
    XCTAssertEqual(response.promptFeedback?.safetyRatings, expectedSafetyRatings)
  }

  func testGenerateContent_success_prefixedModelName() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )
    let model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_success_functionCall_emptyArguments() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-empty-arguments",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    guard let functionCall = part as? FunctionCallPart else {
      XCTFail("Part is not a FunctionCall.")
      return
    }
    XCTAssertEqual(functionCall.name, "current_time")
    XCTAssertTrue(functionCall.args.isEmpty)
    XCTAssertEqual(response.functionCalls, [functionCall])
  }

  func testGenerateContent_success_functionCall_noArguments() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-no-arguments",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    guard let functionCall = part as? FunctionCallPart else {
      XCTFail("Part is not a FunctionCall.")
      return
    }
    XCTAssertEqual(functionCall.name, "current_time")
    XCTAssertTrue(functionCall.args.isEmpty)
    XCTAssertEqual(response.functionCalls, [functionCall])
  }

  func testGenerateContent_success_functionCall_withArguments() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-with-arguments",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let part = try XCTUnwrap(candidate.content.parts.first)
    guard let functionCall = part as? FunctionCallPart else {
      XCTFail("Part is not a FunctionCall.")
      return
    }
    XCTAssertEqual(functionCall.name, "sum")
    XCTAssertEqual(functionCall.args.count, 2)
    let argX = try XCTUnwrap(functionCall.args["x"])
    XCTAssertEqual(argX, .number(4))
    let argY = try XCTUnwrap(functionCall.args["y"])
    XCTAssertEqual(argY, .number(5))
    XCTAssertEqual(response.functionCalls, [functionCall])
  }

  func testGenerateContent_success_functionCall_parallelCalls() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-parallel-calls",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 3)
    let functionCalls = response.functionCalls
    XCTAssertEqual(functionCalls.count, 3)
  }

  func testGenerateContent_success_functionCall_mixedContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-mixed-content",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 4)
    let functionCalls = response.functionCalls
    XCTAssertEqual(functionCalls.count, 2)
    let text = try XCTUnwrap(response.text)
    XCTAssertEqual(text, "The sum of [1, 2, 3] is")
  }

  func testGenerateContent_success_thinking_thoughtSummary() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-thinking-reply-thought-summary",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.finishReason, .stop)
    XCTAssertEqual(candidate.content.parts.count, 2)
    let thoughtPart = try XCTUnwrap(candidate.content.parts.first as? TextPart)
    XCTAssertTrue(thoughtPart.isThought)
    XCTAssertTrue(thoughtPart.text.hasPrefix("Right, someone needs the city where Google"))
    XCTAssertEqual(response.thoughtSummary, thoughtPart.text)
    let textPart = try XCTUnwrap(candidate.content.parts.last as? TextPart)
    XCTAssertFalse(textPart.isThought)
    XCTAssertEqual(textPart.text, "Mountain View")
    XCTAssertEqual(response.text, textPart.text)
  }

  func testGenerateContent_success_codeExecution() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-code-execution",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let parts = candidate.content.parts
    XCTAssertEqual(candidate.finishReason, .stop)
    XCTAssertEqual(parts.count, 4)
    let textPart1 = try XCTUnwrap(parts[0] as? TextPart)
    XCTAssertFalse(textPart1.isThought)
    XCTAssertTrue(textPart1.text.hasPrefix("To find the sum of the first 5 prime numbers"))
    let executableCodePart = try XCTUnwrap(parts[1] as? ExecutableCodePart)
    XCTAssertFalse(executableCodePart.isThought)
    XCTAssertEqual(executableCodePart.language, .python)
    XCTAssertTrue(executableCodePart.code.starts(with: "prime_numbers = [2, 3, 5, 7, 11]"))
    let codeExecutionResultPart = try XCTUnwrap(parts[2] as? CodeExecutionResultPart)
    XCTAssertFalse(codeExecutionResultPart.isThought)
    XCTAssertEqual(codeExecutionResultPart.outcome, .ok)
    XCTAssertEqual(codeExecutionResultPart.output, "The sum of the first 5 prime numbers is: 28\n")
    let textPart2 = try XCTUnwrap(parts[3] as? TextPart)
    XCTAssertFalse(textPart2.isThought)
    XCTAssertEqual(
      textPart2.text, "The sum of the first 5 prime numbers (2, 3, 5, 7, and 11) is 28."
    )
    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.toolUsePromptTokenCount, 371)
  }

  func testGenerateContent_success_urlContext() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-url-context",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let urlContextMetadata = try XCTUnwrap(candidate.urlContextMetadata)
    XCTAssertEqual(urlContextMetadata.urlMetadata.count, 1)
    let urlMetadata = try XCTUnwrap(urlContextMetadata.urlMetadata.first)
    let retrievedURL = try XCTUnwrap(urlMetadata.retrievedURL)
    XCTAssertEqual(
      retrievedURL,
      URL(string: "https://berkshirehathaway.com")
    )
    XCTAssertEqual(urlMetadata.retrievalStatus, .success)
    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.toolUsePromptTokenCount, 34)
    XCTAssertEqual(usageMetadata.thoughtsTokenCount, 36)
  }

  func testGenerateContent_success_urlContext_mixedValidity() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-url-context-mixed-validity",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    let candidate = try XCTUnwrap(response.candidates.first)
    let urlContextMetadata = try XCTUnwrap(candidate.urlContextMetadata)
    XCTAssertEqual(urlContextMetadata.urlMetadata.count, 3)

    let paywallURLMetadata = urlContextMetadata.urlMetadata[0]
    XCTAssertEqual(paywallURLMetadata.retrievalStatus, .error)

    let successURLMetadata = urlContextMetadata.urlMetadata[1]
    XCTAssertEqual(successURLMetadata.retrievalStatus, .success)

    let errorURLMetadata = urlContextMetadata.urlMetadata[2]
    XCTAssertEqual(errorURLMetadata.retrievalStatus, .error)
  }

  func testGenerateContent_success_urlContext_retrievedURLPresentOnErrorStatus() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-url-context-missing-retrievedurl",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    let candidate = try XCTUnwrap(response.candidates.first)
    let urlContextMetadata = try XCTUnwrap(candidate.urlContextMetadata)
    let urlMetadata = try XCTUnwrap(urlContextMetadata.urlMetadata.first)
    let retrievedURL = try XCTUnwrap(urlMetadata.retrievedURL)
    XCTAssertEqual(retrievedURL.absoluteString, "https://example.com/8")
    XCTAssertEqual(urlMetadata.retrievalStatus, .error)
  }

  func testGenerateContent_success_image_invalidSafetyRatingsIgnored() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-image-invalid-safety-ratings",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    XCTAssertEqual(candidate.safetyRatings.sorted(), safetyRatingsInvalidIgnored)
    let inlineDataParts = response.inlineDataParts
    XCTAssertEqual(inlineDataParts.count, 1)
    let imagePart = try XCTUnwrap(inlineDataParts.first)
    XCTAssertEqual(imagePart.mimeType, "image/png")
    XCTAssertGreaterThan(imagePart.data.count, 0)
  }

  func testGenerateContent_success_image_emptyPartIgnored() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-empty-part",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 2)
    let inlineDataParts = response.inlineDataParts
    XCTAssertEqual(inlineDataParts.count, 1)
    let imagePart = try XCTUnwrap(inlineDataParts.first)
    XCTAssertEqual(imagePart.mimeType, "image/png")
    XCTAssertGreaterThan(imagePart.data.count, 0)
    let text = try XCTUnwrap(response.text)
    XCTAssertTrue(text.starts(with: "I can certainly help you with that"))
  }

  func testGenerateContent_appCheck_validToken() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(token: appCheckToken)
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        appCheckToken: appCheckToken
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_appCheck_validToken_limitedUse() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(token: appCheckToken),
        useLimitedUseAppCheckTokens: true
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        appCheckToken: "limited_use_\(appCheckToken)"
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_dataCollectionOff() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(token: appCheckToken), privateAppID: true
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        appCheckToken: appCheckToken,
        dataCollection: false
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_appCheck_tokenRefreshError() async throws {
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(error: AppCheckErrorFake())
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        appCheckToken: AppCheckInteropFake.placeholderTokenValue
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_validAuthToken() async throws {
    let authToken = "test-valid-token"
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        auth: AuthInteropFake(token: authToken)
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        authToken: authToken
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_nilAuthToken() async throws {
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(auth: AuthInteropFake(token: nil)),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        authToken: nil
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_authTokenRefreshError() async throws {
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        auth: AuthInteropFake(error: AuthErrorFake())
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        authToken: nil
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw internalError(AuthErrorFake); no error.")
    } catch GenerateContentError.internalError(_ as AuthErrorFake) {
      //
    } catch {
      XCTFail("Should throw internalError(AuthErrorFake); error thrown: \(error)")
    }
  }

  func testGenerateContent_usageMetadata() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    let response = try await model.generateContent(testPrompt)

    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokenCount, 6)
    XCTAssertEqual(usageMetadata.candidatesTokenCount, 7)
    XCTAssertEqual(usageMetadata.totalTokenCount, 13)
    XCTAssertEqual(usageMetadata.promptTokensDetails.isEmpty, true)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails.isEmpty, true)
  }

  func testGenerateContent_groundingMetadata() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-search-grounding",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)

    XCTAssertEqual(groundingMetadata.webSearchQueries, ["current weather in London"])
    XCTAssertNotNil(groundingMetadata.searchEntryPoint)
    XCTAssertNotNil(groundingMetadata.searchEntryPoint?.renderedContent)

    XCTAssertEqual(groundingMetadata.groundingChunks.count, 2)
    let firstChunk = try XCTUnwrap(groundingMetadata.groundingChunks.first?.web)
    XCTAssertEqual(firstChunk.title, "accuweather.com")
    XCTAssertNotNil(firstChunk.uri)
    XCTAssertNil(firstChunk.domain) // Domain is not supported by Google AI backend

    XCTAssertEqual(groundingMetadata.groundingSupports.count, 3)
    let firstSupport = try XCTUnwrap(groundingMetadata.groundingSupports.first)
    let segment = try XCTUnwrap(firstSupport.segment)
    XCTAssertEqual(segment.text, "The current weather in London, United Kingdom is cloudy.")
    XCTAssertEqual(segment.startIndex, 0)
    XCTAssertEqual(segment.partIndex, 0)
    XCTAssertEqual(segment.endIndex, 56)
    XCTAssertEqual(firstSupport.groundingChunkIndices, [0])
  }

  func testGenerateContent_withGoogleSearchTool() async throws {
    let model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: [.googleSearch()],
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_failure_invalidAPIKey() async throws {
    let expectedStatusCode = 400
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-api-key",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        statusCode: expectedStatusCode
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(error as BackendError) {
      XCTAssertEqual(error.httpResponseCode, 400)
      XCTAssertEqual(error.status, .invalidArgument)
      XCTAssertEqual(error.message, "API key not valid. Please pass a valid API key.")
      XCTAssertTrue(error.localizedDescription.contains(error.message))
      XCTAssertTrue(error.localizedDescription.contains(error.status.rawValue))
      XCTAssertTrue(error.localizedDescription.contains("\(error.httpResponseCode)"))
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "\(Constants.baseErrorDomain).\(BackendError.self)")
      XCTAssertEqual(nsError.code, error.httpResponseCode)
      return
    } catch {
      XCTFail("Should throw GenerateContentError.internalError(RPCError); error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_firebaseVertexAIAPINotEnabled() async throws {
    let expectedStatusCode = 403
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-firebasevertexai-api-not-enabled",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        statusCode: expectedStatusCode
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(error as BackendError) {
      XCTAssertEqual(error.httpResponseCode, expectedStatusCode)
      XCTAssertEqual(error.status, .permissionDenied)
      XCTAssertTrue(error.message
        .starts(with: "Vertex AI in Firebase API has not been used in project"))
      XCTAssertTrue(error.isVertexAIInFirebaseServiceDisabledError())
      return
    } catch {
      XCTFail("Should throw GenerateContentError.internalError(RPCError); error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_emptyContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-empty-content",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError
      .internalError(underlying: invalidCandidateError as InvalidCandidateError) {
      guard case let .emptyContent(underlyingError) = invalidCandidateError else {
        XCTFail("Should be an InvalidCandidateError.emptyContent error: \(invalidCandidateError)")
        return
      }
      _ = try XCTUnwrap(underlyingError as? Candidate.EmptyContentError,
                        "Should be an empty content error: \(underlyingError)")
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_finishReasonSafety() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-finish-reason-safety",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, .safety)
      XCTAssertEqual(response.text, "<redacted>")
    } catch {
      XCTFail("Should throw a responseStoppedEarly")
    }
  }

  func testGenerateContent_failure_finishReasonSafety_noContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-finish-reason-safety-no-content",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, .safety)
      XCTAssertNil(response.text)
    } catch {
      XCTFail("Should throw a responseStoppedEarly")
    }
  }

  func testGenerateContent_failure_imageRejected() async throws {
    let expectedStatusCode = 400
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-image-rejected",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        statusCode: 400
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(underlying: rpcError as BackendError) {
      XCTAssertEqual(rpcError.status, .invalidArgument)
      XCTAssertEqual(rpcError.httpResponseCode, expectedStatusCode)
      XCTAssertEqual(rpcError.message, "Request contains an invalid argument.")
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_promptBlockedSafety() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-prompt-blocked-safety",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.promptBlocked(response) {
      XCTAssertNil(response.text)
      let promptFeedback = try XCTUnwrap(response.promptFeedback)
      XCTAssertEqual(promptFeedback.blockReason, PromptFeedback.BlockReason.safety)
      XCTAssertNil(promptFeedback.blockReasonMessage)
    } catch {
      XCTFail("Should throw a promptBlocked")
    }
  }

  func testGenerateContent_failure_promptBlockedSafetyWithMessage() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-prompt-blocked-safety-with-message",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.promptBlocked(response) {
      XCTAssertNil(response.text)
      let promptFeedback = try XCTUnwrap(response.promptFeedback)
      XCTAssertEqual(promptFeedback.blockReason, PromptFeedback.BlockReason.safety)
      XCTAssertEqual(promptFeedback.blockReasonMessage, "Reasons")
    } catch {
      XCTFail("Should throw a promptBlocked")
    }
  }

  func testGenerateContent_failure_unknownEnum_finishReason() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-unknown-enum-finish-reason",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )
    let unknownFinishReason = FinishReason(rawValue: "FAKE_NEW_FINISH_REASON")

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, unknownFinishReason)
      XCTAssertEqual(response.text, "Some text")
    } catch {
      XCTFail("Should throw a responseStoppedEarly")
    }
  }

  func testGenerateContent_failure_unknownEnum_promptBlocked() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-unknown-enum-prompt-blocked",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )
    let unknownBlockReason = PromptFeedback.BlockReason(rawValue: "FAKE_NEW_BLOCK_REASON")

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.promptBlocked(response) {
      let promptFeedback = try XCTUnwrap(response.promptFeedback)
      XCTAssertEqual(promptFeedback.blockReason, unknownBlockReason)
    } catch {
      XCTFail("Should throw a promptBlocked")
    }
  }

  func testGenerateContent_failure_unknownModel() async throws {
    let expectedStatusCode = 404
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-unknown-model",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        statusCode: 404
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(underlying: rpcError as BackendError) {
      XCTAssertEqual(rpcError.status, .notFound)
      XCTAssertEqual(rpcError.httpResponseCode, expectedStatusCode)
      XCTAssertTrue(rpcError.message.hasPrefix("models/unknown is not found"))
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_nonHTTPResponse() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.nonHTTPRequestHandler()

    var responseError: Error?
    var content: GenerateContentResponse?
    do {
      content = try await model.generateContent(testPrompt)
    } catch {
      responseError = error
    }

    XCTAssertNil(content)
    XCTAssertNotNil(responseError)
    let generateContentError = try XCTUnwrap(responseError as? GenerateContentError)
    guard case let .internalError(underlyingError) = generateContentError else {
      XCTFail("Should be an internal error: \(generateContentError)")
      return
    }
    XCTAssertEqual(underlyingError.localizedDescription, "Response was not an HTTP response.")
    let underlyingNSError = underlyingError as NSError
    XCTAssertEqual(underlyingNSError.domain, NSURLErrorDomain)
    XCTAssertEqual(underlyingNSError.code, URLError.Code.badServerResponse.rawValue)
  }

  func testGenerateContent_failure_invalidResponse() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-invalid-response",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    var responseError: Error?
    var content: GenerateContentResponse?
    do {
      content = try await model.generateContent(testPrompt)
    } catch {
      responseError = error
    }

    XCTAssertNil(content)
    XCTAssertNotNil(responseError)
    let generateContentError = try XCTUnwrap(responseError as? GenerateContentError)
    guard case let .internalError(underlyingError) = generateContentError else {
      XCTFail("Should be an internal error: \(generateContentError)")
      return
    }
    let decodingError = try XCTUnwrap(underlyingError as? DecodingError)
    guard case let .dataCorrupted(context) = decodingError else {
      XCTFail("Should be a data corrupted error: \(decodingError)")
      return
    }
    XCTAssert(context.debugDescription.hasPrefix("Failed to decode GenerateContentResponse"))
  }

  func testGenerateContent_failure_malformedContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        // Note: Although this file does not contain `parts` in `content`, it is not actually
        // malformed. The `invalid-field` in the payload could be added, as a non-breaking change to
        // the proto API. Therefore, this test checks for the `emptyContent` error instead.
        forResource: "unary-failure-malformed-content",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    var responseError: Error?
    var content: GenerateContentResponse?
    do {
      content = try await model.generateContent(testPrompt)
    } catch {
      responseError = error
    }

    XCTAssertNil(content)
    XCTAssertNotNil(responseError)
    let generateContentError = try XCTUnwrap(responseError as? GenerateContentError)
    guard case let .internalError(underlyingError) = generateContentError else {
      XCTFail("Should be an internal error: \(generateContentError)")
      return
    }
    let invalidCandidateError = try XCTUnwrap(underlyingError as? InvalidCandidateError)
    guard case let .emptyContent(emptyContentUnderlyingError) = invalidCandidateError else {
      XCTFail("Should be an empty content error: \(invalidCandidateError)")
      return
    }
    _ = try XCTUnwrap(
      emptyContentUnderlyingError as? Candidate.EmptyContentError,
      "Should be an empty content error: \(emptyContentUnderlyingError)"
    )
  }

  func testGenerateContentMissingSafetyRatings() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-missing-safety-ratings",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let content = try await model.generateContent(testPrompt)
    let promptFeedback = try XCTUnwrap(content.promptFeedback)
    XCTAssertEqual(promptFeedback.safetyRatings.count, 0)
    XCTAssertEqual(content.text, "This is the generated content.")
  }

  func testGenerateContent_requestOptions_customTimeout() async throws {
    let expectedTimeout = 150.0
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: requestOptions,
      urlSession: urlSession
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
  }

  // MARK: - Generate Content (Streaming)

  func testGenerateContentStream_failureInvalidAPIKey() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-api-key",
        withExtension: "json",
        subdirectory: vertexSubdirectory
      )

    do {
      let stream = try model.generateContentStream("Hi")
      for try await _ in stream {
        XCTFail("No content is there, this shouldn't happen.")
      }
    } catch let GenerateContentError.internalError(error as BackendError) {
      XCTAssertEqual(error.httpResponseCode, 400)
      XCTAssertEqual(error.status, .invalidArgument)
      XCTAssertEqual(error.message, "API key not valid. Please pass a valid API key.")
      XCTAssertTrue(error.localizedDescription.contains(error.message))
      XCTAssertTrue(error.localizedDescription.contains(error.status.rawValue))
      XCTAssertTrue(error.localizedDescription.contains("\(error.httpResponseCode)"))
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, "\(Constants.baseErrorDomain).\(BackendError.self)")
      XCTAssertEqual(nsError.code, error.httpResponseCode)
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failure_vertexAIInFirebaseAPINotEnabled() async throws {
    let expectedStatusCode = 403
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-failure-firebasevertexai-api-not-enabled",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        statusCode: expectedStatusCode
      )

    do {
      let stream = try model.generateContentStream(testPrompt)
      for try await _ in stream {
        XCTFail("No content is there, this shouldn't happen.")
      }
    } catch let GenerateContentError.internalError(error as BackendError) {
      XCTAssertEqual(error.httpResponseCode, expectedStatusCode)
      XCTAssertEqual(error.status, .permissionDenied)
      XCTAssertTrue(error.message
        .starts(with: "Vertex AI in Firebase API has not been used in project"))
      XCTAssertTrue(error.isVertexAIInFirebaseServiceDisabledError())
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failureEmptyContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-empty-content",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    do {
      let stream = try model.generateContentStream("Hi")
      for try await _ in stream {
        XCTFail("No content is there, this shouldn't happen.")
      }
    } catch GenerateContentError.internalError(_ as InvalidCandidateError) {
      // Underlying error is as expected, nothing else to check.
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failureFinishReasonSafety() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-finish-reason-safety",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    do {
      let stream = try model.generateContentStream("Hi")
      for try await _ in stream {
        XCTFail("Content shouldn't be shown, this shouldn't happen.")
      }
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, .safety)
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertEqual(candidate.finishReason, reason)
      XCTAssertTrue(candidate.safetyRatings.contains { $0.blocked })
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failurePromptBlockedSafety() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-prompt-blocked-safety",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    do {
      let stream = try model.generateContentStream("Hi")
      for try await _ in stream {
        XCTFail("Content shouldn't be shown, this shouldn't happen.")
      }
    } catch let GenerateContentError.promptBlocked(response) {
      let promptFeedback = try XCTUnwrap(response.promptFeedback)
      XCTAssertEqual(promptFeedback.blockReason, .safety)
      XCTAssertNil(promptFeedback.blockReasonMessage)
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failurePromptBlockedSafetyWithMessage() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-prompt-blocked-safety-with-message",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    do {
      let stream = try model.generateContentStream("Hi")
      for try await _ in stream {
        XCTFail("Content shouldn't be shown, this shouldn't happen.")
      }
    } catch let GenerateContentError.promptBlocked(response) {
      let promptFeedback = try XCTUnwrap(response.promptFeedback)
      XCTAssertEqual(promptFeedback.blockReason, .safety)
      XCTAssertEqual(promptFeedback.blockReasonMessage, "Reasons")
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_failureUnknownFinishEnum() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-unknown-finish-enum",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )
    let unknownFinishReason = FinishReason(rawValue: "FAKE_ENUM")

    let stream = try model.generateContentStream("Hi")
    do {
      for try await content in stream {
        XCTAssertNotNil(content.text)
      }
    } catch let GenerateContentError.responseStoppedEarly(reason, _) {
      XCTAssertEqual(reason, unknownFinishReason)
      return
    }

    XCTFail("Should have caught an error.")
  }

  func testGenerateContentStream_successBasicReplyLong() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-long",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    var responses = 0
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 4)
  }

  func testGenerateContentStream_successBasicReplyShort() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    var responses = 0
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 1)
  }

  func testGenerateContentStream_successUnknownSafetyEnum() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-unknown-safety-enum",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )
    let unknownSafetyRating = SafetyRating(
      category: HarmCategory(rawValue: "HARM_CATEGORY_DANGEROUS_CONTENT_NEW_ENUM"),
      probability: SafetyRating.HarmProbability(rawValue: "NEGLIGIBLE_UNKNOWN_ENUM"),
      probabilityScore: 0.0,
      severity: SafetyRating.HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
      severityScore: 0.0,
      blocked: false
    )

    var foundUnknownSafetyRating = false
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      if let ratings = content.candidates.first?.safetyRatings,
         ratings.contains(where: { $0 == unknownSafetyRating }) {
        foundUnknownSafetyRating = true
      }
    }

    XCTAssertTrue(foundUnknownSafetyRating)
  }

  func testGenerateContentStream_successWithCitations() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-citations",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )
    let expectedPublicationDate = DateComponents(
      calendar: Calendar(identifier: .gregorian),
      year: 2014,
      month: 3,
      day: 30
    )

    let stream = try model.generateContentStream("Hi")
    var citations = [Citation]()
    var responses = [GenerateContentResponse]()
    for try await content in stream {
      responses.append(content)
      XCTAssertNotNil(content.text)
      let candidate = try XCTUnwrap(content.candidates.first)
      if let sources = candidate.citationMetadata?.citations {
        citations.append(contentsOf: sources)
      }
    }

    let lastCandidate = try XCTUnwrap(responses.last?.candidates.first)
    XCTAssertEqual(lastCandidate.finishReason, .stop)
    XCTAssertEqual(citations.count, 6)
    XCTAssertTrue(citations
      .contains {
        $0.startIndex == 0 && $0.endIndex == 128
          && $0.uri == "https://www.example.com/some-citation-1" && $0.title == nil
          && $0.license == nil && $0.publicationDate == nil
      })
    XCTAssertTrue(citations
      .contains {
        $0.startIndex == 130 && $0.endIndex == 265 && $0.uri == nil
          && $0.title == "some-citation-2" && $0.license == nil
          && $0.publicationDate == expectedPublicationDate
      })
    XCTAssertTrue(citations
      .contains {
        $0.startIndex == 272 && $0.endIndex == 431
          && $0.uri == "https://www.example.com/some-citation-3" && $0.title == nil
          && $0.license == "mit" && $0.publicationDate == nil
      })
    XCTAssertFalse(citations.contains { $0.uri?.isEmpty ?? false })
    XCTAssertFalse(citations.contains { $0.title?.isEmpty ?? false })
    XCTAssertFalse(citations.contains { $0.license?.isEmpty ?? false })
  }

  func testGenerateContentStream_successWithThinking_thoughtSummary() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-thinking-reply-thought-summary",
      withExtension: "txt",
      subdirectory: vertexSubdirectory
    )

    var thoughtSummary = ""
    var text = ""
    let stream = try model.generateContentStream("Hi")
    for try await response in stream {
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertEqual(candidate.content.parts.count, 1)
      let part = try XCTUnwrap(candidate.content.parts.first)
      let textPart = try XCTUnwrap(part as? TextPart)
      if textPart.isThought {
        let newThought = try XCTUnwrap(response.thoughtSummary)
        thoughtSummary.append(newThought)
      } else {
        text.append(textPart.text)
      }
    }

    XCTAssertTrue(thoughtSummary.hasPrefix("**Understanding the Core Question**"))
    XCTAssertTrue(text.hasPrefix("The sky is blue due to a phenomenon"))
  }

  func testGenerateContentStream_success_codeExecution() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-code-execution",
      withExtension: "txt",
      subdirectory: vertexSubdirectory
    )

    var parts = [any Part]()
    let stream = try model.generateContentStream(testPrompt)
    for try await response in stream {
      if let responseParts = response.candidates.first?.content.parts {
        parts.append(contentsOf: responseParts)
      }
    }

    let thoughtParts = parts.filter { $0.isThought }
    XCTAssertEqual(thoughtParts.count, 0)
    let textParts = parts.filter { $0 is TextPart }
    XCTAssertGreaterThan(textParts.count, 0)
    let executableCodeParts = parts.compactMap { $0 as? ExecutableCodePart }
    XCTAssertEqual(executableCodeParts.count, 1)
    let executableCodePart = try XCTUnwrap(executableCodeParts.first)
    XCTAssertFalse(executableCodePart.isThought)
    XCTAssertEqual(executableCodePart.language, .python)
    XCTAssertTrue(executableCodePart.code.starts(with: "prime_numbers = [2, 3, 5, 7, 11]"))
    let codeExecutionResultParts = parts.compactMap { $0 as? CodeExecutionResultPart }
    XCTAssertEqual(codeExecutionResultParts.count, 1)
    let codeExecutionResultPart = try XCTUnwrap(codeExecutionResultParts.first)
    XCTAssertFalse(codeExecutionResultPart.isThought)
    XCTAssertEqual(codeExecutionResultPart.outcome, .ok)
    XCTAssertEqual(codeExecutionResultPart.output, "The sum of the first 5 prime numbers is: 28\n")
  }

  func testGenerateContentStream_successWithInvalidSafetyRatingsIgnored() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-image-invalid-safety-ratings",
      withExtension: "txt",
      subdirectory: vertexSubdirectory
    )

    let stream = try model.generateContentStream(testPrompt)
    var responses = [GenerateContentResponse]()
    for try await content in stream {
      responses.append(content)
    }

    let response = try XCTUnwrap(responses.first)
    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.safetyRatings.sorted(), safetyRatingsInvalidIgnored)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let inlineDataParts = response.inlineDataParts
    XCTAssertEqual(inlineDataParts.count, 1)
    let imagePart = try XCTUnwrap(inlineDataParts.first)
    XCTAssertEqual(imagePart.mimeType, "image/png")
    XCTAssertGreaterThan(imagePart.data.count, 0)
  }

  func testGenerateContentStream_appCheck_validToken() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(token: appCheckToken)
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        subdirectory: vertexSubdirectory,
        appCheckToken: appCheckToken
      )

    let stream = try model.generateContentStream(testPrompt)
    for try await _ in stream {}
  }

  func testGenerateContentStream_appCheck_tokenRefreshError() async throws {
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(
        appCheck: AppCheckInteropFake(error: AppCheckErrorFake())
      ),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        subdirectory: vertexSubdirectory,
        appCheckToken: AppCheckInteropFake.placeholderTokenValue
      )

    let stream = try model.generateContentStream(testPrompt)
    for try await _ in stream {}
  }

  func testGenerateContentStream_usageMetadata() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )
    var responses = [GenerateContentResponse]()

    let stream = try model.generateContentStream(testPrompt)
    for try await response in stream {
      responses.append(response)
    }

    for (index, response) in responses.enumerated() {
      if index == responses.endIndex - 1 {
        let usageMetadata = try XCTUnwrap(response.usageMetadata)
        XCTAssertEqual(usageMetadata.promptTokenCount, 6)
        XCTAssertEqual(usageMetadata.candidatesTokenCount, 4)
        XCTAssertEqual(usageMetadata.totalTokenCount, 10)
      } else {
        // Only the last streamed response contains usage metadata
        XCTAssertNil(response.usageMetadata)
      }
    }
  }

  func testGenerateContentStream_errorMidStream() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-failure-error-mid-stream",
      withExtension: "txt",
      subdirectory: vertexSubdirectory
    )

    var responseCount = 0
    do {
      let stream = try model.generateContentStream("Hi")
      for try await content in stream {
        XCTAssertNotNil(content.text)
        responseCount += 1
      }
    } catch let GenerateContentError.internalError(rpcError as BackendError) {
      XCTAssertEqual(rpcError.httpResponseCode, 499)
      XCTAssertEqual(rpcError.status, .cancelled)

      // Check the content count is correct.
      XCTAssertEqual(responseCount, 2)
      return
    }

    XCTFail("Expected an internalError with an RPCError.")
  }

  func testGenerateContentStream_nonHTTPResponse() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.nonHTTPRequestHandler()

    let stream = try model.generateContentStream("Hi")
    do {
      for try await content in stream {
        XCTFail("Unexpected content in stream: \(content)")
      }
    } catch let GenerateContentError.internalError(underlying) {
      XCTAssertEqual(underlying.localizedDescription, "Response was not an HTTP response.")
      return
    }

    XCTFail("Expected an internal error.")
  }

  func testGenerateContentStream_invalidResponse() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-failure-invalid-json",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    let stream = try model.generateContentStream(testPrompt)
    do {
      for try await content in stream {
        XCTFail("Unexpected content in stream: \(content)")
      }
    } catch let GenerateContentError.internalError(underlying as DecodingError) {
      guard case let .dataCorrupted(context) = underlying else {
        XCTFail("Should be a data corrupted error: \(underlying)")
        return
      }
      XCTAssert(context.debugDescription.hasPrefix("Failed to decode GenerateContentResponse"))
      return
    }

    XCTFail("Expected an internal error.")
  }

  func testGenerateContentStream_malformedContent() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        // Note: Although this file does not contain `parts` in `content`, it is not actually
        // malformed. The `invalid-field` in the payload could be added, as a non-breaking change to
        // the proto API. Therefore, this test checks for the `emptyContent` error instead.
        forResource: "streaming-failure-malformed-content",
        withExtension: "txt",
        subdirectory: vertexSubdirectory
      )

    let stream = try model.generateContentStream(testPrompt)
    do {
      for try await content in stream {
        XCTFail("Unexpected content in stream: \(content)")
      }
    } catch let GenerateContentError.internalError(underlyingError as InvalidCandidateError) {
      guard case let .emptyContent(contentError) = underlyingError else {
        XCTFail("Should be an empty content error: \(underlyingError)")
        return
      }

      XCTAssert(contentError is Candidate.EmptyContentError)
      return
    }

    XCTFail("Expected an internal decoding error.")
  }

  func testGenerateContentStream_requestOptions_customTimeout() async throws {
    let expectedTimeout = 150.0
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        subdirectory: vertexSubdirectory,
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: requestOptions,
      urlSession: urlSession
    )

    var responses = 0
    let stream = try model.generateContentStream(testPrompt)
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 1)
  }

  func testGenerateContentStream_success_urlContext() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-url-context",
      withExtension: "txt",
      subdirectory: vertexSubdirectory
    )

    var responses = [GenerateContentResponse]()
    let stream = try model.generateContentStream(testPrompt)
    for try await response in stream {
      responses.append(response)
    }

    let firstResponse = try XCTUnwrap(responses.first)
    let candidate = try XCTUnwrap(firstResponse.candidates.first)
    let urlContextMetadata = try XCTUnwrap(candidate.urlContextMetadata)
    XCTAssertEqual(urlContextMetadata.urlMetadata.count, 1)
    let urlMetadata = try XCTUnwrap(urlContextMetadata.urlMetadata.first)
    let retrievedURL = try XCTUnwrap(urlMetadata.retrievedURL)
    XCTAssertEqual(retrievedURL, URL(string: "https://google.com"))
    XCTAssertEqual(urlMetadata.retrievalStatus, .success)
  }

  // MARK: - Count Tokens

  func testCountTokens_succeeds() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-total-tokens",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.countTokens("Why is the sky blue?")

    XCTAssertEqual(response.totalTokens, 6)
  }

  func testCountTokens_succeeds_detailed() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-detailed-token-response",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.countTokens("Why is the sky blue?")

    XCTAssertEqual(response.totalTokens, 1837)
    XCTAssertEqual(response.promptTokensDetails.count, 2)
    XCTAssertEqual(response.promptTokensDetails[0].modality, .image)
    XCTAssertEqual(response.promptTokensDetails[0].tokenCount, 1806)
    XCTAssertEqual(response.promptTokensDetails[1].modality, .text)
    XCTAssertEqual(response.promptTokensDetails[1].tokenCount, 31)
  }

  func testCountTokens_succeeds_allOptions() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-total-tokens",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )
    let generationConfig = GenerationConfig(
      temperature: 0.5,
      topP: 0.9,
      topK: 3,
      candidateCount: 1,
      maxOutputTokens: 1024,
      stopSequences: ["test-stop"],
      responseMIMEType: "text/plain"
    )
    let sumFunction = FunctionDeclaration(
      name: "sum",
      description: "Add two integers.",
      parameters: ["x": .integer(), "y": .integer()]
    )
    let systemInstruction = ModelContent(
      role: "system",
      parts: "You are a calculator. Use the provided tools."
    )
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      generationConfig: generationConfig,
      tools: [Tool(functionDeclarations: [sumFunction])],
      systemInstruction: systemInstruction,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let response = try await model.countTokens("Why is the sky blue?")

    XCTAssertEqual(response.totalTokens, 6)
  }

  func testCountTokens_succeeds_noBillableCharacters() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-no-billable-characters",
      withExtension: "json",
      subdirectory: vertexSubdirectory
    )

    let response = try await model.countTokens(InlineDataPart(data: Data(), mimeType: "image/jpeg"))

    XCTAssertEqual(response.totalTokens, 258)
  }

  func testCountTokens_modelNotFound() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-model-not-found", withExtension: "json",
      subdirectory: vertexSubdirectory,
      statusCode: 404
    )

    do {
      _ = try await model.countTokens("Why is the sky blue?")
      XCTFail("Request should not have succeeded.")
    } catch let rpcError as BackendError {
      XCTAssertEqual(rpcError.httpResponseCode, 404)
      XCTAssertEqual(rpcError.status, .notFound)
      XCTAssert(rpcError.message.hasPrefix("models/test-model-name is not found"))
      return
    }

    XCTFail("Expected internal RPCError.")
  }

  func testCountTokens_requestOptions_customTimeout() async throws {
    let expectedTimeout = 150.0
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-total-tokens",
        withExtension: "json",
        subdirectory: vertexSubdirectory,
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      modelName: testModelName,
      modelResourceName: testModelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: apiConfig,
      tools: nil,
      requestOptions: requestOptions,
      urlSession: urlSession
    )

    let response = try await model.countTokens(testPrompt)

    XCTAssertEqual(response.totalTokens, 6)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension SafetyRating: Swift.Comparable {
  public static func < (lhs: SafetyRating, rhs: SafetyRating) -> Bool {
    return lhs.category.rawValue < rhs.category.rawValue
  }
}
