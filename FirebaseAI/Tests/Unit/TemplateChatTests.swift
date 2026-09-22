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
import FirebaseCore
import XCTest

@available(macOS 12.0, watchOS 8.0, *)
final class TemplateChatTests: XCTestCase {
  var model: TemplateGenerativeModel!
  var urlSession: URLSession!

  override func setUp() {
    super.setUp()

    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [MockURLProtocol.self]
    urlSession = URLSession(configuration: configuration)
    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    model = TemplateGenerativeModel(
      firebaseInfo: firebaseInfo,
      apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
      tools: nil,
      toolConfig: nil,
      requestOptions: RequestOptions(),
      urlSession: urlSession
    )
  }

  func testSendMessage() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])

    let response = try await chat.sendMessage("Hello")

    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].role, "user")
    XCTAssertEqual((chat.history[0].parts.first as? TextPart)?.text, "Hello")
    XCTAssertEqual(chat.history[1].role, "model")
    XCTAssertEqual(
      (chat.history[1].parts.first as? TextPart)?.text,
      "Google's headquarters, also known as the Googleplex, is located in **Mountain View, California**.\n"
    )
    XCTAssertEqual(response.candidates.count, 1)
  }

  func testSendMessageStream() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])
    let stream = try chat.sendMessageStream("Hello")

    let content = try await GenerativeModelTestUtil.collectTextFromStream(stream)

    XCTAssertEqual(content, "The capital of Wyoming is **Cheyenne**.\n")
    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].role, "user")
    XCTAssertEqual((chat.history[0].parts.first as? TextPart)?.text, "Hello")
    XCTAssertEqual(chat.history[1].role, "model")
  }

  func testSendMessageWithModelContent() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])

    let response = try await chat.sendMessage([ModelContent(parts: [TextPart("Hello")])])

    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].role, "user")
    XCTAssertEqual((chat.history[0].parts.first as? TextPart)?.text, "Hello")
    XCTAssertEqual(chat.history[1].role, "model")
    XCTAssertEqual(
      (chat.history[1].parts.first as? TextPart)?.text,
      "Google's headquarters, also known as the Googleplex, is located in **Mountain View, California**.\n"
    )
    XCTAssertEqual(response.candidates.count, 1)
  }

  func testSendMessageStreamWithModelContent() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])
    let stream = try chat.sendMessageStream([ModelContent(parts: [TextPart("Hello")])])

    let content = try await GenerativeModelTestUtil.collectTextFromStream(stream)

    XCTAssertEqual(content, "The capital of Wyoming is **Cheyenne**.\n")
    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].role, "user")
    XCTAssertEqual((chat.history[0].parts.first as? TextPart)?.text, "Hello")
    XCTAssertEqual(chat.history[1].role, "model")
  }
}
