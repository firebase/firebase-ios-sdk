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

#if !os(watchOS)
  @available(macOS 12.0, *)
  final class GenerativeAIServiceTests: XCTestCase {
    let testModelName = "test-model"
    let testModelResourceName =
      "projects/test-project-id/locations/test-location/publishers/google/models/test-model"
    let apiConfig = FirebaseAI.defaultVertexAIAPIConfig

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
      MockURLProtocol.errorToThrowMidStream = nil
      MockURLProtocol.stopLoadingExpectation = nil
      MockURLProtocol.neverFinishes = false
    }

    func testGenerateContent_failure_unrecognizedErrorPayload() async throws {
      let expectedStatusCode = 500
      let responseBody = "Internal Server Error"

      // We need to construct the handler to return specific data
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      addTeardownBlock {
        try? FileManager.default.removeItem(at: tempURL)
      }

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
        let stream = URL(fileURLWithPath: tempURL.path).lines
        return (response, stream)
      }

      do {
        _ = try await model.generateContent("test")
        XCTFail("An error should have been thrown, but no error was thrown.")
      } catch let GenerateContentError
        .internalError(underlying: unrecognizedError as UnrecognizedRPCError) {
        // MockURLProtocol appends a newline to the response.
        XCTAssertEqual(unrecognizedError.responseBody, responseBody + "\n")
      } catch {
        XCTFail("Caught unexpected error: \(error)")
      }
    }

    func testGenerateContentStream_failure_midStreamError_throwsError() async throws {
      let expectedStatusCode = 200
      // Send a large amount of data so URLSession doesn't buffer it and delay returning
      // urlSession.bytes
      let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
      let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 2000)

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      addTeardownBlock {
        try? FileManager.default.removeItem(at: tempURL)
      }

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
        let stream = URL(fileURLWithPath: tempURL.path).lines
        return (response, stream)
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
        } catch let urlError as URLError where urlError.code == .networkConnectionLost {
          // This is the expected behavior!
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
      // Send a massive string so URLSession returns the stream immediately without waiting for more
      // data.
      let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
      let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 2000)

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      addTeardownBlock {
        try? FileManager.default.removeItem(at: tempURL)
      }

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
        let stream = URL(fileURLWithPath: tempURL.path).lines
        return (response, stream)
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
        } catch let urlError as URLError where urlError.code == .networkConnectionLost {
          // This is the expected behavior!
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

      // We don't use responseBody here because we want to manually yield lines slowly
      // to test that the mock continues sending them even after the stream is cancelled.
      // But MockURLProtocol currently doesn't support manual line yielding.
      // Let's rely on the fact that if it's NOT cancelled, the Task continues doing work.
      // We can use a large payload and assert that MockURLProtocol finishes its sleep.

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      addTeardownBlock {
        try? FileManager.default.removeItem(at: tempURL)
      }

      MockURLProtocol.requestHandler = { request in
        let response = HTTPURLResponse(
          url: request.url!,
          statusCode: expectedStatusCode,
          httpVersion: nil,
          headerFields: nil
        )!

        let validJSON = "{\"candidates\": [{\"content\": {\"parts\": [{\"text\": \"Hello\"}]}}]}"
        let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 100)
        try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
        let stream = URL(fileURLWithPath: tempURL.path).lines
        return (response, stream)
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

      // Now that we've stopped listening to the stream, the internal task *should* be cancelled,
      // which would instantly fulfill the expectation.
      // Because the current implementation is buggy, it leaks the background task and never
      // cancels the URLSession task. Therefore, `stopLoading` is never called, and the expectation
      // times out (passing the test because it is inverted).

      await fulfillment(of: [stopLoadingExpectation], timeout: 2.0)
    }
  }
#endif // !os(watchOS)
