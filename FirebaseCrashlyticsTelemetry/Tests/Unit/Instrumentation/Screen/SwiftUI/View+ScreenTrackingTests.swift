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
import XCTest

@testable import FirebaseCrashlyticsTelemetry

@MainActor
final class ScreenTrackingExtensionTests: XCTestCase {
  func test_crashlyticsScreen_appliesScreenName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.crashlyticsScreen("CustomScreenName")

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "CustomScreenName")
  }

  // MARK: - Private Reflection Helper

  /// Inspects the modified view hierarchy via Mirror reflection to retrieve the screenName stored
  /// on ScreenTrackingModifier.
  private func extractScreenName<V: View>(from view: V) -> String? {
    let mirror = Mirror(reflecting: view)
    guard let modifier = mirror.children.first(where: { $0.label == "modifier" })?
      .value as? ScreenTrackingModifier else {
      XCTFail("Expected view to be wrapped in ModifiedContent with ScreenTrackingModifier")
      return nil
    }

    let modifierMirror = Mirror(reflecting: modifier)
    return modifierMirror.children.first(where: { $0.label == "screenName" })?.value as? String
  }
}
