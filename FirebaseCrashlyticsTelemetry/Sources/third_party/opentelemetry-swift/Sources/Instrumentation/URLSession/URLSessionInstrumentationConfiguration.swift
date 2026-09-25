/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public typealias DataOrFile = Any
public typealias SessionTaskId = String
public typealias HTTPStatus = Int

/// Controls which HTTP semantic conventions to emit.
///
/// See migration guide: https://opentelemetry.io/docs/specs/semconv/non-normative/http-migration/
public enum HTTPSemanticConvention {
  case old      // Old HTTP and networking conventions
  case stable   // Stable HTTP and networking conventions (v1.23.1+)
  case httpDup  // Emit both old and stable (migration period)
}

public struct URLSessionInstrumentationConfiguration {
  public init(shouldRecordPayload: ((URLSession) -> (Bool)?)? = nil,
              shouldInstrument: ((URLRequest) -> (Bool)?)? = nil,
              nameSpan: ((URLRequest) -> (String)?)? = nil,
              spanCustomization: ((URLRequest, SpanBuilder) -> Void)? = nil,
              shouldInjectTracingHeaders: ((URLRequest) -> (Bool)?)? = nil,
              injectCustomHeaders: ((inout URLRequest, Span?) -> Void)? = nil,
              createdRequest: ((URLRequest, Span) -> Void)? = nil,
              receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)? = nil,
              receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)? = nil,
              delegateClassesToInstrument: [AnyClass]? = nil,
              baggageProvider: ((inout URLRequest, Span?) -> (Baggage)?)? = nil,
              tracer: Tracer? = nil,
              ignoredClassPrefixes: [String]? = nil,
              semanticConvention: HTTPSemanticConvention = .old) {
    self.shouldRecordPayload = shouldRecordPayload
    self.shouldInstrument = shouldInstrument
    self.shouldInjectTracingHeaders = shouldInjectTracingHeaders
    self.injectCustomHeaders = injectCustomHeaders
    self.nameSpan = nameSpan
    self.spanCustomization = spanCustomization
    self.createdRequest = createdRequest
    self.receivedResponse = receivedResponse
    self.receivedError = receivedError
    self.delegateClassesToInstrument = delegateClassesToInstrument
    self.baggageProvider = baggageProvider
    self.tracer = tracer ??
      OpenTelemetry.instance.tracerProvider.get(instrumentationName: "NSURLSession", instrumentationVersion: "1.0.0")
    self.ignoredClassPrefixes = ignoredClassPrefixes
    self.semanticConvention = semanticConvention
  }

  public var tracer: Tracer

  // Instrumentation Callbacks

  /// Implement this callback to filter which requests you want to instrument, all by default
  public var shouldInstrument: ((URLRequest) -> (Bool)?)?

  /// Implement this callback if you want the session to record payload data, false by default.
  /// This callback is only necessary when using session delegate
  public var shouldRecordPayload: ((URLSession) -> (Bool)?)?

  /// Implement this callback to filter which requests you want to inject headers to follow the trace,
  /// also must implement it if you want to inject custom headers
  /// Instruments all requests by default
  public var shouldInjectTracingHeaders: ((URLRequest) -> (Bool)?)?

  /// Implement this callback to inject custom headers or modify the request in any other way
  public var injectCustomHeaders: ((inout URLRequest, Span?) -> Void)?

  /// Implement this callback to override the default span name for a given request, return nil to use default.
  /// default name: `HTTP {method}` e.g. `HTTP PUT`
  public var nameSpan: ((URLRequest) -> (String)?)?

  /// Implement this callback to customize the span, such as by adding a parent, a link, attributes, etc
  public var spanCustomization: ((URLRequest, SpanBuilder) -> Void)?

  ///  Called before the span is created, it allows to add extra information to the Span
  public var createdRequest: ((URLRequest, Span) -> Void)?

  ///  Called before the span is ended, it allows to add extra information to the Span
  public var receivedResponse: ((URLResponse, DataOrFile?, Span) -> Void)?

  ///  Called before the span is ended, it allows to add extra information to the Span
  public var receivedError: ((Error, DataOrFile?, HTTPStatus, Span) -> Void)?

  ///  The array of URLSession delegate classes that will be instrumented by the library, will autodetect if nil is passed.
  public var delegateClassesToInstrument: [AnyClass]?

  /// Provides a baggage instance for instrumented requests that is merged with active baggage (if any).
  /// The callback can be used to define static baggage for all requests or create dynamic baggage
  /// based on the provided URLRequest and Span parameters.
  ///
  /// The resulting baggage is injected into request headers using the configured `TextMapBaggagePropagator`,
  /// ensuring consistent propagation across requests, regardless of the active context.
  ///
  /// Note: The injected baggage depends on the propagator in use (e.g., W3C or custom).
  /// Returns: A `Baggage` instance or `nil` if no baggage is needed.
  public let baggageProvider: ((inout URLRequest, Span?) -> (Baggage)?)?

  /// The Array of Prefixes you can avoid in swizzle process
  public let ignoredClassPrefixes: [String]?

  /// Which HTTP semantic conventions to emit
  public var semanticConvention: HTTPSemanticConvention
}
