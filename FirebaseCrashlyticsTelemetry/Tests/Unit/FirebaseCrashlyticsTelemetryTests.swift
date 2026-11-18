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
      installations: MockInstallationsProvider(installationId: "mock-fid-123"),
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

  func test_filterNetworkRequests_excludesTelemetryEndpointsAndAllowsOtherURLs() throws {
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

    let clientTelemetryRequest = try URLRequest(
      url: XCTUnwrap(
        URL(string: "https://clienttelemetry.googleapis.com/v1/projects/test/traces")
      )
    )
    XCTAssertFalse(
      FirebaseCrashlyticsTelemetry.filterNetworkRequests(urlRequest: clientTelemetryRequest)
    )

    let uppercaseClientTelemetryRequest = try URLRequest(
      url: XCTUnwrap(
        URL(string: "https://CLIENTTELEMETRY.googleapis.com/v1/projects/test/traces")
      )
    )
    XCTAssertFalse(
      FirebaseCrashlyticsTelemetry.filterNetworkRequests(
        urlRequest: uppercaseClientTelemetryRequest
      )
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

  func test_networkSpanName_usesHttpMethodOrFallsBackToHTTP() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/items/123"))

    let defaultGetRequest = URLRequest(url: url)
    XCTAssertEqual(
      FirebaseCrashlyticsTelemetry.networkSpanName(urlRequest: defaultGetRequest),
      "GET"
    )

    var postRequest = URLRequest(url: url)
    postRequest.httpMethod = "POST"
    XCTAssertEqual(FirebaseCrashlyticsTelemetry.networkSpanName(urlRequest: postRequest), "POST")

    var emptyMethodRequest = URLRequest(url: url)
    emptyMethodRequest.httpMethod = ""
    XCTAssertEqual(
      FirebaseCrashlyticsTelemetry.networkSpanName(urlRequest: emptyMethodRequest),
      "HTTP"
    )
  }

  func test_annotateNetworkResponse_setsErrorTypeOnlyForErrorStatusCodes() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api"))

    let okResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
    )
    let okSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(okResponse, span: okSpan)
    okSpan.end()
    let readableOkSpan = try XCTUnwrap(okSpan as? ReadableSpan)
    XCTAssertNil(readableOkSpan.getAttributes()[SemanticConventions.Error.type.rawValue])

    let redirectResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)
    )
    let redirectSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(redirectResponse, span: redirectSpan)
    redirectSpan.end()
    let readableRedirectSpan = try XCTUnwrap(redirectSpan as? ReadableSpan)
    XCTAssertNil(readableRedirectSpan.getAttributes()[SemanticConventions.Error.type.rawValue])

    let notFoundResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
    )
    let notFoundSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(notFoundResponse, span: notFoundSpan)
    notFoundSpan.end()
    let readableNotFoundSpan = try XCTUnwrap(notFoundSpan as? ReadableSpan)
    XCTAssertEqual(
      readableNotFoundSpan.getAttributes()[SemanticConventions.Error.type.rawValue],
      .string("404")
    )

    let serverErrorResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
    )
    let serverErrorSpan = Self.telemetry.tracer.spanBuilder(spanName: "POST").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(serverErrorResponse, span: serverErrorSpan)
    serverErrorSpan.end()
    let readableServerErrorSpan = try XCTUnwrap(serverErrorSpan as? ReadableSpan)
    XCTAssertEqual(
      readableServerErrorSpan.getAttributes()[SemanticConventions.Error.type.rawValue],
      .string("500")
    )

    let nonHttpResponse = URLResponse(
      url: url,
      mimeType: nil,
      expectedContentLength: 0,
      textEncodingName: nil
    )
    let nonHttpSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(nonHttpResponse, span: nonHttpSpan)
    nonHttpSpan.end()
    let readableNonHttpSpan = try XCTUnwrap(nonHttpSpan as? ReadableSpan)
    XCTAssertNil(readableNonHttpSpan.getAttributes()[SemanticConventions.Error.type.rawValue])
  }

  func test_annotateNetworkResponse_setsResponseContentTypeHeaderWhenPresent() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api"))
    let responseWithHeader = try XCTUnwrap(
      HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["content-type": "application/json; charset=utf-8"]
      )
    )
    let span = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(responseWithHeader, span: span)
    span.end()

    let readableSpan = try XCTUnwrap(span as? ReadableSpan)
    let responseContentTypeKey =
      "\(SemanticConventions.Http.responseHeader.rawValue).content-type"
    XCTAssertEqual(
      readableSpan.getAttributes()[responseContentTypeKey],
      AttributeValue(["application/json; charset=utf-8"])
    )

    let responseWithoutHeader = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)
    )
    let emptySpan = Self.telemetry.tracer.spanBuilder(spanName: "DELETE").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkResponse(responseWithoutHeader, span: emptySpan)
    emptySpan.end()

    let readableEmptySpan = try XCTUnwrap(emptySpan as? ReadableSpan)
    XCTAssertNil(readableEmptySpan.getAttributes()[responseContentTypeKey])
  }

  func test_annotateNetworkError_usesStatusCodeWhenAvailableOrErrorDomainAndCode() throws {
    let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

    let transportSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkError(
      timeoutError,
      statusCode: 0,
      span: transportSpan
    )
    transportSpan.end()
    let readableTransportSpan = try XCTUnwrap(transportSpan as? ReadableSpan)
    XCTAssertEqual(
      readableTransportSpan.getAttributes()[SemanticConventions.Error.type.rawValue],
      .string("\(NSURLErrorDomain):\(NSURLErrorTimedOut)")
    )

    let httpErrorSpan = Self.telemetry.tracer.spanBuilder(spanName: "GET").startSpan()
    FirebaseCrashlyticsTelemetry.annotateNetworkError(
      timeoutError,
      statusCode: 503,
      span: httpErrorSpan
    )
    httpErrorSpan.end()
    let readableHttpErrorSpan = try XCTUnwrap(httpErrorSpan as? ReadableSpan)
    XCTAssertEqual(
      readableHttpErrorSpan.getAttributes()[SemanticConventions.Error.type.rawValue],
      .string("503")
    )
  }

  func test_customizeNetworkSpan_whenActiveSpanExists_setsParentSpan() throws {
    XCTAssertEqual(Self.telemetry.startSpan(), 1)

    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = Self.telemetry.tracer.spanBuilder(spanName: "GET")
    Self.telemetry.customizeNetworkSpan(req: request, builder: builder)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertNotNil(readableSpan.toSpanData().parentSpanId)
  }

  func test_customizeNetworkSpan_whenNoActiveSpan_doesNotSetParentSpan() throws {
    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = Self.telemetry.tracer.spanBuilder(spanName: "GET")
    Self.telemetry.customizeNetworkSpan(req: request, builder: builder)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertNil(readableSpan.toSpanData().parentSpanId)
  }

  func test_customizeNetworkSpan_setsUrlDomainAndOptionalRequestHeaders() throws {
    var request = try URLRequest(url: XCTUnwrap(URL(string: "https://api.example.com/v1/items")))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let builder = Self.telemetry.tracer.spanBuilder(spanName: "POST")
    Self.telemetry.customizeNetworkSpan(req: request, builder: builder)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    let attrs = readableSpan.getAttributes()
    XCTAssertEqual(attrs[SemanticConventions.Url.domain.rawValue], .string("api.example.com"))
    XCTAssertEqual(
      attrs["\(SemanticConventions.Http.requestHeader.rawValue).accept"],
      AttributeValue(["application/json"])
    )
    XCTAssertEqual(
      attrs["\(SemanticConventions.Http.requestHeader.rawValue).content-type"],
      AttributeValue(["application/json"])
    )

    let plainRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://api.example.com/ping")))
    let plainBuilder = Self.telemetry.tracer.spanBuilder(spanName: "GET")
    Self.telemetry.customizeNetworkSpan(req: plainRequest, builder: plainBuilder)

    let plainSpan = plainBuilder.startSpan()
    defer { plainSpan.end() }

    let readablePlainSpan = try XCTUnwrap(plainSpan as? ReadableSpan)
    let plainAttrs = readablePlainSpan.getAttributes()
    XCTAssertEqual(plainAttrs[SemanticConventions.Url.domain.rawValue], .string("api.example.com"))
    XCTAssertNil(plainAttrs["\(SemanticConventions.Http.requestHeader.rawValue).accept"])
    XCTAssertNil(plainAttrs["\(SemanticConventions.Http.requestHeader.rawValue).content-type"])
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
