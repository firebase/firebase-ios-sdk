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
final class TrackViewExtensionTests: XCTestCase {
  // MARK: - Indirect Name Resolution Tests (via trackView)

  func test_trackView_withExplicitName_appliesExplicitScreenName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.trackView("CustomScreenName")

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "CustomScreenName")
  }

  func test_trackView_withNilNameAndStandardFileID_extractsCleanFileName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.trackView(nil, fileID: "MyModule/ProfileView.swift")

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "ProfileView")
  }

  func test_trackView_withNilNameAndNestedPathFileID_extractsCleanFileName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.trackView(
      nil,
      fileID: "App/Features/Settings/Subfeatures/NotificationSettingsView.swift"
    )

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "NotificationSettingsView")
  }

  func test_trackView_withNilNameAndFileIDWithoutSwiftExtension_returnsBaseName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.trackView(nil, fileID: "App/Features/DashboardView")

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "DashboardView")
  }

  func test_trackView_withNilNameAndEmptyFileID_returnsFallbackName() {
    let baseView = Text("Hello World")
    let modifiedView = baseView.trackView(nil, fileID: "")

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "UnknownView")
  }

  func test_trackView_withDefaultParameters_usesCurrentTestFileName() {
    let baseView = Text("Hello World")
    // When called with default arguments, #fileID defaults to this test file's name
    let modifiedView = baseView.trackView()

    let extractedName = extractScreenName(from: modifiedView)
    XCTAssertEqual(extractedName, "View+TrackingTests")
  }

  // MARK: - Private Reflection Helper

  /// Inspects the modified view hierarchy via Mirror reflection to retrieve the screenName stored
  /// on ViewTrackingModifier.
  private func extractScreenName<V: View>(from view: V) -> String? {
    let mirror = Mirror(reflecting: view)
    guard let modifier = mirror.children.first(where: { $0.label == "modifier" })?
      .value as? ViewTrackingModifier else {
      XCTFail("Expected view to be wrapped in ModifiedContent with ViewTrackingModifier")
      return nil
    }

    let modifierMirror = Mirror(reflecting: modifier)
    return modifierMirror.children.first(where: { $0.label == "screenName" })?.value as? String
  }
}
