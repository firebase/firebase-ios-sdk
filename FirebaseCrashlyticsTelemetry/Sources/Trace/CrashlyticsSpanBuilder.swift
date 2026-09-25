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

/// A specialized span builder that ensures created spans are instrumented for persistence.
///
/// The primary purpose of this wrapper is to complete the custom telemetry pipeline.
/// While it forwards standard configuration to an underlying OpenTelemetry `SpanBuilder`,
/// it overrides the creation process so that `startSpan()` returns a `CrashlyticsSpan`.
class CrashlyticsSpanBuilder: SpanBuilder {
  /// The underlying span builder that provides the functionality.
  private let otelSpanBuilder: SpanBuilder
  /// The processor injected into created spans to handle disk persistence.
  private let crashlyticsProcessor: CrashlyticsSpanProcessor

  /// Initializes a new Crashlytics-aware span builder.
  ///
  /// - Parameters:
  ///   - spanBuilder: The underlying OpenTelemetry span builder.
  ///   - crashlyticsProcessor: The processor used to intercept and persist mutations.
  init(
    spanBuilder: SpanBuilder,
    crashlyticsProcessor: CrashlyticsSpanProcessor
  ) {
    self.otelSpanBuilder = spanBuilder
    self.crashlyticsProcessor = crashlyticsProcessor
  }

  /// Starts a new span and wraps it to support real-time disk persistence.
  ///
  /// This method starts the underlying span, wraps it in a `CrashlyticsSpan`, and immediately
  /// notifies the processor that the span has started so it can be allocated in the disk buffer.
  ///
  /// - Returns: A `CrashlyticsSpan` if the underlying span is readable; otherwise `Any Span`
  func startSpan() -> Span {
    let realSpan = self.otelSpanBuilder
      // TODO: Remove this attribute. Currently added as a work around to a limitation in the
      // backend server.
      .setAttribute(key: "gcp.firebase.app_version", value: "1.0")
      .startSpan()

    if let readableSpan = realSpan as? ReadableSpan {
      let crashlyticsSpan = CrashlyticsSpan(
        span: readableSpan,
        crashlyticsProcessor: self.crashlyticsProcessor
      )

      self.crashlyticsProcessor.onStart(parentContext: nil, span: crashlyticsSpan)
      return crashlyticsSpan
    }

    return realSpan
  }

  // MARK: - Forwarded Configuration Methods

  /// Sets an attribute on the underlying span builder.
  ///
  /// - Parameters:
  ///   - key: The attribute key.
  ///   - value: The attribute value.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setAttribute(
    key: String,
    value: OpenTelemetryApi.AttributeValue
  ) -> Self {
    _ = self.otelSpanBuilder.setAttribute(key: key, value: value)
    return self
  }

  /// Sets whether the created span should be the active span in the current context.
  ///
  /// - Parameter active: A boolean indicating if the span should be active.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setActive(_ active: Bool) -> Self {
    _ = self.otelSpanBuilder.setActive(active)
    return self
  }

  /// Sets the kind of the underlying span.
  ///
  /// - Parameter spanKind: The OpenTelemetry span kind.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setSpanKind(spanKind: OpenTelemetryApi.SpanKind) -> Self {
    _ = self.otelSpanBuilder.setSpanKind(spanKind: spanKind)
    return self
  }

  /// Sets the parent span for the underlying span builder.
  ///
  /// - Parameter parent: The parent span.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setParent(_ parent: OpenTelemetryApi.Span) -> Self {
    _ = self.otelSpanBuilder.setParent(parent)
    return self
  }

  /// Sets the parent span context for the underlying span builder.
  ///
  /// - Parameter parent: The parent span context.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setParent(_ parent: OpenTelemetryApi.SpanContext) -> Self {
    _ = self.otelSpanBuilder.setParent(parent)
    return self
  }

  /// Explicitly sets the span to have no parent.
  ///
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setNoParent() -> Self {
    _ = self.otelSpanBuilder.setNoParent()
    return self
  }

  /// Sets an explicit start time for the underlying span.
  ///
  /// - Parameter time: The explicit start time.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func setStartTime(time: Date) -> Self {
    _ = self.otelSpanBuilder.setStartTime(time: time)
    return self
  }

  /// Adds a link to the underlying span builder.
  ///
  /// - Parameter spanContext: The context of the span to link.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func addLink(spanContext: OpenTelemetryApi.SpanContext) -> Self {
    _ = self.otelSpanBuilder.addLink(spanContext: spanContext)
    return self
  }

  /// Adds a link with attributes to the underlying span builder.
  ///
  /// - Parameters:
  ///   - spanContext: The context of the span to link.
  ///   - attributes: The attributes associated with the link.
  /// - Returns: This builder instance, for chaining.
  @discardableResult func addLink(
    spanContext: OpenTelemetryApi.SpanContext,
    attributes: [String: OpenTelemetryApi.AttributeValue]
  ) -> Self {
    _ = self.otelSpanBuilder.addLink(spanContext: spanContext, attributes: attributes)
    return self
  }

  /// Executes an operation with the created span set as active.
  ///
  /// - Parameter operation: The closure to execute.
  /// - Throws: Any error thrown by the provided operation.
  /// - Returns: The result of the operation.
  public func withActiveSpan<T>(
    _ operation: (any OpenTelemetryApi.SpanBase) throws -> T
  ) rethrows -> T {
    return try self.otelSpanBuilder.withActiveSpan(operation)
  }

  #if canImport(_Concurrency)
    /// Executes an asynchronous operation with the created span set as active.
    ///
    /// - Parameter operation: The concurrent closure to execute.
    /// - Throws: Any error thrown by the provided operation.
    /// - Returns: The result of the operation.
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveSpan<T>(
      _ operation: @concurrent (any SpanBase) async throws -> T
    ) async rethrows -> T {
      let createdSpan = self.setActive(true).startSpan()
      defer {
        createdSpan.end()
      }

      return try await operation(createdSpan)
    }
  #endif
}
