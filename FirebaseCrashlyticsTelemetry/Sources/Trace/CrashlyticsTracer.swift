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

/// A specialized wrapper around a tracer that injects Crashlytics persistence into the pipeline.
///
/// `CrashlyticsTracer` intercepts the standard span creation process. By overriding the `spanBuilder`
/// method, it ensures that all telemetry generated through this tracer is built using a `CrashlyticsSpanBuilder`.
class CrashlyticsTracer: Tracer {
  /// The underlying tracer providing core functionality.
  private let otelTracer: Tracer
  /// The processor passed down the pipeline to handle disk persistence for created spans.
  private let crashlyticsProcessor: CrashlyticsSpanProcessor

  /// Initializes a new Crashlytics-aware tracer wrapper.
  ///
  /// - Parameters:
  ///   - tracer: The underlying OpenTelemetry tracer to wrap.
  ///   - crashlyticsProcessor: The processor used to intercept and persist span mutations.
  init(
    tracer: Tracer,
    crashlyticsProcessor: CrashlyticsSpanProcessor
  ) {
    self.otelTracer = tracer
    self.crashlyticsProcessor = crashlyticsProcessor
  }

  /// Creates a span builder equipped with Crashlytics persistence tracking.
  ///
  /// This method forwards the span name to the underlying tracer to create a base builder,
  /// and then wraps that builder in a `CrashlyticsSpanBuilder`.
  ///
  /// - Parameter spanName: The name of the span to be built.
  /// - Returns: A `CrashlyticsSpanBuilder` instance configured with the active processor.
  func spanBuilder(spanName: String) -> SpanBuilder {
    let realBuilder = self.otelTracer.spanBuilder(spanName: spanName)
    return CrashlyticsSpanBuilder(
      spanBuilder: realBuilder,
      crashlyticsProcessor: self.crashlyticsProcessor
    )
  }
}
