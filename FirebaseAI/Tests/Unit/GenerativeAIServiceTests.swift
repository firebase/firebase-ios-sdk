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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import XCTest

@testable import FirebaseAILogic

#if !COCOAPODS
  import GeminiHTTPClient
#endif // !COCOAPODS

#if !os(watchOS)
  @available(macOS 12.0, *)
  final class GenerativeAIServiceTests: XCTestCase {
    let testModelName = "test-model"
    let testModelResourceName =
      "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
    let apiConfig = FirebaseAI.defaultAgentPlatformAPIConfig

    var httpClient: HTTPClient!
    var model: GenerativeModel!

    override func setUp() async throws {
      let configuration = URLSessionConfiguration.default
      configuration.protocolClasses = [MockURLProtocol.self]
      httpClient = HTTPClient(configuration: configuration)
      model = GenerativeModel(
        modelName: testModelName,
        modelResourceName: testModelResourceName,
        firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
        apiConfig: apiConfig,
        tools: nil,
        requestOptions: RequestOptions(),
        httpClient: httpClient
      )
    }

    override func tearDown() {
      MockURLProtocol.requestHandler = nil
      MockURLProtocol.errorToThrowMidStream = nil
      MockURLProtocol.stopLoadingExpectation = nil
      MockURLProtocol.neverFinishes = false
      MockURLProtocol.chunkSize = nil
    }

    func testModelsShareDefaultHTTPClient() {
      let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
      let model1 = GenerativeModel(
        modelName: testModelName,
        modelResourceName: testModelResourceName,
        firebaseInfo: firebaseInfo,
        apiConfig: apiConfig,
        tools: nil,
        requestOptions: RequestOptions()
      )
      let model2 = TemplateGenerativeModel(
        firebaseInfo: firebaseInfo,
        apiConfig: apiConfig,
        tools: nil,
        toolConfig: nil,
        requestOptions: RequestOptions()
      )

      XCTAssertTrue(model1.generativeAIService.httpClient === HTTPClient.default)
      XCTAssertTrue(model2.generativeAIService.httpClient === HTTPClient.default)
      XCTAssertTrue(model.generativeAIService.httpClient === httpClient)
    }

    func testGenerateContent_failure_unrecognizedErrorPayload() async throws {
      let expectedStatusCode = 500
      let responseBody = "Internal Server Error"

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        return (response, Data(responseBody.utf8))
      }

      do {
        _ = try await model.generateContent("test")
        XCTFail("An error should have been thrown, but no error was thrown.")
      } catch let GenerateContentError
        .internalError(underlying: unrecognizedError as UnrecognizedRPCError) {
        XCTAssertEqual(unrecognizedError.responseBody, responseBody)
      } catch {
        XCTFail("Caught unexpected error: \(error)")
      }
    }

    func testGenerateContentStream_singleChunkMultipleEvents() async throws {
      MockURLProtocol.chunkSize = .max
      let event1 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello \"}]}}]}"
      let event2 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"world!\"}]}}]}"
      let responseBody = "data: \(event1)\n\ndata: \(event2)\n\n"

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data(responseBody.utf8))
      }

      let stream = try model.generateContentStream("test")
      var texts = [String]()
      for try await chunk in stream {
        if let text = chunk.text {
          texts.append(text)
        }
      }

      XCTAssertEqual(texts, ["Hello ", "world!"])
    }

    func testGenerateContentStream_crlfFramingAndArbitraryChunkBoundaries() async throws {
      MockURLProtocol.chunkSize = 17
      let event1 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"First\"}]}}]}"
      let event2 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Second\"}]}}]}"
      let responseBody = "data: \(event1)\r\n\r\ndata: \(event2)\r\n\r\n"

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data(responseBody.utf8))
      }

      let stream = try model.generateContentStream("test")
      var texts = [String]()
      for try await chunk in stream {
        if let text = chunk.text {
          texts.append(text)
        }
      }

      XCTAssertEqual(texts, ["First", "Second"])
    }

    func testGenerateContentStream_preservesUnicodeLineSeparatorsInJSON() async throws {
      let expectedText = "Line 1\u{2028}Line 2\u{2029}Line 3"
      let event =
        "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"\(expectedText)\"}]}}]}"
      let responseBody = "data: \(event)\n\n"

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data(responseBody.utf8))
      }

      let stream = try model.generateContentStream("test")
      var texts = [String]()
      for try await chunk in stream {
        if let text = chunk.text {
          texts.append(text)
        }
      }

      XCTAssertEqual(texts, [expectedText])
    }

    func testGenerateContentStream_ignoresSSECommentsAndControlFields() async throws {
      let event1 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello \"}]}}]}"
      let event2 = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"world!\"}]}}]}"
      let responseBody = """
      : keep-alive
      event: message
      id: 1
      retry: 5000
      data: \(event1)

      : keep-alive
      data: \(event2)


      """

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data(responseBody.utf8))
      }

      let stream = try model.generateContentStream("test")
      var texts = [String]()
      for try await chunk in stream {
        if let text = chunk.text {
          texts.append(text)
        }
      }

      XCTAssertEqual(texts, ["Hello ", "world!"])
    }

    func testGenerateContentStream_failure_midStreamError_throwsError() async throws {
      let expectedStatusCode = 200
      let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
      let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 100)

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        return (response, Data(responseBody.utf8))
      }

      // Simulate a network drop mid-stream
      MockURLProtocol.errorToThrowMidStream = URLError(.networkConnectionLost)

      let localModel = model!

      let throwsExpectation =
        XCTestExpectation(description: "Stream should throw URLError(.networkConnectionLost)")

      Task {
        do {
          let stream = try localModel.generateContentStream("test")
          for try await _ in stream {
            // Read lines
          }
          XCTFail(
            "Stream should not finish successfully; it should throw a mid-stream network error."
          )
          throwsExpectation.fulfill()
        } catch let GenerateContentError.internalError(underlying: urlError as URLError)
          where urlError.code == .networkConnectionLost {
          // This is the expected behavior.
          throwsExpectation.fulfill()
        } catch {
          XCTFail("Stream threw unexpected error: \(error)")
          throwsExpectation.fulfill()
        }
      }

      await fulfillment(of: [throwsExpectation], timeout: 4.0)
    }

    func testGenerateContentStream_failure_midStreamError_badResponse_throwsError() async throws {
      let expectedStatusCode = 400
      let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
      let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 100)

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        return (response, Data(responseBody.utf8))
      }

      // Simulate a network drop mid-stream while reading the error payload
      MockURLProtocol.errorToThrowMidStream = URLError(.networkConnectionLost)

      let localModel = model!

      let throwsExpectation =
        XCTestExpectation(description: "Stream should throw URLError(.networkConnectionLost)")

      Task {
        do {
          let stream = try localModel.generateContentStream("test")
          for try await _ in stream {
            // Read lines
          }
          XCTFail(
            "Stream should not finish successfully; it should throw a mid-stream network error."
          )
          throwsExpectation.fulfill()
        } catch let GenerateContentError.internalError(underlying: urlError as URLError)
          where urlError.code == .networkConnectionLost {
          // This is the expected behavior.
          throwsExpectation.fulfill()
        } catch {
          XCTFail("Stream threw unexpected error: \(error)")
          throwsExpectation.fulfill()
        }
      }

      await fulfillment(of: [throwsExpectation], timeout: 4.0)
    }

    func testGenerateContentStream_cancellation_resourceLeak() async throws {
      let expectedStatusCode = 200

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
        let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 100)
        return (response, Data(responseBody.utf8))
      }

      // Prevent the mock server from finishing naturally so it keeps the connection open.
      MockURLProtocol.neverFinishes = true

      let stopLoadingExpectation =
        XCTestExpectation(description: "stopLoading should be called when task is cancelled")
      MockURLProtocol.stopLoadingExpectation = stopLoadingExpectation

      let localModel = model!

      do {
        let stream = try localModel.generateContentStream("test")
        var iterator = stream.makeAsyncIterator()
        // Read just one item, then stop (which drops the iterator and cancels the stream)
        _ = try await iterator.next()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }

      // Dropping the iterator cancels the stream. This cancellation should propagate
      // down to the underlying URLSession task, instantly calling stopLoading().

      await fulfillment(of: [stopLoadingExpectation], timeout: 2.0)
    }
  }
#endif // !os(watchOS)
