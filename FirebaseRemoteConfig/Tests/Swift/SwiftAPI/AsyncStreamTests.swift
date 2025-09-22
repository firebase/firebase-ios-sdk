// Copyright 2024 Google LLC
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
@testable import FirebaseRemoteConfig
import XCTest

#if SWIFT_PACKAGE
  import RemoteConfigFakeConsoleObjC
#endif

// MARK: - Mock Objects for Testing

/// A mock listener registration that allows tests to verify that its `remove()` method was called.
class MockListenerRegistration: ConfigUpdateListenerRegistration, @unchecked Sendable {
  var wasRemoveCalled = false
  override func remove() {
    wasRemoveCalled = true
  }
}

/// A mock for the RCNConfigRealtime component that allows tests to control the config update
/// listener.
class MockRealtime: RCNConfigRealtime {
  /// The listener closure captured from the `updates` async stream.
  var listener: ((RemoteConfigUpdate?, Error?) -> Void)?
  let mockRegistration = MockListenerRegistration()

  override func addConfigUpdateListener(_ listener: @escaping (RemoteConfigUpdate?, Error?)
    -> Void) -> ConfigUpdateListenerRegistration {
    self.listener = listener
    return mockRegistration
  }

  /// Simulates the backend sending a successful configuration update.
  func sendUpdate(keys: [String]) {
    let update = RemoteConfigUpdate(updatedKeys: Set(keys))
    listener?(update, nil)
  }

  /// Simulates the backend sending an error.
  func sendError(_ error: Error) {
    listener?(nil, error)
  }

  /// Simulates the listener completing without an update or error.
  func sendCompletion() {
    listener?(nil, nil)
  }
}

// MARK: - AsyncStreamTests2

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AsyncStreamTests: XCTestCase {
  var app: FirebaseApp!
  var config: RemoteConfig!
  var mockRealtime: MockRealtime!

  struct TestError: Error, Equatable {}

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Perform one-time setup of the FirebaseApp for testing.
    if FirebaseApp.app() == nil {
      let options = FirebaseOptions(googleAppID: "1:123:ios:123abc",
                                    gcmSenderID: "correct_gcm_sender_id")
      options.apiKey = "A23456789012345678901234567890123456789"
      options.projectID = "Fake_Project"
      FirebaseApp.configure(options: options)
    }

    app = FirebaseApp.app()!
    config = RemoteConfig.remoteConfig(app: app)

    // Install the mock realtime service.
    mockRealtime = MockRealtime()
    config.configRealtime = mockRealtime
  }

  override func tearDownWithError() throws {
    app = nil
    config = nil
    mockRealtime = nil
    try super.tearDownWithError()
  }

  func testStreamYieldsUpdate_whenUpdateIsSent() async throws {
    let expectation = self.expectation(description: "Stream should yield an update.")
    let keysToUpdate = ["foo", "bar"]

    let listeningTask = Task {
      for try await update in config.updates {
        XCTAssertEqual(update.updatedKeys, Set(keysToUpdate))
        expectation.fulfill()
        break // End the loop after receiving the expected update.
      }
    }

    // Ensure the listener is attached before sending the update.
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    mockRealtime.sendUpdate(keys: keysToUpdate)

    await fulfillment(of: [expectation], timeout: 1.0)
    listeningTask.cancel()
  }

  func testStreamFinishes_whenErrorIsSent() async throws {
    let expectation = self.expectation(description: "Stream should throw an error.")
    let testError = TestError()

    let listeningTask = Task {
      do {
        for try await _ in config.updates {
          XCTFail("Stream should not have yielded any updates.")
        }
      } catch {
        XCTAssertEqual(error as? TestError, testError)
        expectation.fulfill()
      }
    }

    // Ensure the listener is attached before sending the error.
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    mockRealtime.sendError(testError)

    await fulfillment(of: [expectation], timeout: 1.0)
    listeningTask.cancel()
  }

  func testStreamCancellation_callsRemoveOnListener() async throws {
    let listeningTask = Task {
      for try await _ in config.updates {
        // We will cancel the task, so it should not reach here.
      }
    }

    // Ensure the listener has time to be established.
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // Verify the listener has not been removed yet.
    XCTAssertFalse(mockRealtime.mockRegistration.wasRemoveCalled)

    // Cancel the task, which should trigger the stream's onTermination handler.
    listeningTask.cancel()

    // Give the cancellation a moment to propagate.
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // Verify the listener was removed.
    XCTAssertTrue(mockRealtime.mockRegistration.wasRemoveCalled)
  }

  func testStreamFinishesGracefully_whenListenerSendsNil() async throws {
    let expectation = self.expectation(description: "Stream should finish without error.")

    let listeningTask = Task {
      var updateCount = 0
      do {
        for try await _ in config.updates {
          updateCount += 1
        }
        // The loop finished without throwing, which is the success condition.
        XCTAssertEqual(updateCount, 0, "No updates should have been received.")
        expectation.fulfill()
      } catch {
        XCTFail("Stream should not have thrown an error, but threw \(error).")
      }
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    mockRealtime.sendCompletion()

    await fulfillment(of: [expectation], timeout: 1.0)
    listeningTask.cancel()
  }

  func testStreamYieldsMultipleUpdates_whenMultipleUpdatesAreSent() async throws {
    let expectation = self.expectation(description: "Stream should receive two updates.")
    expectation.expectedFulfillmentCount = 2

    let updatesToSend = [
      Set(["key1", "key2"]),
      Set(["key3"]),
    ]
    var receivedUpdates: [Set<String>] = []

    let listeningTask = Task {
      for try await update in config.updates {
        receivedUpdates.append(update.updatedKeys)
        expectation.fulfill()
        if receivedUpdates.count == updatesToSend.count {
          break
        }
      }
      return receivedUpdates
    }

    try await Task.sleep(nanoseconds: 100_000_000)

    mockRealtime.sendUpdate(keys: Array(updatesToSend[0]))
    try await Task.sleep(nanoseconds: 100_000_000) // Brief pause between sends
    mockRealtime.sendUpdate(keys: Array(updatesToSend[1]))

    await fulfillment(of: [expectation], timeout: 2.0)

    let finalUpdates = try await listeningTask.value
    XCTAssertEqual(finalUpdates, updatesToSend)
    listeningTask.cancel()
  }
}
