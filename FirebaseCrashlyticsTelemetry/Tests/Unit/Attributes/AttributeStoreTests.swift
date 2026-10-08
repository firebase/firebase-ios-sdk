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

import OpenTelemetryApi
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class AttributeStoreTests: XCTestCase {
  override func tearDown() {
    AttributeStore.setScreenName(CrashlyticsScreen.unknown.name)
    super.tearDown()
  }

  func test_commonSpanAttributes_containsScreenNameAndAppVersion() {
    let attributes = AttributeStore.commonSpanAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertEqual(
      attributes["gcp.firebase.app_version"],
      .string("1.0")
    )
  }

  func test_commonLogAttributes_containsScreenName() {
    let attributes = AttributeStore.commonLogAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
  }

  func test_setScreenName_updatesCommonSpanAndLogAttributes() {
    AttributeStore.setScreenName("SettingsScreen")

    XCTAssertEqual(
      AttributeStore.commonSpanAttributes()[SemanticConventions.App.screenName.rawValue],
      .string("SettingsScreen")
    )
    XCTAssertEqual(
      AttributeStore.commonLogAttributes()[SemanticConventions.App.screenName.rawValue],
      .string("SettingsScreen")
    )
  }
}
