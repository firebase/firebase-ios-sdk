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

/// Representation of a span that was in-flight at the time of
/// a crash and recovered from the span buffer.
///
/// When persisting an in-flight span we map SpanData (defined by OTel core) to CppSpan (defined
/// by native persistence library). When recovering the CppSpan from the in-flight span buffer
/// we are not able to reverse this mapping. We can not go from CppSpan to SpanData OTel has
/// defined SpanData without any public initializer, hence its initialization is package private.
///
/// RecoveredSpan serves as the next best alternative. We can map CppSpan to RecoveredSpan which
/// is a Swift native struct allowing for the data to be passed around and modified before being
/// converted in to a proto and exported.
public struct RecoveredSpan: @unchecked Sendable {
  /// The OpenTelemetry Trace ID for this span
  public let traceID: TraceId

  /// The OpenTelemetry Span ID for this span
  public let spanID: SpanId

  /// The OpenTelemetry Span ID of the parent span for this span
  public let parentSpanID: SpanId?

  /// The start time for this span
  public let startTime: Date

  /// The end time for this span
  public var endTime: Date?

  /// The kind of this span as defined in the span ring buffer
  public var kind: SpanKind = .internal

  /// The status of this span.
  public var status: Status = .unset

  /// The name for this span
  public let name: String

  /// The attributes recorded for this span
  public let attributes: [String: AttributeValue]
}
