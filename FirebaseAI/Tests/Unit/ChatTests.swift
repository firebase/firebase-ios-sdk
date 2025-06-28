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

@testable import FirebaseAI

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
          firebaseApp: app
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

  func testChatHistory() async throws {
    // Skip tests using MockURLProtocol on watchOS; unsupported in watchOS 2 and later, see
    // https://developer.apple.com/documentation/foundation/urlprotocol for details.
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #else // os(watchOS)
      let app = FirebaseApp(instanceWithName: "testAppHistory", // Use a unique name
                            options: FirebaseOptions(googleAppID: "ignore",
                                                     gcmSenderID: "ignore"))
      let model = GenerativeModel(
        modelName: modelName, // Assuming modelName is available from the class
        modelResourceName: modelResourceName, // Assuming modelResourceName is available
        firebaseInfo: FirebaseInfo(
          projectID: "my-project-id",
          apiKey: "API_KEY",
          firebaseAppID: "My app ID",
          firebaseApp: app
        ),
        apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
        tools: nil,
        requestOptions: RequestOptions(),
        urlSession: urlSession // Assuming urlSession is available from the class
      )

      // Initial chat history
      let initialHistory: [ModelContent] = [
        ModelContent(role: "user", parts: "Hello"),
        ModelContent(role: "model", parts: "Hi there! How can I help you today?")
      ]

      let chat = Chat(model: model, history: initialHistory)
      XCTAssertEqual(chat.history.count, 2, "Initial history count should be 2.")

      // Mock the network response
      let mockResponseText = "This is a mocked response."
      // Construct a data object that mimics the streaming format.
      // Each line should be a ServerSentEvent. Note the double newlines for SSE.
      let mockResponseString = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"\(mockResponseText)\"}]}}]}"

      // Convert the string to Data
      let mockResponseData = mockResponseString.data(using: .utf8)!

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: ["Content-Type": "application/json"] // Appropriate content type
        )!
        // Simulate streaming: send the data as a single chunk followed by an empty line to signify end.
        // Actual streaming might involve multiple data chunks. For this test, one is sufficient.
        // The key is that `MockURLProtocol` expects an array of Data objects, where each represents a "line" or chunk.
        // let responseChunks = [mockResponseData, Data()] // Send data then an empty line
        // return (response, responseChunks)
        let sseLine = mockResponseString // mockResponseString is already defined
        let stringStream = AsyncStream<String> { continuation in
            continuation.yield(sseLine) // The single SSE event line
            // To mimic fileURL.lines which processes line by line,
            // and MockURLProtocol adds a newline after each Data chunk from the string.
            // If your SSE stream had multiple distinct "data:" lines, you'd yield them separately.
            continuation.finish()
        }
        // Return this stream. It's an AsyncSequence<String>.
        // The existing testMergingText uses fileURL.lines (which is AsyncLineSequence<String>)
        // and it works with MockURLProtocol. So we do the same.
        return (response, stringStream)
      }

      // Send a new message
      let newMessageText = "How about now?"
      let stream = try chat.sendMessageStream(newMessageText)

      // Consume the stream to ensure the message is processed
      for try await _ in stream {}

      // Verify history
      XCTAssertEqual(chat.history.count, 4, "History count should be 4 after sending a new message.")

      // Check initial history (already present)
      XCTAssertEqual(chat.history[0].role, "user")
      var part = try XCTUnwrap(chat.history[0].parts.first)
      var textPart = try XCTUnwrap(part as? TextPart)
      XCTAssertEqual(textPart.text, "Hello")

      XCTAssertEqual(chat.history[1].role, "model")
      part = try XCTUnwrap(chat.history[1].parts.first)
      textPart = try XCTUnwrap(part as? TextPart)
      XCTAssertEqual(textPart.text, "Hi there! How can I help you today?")

      // Check the new user message
      XCTAssertEqual(chat.history[2].role, "user")
      part = try XCTUnwrap(chat.history[2].parts.first)
      textPart = try XCTUnwrap(part as? TextPart)
      XCTAssertEqual(textPart.text, newMessageText)

      // Check the mocked model response
      XCTAssertEqual(chat.history[3].role, "model")
      part = try XCTUnwrap(chat.history[3].parts.first)
      textPart = try XCTUnwrap(part as? TextPart)
      XCTAssertEqual(textPart.text, mockResponseText) // mockResponseText was defined in the previous step
    #endif // os(watchOS)
  }

  func testChatHistoryWithEmptyInitialHistory() async throws {
    // Skip tests using MockURLProtocol on watchOS...
    #if os(watchOS)
      throw XCTSkip("Custom URL protocols are unsupported in watchOS 2 and later.")
    #else // os(watchOS)
      // Setup FirebaseApp & GenerativeModel (unique app name)
      let app = FirebaseApp(instanceWithName: "testAppEmptyHistory",
                            options: FirebaseOptions(googleAppID: "ignore", gcmSenderID: "ignore"))
      let model = GenerativeModel(
        modelName: modelName,
        modelResourceName: modelResourceName,
        firebaseInfo: FirebaseInfo(
          projectID: "my-project-id",
          apiKey: "API_KEY",
          firebaseAppID: "My app ID",
          firebaseApp: app
        ),
        apiConfig: FirebaseAI.defaultVertexAIAPIConfig,
        tools: nil,
        requestOptions: RequestOptions(),
        urlSession: urlSession
      )

      // Initialize Chat with empty history
      let initialHistory: [ModelContent] = []
      let chat = Chat(model: model, history: initialHistory)
      XCTAssertEqual(chat.history.count, 0, "Initial history count should be 0.")

      // Mock network response
      let mockResponseText = "Mocked response for empty history test."
      let mockResponseString = "data: {\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"\(mockResponseText)\"}]}}]}"
      let mockResponseData = mockResponseString.data(using: .utf8)!
      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: ["Content-Type": "application/json"]
        )!
        // let responseChunks = [mockResponseData, Data()]
        // return (response, responseChunks)
        let sseLine = mockResponseString // mockResponseString is already defined for this function
        let stringStream = AsyncStream<String> { continuation in
            continuation.yield(sseLine) // The single SSE event line
            continuation.finish()
        }
        // Return this stream, consistent with the fix in testChatHistory and pattern in testMergingText
        return (response, stringStream)
      }

      // Send a new message
      let newMessageText = "First message here"
      let stream = try chat.sendMessageStream(newMessageText)

      // Consume the stream
      for try await _ in stream {}

      // Verify history
      XCTAssertEqual(chat.history.count, 2, "History count should be 2 after sending the first message.")

      // Check the new user message
      let userMessagePart = try XCTUnwrap(chat.history[0].parts.first)
      let userMessageText = try XCTUnwrap(userMessagePart as? TextPart)
      XCTAssertEqual(chat.history[0].role, "user")
      XCTAssertEqual(userMessageText.text, newMessageText)

      // Check the mocked model response
      let modelMessagePart = try XCTUnwrap(chat.history[1].parts.first)
      let modelMessageText = try XCTUnwrap(modelMessagePart as? TextPart)
      XCTAssertEqual(chat.history[1].role, "model")
      XCTAssertEqual(modelMessageText.text, mockResponseText)
    #endif // os(watchOS)
  }
}
