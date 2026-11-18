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

import FirebaseCore
import OpenTelemetryApi
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class AttributeStoreTests: XCTestCase {
  override func tearDown() {
    AttributeStore.setScreenName(CrashlyticsScreen.unknown.name)
    AttributeStore.setSessionId(nil)
    super.tearDown()
  }

  func test_commonSpanAttributes_containsScreenNameAndOmitsSessionIdWhenNil() {
    let attributes = AttributeStore.commonSpanAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertNil(attributes["gcp.firebase.app_version"])
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

  func test_resourceAttributes_setsRequiredMobileAndBackendAttributes() {
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
    options.projectID = "test-project"
    let environment = MockTelemetryEnvironment(
      bundleIdentifier: "com.example.demo",
      appVersion: "3.4.5",
      appBuildId: "108",
      sdkVersion: "13.0.0"
    )

    let attributes = AttributeStore.resourceAttributes(
      options: options,
      installationId: "fid-abc-123",
      environment: environment
    )

    XCTAssertEqual(
      attributes[SemanticConventions.Service.name.rawValue],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsFirebaseAppId],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsProjectId],
      .string("test-project")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Service.namespace.rawValue],
      .string("com.example.demo")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Service.version.rawValue],
      .string("3.4.5")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.App.buildId.rawValue],
      .string("108")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Service.instanceId.rawValue],
      .string("fid-abc-123")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.App.installationId.rawValue],
      .string("fid-abc-123")
    )
  }

  func test_resourceAttributes_omitsNilAndEmptyOptionalValues() {
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
    options.projectID = ""
    let environment = MockTelemetryEnvironment(
      bundleIdentifier: nil,
      appVersion: "",
      appBuildId: nil,
      sdkVersion: "13.0.0"
    )

    let attributes = AttributeStore.resourceAttributes(
      options: options,
      installationId: "",
      environment: environment
    )

    XCTAssertEqual(
      attributes[SemanticConventions.Service.name.rawValue],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsFirebaseAppId],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertNil(attributes[SemanticConventions.Gcp.crashlyticsProjectId])
    XCTAssertNil(attributes[SemanticConventions.Service.namespace.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Service.version.rawValue])
    XCTAssertNil(attributes[SemanticConventions.App.buildId.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Service.instanceId.rawValue])
    XCTAssertNil(attributes[SemanticConventions.App.installationId.rawValue])
  }

  func test_instrumentationScopeAttributes_setsExpectedClientAttributes() {
    let environment = MockTelemetryEnvironment(sdkVersion: "13.2.1")

    let attributes = AttributeStore.instrumentationScopeAttributes(environment: environment)

    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsClientArtifact],
      .string("FirebaseCrashlyticsTelemetry")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsClientRepo],
      .string("firebase/firebase-ios-sdk")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.clientService.rawValue],
      .string("firebasetelemetry")
    )
    XCTAssertEqual(
      attributes[SemanticConventions.Gcp.crashlyticsClientVersion],
      .string("v13.2.1")
    )
  }
}
