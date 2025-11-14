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

import FirebaseCore
import Foundation
import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ChatTests: XCTestCase {
  let modelName = "test-model-name"
  let modelResourceName = "projects/my-project/locations/us-central1/models/test-model-name"

  var urlSession: URLSession!

  override func setUp() {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = URLSession(configuration: configuration)
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
  }

  func testMergingText() async throws {
    let bundle = BundleTestUtil.bundle()
    let fileURL = try XCTUnwrap(bundle.url(
      forResource: "streaming-success-basic-reply-parts",
      withExtension: "txt",
      subdirectory: "mock-responses/vertexai"
    ))

    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #else // os(watchOS)
      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, fileURL.lines)
      }

      let app = FirebaseApp(instanceWithName: "testApp",
                            options: FirebaseOptions(googleAppID: "ignore",
                                                     gcmSenderID: "ignore"))
      let model = GenerativeModel(
        modelName: modelName,
        modelResourceName: modelResourceName,
        firebaseInfo: FirebaseInfo(
          projectID: "my-project-id",
          apiKey: "API_KEY",
          firebaseAppID: "My app ID",
          firebaseApp: app,
          useLimitedUseAppCheckTokens: false
        ),
        apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
        tools: nil,
        requestOptions: RequestOptions(),
        urlSession: urlSession
      )
      let chat = Chat(model: model, history: [])
      let input = "Test input"
      let stream = try chat.sendMessageStream(input)

      // Ensure the values are parsed correctly
      for try await value in stream {
        XCTAssertNotNil(value.text)
      }

      XCTAssertEqual(chat.history.count, 2)
      let part = try XCTUnwrap(chat.history[0].parts[0])
      let textPart = try XCTUnwrap(part as? TextPart)
      XCTAssertEqual(textPart.text, input)

      let finalText = "1 2 3 4 5 6 7 8"
      let assembledExpectation = ModelContent(role: "model", parts: finalText)
      XCTAssertEqual(chat.history[1], assembledExpectation)
    #endif // os(watchOS)
  }

  func testSendMessage_unary_appendsHistory() async throws {
    let expectedInput = "Test input"
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai"
    )
    let model = GenerativeModel(
      modelName: modelName,
      modelResourceName: modelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    let chat = model.startChat()

    // Pre-condition: History should be empty.
    XCTAssertTrue(chat.history.isEmpty)

    let response = try await chat.sendMessage(expectedInput)

    XCTAssertNotNil(response.text)
    let text = try XCTUnwrap(response.text)
    XCTAssertFalse(text.isEmpty)

    // Post-condition: History should have the user's message and the model's response.
    XCTAssertEqual(chat.history.count, 2)
    let userInput = try XCTUnwrap(chat.history.first)
    XCTAssertEqual(userInput.role, "user")
    XCTAssertEqual(userInput.parts.count, 1)
    let userInputText = try XCTUnwrap(userInput.parts.first as? TextPart)
    XCTAssertEqual(userInputText.text, expectedInput)

    let modelResponse = try XCTUnwrap(chat.history.last)
    XCTAssertEqual(modelResponse.role, "model")
    XCTAssertEqual(modelResponse.parts.count, 1)
    let modelResponseText = try XCTUnwrap(modelResponse.parts.first as? TextPart)
    XCTAssertFalse(modelResponseText.text.isEmpty)
  }

  func testSendMessageStream_error_doesNotAppendHistory() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-failure-finish-reason-safety",
      withExtension: "txt",
      subdirectory: "mock-responses/vertexai"
    )
    let model = GenerativeModel(
      modelName: modelName,
      modelResourceName: modelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
    let chat = model.startChat()
    let input = "Test input"

    // Pre-condition: History should be empty.
    XCTAssertTrue(chat.history.isEmpty)

    do {
      let stream = try chat.sendMessageStream(input)
      for try await _ in stream {
        // Consume the stream.
      }
      XCTFail("Should have thrown a responseStoppedEarly error.")
    } catch let GenerateContentError.responseStoppedEarly(reason, _) {
      XCTAssertEqual(reason, .safety)
    } catch {
      XCTFail("Unexpected error thrown: \(error)")
    }

    // Post-condition: History should still be empty.
    XCTAssertEqual(chat.history.count, 0)
  }

  func testStartChat_withHistory_initializesCorrectly() async throws {
    let history = [
      ModelContent(role: "user", parts: "Question 1"),
      ModelContent(role: "model", parts: "Answer 1"),
    ]
    let model = GenerativeModel(
      modelName: modelName,
      modelResourceName: modelResourceName,
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
      tools: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )

    let chat = model.startChat(history: history)

    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history, history)
  }
}
