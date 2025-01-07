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

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class GenerativeModelTests: XCTestCase {
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
  let testModelResourceName =
    "projects/test-project-id/locations/test-location/publishers/google/models/test-model"

  var urlSession: URLSession!
  var model: GenerativeModel!

  override func setUp() async throws {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = try XCTUnwrap(URLSession(configuration: configuration))
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  // MARK: - Generate Content

  func testGenerateContent_success_basicReplyLong() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-long",
        withExtension: "json"
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
  }

  func testGenerateContent_success_basicReplyShort() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json"
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

  func testGenerateContent_success_citations() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-citations",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-quote-reply",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-unknown-enum-safety-ratings",
        withExtension: "json"
      )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.text, "Some text")
    XCTAssertEqual(response.candidates.first?.safetyRatings, expectedSafetyRatings)
    XCTAssertEqual(response.promptFeedback?.safetyRatings, expectedSafetyRatings)
  }

  func testGenerateContent_success_prefixedModelName() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json"
      )
    let model = GenerativeModel(
      // Model name is prefixed with "models/".
      name: "models/test-model",
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_success_functionCall_emptyArguments() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-function-call-empty-arguments",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-function-call-no-arguments",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-function-call-with-arguments",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-function-call-parallel-calls",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-function-call-mixed-content",
        withExtension: "json"
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

  func testGenerateContent_appCheck_validToken() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: AppCheckInteropFake(token: appCheckToken),
      auth: nil,
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        appCheckToken: appCheckToken
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_appCheck_tokenRefreshError() async throws {
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: AppCheckInteropFake(error: AppCheckErrorFake()),
      auth: nil,
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        appCheckToken: AppCheckInteropFake.placeholderTokenValue
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_validAuthToken() async throws {
    let authToken = "test-valid-token"
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: AuthInteropFake(token: authToken),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        authToken: authToken
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_nilAuthToken() async throws {
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: AuthInteropFake(token: nil),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        authToken: nil
      )

    _ = try await model.generateContent(testPrompt)
  }

  func testGenerateContent_auth_authTokenRefreshError() async throws {
    model = GenerativeModel(
      name: "my-model",
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: AuthInteropFake(error: AuthErrorFake()),
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json"
      )

    let response = try await model.generateContent(testPrompt)

    let usageMetadata = try XCTUnwrap(response.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokenCount, 6)
    XCTAssertEqual(usageMetadata.candidatesTokenCount, 7)
    XCTAssertEqual(usageMetadata.totalTokenCount, 13)
  }

  func testGenerateContent_failure_invalidAPIKey() async throws {
    let expectedStatusCode = 400
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-api-key",
        withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-firebasevertexai-api-not-enabled",
        withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-empty-content",
        withExtension: "json"
      )

    do {
      _ = try await model.generateContent(testPrompt)
      XCTFail("Should throw GenerateContentError.internalError; no error thrown.")
    } catch let GenerateContentError
      .internalError(underlying: invalidCandidateError as InvalidCandidateError) {
      guard case let .emptyContent(decodingError) = invalidCandidateError else {
        XCTFail("Not an InvalidCandidateError.emptyContent error: \(invalidCandidateError)")
        return
      }
      _ = try XCTUnwrap(decodingError as? DecodingError,
                        "Not a DecodingError: \(decodingError)")
    } catch {
      XCTFail("Should throw GenerateContentError.internalError; error thrown: \(error)")
    }
  }

  func testGenerateContent_failure_finishReasonSafety() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-finish-reason-safety",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-finish-reason-safety-no-content",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-image-rejected",
        withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-prompt-blocked-safety",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-prompt-blocked-safety-with-message",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-unknown-enum-finish-reason",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-unknown-enum-prompt-blocked",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-unknown-model",
        withExtension: "json",
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
    MockURLProtocol.requestHandler = try nonHTTPRequestHandler()

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
      XCTFail("Not an internal error: \(generateContentError)")
      return
    }
    XCTAssertEqual(underlyingError.localizedDescription, "Response was not an HTTP response.")
    let underlyingNSError = underlyingError as NSError
    XCTAssertEqual(underlyingNSError.domain, NSURLErrorDomain)
    XCTAssertEqual(underlyingNSError.code, URLError.Code.badServerResponse.rawValue)
  }

  func testGenerateContent_failure_invalidResponse() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-failure-invalid-response",
      withExtension: "json"
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
      XCTFail("Not an internal error: \(generateContentError)")
      return
    }
    let decodingError = try XCTUnwrap(underlyingError as? DecodingError)
    guard case let .dataCorrupted(context) = decodingError else {
      XCTFail("Not a data corrupted error: \(decodingError)")
      return
    }
    XCTAssert(context.debugDescription.hasPrefix("Failed to decode GenerateContentResponse"))
  }

  func testGenerateContent_failure_malformedContent() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-malformed-content",
        withExtension: "json"
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
      XCTFail("Not an internal error: \(generateContentError)")
      return
    }
    let invalidCandidateError = try XCTUnwrap(underlyingError as? InvalidCandidateError)
    guard case let .malformedContent(malformedContentUnderlyingError) = invalidCandidateError else {
      XCTFail("Not a malformed content error: \(invalidCandidateError)")
      return
    }
    _ = try XCTUnwrap(
      malformedContentUnderlyingError as? DecodingError,
      "Not a decoding error: \(malformedContentUnderlyingError)"
    )
  }

  func testGenerateContentMissingSafetyRatings() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-success-missing-safety-ratings",
      withExtension: "json"
    )

    let content = try await model.generateContent(testPrompt)
    let promptFeedback = try XCTUnwrap(content.promptFeedback)
    XCTAssertEqual(promptFeedback.safetyRatings.count, 0)
    XCTAssertEqual(content.text, "This is the generated content.")
  }

  func testGenerateContent_requestOptions_customTimeout() async throws {
    let expectedTimeout = 150.0
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-basic-reply-short",
        withExtension: "json",
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: requestOptions,
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )

    let response = try await model.generateContent(testPrompt)

    XCTAssertEqual(response.candidates.count, 1)
  }

  // MARK: - Generate Content (Streaming)

  func testGenerateContentStream_failureInvalidAPIKey() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-api-key",
        withExtension: "json"
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-failure-firebasevertexai-api-not-enabled",
        withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-empty-content",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-finish-reason-safety",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-prompt-blocked-safety",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-prompt-blocked-safety-with-message",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-unknown-finish-enum",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-long",
        withExtension: "txt"
      )

    var responses = 0
    let stream = try model.generateContentStream("Hi")
    for try await content in stream {
      XCTAssertNotNil(content.text)
      responses += 1
    }

    XCTAssertEqual(responses, 6)
  }

  func testGenerateContentStream_successBasicReplyShort() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-unknown-safety-enum",
        withExtension: "txt"
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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-citations",
        withExtension: "txt"
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

  func testGenerateContentStream_appCheck_validToken() async throws {
    let appCheckToken = "test-valid-token"
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: AppCheckInteropFake(token: appCheckToken),
      auth: nil,
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        appCheckToken: appCheckToken
      )

    let stream = try model.generateContentStream(testPrompt)
    for try await _ in stream {}
  }

  func testGenerateContentStream_appCheck_tokenRefreshError() async throws {
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: RequestOptions(),
      appCheck: AppCheckInteropFake(error: AppCheckErrorFake()),
      auth: nil,
      urlSession: urlSession
    )
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        appCheckToken: AppCheckInteropFake.placeholderTokenValue
      )

    let stream = try model.generateContentStream(testPrompt)
    for try await _ in stream {}
  }

  func testGenerateContentStream_usageMetadata() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt"
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
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "streaming-failure-error-mid-stream",
      withExtension: "txt"
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
    MockURLProtocol.requestHandler = try nonHTTPRequestHandler()

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
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-invalid-json",
        withExtension: "txt"
      )

    let stream = try model.generateContentStream(testPrompt)
    do {
      for try await content in stream {
        XCTFail("Unexpected content in stream: \(content)")
      }
    } catch let GenerateContentError.internalError(underlying as DecodingError) {
      guard case let .dataCorrupted(context) = underlying else {
        XCTFail("Not a data corrupted error: \(underlying)")
        return
      }
      XCTAssert(context.debugDescription.hasPrefix("Failed to decode GenerateContentResponse"))
      return
    }

    XCTFail("Expected an internal error.")
  }

  func testGenerateContentStream_malformedContent() async throws {
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-failure-malformed-content",
        withExtension: "txt"
      )

    let stream = try model.generateContentStream(testPrompt)
    do {
      for try await content in stream {
        XCTFail("Unexpected content in stream: \(content)")
      }
    } catch let GenerateContentError.internalError(underlyingError as InvalidCandidateError) {
      guard case let .malformedContent(contentError) = underlyingError else {
        XCTFail("Not a malformed content error: \(underlyingError)")
        return
      }

      XCTAssert(contentError is DecodingError)
      return
    }

    XCTFail("Expected an internal decoding error.")
  }

  func testGenerateContentStream_requestOptions_customTimeout() async throws {
    let expectedTimeout = 150.0
    MockURLProtocol
      .requestHandler = try httpRequestHandler(
        forResource: "streaming-success-basic-reply-short",
        withExtension: "txt",
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: requestOptions,
      appCheck: nil,
      auth: nil,
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

  // MARK: - Count Tokens

  func testCountTokens_succeeds() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-success-total-tokens",
      withExtension: "json"
    )

    let response = try await model.countTokens("Why is the sky blue?")

    XCTAssertEqual(response.totalTokens, 6)
    XCTAssertEqual(response.totalBillableCharacters, 16)
  }

  func testCountTokens_succeeds_allOptions() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-success-total-tokens",
      withExtension: "json"
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
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      generationConfig: generationConfig,
      tools: [Tool(functionDeclarations: [sumFunction])],
      systemInstruction: systemInstruction,
      requestOptions: RequestOptions(),
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )

    let response = try await model.countTokens("Why is the sky blue?")

    XCTAssertEqual(response.totalTokens, 6)
    XCTAssertEqual(response.totalBillableCharacters, 16)
  }

  func testCountTokens_succeeds_noBillableCharacters() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-success-no-billable-characters",
      withExtension: "json"
    )

    let response = try await model.countTokens(InlineDataPart(data: Data(), mimeType: "image/jpeg"))

    XCTAssertEqual(response.totalTokens, 258)
    XCTAssertNil(response.totalBillableCharacters)
  }

  func testCountTokens_modelNotFound() async throws {
    MockURLProtocol.requestHandler = try httpRequestHandler(
      forResource: "unary-failure-model-not-found", withExtension: "json",
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
      .requestHandler = try httpRequestHandler(
        forResource: "unary-success-total-tokens",
        withExtension: "json",
        timeout: expectedTimeout
      )
    let requestOptions = RequestOptions(timeout: expectedTimeout)
    model = GenerativeModel(
      name: testModelResourceName,
      projectID: "my-project-id",
      apiKey: "API_KEY",
      tools: nil,
      requestOptions: requestOptions,
      appCheck: nil,
      auth: nil,
      urlSession: urlSession
    )

    let response = try await model.countTokens(testPrompt)

    XCTAssertEqual(response.totalTokens, 6)
  }

  // MARK: - Helpers

  private func nonHTTPRequestHandler() throws -> ((URLRequest) -> (
    URLResponse,
    AsyncLineSequence<URL.AsyncBytes>?
  )) {
    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #endif // os(watchOS)
    return { request in
      // This is *not* an HTTPURLResponse
      let response = URLResponse(
        url: request.url!,
        mimeType: nil,
        expectedContentLength: 0,
        textEncodingName: nil
      )
      return (response, nil)
    }
  }

  private func httpRequestHandler(forResource name: String,
                                  withExtension ext: String,
                                  statusCode: Int = 200,
                                  timeout: TimeInterval = RequestOptions().timeout,
                                  appCheckToken: String? = nil,
                                  authToken: String? = nil) throws -> ((URLRequest) throws -> (
    URLResponse,
    AsyncLineSequence<URL.AsyncBytes>?
  )) {
    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #endif // os(watchOS)
    let bundle = BundleTestUtil.bundle()
    let fileURL = try XCTUnwrap(bundle.url(forResource: name, withExtension: ext))
    return { request in
      let requestURL = try XCTUnwrap(request.url)
      XCTAssertEqual(requestURL.path.occurrenceCount(of: "models/"), 1)
      XCTAssertEqual(request.timeoutInterval, timeout)
      let apiClientTags = try XCTUnwrap(request.value(forHTTPHeaderField: "x-goog-api-client"))
        .components(separatedBy: " ")
      XCTAssert(apiClientTags.contains(GenerativeAIService.languageTag))
      XCTAssert(apiClientTags.contains(GenerativeAIService.firebaseVersionTag))
      XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), appCheckToken)
      if let authToken {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Firebase \(authToken)")
      } else {
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
      }
      let response = try XCTUnwrap(HTTPURLResponse(
        url: requestURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      ))
      return (response, fileURL.lines)
    }
  }
}

