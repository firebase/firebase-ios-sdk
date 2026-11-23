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

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class NetworkInstrumentationTests: XCTestCase {
  private var tracer: Tracer!

  override func setUp() {
    super.setUp()
    let tracerProvider = TracerProviderBuilder().build()
    tracer = tracerProvider.get(
      instrumentationName: "NetworkInstrumentationTests",
      instrumentationVersion: nil
    )
  }

  override func tearDown() {
    tracer = nil
    super.tearDown()
  }

  func test_shouldInstrument_excludesTelemetryHostsAndAllowsOtherURLs() throws {
    let excludedURLs = [
      "https://firebasetelemetry.googleapis.com/v1/projects/test/traces",
      "https://FIREBASETELEMETRY.googleapis.com/v1/projects/test/traces",
      "https://firebasetelemetry.googleapis.com./v1/projects/test/traces",
      "https://clienttelemetry.googleapis.com/v1/projects/test/traces",
      "https://CLIENTTELEMETRY.googleapis.com/v1/projects/test/traces",
      "https://clienttelemetry.us-east5.rep.googleapis.com/v1/projects/test/traces",
      "https://firebasetelemetry.us-east5.rep.googleapis.com/v1/projects/test/traces",
      "https://staging-firebasetelemetry.sandbox.googleapis.com/v1/projects/test/traces",
      "https://dev-clienttelemetry.sandbox.googleapis.com/v1/projects/test/traces",
    ]
    for urlString in excludedURLs {
      let request = try URLRequest(url: XCTUnwrap(URL(string: urlString)))
      XCTAssertFalse(
        NetworkInstrumentation.shouldInstrument(request),
        "Expected \(urlString) to be excluded from instrumentation"
      )
    }

    let allowedURLs = [
      "http://localhost:8080/api/data",
      "https://example.com/api/resource",
      "https://example.com/docs/firebasetelemetry",
      "https://example.com/api?source=clienttelemetry",
      "https://firebasetelemetry.example.com/v1/traces",
      "https://firestore.googleapis.com/v1/projects/test/databases",
    ]
    for urlString in allowedURLs {
      let request = try URLRequest(url: XCTUnwrap(URL(string: urlString)))
      XCTAssertTrue(
        NetworkInstrumentation.shouldInstrument(request),
        "Expected \(urlString) to be instrumented"
      )
    }

    var nilURLRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com")))
    nilURLRequest.url = nil
    XCTAssertFalse(NetworkInstrumentation.shouldInstrument(nilURLRequest))
  }

  func test_spanName_usesHttpMethodOrFallsBackToHTTP() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api/v1/items/123"))

    let defaultGetRequest = URLRequest(url: url)
    XCTAssertEqual(NetworkInstrumentation.spanName(for: defaultGetRequest), "GET")

    var postRequest = URLRequest(url: url)
    postRequest.httpMethod = "POST"
    XCTAssertEqual(NetworkInstrumentation.spanName(for: postRequest), "POST")

    var emptyMethodRequest = URLRequest(url: url)
    emptyMethodRequest.httpMethod = ""
    XCTAssertEqual(NetworkInstrumentation.spanName(for: emptyMethodRequest), "HTTP")
  }

  func test_annotateResponse_setsErrorTypeOnlyForErrorStatusCodes() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api"))

    let okResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
    )
    let okSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(okResponse, span: okSpan)
    okSpan.end()
    let readableOkSpan = try XCTUnwrap(okSpan as? ReadableSpan)
    XCTAssertNil(readableOkSpan.getAttributes()[SemanticConventions.Error.type.rawValue])

    let redirectResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)
    )
    let redirectSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(redirectResponse, span: redirectSpan)
    redirectSpan.end()
    let readableRedirectSpan = try XCTUnwrap(redirectSpan as? ReadableSpan)
    XCTAssertNil(readableRedirectSpan.getAttributes()[SemanticConventions.Error.type.rawValue])

    let notFoundResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
    )
    let notFoundSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(notFoundResponse, span: notFoundSpan)
    notFoundSpan.end()
    let readableNotFoundSpan = try XCTUnwrap(notFoundSpan as? ReadableSpan)
    XCTAssertEqual(
      readableNotFoundSpan.getAttributes()[SemanticConventions.Error.type.rawValue],
      .string("404")
    )

    let serverErrorResponse = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
    )
    let serverErrorSpan = tracer.spanBuilder(spanName: "POST").startSpan()
    NetworkInstrumentation.annotateResponse(serverErrorResponse, span: serverErrorSpan)
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
    let nonHttpSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(nonHttpResponse, span: nonHttpSpan)
    nonHttpSpan.end()
    let readableNonHttpSpan = try XCTUnwrap(nonHttpSpan as? ReadableSpan)
    XCTAssertNil(readableNonHttpSpan.getAttributes()[SemanticConventions.Error.type.rawValue])
  }

  func test_annotateResponse_setsResponseContentTypeHeaderWhenPresent() throws {
    let url = try XCTUnwrap(URL(string: "https://example.com/api"))
    let responseContentTypeKey =
      "\(SemanticConventions.Http.responseHeader.rawValue).content-type"

    let responseWithHeader = try XCTUnwrap(
      HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["content-type": "application/json; charset=utf-8"]
      )
    )
    let span = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(responseWithHeader, span: span)
    span.end()

    let readableSpan = try XCTUnwrap(span as? ReadableSpan)
    XCTAssertEqual(
      readableSpan.getAttributes()[responseContentTypeKey],
      AttributeValue(["application/json; charset=utf-8"])
    )

    let responseWithoutHeader = try XCTUnwrap(
      HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)
    )
    let emptySpan = tracer.spanBuilder(spanName: "DELETE").startSpan()
    NetworkInstrumentation.annotateResponse(responseWithoutHeader, span: emptySpan)
    emptySpan.end()

    let readableEmptySpan = try XCTUnwrap(emptySpan as? ReadableSpan)
    XCTAssertNil(readableEmptySpan.getAttributes()[responseContentTypeKey])

    let responseWithEmptyHeader = try XCTUnwrap(
      HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": ""]
      )
    )
    let blankHeaderSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateResponse(responseWithEmptyHeader, span: blankHeaderSpan)
    blankHeaderSpan.end()

    let readableBlankHeaderSpan = try XCTUnwrap(blankHeaderSpan as? ReadableSpan)
    XCTAssertNil(readableBlankHeaderSpan.getAttributes()[responseContentTypeKey])
  }

  func test_annotateError_usesStatusCodeWhenAvailableOrErrorDomainAndCode() throws {
    let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

    let transportSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateError(
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

    let httpErrorSpan = tracer.spanBuilder(spanName: "GET").startSpan()
    NetworkInstrumentation.annotateError(
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

  func test_customizeSpan_whenParentSpanExists_setsParentSpan() throws {
    let parentSpan = tracer.spanBuilder(spanName: "parent").startSpan()
    defer { parentSpan.end() }

    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = tracer.spanBuilder(spanName: "GET")
    NetworkInstrumentation.customizeSpan(request, builder: builder, parentSpan: parentSpan)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertEqual(readableSpan.toSpanData().parentSpanId, parentSpan.context.spanId)
  }

  func test_customizeSpan_whenNoParentSpan_doesNotSetParentSpan() throws {
    let request = try URLRequest(url: XCTUnwrap(URL(string: "https://example.com/api")))
    let builder = tracer.spanBuilder(spanName: "GET")
    NetworkInstrumentation.customizeSpan(request, builder: builder, parentSpan: nil)

    let networkSpan = builder.startSpan()
    defer { networkSpan.end() }

    let readableSpan = try XCTUnwrap(networkSpan as? ReadableSpan)
    XCTAssertNil(readableSpan.toSpanData().parentSpanId)
  }

  func test_customizeSpan_setsUrlDomainAndOptionalRequestHeaders() throws {
    var request = try URLRequest(url: XCTUnwrap(URL(string: "https://api.example.com/v1/items")))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let builder = tracer.spanBuilder(spanName: "POST")
    NetworkInstrumentation.customizeSpan(request, builder: builder, parentSpan: nil)

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
    let plainBuilder = tracer.spanBuilder(spanName: "GET")
    NetworkInstrumentation.customizeSpan(plainRequest, builder: plainBuilder, parentSpan: nil)

    let plainSpan = plainBuilder.startSpan()
    defer { plainSpan.end() }

    let readablePlainSpan = try XCTUnwrap(plainSpan as? ReadableSpan)
    let plainAttrs = readablePlainSpan.getAttributes()
    XCTAssertEqual(plainAttrs[SemanticConventions.Url.domain.rawValue], .string("api.example.com"))
    XCTAssertNil(plainAttrs["\(SemanticConventions.Http.requestHeader.rawValue).accept"])
    XCTAssertNil(plainAttrs["\(SemanticConventions.Http.requestHeader.rawValue).content-type"])

    var nilURLRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://api.example.com")))
    nilURLRequest.url = nil
    let nilURLBuilder = tracer.spanBuilder(spanName: "GET")
    NetworkInstrumentation.customizeSpan(nilURLRequest, builder: nilURLBuilder, parentSpan: nil)

    let nilURLSpan = nilURLBuilder.startSpan()
    defer { nilURLSpan.end() }

    let readableNilURLSpan = try XCTUnwrap(nilURLSpan as? ReadableSpan)
    XCTAssertNil(readableNilURLSpan.getAttributes()[SemanticConventions.Url.domain.rawValue])
  }
}
