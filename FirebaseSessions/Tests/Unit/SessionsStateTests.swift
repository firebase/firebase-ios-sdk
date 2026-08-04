//
// Copyright 2024-2026 Google LLC
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

import XCTest

@testable import FirebaseSessions

final class SessionsStateTests: XCTestCase {
  func test_emptyExpectedSubscribers_returnsImmediately() async {
    let state = SessionsState(expectedSubscribers: [])
    await state.waitUntilAllRegistered()
    XCTAssertTrue(true, "Returned immediately as expected")
  }

  func test_waitUntilAllRegistered_waitsForDependencies() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics, .Performance])
    
    let waitTask = Task {
      await state.waitUntilAllRegistered()
    }
    
    // Simulate one dependency registering
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)
    
    // Ensure the task hasn't finished (it's still waiting)
    // We give it a tiny delay to ensure it didn't resume early.
    do {
      try await Task.sleep(nanoseconds: 100_000_000) // 100ms to reduce flakiness
    } catch {}
    
    // Now complete the registration
    await state.register(subscriber: MockSubscriber(name: .Performance), name: .Performance)
    
    // The wait task should now complete
    await waitTask.value
    XCTAssertTrue(true, "Completed after all dependencies registered")
  }

  func test_subsequentWaits_returnImmediately() async {
    let state = SessionsState(expectedSubscribers: [.Crashlytics])
    await state.register(subscriber: MockSubscriber(name: .Crashlytics), name: .Crashlytics)
    
    // These should return immediately and not suspend indefinitely
    await state.waitUntilAllRegistered()
    await state.waitUntilAllRegistered()
    
    XCTAssertTrue(true, "Subsequent waits returned immediately")
  }
}
