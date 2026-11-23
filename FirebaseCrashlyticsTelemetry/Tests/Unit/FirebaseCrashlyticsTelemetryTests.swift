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
internal import FirebaseCoreExtension
import FirebaseSessions
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class FirebaseCrashlyticsTelemetryTests: XCTestCase {
  private nonisolated(unsafe) static var telemetry: FirebaseCrashlyticsTelemetry!
  private nonisolated(unsafe) static var mockSessions: MockSessionsProvider!

  override class func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
    options.projectID = "test-project"
    mockSessions = MockSessionsProvider(initialSessionId: "initial-session-id")
    telemetry = FirebaseCrashlyticsTelemetry(
      options: options,
      sessions: mockSessions,
      environment: MockTelemetryEnvironment()
    )
  }

  override class func tearDown() {
    AttributeStore.setSessionId(nil)
    telemetry = nil
    mockSessions = nil
    super.tearDown()
  }

  override func tearDown() {
    while Self.telemetry.stopSpan() > 0 {}
    AttributeStore.setSessionId("initial-session-id")
    super.tearDown()
  }

  func test_init_registersSubscriberWithSessionsProvider() {
    XCTAssertEqual(Self.mockSessions.registeredSubscribers.count, 1)
    XCTAssertEqual(
      Self.mockSessions.registeredSubscribers.first?.sessionsSubscriberName,
      .CrashlyticsTelemetry
    )
    XCTAssertEqual(
      AttributeStore.commonSpanAttributes()[SemanticConventions.Session.id.rawValue],
      .string("initial-session-id")
    )
  }

  func test_init_populatesResourceAndInstrumentationScope() {
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Service.name.rawValue],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Gcp.crashlyticsFirebaseAppId],
      .string("1:1234567890:ios:abcdef")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Gcp.crashlyticsProjectId],
      .string("test-project")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Service.namespace.rawValue],
      .string("com.example.testapp")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Service.version.rawValue],
      .string("2.1.0")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.App.buildId.rawValue],
      .string("42")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Os.name.rawValue],
      .string("ios")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Os.version.rawValue],
      .string("18.2")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.manufacturer.rawValue],
      .string("Apple")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.modelIdentifier.rawValue],
      .string("iPhone16,2")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.crashlyticsArch],
      .string("arm64")
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.crashlyticsCores],
      .int(6)
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.crashlyticsRam],
      .int(8_589_934_592)
    )
    XCTAssertEqual(
      Self.telemetry.resource.attributes[SemanticConventions.Device.crashlyticsSimulator],
      .bool(true)
    )

    XCTAssertEqual(Self.telemetry.scopeInfo.name, "FirebaseCrashlyticsTelemetry")
    XCTAssertEqual(Self.telemetry.scopeInfo.version, "13.0.0")
    XCTAssertEqual(
      Self.telemetry.scopeInfo.attributes?[SemanticConventions.Gcp.crashlyticsClientArtifact],
      .string("FirebaseCrashlyticsTelemetry")
    )
    XCTAssertEqual(
      Self.telemetry.scopeInfo.attributes?[SemanticConventions.Gcp.crashlyticsClientRepo],
      .string("firebase/firebase-ios-sdk")
    )
    XCTAssertEqual(
      Self.telemetry.scopeInfo.attributes?[SemanticConventions.Gcp.clientService.rawValue],
      .string("firebasetelemetry")
    )
    XCTAssertEqual(
      Self.telemetry.scopeInfo.attributes?[SemanticConventions.Gcp.crashlyticsClientVersion],
      .string("v13.0.0")
    )
  }

  func test_onSessionChanged_updatesSessionIdOnGeneratedSpansAndLogs() throws {
    Self.mockSessions.simulateSessionChanged(sessionId: "updated-session-id")

    let span = Self.telemetry.tracer.spanBuilder(spanName: "session_span").startSpan()
    defer { span.end() }

    let readableSpan = try XCTUnwrap(span as? ReadableSpan)
    XCTAssertEqual(
      readableSpan.getAttributes()[SemanticConventions.Session.id.rawValue],
      .string("updated-session-id")
    )
    XCTAssertEqual(
      AttributeStore.commonLogAttributes()[SemanticConventions.Session.id.rawValue],
      .string("updated-session-id")
    )
  }

  func test_filterNetworkRequests_excludesFirebaseTelemetryAndAllowsOtherURLs() throws {
    let firebaseTelemetryRequest = try URLRequest(
      url: XCTUnwrap(
        URL(string: "https://firebasetelemetry.googleapis.com/v1/projects/test/traces")
      )
    )
    XCTAssertFalse(
      FirebaseCrashlyticsTelemetry.filterNetworkRequests(urlRequest: firebaseTelemetryRequest)
    )

    let uppercaseTelemetryRequest = try URLRequest(
      url: XCTUnwrap(
        URL(string: "https://FIREBASETELEMETRY.googleapis.com/v1/projects/test/traces")
      )
    )
    XCTAssertFalse(
      FirebaseCrashlyticsTelemetry.filterNetworkRequests(urlRequest: uppercaseTelemetryRequest)
    )

    let localhostRequest = try URLRequest(
      url: XCTUnwrap(URL(string: "http://localhost:8080/api/data"))
    )
    XCTAssertTrue(FirebaseCrashlyticsTelemetry.filterNetworkRequests(urlRequest: localhostRequest))

    let externalRequest = try URLRequest(
      url: XCTUnwrap(URL(string: "https://example.com/api/resource"))
    )
    XCTAssertTrue(FirebaseCrashlyticsTelemetry.filterNetworkRequests(urlRequest: externalRequest))
  }

  func test_customizeNetworkSpan_whenActiveSpanExists_setsParentSpan() throws {
    XCTAssertEqual(Self.telemetry.startSpan(), 1)

    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = Self.telemetry.tracer.spanBuilder(spanName: "HTTP GET")
    Self.telemetry.customizeNetworkSpan(req: request, builder: builder)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertNotNil(readableSpan.toSpanData().parentSpanId)
  }

  func test_customizeNetworkSpan_whenNoActiveSpan_doesNotSetParentSpan() throws {
    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = Self.telemetry.tracer.spanBuilder(spanName: "HTTP GET")
    Self.telemetry.customizeNetworkSpan(req: request, builder: builder)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertNil(readableSpan.toSpanData().parentSpanId)
  }

  func test_componentsToRegister_whenSessionsProviderMissing_returnsNil() throws {
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
    options.projectID = "test-project"

    let appClass = try XCTUnwrap(NSClassFromString("FIRApp") as? NSObject.Type)
    let app = appClass.init()
    app.setValue(true, forKey: "isDefaultApp")
    app.setValue(options, forKey: "options")

    let containerClass = try XCTUnwrap(
      NSClassFromString("FIRComponentContainer") as? NSObject.Type
    )
    let containerObject = containerClass.init()
    containerObject.setValue(app, forKey: "app")
    let container = try XCTUnwrap(containerObject as? FirebaseComponentContainer)

    let component = try XCTUnwrap(FirebaseCrashlyticsTelemetry.componentsToRegister().first)
    var isCacheable: ObjCBool = false
    let result = component.creationBlock(container, &isCacheable)

    XCTAssertNil(result)
    XCTAssertFalse(isCacheable.boolValue)
  }
}
