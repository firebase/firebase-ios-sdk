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

/// A specialized span processor that synchronizes telemetry data with the persistence layer.
///
/// This processor intercepts span lifecycle events and custom mutations to ensure that active
/// spans are written to the disk buffer for crash resilience.
class CrashlyticsSpanProcessor: SpanProcessor {
  let isStartRequired = true
  let isEndRequired = true

  /// Initializes a new Crashlytics span processor.
  public init() {}

  /// Called when a span begins its lifecycle.
  ///
  /// This method converts a custom `CrashlyticsSpan` to standard span data and asynchronously writes
  /// it to the persistence layer.
  ///
  /// - Parameters:
  ///   - parentContext: The context of the parent span, if any.
  ///   - span: The newly started readable span.
  func onStart(parentContext: SpanContext?, span: ReadableSpan) {
    let spanData = span.toSpanData()

    Task {
      await PersistenceManager.shared?.onSpanStart(span: spanData)
    }
  }

  // TODO: Add hook for on name change.

  /// Synchronizes a newly added attribute with the active persistence buffer.
  ///
  /// This is a custom Crashlytics hook called by the `CrashlyticsSpan` wrapper to ensure intermediate
  /// span mutations are safely persisted to disk before a potential crash.
  ///
  /// This is inspired by the proposal to add mutation hooks to span processors:
  /// https://github.com/open-telemetry/opentelemetry-specification/issues/5002
  ///
  /// - Parameters:
  ///   - span: The active readable span being mutated.
  ///   - key: The key of the added attribute.
  ///   - value: The value of the added attribute.
  func onAddAttribute(span: ReadableSpan, key: String, value: AttributeValue?) {
    Task {
      await PersistenceManager.shared?.onSpanAddAttribute(
        spanId: span.context.spanId.rawValue, key: key, value: value?.description)
    }
  }

  /// Called when a span completes its lifecycle.
  ///
  /// This method exports the finalized span data. If the export succeeds, it asynchronously instructs
  /// the persistence layer to free the span's allocated memory slot in the in-flight disk buffer.
  ///
  /// - Parameter span: The completed readable span.
  func onEnd(span: ReadableSpan) {
    let timestampNanoseconds = UInt64(span.toSpanData().endTime.timeIntervalSince1970 * 1_000_000_000)

    Task {
      await PersistenceManager.shared?.onSpanEnd(
        spanId: span.context.spanId.rawValue,
        endTime: timestampNanoseconds
      )
    }
  }

  func forceFlush(timeout: TimeInterval?) {}

  func shutdown(explicitTimeout: TimeInterval?) {}
}