private extension String {
  /// Returns the number of occurrences of `substring` in the `String`.
  func occurrenceCount(of substring: String) -> Int {
    return components(separatedBy: substring).count - 1
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
class AppCheckInteropFake: NSObject, AppCheckInterop {
  /// The placeholder token value returned when an error occurs
  static let placeholderTokenValue = "placeholder-token"

  var token: String
  var error: Error?

  private init(token: String, error: Error?) {
    self.token = token
    self.error = error
  }

  convenience init(token: String) {
    self.init(token: token, error: nil)
  }

  convenience init(error: Error) {
    self.init(token: AppCheckInteropFake.placeholderTokenValue, error: error)
  }

  func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop {
    return AppCheckTokenResultInteropFake(token: token, error: error)
  }

  func tokenDidChangeNotificationName() -> String {
    fatalError("\(#function) not implemented.")
  }

  func notificationTokenKey() -> String {
    fatalError("\(#function) not implemented.")
  }

  func notificationAppNameKey() -> String {
    fatalError("\(#function) not implemented.")
  }

  private class AppCheckTokenResultInteropFake: NSObject, FIRAppCheckTokenResultInterop {
    var token: String
    var error: Error?

    init(token: String, error: Error?) {
      self.token = token
      self.error = error
    }
  }
}

struct AppCheckErrorFake: Error {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension SafetyRating: Swift.Comparable {
  public static func < (lhs: FirebaseVertexAI.SafetyRating,
                        rhs: FirebaseVertexAI.SafetyRating) -> Bool {
    return lhs.category.rawValue < rhs.category.rawValue
  }
}
