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

import Foundation
import XCTest

@testable import FirebaseFunctions

@available(macOS 12.0, watchOS 8.0, *)
class FunctionsStreamTests: XCTestCase {
  private struct EmptyRequest: Encodable, Sendable {}

  override func setUp() {
    super.setUp()
    URLProtocol.registerClass(MockURLProtocol.self)
    MockURLProtocol.requestHandlersQueue.removeAll()
    MockURLProtocol.errorToThrowMidStream = nil
    MockURLProtocol.stopLoadingExpectation = nil
    MockURLProtocol.neverFinishes = false
  }

  override func tearDown() {
    URLProtocol.unregisterClass(MockURLProtocol.self)
    super.tearDown()
  }

  func testStream_cancellation_resourceLeak() async throws {
    let expectedStatusCode = 200

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: tempURL)
    }

    MockURLProtocol.requestHandler = { request in
      let validJSON = "{\"result\": \"Hello\"}"
      let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 1000)
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: expectedStatusCode,
        httpVersion: nil,
        headerFields: [
          "Content-Type": "text/event-stream",
          "Content-Length": String(responseBody.utf8.count),
        ]
      )!

      try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
      let stream = URL(fileURLWithPath: tempURL.path).lines
      return (response, stream)
    }

    MockURLProtocol.neverFinishes = true

    let stopLoadingExpectation =
      XCTestExpectation(description: "stopLoading should be called when task is cancelled")
    MockURLProtocol.stopLoadingExpectation = stopLoadingExpectation

    // Using test-specific initialization so we don't need a real FirebaseApp
    let functions = Functions(
      projectID: "test-project",
      region: "us-central1",
      customDomain: nil,
      auth: nil,
      messaging: nil,
      appCheck: nil
    )
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("testStream")

    let consumerTask = Task {
      do {
        let stream = try callable.stream()
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
      } catch {
        // We expect a cancellation error here.
      }
    }

    // Give the stream a moment to initiate the URLSession request
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Cancelling the consumer task should cascade down and stop the URLSession task,
    // which should trigger MockURLProtocol.stopLoading()
    consumerTask.cancel()

    await fulfillment(of: [stopLoadingExpectation], timeout: 2.0)
  }

  func testStream_failure_midStreamError_throwsError() async throws {
    let expectedStatusCode = 200
    let validJSON = "{\"result\": \"Hello\"}"
    let responseBody = String(repeating: "data: \(validJSON)\n\n", count: 1000)

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: tempURL)
    }

    MockURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: expectedStatusCode,
        httpVersion: nil,
        headerFields: [
          "Content-Type": "text/event-stream",
          "Content-Length": String(responseBody.utf8.count),
        ]
      )!

      try responseBody.write(to: tempURL, atomically: true, encoding: .utf8)
      let stream = URL(fileURLWithPath: tempURL.path).lines
      return (response, stream)
    }

    // Simulate a network drop mid-stream
    MockURLProtocol.errorToThrowMidStream = URLError(.networkConnectionLost)

    let functions = Functions(
      projectID: "test-project",
      region: "us-central1",
      customDomain: nil,
      auth: nil,
      messaging: nil,
      appCheck: nil
    )
    let callable: Callable<EmptyRequest, String> = functions.httpsCallable("testStream")

    let throwsExpectation =
      XCTestExpectation(
        description: "Stream should throw dataLoss wrapping URLError(.networkConnectionLost)"
      )

    Task {
      do {
        let stream = try callable.stream()
        for try await _ in stream {
          // Read lines
        }
        XCTFail(
          "Stream should not finish successfully; it should throw a mid-stream network error."
        )
        throwsExpectation.fulfill()
      } catch let error as FunctionsError {
        XCTAssertEqual(error.code, .dataLoss)
        if let underlying = error.errorUserInfo[NSUnderlyingErrorKey] as? URLError {
          XCTAssertEqual(underlying.code, .networkConnectionLost)
        } else {
          XCTFail("Expected underlying URLError(.networkConnectionLost)")
        }
        throwsExpectation.fulfill()
      } catch {
        XCTFail("Stream threw unexpected error type: \(error)")
        throwsExpectation.fulfill()
      }
    }

    await fulfillment(of: [throwsExpectation], timeout: 4.0)
  }
}
