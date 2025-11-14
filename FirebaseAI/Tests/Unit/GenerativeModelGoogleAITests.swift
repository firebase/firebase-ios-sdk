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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerativeModelGoogleAITests: XCTestCase {
  let testPrompt = "What sorts of questions can I ask you?"
  let safetyRatingsNegligible: [SafetyRating] = [
    .init(
      category: .sexuallyExplicit,
      probability: .negligible,
      probabilityScore: 0.0,
      severity: SafetyRating.HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
      severityScore: 0.0,
      blocked: false
    ),
    .init(
      category: .hateSpeech,
      probability: .negligible,
      probabilityScore: 0.0,
      severity: SafetyRating.HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
      severityScore: 0.0,
      blocked: false
    ),
    .init(
      category: .harassment,
      probability: .negligible,
      probabilityScore: 0.0,
      severity: SafetyRating.HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
      severityScore: 0.0,
      blocked: false
    ),
    .init(
      category: .dangerousContent,
      probability: .negligible,
      probabilityScore: 0.0,
      severity: SafetyRating.HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED"),
      severityScore: 0.0,
      blocked: false
    ),
  ].sorted()
  let testModelName = "test-model"
  let testModelResourceName = "projects/test-project-id/models/test-model"
  let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

  let googleAISubdirectory = "mock-responses/googleai"

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
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-long",
      withExtension: "json",
      subdirectory: googleAISubdirectory
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
    XCTAssertTrue(partText.hasPrefix("Making professional-quality"))
    XCTAssertEqual(response.text, partText)
    XCTAssertEqual(response.functionCalls, [])
    XCTAssertEqual(response.inlineDataParts, [])
  }

  func testGenerateContent_success_basicReplyShort() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: googleAISubdirectory
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
    XCTAssertTrue(textPart.text.hasPrefix("Google's headquarters"))
    XCTAssertEqual(response.text, textPart.text)
    XCTAssertEqual(response.functionCalls, [])
    XCTAssertEqual(response.inlineDataParts, [])
  }

  func testGenerateContent_success_citations() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-citations",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 1)
    let text = try XCTUnwrap(response.text)
    XCTAssertTrue(text.hasPrefix("Okay, let's break down quantum mechanics."))
    let citationMetadata = try XCTUnwrap(candidate.citationMetadata)
    XCTAssertEqual(citationMetadata.citations.count, 4)
    let citationSource1 = try XCTUnwrap(citationMetadata.citations[0])
    XCTAssertEqual(citationSource1.uri, "https://www.example.com/some-citation-1")
    XCTAssertEqual(citationSource1.startIndex, 548)
    XCTAssertEqual(citationSource1.endIndex, 690)
    XCTAssertNil(citationSource1.title)
    XCTAssertEqual(citationSource1.license, "mit")
    XCTAssertNil(citationSource1.publicationDate)
    let citationSource2 = try XCTUnwrap(citationMetadata.citations[1])
    XCTAssertEqual(citationSource2.uri, "https://www.example.com/some-citation-1")
    XCTAssertEqual(citationSource2.startIndex, 1240)
    XCTAssertEqual(citationSource2.endIndex, 1407)
    XCTAssertNil(citationSource2.title, "some-citation-2")
    XCTAssertNil(citationSource2.license)
    XCTAssertNil(citationSource2.publicationDate)
    let citationSource3 = try XCTUnwrap(citationMetadata.citations[2])
    XCTAssertEqual(citationSource3.startIndex, 1942)
    XCTAssertEqual(citationSource3.endIndex, 2149)
    XCTAssertNil(citationSource3.uri)
    XCTAssertNil(citationSource3.license)
    XCTAssertNil(citationSource3.title)
    XCTAssertNil(citationSource3.publicationDate)
    let citationSource4 = try XCTUnwrap(citationMetadata.citations[3])
    XCTAssertEqual(citationSource4.startIndex, 2036)
    XCTAssertEqual(citationSource4.endIndex, 2175)
    XCTAssertNil(citationSource4.uri)
    XCTAssertNil(citationSource4.license)
    XCTAssertNil(citationSource4.title)
    XCTAssertNil(citationSource4.publicationDate)
  }

  func testGenerateContent_usageMetadata() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokenCount, 7)
    XCTAssertEqual(usageMetadata.promptTokensDetails.count, 1)
    XCTAssertEqual(usageMetadata.promptTokensDetails[0].modality, .text)
    XCTAssertEqual(usageMetadata.promptTokensDetails[0].tokenCount, 7)
    XCTAssertEqual(usageMetadata.candidatesTokenCount, 22)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails.count, 1)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails[0].modality, .text)
    XCTAssertEqual(usageMetadata.candidatesTokensDetails[0].tokenCount, 22)
  }

  func testGenerateContent_groundingMetadata() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-search-grounding",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)

    XCTAssertEqual(groundingMetadata.webSearchQueries, ["current weather in London"])
    let searchEntryPoint = try XCTUnwrap(groundingMetadata.searchEntryPoint)
    XCTAssertFalse(searchEntryPoint.renderedContent.isEmpty)

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

  // This test case can be deleted once https://b.corp.google.com/issues/422779395 (internal) is
  // fixed.
  func testGenerateContent_groundingMetadata_emptyGroundingChunks() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-google-search-grounding-empty-grounding-chunks",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let groundingMetadata = try XCTUnwrap(candidate.groundingMetadata)
    XCTAssertNotNil(groundingMetadata.searchEntryPoint)
    XCTAssertEqual(groundingMetadata.webSearchQueries, ["current weather London"])

    // Chunks exist, but contain no web information.
    XCTAssertEqual(groundingMetadata.groundingChunks.count, 2)
    XCTAssertNil(groundingMetadata.groundingChunks[0].web)
    XCTAssertNil(groundingMetadata.groundingChunks[1].web)

    XCTAssertEqual(groundingMetadata.groundingSupports.count, 1)
    let support = try XCTUnwrap(groundingMetadata.groundingSupports.first)
    XCTAssertEqual(support.groundingChunkIndices, [0])
    XCTAssertEqual(
      support.segment.text,
      "There is a 0% chance of rain and the humidity is around 41%."
    )
  }

  func testGenerateContent_success_thinking_thoughtSummary() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-thinking-reply-thought-summary",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.content.parts.count, 2)
    let thoughtPart = try XCTUnwrap(candidate.content.parts.first as? TextPart)
    XCTAssertTrue(thoughtPart.isThought)
    XCTAssertTrue(thoughtPart.text.hasPrefix("**Thinking About Google's Headquarters**"))
    XCTAssertEqual(thoughtPart.text, response.thoughtSummary)
    let textPart = try XCTUnwrap(candidate.content.parts.last as? TextPart)
    XCTAssertFalse(textPart.isThought)
    XCTAssertEqual(textPart.text, "Mountain View")
    XCTAssertEqual(textPart.text, response.text)
  }

  func testGenerateContent_success_thinking_functionCall_thoughtSummaryAndSignature() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-thinking-function-call-thought-summary-signature",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    XCTAssertEqual(candidate.finishReason, .stop)
    XCTAssertEqual(candidate.content.parts.count, 2)
    let thoughtPart = try XCTUnwrap(candidate.content.parts.first as? TextPart)
    XCTAssertTrue(thoughtPart.isThought)
    XCTAssertTrue(thoughtPart.text.hasPrefix("**Thinking Through the New Year's Eve Calculation**"))
    let functionCallPart = try XCTUnwrap(candidate.content.parts.last as? FunctionCallPart)
    XCTAssertFalse(functionCallPart.isThought)
    XCTAssertEqual(functionCallPart.name, "now")
    XCTAssertTrue(functionCallPart.args.isEmpty)
    let thoughtSignature = try XCTUnwrap(functionCallPart.thoughtSignature)
    XCTAssertTrue(thoughtSignature.hasPrefix("CtQOAVSoXO74PmYr9AFu"))
  }

  func testGenerateContent_success_codeExecution() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-code-execution",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
    let candidate = try XCTUnwrap(response.candidates.first)
    let parts = candidate.content.parts
    XCTAssertEqual(candidate.finishReason, .stop)
    XCTAssertEqual(parts.count, 3)
    let executableCodePart = try XCTUnwrap(parts[0] as? ExecutableCodePart)
    XCTAssertFalse(executableCodePart.isThought)
    XCTAssertEqual(executableCodePart.language, .python)
    XCTAssertTrue(executableCodePart.code.starts(with: "prime_numbers = [2, 3, 5, 7, 11]"))
    let codeExecutionResultPart = try XCTUnwrap(parts[1] as? CodeExecutionResultPart)
    XCTAssertFalse(codeExecutionResultPart.isThought)
    XCTAssertEqual(codeExecutionResultPart.outcome, .ok)
    XCTAssertEqual(codeExecutionResultPart.output, "sum_of_primes=28\n")
    let textPart = try XCTUnwrap(parts[2] as? TextPart)
    XCTAssertFalse(textPart.isThought)
    XCTAssertTrue(textPart.text.hasPrefix("The first 5 prime numbers are 2, 3, 5, 7, and 11."))
    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.toolUsePromptTokenCount, 160)
  }

  func testGenerateContent_success_urlContext() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-url-context",
      withExtension: "json",
      subdirectory: googleAISubdirectory
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
    XCTAssertEqual(usageMetadata.toolUsePromptTokenCount, 424)
  }

  func testGenerateContent_success_urlContext_mixedValidity() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-url-context-mixed-validity",
      withExtension: "json",
      subdirectory: googleAISubdirectory
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

  func testGenerateContent_failure_invalidAPIKey() async throws {
    let expectedStatusCode = 400
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-api-key",
      withExtension: "json",
      subdirectory: googleAISubdirectory,
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

  func testGenerateContent_failure_finishReasonSafety() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-finish-reason-safety",
      withExtension: "json",
      subdirectory: googleAISubdirectory
    )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw")
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, .safety)
      XCTAssertEqual(response.text, "Safety error incoming in 5, 4, 3, 2...")
    } catch {
      XCTFail("Should throw a responseStoppedEarly")
    }
  }

  func testGenerateContent_failure_unknownModel() async throws {
    let expectedStatusCode = 404
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-unknown-model",
      withExtension: "json",
      subdirectory: googleAISubdirectory,
      statusCode: 404
    )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError.internalError(underlying: rpcError as BackendError) {
      XCTAssertEqual(rpcError.status, .notFound)
      XCTAssertEqual(rpcError.httpResponseCode, expectedStatusCode)
      XCTAssertTrue(rpcError.message.hasPrefix("models/gemini-5.0-flash is not found"))
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }

  // MARK: - Generate Content (Streaming)

  func testGenerateContentStream_successBasicReplyLong() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-long",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    var responses = 0
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 36)
  }

  func testGenerateContentStream_successBasicReplyShort() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    var responses = 0
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 3)
  }

  func testGenerateContentStream_successWithCitations() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-citations",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
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
    XCTAssertEqual(citations.count, 1)
    let citation = try XCTUnwrap(citations.first)
    XCTAssertEqual(citation.startIndex, 111)
    XCTAssertEqual(citation.endIndex, 236)
    let citationURI = try XCTUnwrap(citation.uri)
    XCTAssertTrue(citationURI.starts(with: "https://www."))
    XCTAssertNil(citation.license)
    XCTAssertNil(citation.title)
    XCTAssertNil(citation.publicationDate)
  }

  func testGenerateContentStream_successWithThoughtSummary() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-thinking-reply-thought-summary",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    var thoughtSummary = ""
    var text = ""
    let stream = try model.generateContentStream("Hi")
    for try await response in stream {
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertEqual(candidate.content.parts.count, 1)
      let textPart = try XCTUnwrap(candidate.content.parts.first as? TextPart)
      if textPart.isThought {
        let newThought = try XCTUnwrap(response.thoughtSummary)
        XCTAssertEqual(textPart.text, newThought)
        thoughtSummary.append(newThought)
      } else {
        let newText = try XCTUnwrap(response.text)
        XCTAssertEqual(textPart.text, newText)
        text.append(newText)
      }
    }

    XCTAssertTrue(thoughtSummary.hasPrefix("**Exploring Sky Color**"))
    XCTAssertTrue(text.hasPrefix("The sky is blue because"))
  }

  func testGenerateContentStream_success_thinking_functionCall_thoughtSummary_signature() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-thinking-function-call-thought-summary-signature",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    var thoughtSummary = ""
    var functionCalls: [FunctionCallPart] = []
    let stream = try model.generateContentStream("Hi")
    for try await response in stream {
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertEqual(candidate.content.parts.count, 1)
      let part = try XCTUnwrap(candidate.content.parts.first)
      if part.isThought {
        let textPart = try XCTUnwrap(part as? TextPart)
        let newThought = try XCTUnwrap(response.thoughtSummary)
        XCTAssertEqual(textPart.text, newThought)
        thoughtSummary.append(newThought)
      } else {
        let functionCallPart = try XCTUnwrap(part as? FunctionCallPart)
        XCTAssertEqual(response.functionCalls.count, 1)
        let newFunctionCall = try XCTUnwrap(response.functionCalls.first)
        XCTAssertEqual(functionCallPart, newFunctionCall)
        functionCalls.append(newFunctionCall)
      }
    }

    XCTAssertTrue(thoughtSummary.hasPrefix("**Calculating the Days**"))
    XCTAssertEqual(functionCalls.count, 1)
    let functionCall = try XCTUnwrap(functionCalls.first)
    XCTAssertEqual(functionCall.name, "now")
    XCTAssertTrue(functionCall.args.isEmpty)
    let thoughtSignature = try XCTUnwrap(functionCall.thoughtSignature)
    XCTAssertTrue(thoughtSignature.hasPrefix("CiIBVKhc7vB+vaaq6rA"))
  }

  func testGenerateContentStream_success_ignoresEmptyParts() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-empty-parts",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    let stream = try model.generateContentStream("Hi")
    for try await response in stream {
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertGreaterThan(candidate.content.parts.count, 0)
      let text = response.text
      let inlineData = response.inlineDataParts.first
      XCTAssertTrue(text != nil || inlineData != nil, "Response did not contain text or data")
    }
  }

  func testGenerateContentStream_success_codeExecution() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-code-execution",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
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

  func testGenerateContentStream_failureInvalidAPIKey() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-failure-api-key",
      withExtension: "json",
      subdirectory: googleAISubdirectory
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

  func testGenerateContentStream_failureFinishRecitation() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-failure-recitation-no-content",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
    )

    var responses = [GenerateContentResponse]()
    do {
      let stream = try model.generateContentStream("Hi")
      for try await response in stream {
        responses.append(response)
      }
      XCTFail("Expected a GenerateContentError.responseStoppedEarly error, but got no error.")
    } catch let GenerateContentError.responseStoppedEarly(reason, response) {
      XCTAssertEqual(reason, .recitation)
      let candidate = try XCTUnwrap(response.candidates.first)
      XCTAssertEqual(candidate.finishReason, reason)
    } catch {
      XCTFail("Expected a GenerateContentError.responseStoppedEarly error, but got error: \(error)")
    }

    XCTAssertEqual(responses.count, 8)
    let firstResponse = try XCTUnwrap(responses.first)
    XCTAssertEqual(firstResponse.text, "text1")
    let lastResponse = try XCTUnwrap(responses.last)
    XCTAssertEqual(lastResponse.text, "text8")
  }

  func testGenerateContentStream_success_urlContext() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-url-context",
      withExtension: "txt",
      subdirectory: googleAISubdirectory
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
}
