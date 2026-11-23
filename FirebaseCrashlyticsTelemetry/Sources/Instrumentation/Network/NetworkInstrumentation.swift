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

internal import CrashlyticsTelemetryOTelURLSessionInstrumentation
import Foundation
import OpenTelemetryApi

/// Instruments `URLSession` network requests and emits OpenTelemetry spans.
final actor NetworkInstrumentation {
  private let tracer: Tracer
  private let parentSpanProvider: (@Sendable () -> (any Span)?)?
  private var urlInstrumentation: URLSessionInstrumentation?

  init(tracer: Tracer,
       parentSpanProvider: (@Sendable () -> (any Span)?)? = nil) {
    self.tracer = tracer
    self.parentSpanProvider = parentSpanProvider

    Task.detached(priority: .utility) { [weak self] in
      await self?.configure()
    }
  }

  private func configure() {
    ThreadHelper.isNotMainThread()

    urlInstrumentation = URLSessionInstrumentation(
      configuration: URLSessionInstrumentationConfiguration(
        shouldInstrument: Self.shouldInstrument,
        nameSpan: Self.spanName,
        spanCustomization: { [parentSpanProvider] request, builder in
          Self.customizeSpan(request, builder: builder, parentSpan: parentSpanProvider?())
        },
        receivedResponse: { response, _, span in
          Self.annotateResponse(response, span: span)
        },
        receivedError: { error, _, statusCode, span in
          Self.annotateError(error, statusCode: statusCode, span: span)
        },
        tracer: tracer,
        semanticConvention: .stable
      )
    )
  }

  static func shouldInstrument(_ request: URLRequest) -> Bool {
    guard let url = request.url else { return false }
    guard let rawHost = url.host else { return true }

    let lowercasedHost = rawHost.lowercased()
    let host = lowercasedHost.hasSuffix(".") ? String(lowercasedHost.dropLast()) : lowercasedHost

    guard host.hasSuffix(".googleapis.com"),
          let serviceLabel = host.split(separator: ".").first else {
      return true
    }

    let telemetryServices = ["firebasetelemetry", "clienttelemetry"]
    let isTelemetryHost = telemetryServices.contains { service in
      serviceLabel == service || serviceLabel.hasSuffix("-\(service)")
    }
    return !isTelemetryHost
  }

  static func spanName(for request: URLRequest) -> String {
    guard let method = request.httpMethod, !method.isEmpty else {
      return "HTTP"
    }
    return method
  }

  static func annotateResponse(_ response: URLResponse, span: Span) {
    guard let httpResponse = response as? HTTPURLResponse else { return }
    if httpResponse.statusCode >= 400 {
      span.setAttribute(
        key: SemanticConventions.Error.type.rawValue,
        value: .string(String(httpResponse.statusCode))
      )
    }

    if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
       !contentType.isEmpty {
      span.setAttribute(
        key: "\(SemanticConventions.Http.responseHeader.rawValue).content-type",
        value: AttributeValue([contentType])
      )
    }
  }

  static func annotateError(_ error: Error, statusCode: Int, span: Span) {
    let errorType: String
    if statusCode >= 400 {
      errorType = String(statusCode)
    } else {
      let nsError = error as NSError
      errorType = "\(nsError.domain):\(nsError.code)"
    }
    span.setAttribute(
      key: SemanticConventions.Error.type.rawValue,
      value: .string(errorType)
    )
  }

  static func customizeSpan(_ request: URLRequest, builder: SpanBuilder, parentSpan: (any Span)?) {
    if let parentSpan {
      builder.setParent(parentSpan)
    }

    if let host = request.url?.host, !host.isEmpty {
      builder.setAttribute(key: SemanticConventions.Url.domain.rawValue, value: .string(host))
    }

    if let accept = request.value(forHTTPHeaderField: "Accept"), !accept.isEmpty {
      builder.setAttribute(
        key: "\(SemanticConventions.Http.requestHeader.rawValue).accept",
        value: AttributeValue([accept])
      )
    }

    if let contentType = request.value(forHTTPHeaderField: "Content-Type"), !contentType.isEmpty {
      builder.setAttribute(
        key: "\(SemanticConventions.Http.requestHeader.rawValue).content-type",
        value: AttributeValue([contentType])
      )
    }
  }
}
