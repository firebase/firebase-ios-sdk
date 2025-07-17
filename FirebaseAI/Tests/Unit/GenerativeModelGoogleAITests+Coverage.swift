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

@testable import FirebaseAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerativeModelGoogleAITests {
  // MARK: - Tool/Function Calling

  func testGenerateContent_success_functionCall_emptyArguments() async throws {
    MockURLProtocol
      .requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
        forResource: "unary-success-function-call-empty-arguments",
        withExtension: "json",
        subdirectory: "mock-responses/vertexai"
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
        subdirectory: "mock-responses/vertexai"
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
        subdirectory: "mock-responses/vertexai"
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
        subdirectory: "mock-responses/vertexai"
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

  // MARK: - Count Tokens

  func testCountTokens_success() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-total-tokens",
      withExtension: "json",
      subdirectory: "mock-responses/vertexai"
    )

    let response = try await model.countTokens("Why is the sky blue?")
    XCTAssertEqual(response.totalTokens, 6)
  }
}
