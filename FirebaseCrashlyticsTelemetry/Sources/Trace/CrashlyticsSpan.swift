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

/// A specialized wrapper around an OpenTelemetry `ReadableSpan`.
///
/// Opentelemetry Spans lack hooks in to mutating methods such as `addAttribute`. By default spans
/// only have hooks on `onStart` and `onEnd` which makes it difficult to persist any updates in
/// between the start and end of a span.
///
/// `CrashlyticsSpan` adds additional hooks that are needed to properly persist the latest state
/// of a Span at the time of a crash while relying on the underlying functionality provided by
/// OpenTelemetry.
class CrashlyticsSpan: ReadableSpan, @unchecked Sendable {
  /// The underlying span that provides the span functionality
  private let otelSpan: ReadableSpan
  /// The span processor to persist the latest state of this span
  private let crashlyticsProcessor: CrashlyticsSpanProcessor

  /// The name of the span.
  public var name: String {
    get { otelSpan.name }
    // TODO: Call onNameChange hook in CrashlyticsSpanProcessor on name change.
    set { otelSpan.name = newValue }
  }

  /// The status of the span.
  public var status: Status {
    get { otelSpan.status }
    set { otelSpan.status = newValue }
  }

  /// instrumentation library of the named tracer which created this span
  public var instrumentationScopeInfo: InstrumentationScopeInfo {
    otelSpan.instrumentationScopeInfo
  }

  /// True if the span is ended.
  public var hasEnded: Bool { otelSpan.hasEnded }
  /// Returns the latency of the Span in seconds. If still active then returns now() - start time.
  public var latency: TimeInterval { otelSpan.latency }
  /// The kind of the span.
  public var kind: SpanKind { otelSpan.kind }
  /// Contains the identifiers associated with this Span.
  public var context: SpanContext { otelSpan.context }
  /// True if the span is recording.
  public var isRecording: Bool { otelSpan.isRecording }
  /// Description of the span
  public var description: String { "CrashlyticsSpan{}" }

  /// Initializes a new Crashlytics-aware span wrapper.
  ///
  /// - Parameters:
  ///   - span: The underlying OpenTelemetry span to wrap.
  ///   - crashlyticsProcessor: The processor used to intercept and persist mutations.
  init(span: ReadableSpan,
       crashlyticsProcessor: CrashlyticsSpanProcessor) {
    otelSpan = span
    self.crashlyticsProcessor = crashlyticsProcessor
  }

  // MARK: Persistence methods

  /// Marks the span as completed and triggers the processor to free/finalize its space
  /// in the active persistent buffer.
  public func end() {
    otelSpan.end()
    crashlyticsProcessor.onEnd(span: self)
  }

  /// Marks the span as completed at a specific timestamp and triggers the processor to
  /// free its space in the span buffer.
  ///
  /// - Parameter time: The explicit date and time the span ended.
  public func end(time: Date) {
    otelSpan.end(time: time)
    crashlyticsProcessor.onEnd(span: self)
  }

  /// Sets an attribute on the span and triggers the processor to persist the mutation.
  ///
  /// - Parameters:
  ///   - key: The key for the attribute.
  ///   - value: The value of the attribute.
  public func setAttribute(key: String, value: AttributeValue?) {
    otelSpan.setAttribute(key: key, value: value)
    crashlyticsProcessor.onAddAttribute(
      span: self,
      key: key,
      value: value
    )
  }

  /// Sets multiple attributes on the span and triggers the processor to persist the mutations.
  ///
  /// - Parameter attributes: A dictionary of attribute keys and values to add.
  public func setAttributes(_ attributes: [String: AttributeValue]) {
    for (key, value) in attributes {
      setAttribute(key: key, value: value)
    }
  }

  // MARK: Forwarded methods

  /// Converts the underlying active span into immutable span data.
  ///
  /// - Returns: An immutable `SpanData` representation of the span.
  public func toSpanData() -> SpanData {
    return otelSpan.toSpanData()
  }

  /// Retrieves the current attributes of the underlying span.
  ///
  /// - Returns: A dictionary containing the span's current attributes.
  public func getAttributes() -> [String: AttributeValue] {
    return otelSpan.getAttributes()
  }

  /// Adds a named event to the underlying span.
  ///
  /// - Parameter name: The name of the event.
  public func addEvent(name: String) {
    otelSpan.addEvent(name: name)
  }

  /// Adds a named event with a specific timestamp to the underlying span.
  ///
  /// - Parameters:
  ///   - name: The name of the event.
  ///   - timestamp: The explicit timestamp of the event.
  public func addEvent(name: String, timestamp: Date) {
    otelSpan.addEvent(name: name, timestamp: timestamp)
  }

  /// Adds a named event with attributes to the underlying span.
  ///
  /// - Parameters:
  ///   - name: The name of the event.
  ///   - attributes: The attributes associated with the event.
  public func addEvent(name: String, attributes: [String: AttributeValue]) {
    otelSpan.addEvent(name: name, attributes: attributes)
  }

  /// Adds a named event with attributes and a specific timestamp to the underlying span.
  ///
  /// - Parameters:
  ///   - name: The name of the event.
  ///   - attributes: The attributes associated with the event.
  ///   - timestamp: The explicit timestamp of the event.
  public func addEvent(name: String, attributes: [String: AttributeValue], timestamp: Date) {
    otelSpan.addEvent(name: name, attributes: attributes, timestamp: timestamp)
  }

  /// Records an exception on the underlying span.
  ///
  /// - Parameter exception: The exception to record.
  public func recordException(_ exception: any SpanException) {
    otelSpan.recordException(exception)
  }

  /// Records an exception with a specific timestamp on the underlying span.
  ///
  /// - Parameters:
  ///   - exception: The exception to record.
  ///   - timestamp: The explicit timestamp of the exception.
  public func recordException(_ exception: any SpanException, timestamp: Date) {
    otelSpan.recordException(exception, timestamp: timestamp)
  }

  /// Records an exception with attributes on the underlying span.
  ///
  /// - Parameters:
  ///   - exception: The exception to record.
  ///   - attributes: The attributes associated with the exception.
  public func recordException(_ exception: any SpanException,
                              attributes: [String: AttributeValue]) {
    otelSpan.recordException(exception, attributes: attributes)
  }

  /// Records an exception with attributes and a specific timestamp on the underlying span.
  ///
  /// - Parameters:
  ///   - exception: The exception to record.
  ///   - attributes: The attributes associated with the exception.
  ///   - timestamp: The explicit timestamp of the exception.
  public func recordException(_ exception: any SpanException,
                              attributes: [String: AttributeValue],
                              timestamp: Date) {
    otelSpan.recordException(exception, attributes: attributes, timestamp: timestamp)
  }
}
