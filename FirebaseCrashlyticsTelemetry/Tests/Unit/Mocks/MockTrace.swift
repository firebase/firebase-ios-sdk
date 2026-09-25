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

/// Centralized utility factory to generate mock OpenTelemetry trace data and spans for testing.
public enum MockTrace {

  // Create an in-memory, thread-safe Tracer instance using the SDK's TracerProvider.
  nonisolated(unsafe) private static let tracerProvider: TracerProviderSdk = {
    return TracerProviderBuilder().build()
  }()

  nonisolated(unsafe) private static let tracer: Tracer = {
    return tracerProvider.get(instrumentationName: "MockTraceTests", instrumentationVersion: nil)
  }()

  // MARK: - ID Generators

  /// Generates a valid, randomized `TraceId` using the SDK format.
  public static func randomTraceId() -> TraceId {
    return TraceId.random()
  }

  /// Generates a randomized `SpanId`.
  public static func randomSpanId() -> SpanId {
    return SpanId.random()
  }

  // MARK: - Wrapper Structs for Mock Parameters

  public struct MockEvent {
    public var name: String
    public var timestamp: Date
    public var attributes: [String: AttributeValue]

    public init(name: String, timestamp: Date = Date(), attributes: [String: AttributeValue] = [:])
    {
      self.name = name
      self.timestamp = timestamp
      self.attributes = attributes
    }
  }

  public struct MockLink {
    public var context: SpanContext
    public var attributes: [String: AttributeValue]

    public init(context: SpanContext, attributes: [String: AttributeValue] = [:]) {
      self.context = context
      self.attributes = attributes
    }
  }

  // MARK: - Custom Span Builder

  /// Creates a customizable mock `SpanData` instance using the actual SDK tracer.
  public static func mockSpan(
    name: String = "mock_operation",
    parentContext: SpanContext? = nil,
    kind: SpanKind = .internal,
    startTime: Date = Date(),
    duration: TimeInterval = 1.0,
    attributes: [String: AttributeValue] = [:],
    events: [MockEvent] = [],
    links: [MockLink] = [],
    status: Status = .ok
  ) -> SpanData {
    var builder = tracer.spanBuilder(spanName: name)
      .setSpanKind(spanKind: kind)
      .setStartTime(time: startTime)

    if let parent = parentContext {
      builder = builder.setParent(parent)
    } else {
      builder = builder.setNoParent()
    }

    for link in links {
      builder = builder.addLink(spanContext: link.context, attributes: link.attributes)
    }

    let span = builder.startSpan()

    for (key, value) in attributes {
      span.setAttribute(key: key, value: value)
    }

    for event in events {
      span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
    }

    span.status = status
    span.end(time: startTime.addingTimeInterval(duration))

    guard let readableSpan = span as? ReadableSpan else {
      fatalError(
        "Failed to cast Span to ReadableSpan in tests. Verify that OpenTelemetrySdk is linked.")
    }

    return readableSpan.toSpanData()
  }

  // MARK: - Scenarios and Preset Traces

  /// Generates a mock parent-child execution trace.
  ///
  /// - Returns: A tuple containing a root parent span and an inner child span.
  public static func mockParentChildTrace() -> (parent: SpanData, child: SpanData) {
    let parent = mockSpan(
      name: "http_request_handler",
      parentContext: nil,
      kind: .server,
      startTime: Date(),
      duration: 2.0,
      attributes: [
        "http.method": .string("POST"),
        "http.status_code": .int(200),
      ]
    )

    let parentContext = SpanContext.create(
      traceId: parent.traceId,
      spanId: parent.spanId,
      traceFlags: parent.traceFlags,
      traceState: parent.traceState
    )

    let child = mockSpan(
      name: "database_query_users",
      parentContext: parentContext,
      kind: .client,
      startTime: parent.startTime.addingTimeInterval(0.2),
      duration: 0.8,
      attributes: [
        "db.system": .string("postgresql"),
        "db.statement": .string("SELECT * FROM users WHERE id = ?"),
      ]
    )

    return (parent, child)
  }

  /// Generates a mock span that simulates a failed process.
  public static func mockErrorSpan(
    errorMessage: String = "Internal Server Error (500)"
  ) -> SpanData {
    let timestamp = Date()

    let errorEvent = MockEvent(
      name: "exception",
      timestamp: timestamp.addingTimeInterval(0.5),
      attributes: [
        "exception.type": .string("NetworkTimeout"),
        "exception.message": .string(errorMessage),
      ]
    )

    return mockSpan(
      name: "fetch_network_configuration",
      kind: .client,
      startTime: timestamp,
      duration: 1.5,
      attributes: [
        "retry_count": .int(3),
        "is_fatal": .bool(true),
      ],
      events: [errorEvent],
      status: .error(description: errorMessage)
    )
  }

  /// Generates a mock span containing multi-type attribute properties and nested links.
  public static func mockComplexTelemetrySpan() -> SpanData {
    let linkContext = SpanContext.create(
      traceId: randomTraceId(),
      spanId: randomSpanId(),
      traceFlags: TraceFlags(),
      traceState: TraceState()
    )
    let remoteLink = MockLink(
      context: linkContext,
      attributes: ["relation_type": .string("derived_from")]
    )

    return mockSpan(
      name: "process_telemetry_payload",
      kind: .internal,
      attributes: [
        "application.build": .string("2026.08.03-release"),
        "experimental.features": .array(
          AttributeArray(
            values: [AttributeValue("otel_logging"), AttributeValue("crash_intercept")]
          )
        ),
        "performance.scores": .array(
          AttributeArray(
            values: [AttributeValue(98.4), AttributeValue(99.1), AttributeValue(95.0)]
          )
        ),
        "system.active_flags": .array(
          AttributeArray(
            values: [AttributeValue(true), AttributeValue(false), AttributeValue(true)]
          )
        ),
        "system.integer_metrics": .array(
          AttributeArray(
            values: [AttributeValue(1024), AttributeValue(2048), AttributeValue(4096)]
          )
        ),
      ],
      links: [remoteLink],
      status: .unset
    )
  }
}
