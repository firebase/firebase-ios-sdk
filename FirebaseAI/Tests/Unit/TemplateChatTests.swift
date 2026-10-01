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
      apiConfig: FirebaseAI.defaultEnterpriseAPIConfig,
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

  func testSendMessageNoArgs() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "unary-success-basic-reply-short",
      withExtension: "json",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])

    let response = try await chat.sendMessage()

    XCTAssertEqual(chat.history.count, 1)
    XCTAssertEqual(chat.history[0].role, "model")
    XCTAssertEqual(
      (chat.history[0].parts.first as? TextPart)?.text,
      "Google's headquarters, also known as the Googleplex, is located in **Mountain View, California**.\n"
    )
    XCTAssertEqual(response.candidates.count, 1)
  }

  func testSendMessageStreamNoArgs() async throws {
    MockURLProtocol.requestHandler = try GenerativeModelTestUtil.httpRequestHandler(
      forResource: "streaming-success-basic-reply-short",
      withExtension: "txt",
      subdirectory: "mock-responses/googleai",
      isTemplateRequest: true
    )
    let chat = model.startChat(templateID: "test-template", inputs: ["name": "test"])

    let stream = try chat.sendMessageStream()
    let content = try await GenerativeModelTestUtil.collectTextFromStream(stream)

    XCTAssertEqual(content, "The capital of Wyoming is **Cheyenne**.\n")
    XCTAssertEqual(chat.history.count, 1)
    XCTAssertEqual(chat.history[0].role, "model")
  }

  // MARK: - Unexpected Server Responses

  /// A model turn containing a text part, a part type that the SDK does not recognize (e.g., one
  /// added to the backend after this SDK version was released) and a part with only a thought
  /// signature.
  private static let unrecognizedPartsJSON = """
  {"role": "model", "parts": [{"text": "Hello"}, {"futurePartType": {"key": "value"}}, \
  {"thoughtSignature": "sig"}]}
  """

  private static let textResponse = """
  {"candidates": [{"content": {"role": "model", "parts": [{"text": "OK"}]}, \
  "finishReason": "STOP"}]}
  """

  /// Returns a request handler that records the `history` sent in the request body.
  private func historyCapturingHandler(responseBody: String,
                                       _ capture: @escaping ([[String: Any]]) -> Void) throws
    -> MockURLProtocol.MockURLRequestHandler {
    let responseHandler = try GenerativeModelTestUtil.httpRequestHandler(body: responseBody)
    return { request in
      let body = try XCTUnwrap(request.extractBodyData())
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      try capture(XCTUnwrap(json["history"] as? [[String: Any]]))
      return try responseHandler(request)
    }
  }

  func testSendMessage_unrecognizedPartInResponse_nextTurnSucceeds() async throws {
    nonisolated(unsafe) var sentHistory: [[String: Any]]?
    MockURLProtocol.requestHandlersQueue = try [
      GenerativeModelTestUtil.httpRequestHandler(body: """
      {"candidates": [{"content": \(Self.unrecognizedPartsJSON), "finishReason": "STOP"}]}
      """),
      historyCapturingHandler(responseBody: Self.textResponse) { sentHistory = $0 },
    ]
    let chat = model.startChat(templateID: "test-template")

    let response = try await chat.sendMessage("Hi")
    XCTAssertEqual(response.text, "Hello")
    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[1].parts.count, 1)

    // The history, including the unrecognized parts, must be encodable for the next turn.
    let secondResponse = try await chat.sendMessage("Again")

    XCTAssertEqual(secondResponse.text, "OK")
    XCTAssertEqual(chat.history.count, 4)
    let history = try XCTUnwrap(sentHistory)
    XCTAssertEqual(history.count, 3)
    let modelParts = try XCTUnwrap(history[1]["parts"] as? [[String: Any]])
    XCTAssertEqual(modelParts.count, 3)
    XCTAssertEqual(modelParts[0]["text"] as? String, "Hello")
    XCTAssertEqual(modelParts[2]["thoughtSignature"] as? String, "sig")
  }

  func testSendMessageStream_unrecognizedPartInResponse_nextTurnSucceeds() async throws {
    nonisolated(unsafe) var sentHistory: [[String: Any]]?
    MockURLProtocol.requestHandlersQueue = try [
      GenerativeModelTestUtil.httpRequestHandler(body: """
      data: {"candidates": [{"content": {"role": "model", "parts": [{"text": "Hel"}]}}]}

      data: {"candidates": [{"content": \(Self.unrecognizedPartsJSON), "finishReason": "STOP"}]}
      """),
      historyCapturingHandler(responseBody: "data: \(Self.textResponse)") { sentHistory = $0 },
    ]
    let chat = model.startChat(templateID: "test-template")

    let content = try await GenerativeModelTestUtil.collectTextFromStream(
      chat.sendMessageStream("Hi")
    )
    XCTAssertEqual(content, "HelHello")
    XCTAssertEqual(chat.history.count, 2)

    // The aggregated history, including the unrecognized parts, must be encodable for the next
    // turn.
    let secondContent = try await GenerativeModelTestUtil.collectTextFromStream(
      chat.sendMessageStream("Again")
    )

    XCTAssertEqual(secondContent, "OK")
    XCTAssertEqual(chat.history.count, 4)
    let history = try XCTUnwrap(sentHistory)
    XCTAssertEqual(history.count, 3)
    let modelParts = try XCTUnwrap(history[1]["parts"] as? [[String: Any]])
    XCTAssertEqual(modelParts.count, 3)
    XCTAssertEqual(modelParts[0]["text"] as? String, "HelHello")
    XCTAssertEqual(modelParts[2]["thoughtSignature"] as? String, "sig")
  }
}
