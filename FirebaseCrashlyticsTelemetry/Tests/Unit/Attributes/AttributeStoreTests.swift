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
    AttributeStore.setSessionId(nil)
    super.tearDown()
  }

  func test_commonSpanAttributes_containsScreenNameAndAppVersionAndOmitsSessionIdWhenNil() {
    let attributes = AttributeStore.commonSpanAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertEqual(
      attributes["gcp.firebase.app_version"],
      .string("1.0")
    )
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
  }

  func test_commonLogAttributes_containsScreenNameAndOmitsSessionIdWhenNil() {
    let attributes = AttributeStore.commonLogAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
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

  func test_setSessionId_updatesCommonSpanAndLogAttributes() {
    AttributeStore.setSessionId("test-session-123")

    XCTAssertEqual(
      AttributeStore.commonSpanAttributes()[SemanticConventions.Session.id.rawValue],
      .string("test-session-123")
    )
    XCTAssertEqual(
      AttributeStore.commonLogAttributes()[SemanticConventions.Session.id.rawValue],
      .string("test-session-123")
    )
  }
}
