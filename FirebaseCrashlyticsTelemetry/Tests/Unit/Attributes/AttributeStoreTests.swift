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

  func test_commonSpanAttributes_containsScreenNameThreadInfoAndOmitsSessionIdWhenNil() {
    let attributes = AttributeStore.commonSpanAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertNil(attributes["gcp.firebase.app_version"])
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
    if case let .int(threadId) = attributes[SemanticConventions.Thread.id.rawValue] {
      XCTAssertGreaterThan(threadId, 0)
    } else {
      XCTFail("Expected thread.id to be an integer attribute")
    }
    XCTAssertEqual(attributes[SemanticConventions.Thread.name.rawValue], .string("main"))
  }

  func test_commonSpanAttributes_onNamedBackgroundThread_capturesBackgroundThreadInfo() {
    let mainAttributes = AttributeStore.commonSpanAttributes()
    let expectation = expectation(description: "Background thread evaluated attributes")
    let capturedAttributes = LockBox<[String: AttributeValue]>([:])

    let workerThread = Thread {
      capturedAttributes.set(AttributeStore.commonSpanAttributes())
      expectation.fulfill()
    }
    workerThread.name = "crashlytics-worker"
    workerThread.start()

    wait(for: [expectation], timeout: 2.0)

    let workerAttributes = capturedAttributes.get()
    XCTAssertEqual(
      workerAttributes[SemanticConventions.Thread.name.rawValue],
      .string("crashlytics-worker")
    )
    XCTAssertNotEqual(
      workerAttributes[SemanticConventions.Thread.id.rawValue],
      mainAttributes[SemanticConventions.Thread.id.rawValue]
    )
  }

  func test_commonLogAttributes_containsScreenNameAndOmitsSessionIdAndThreadAttributes() {
    let attributes = AttributeStore.commonLogAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Thread.id.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Thread.name.rawValue])
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
      sdkVersion: "13.0.0",
      osName: "ios",
      osVersion: "18.1",
      deviceManufacturer: "Apple",
      deviceModelIdentifier: "iPhone15,3",
      deviceArch: "arm64",
      deviceCores: 6,
      deviceRamBytes: 6_442_450_944,
      isSimulator: false
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
    XCTAssertEqual(attributes[SemanticConventions.Os.name.rawValue], .string("ios"))
    XCTAssertEqual(attributes[SemanticConventions.Os.version.rawValue], .string("18.1"))
    XCTAssertEqual(attributes[SemanticConventions.Device.manufacturer.rawValue], .string("Apple"))
    XCTAssertEqual(
      attributes[SemanticConventions.Device.modelIdentifier.rawValue],
      .string("iPhone15,3")
    )
    XCTAssertEqual(attributes[SemanticConventions.Device.crashlyticsArch], .string("arm64"))
    XCTAssertEqual(attributes[SemanticConventions.Device.crashlyticsCores], .int(6))
    XCTAssertEqual(
      attributes[SemanticConventions.Device.crashlyticsRam],
      .int(6_442_450_944)
    )
    XCTAssertEqual(attributes[SemanticConventions.Device.crashlyticsSimulator], .bool(false))
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
      sdkVersion: "13.0.0",
      osName: "",
      osVersion: nil,
      deviceManufacturer: "",
      deviceModelIdentifier: nil,
      deviceArch: nil,
      deviceCores: 0,
      deviceRamBytes: 0,
      isSimulator: true
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
    XCTAssertNil(attributes[SemanticConventions.Os.name.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Os.version.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Device.manufacturer.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Device.modelIdentifier.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Device.crashlyticsArch])
    XCTAssertNil(attributes[SemanticConventions.Device.crashlyticsCores])
    XCTAssertNil(attributes[SemanticConventions.Device.crashlyticsRam])
    XCTAssertEqual(attributes[SemanticConventions.Device.crashlyticsSimulator], .bool(true))
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

private final class LockBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func set(_ newValue: Value) {
    lock.lock()
    defer { lock.unlock() }
    value = newValue
  }

  func get() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}
