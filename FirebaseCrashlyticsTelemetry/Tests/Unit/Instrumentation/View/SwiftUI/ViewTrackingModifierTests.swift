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

import XCTest
import SwiftUI

@testable import FirebaseCrashlyticsTelemetry

@MainActor
final class ViewTrackingModifierTests: XCTestCase {
  func test_viewTrackingModifier_onAppear_postsAppearNotification() async throws {
    let screenName = "HomeScreen"
    let harness = ViewLifecycleHarness(
      view: Text("Test View").modifier(ViewTrackingModifier(screenName: screenName))
    )

    let event = try await waitForViewEvent(matching: { $0.type == .appear }) {
      harness.appear()
    }

    XCTAssertEqual(event.screenName, screenName)
    XCTAssertEqual(event.type, .appear)

    harness.cleanup()
  }

  func test_viewTrackingModifier_onDisappear_postsDisappearNotification() async throws {
    let screenName = "SettingsScreen"
    let harness = ViewLifecycleHarness(
      view: Text("Test View").modifier(ViewTrackingModifier(screenName: screenName))
    )

    _ = try await waitForViewEvent(matching: { $0.type == .appear }) {
      harness.appear()
    }

    let event = try await waitForViewEvent(matching: { $0.type == .disappear }) {
      harness.disappear()
    }

    XCTAssertEqual(event.screenName, screenName)
    XCTAssertEqual(event.type, .disappear)

    harness.cleanup()
  }

  func test_viewTrackingModifier_appearAndDisappear_shareSameInstanceID() async throws {
    let screenName = "DetailScreen"
    let harness = ViewLifecycleHarness(
      view: Text("Test View").modifier(ViewTrackingModifier(screenName: screenName))
    )

    let appearEvent = try await waitForViewEvent(matching: { $0.type == .appear }) {
      harness.appear()
    }

    let disappearEvent = try await waitForViewEvent(matching: { $0.type == .disappear }) {
      harness.disappear()
    }

    XCTAssertEqual(
      appearEvent.id,
      disappearEvent.id,
      "Instance ID must remain identical across appear and disappear"
    )

    harness.cleanup()
  }
}
