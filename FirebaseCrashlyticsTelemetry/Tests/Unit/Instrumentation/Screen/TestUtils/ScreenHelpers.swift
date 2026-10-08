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

import SwiftUI

@testable import FirebaseCrashlyticsTelemetry

struct TestScreenEvent: Sendable, Equatable {
  let screenName: String
  let type: ScreenEventType
  let id: UUID

  init?(from notification: Notification) {
    guard let screenName = notification.userInfo?["screenName"] as? String,
          let type = notification.userInfo?["type"] as? ScreenEventType,
          let id = notification.userInfo?["id"] as? UUID else {
      return nil
    }
    self.screenName = screenName
    self.type = type
    self.id = id
  }
}

/// Listens to `NotificationCenter.default` and collects the first matching screenTrackingEvent.
@MainActor
func waitForScreenEvent(matching predicate: @escaping @Sendable (TestScreenEvent) -> Bool,
                        timeout: TimeInterval = 2.0,
                        action: () -> Void) async throws -> TestScreenEvent {
  let notifications = NotificationCenter.default.notifications(named: .screenTrackingEvent)

  return try await withThrowingTaskGroup(of: TestScreenEvent.self) { group in
    group.addTask {
      for await notification in notifications {
        try Task.checkCancellation()
        if let event = TestScreenEvent(from: notification), predicate(event) {
          return event
        }
      }
      throw XCTTimeoutError()
    }

    action()

    group.addTask {
      try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
      throw XCTTimeoutError()
    }

    guard let firstResult = try await group.next() else {
      throw XCTTimeoutError()
    }

    group.cancelAll()
    return firstResult
  }
}
