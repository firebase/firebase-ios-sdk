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

/// A specialized wrapper around a tracer provider that injects persistence into the trace pipeline.
///
/// `CrashlyticsTracerProvider` intercepts the standard tracer creation process. By overriding
/// the `get` method, it ensures that all tracers generated through this provider are returned as
/// `CrashlyticsTracer` instances.
class CrashlyticsTracerProvider: TracerProvider {
  /// The underlying OpenTelemetry tracer provider.
  private let otelTracerProvider: TracerProvider
  /// The processor injected into the telemetry pipeline to handle disk persistence.
  private let crashlyticsProcessor: CrashlyticsSpanProcessor

  /// Initializes a new Crashlytics-aware tracer provider.
  ///
  /// - Parameters:
  ///   - tracerProvider: The underlying OpenTelemetry tracer provider to wrap.
  ///   - crashlyticsProcessor: The processor used to intercept and persist span mutations.
  init(
    tracerProvider: TracerProvider,
    crashlyticsProcessor: CrashlyticsSpanProcessor
  ) {
    self.otelTracerProvider = tracerProvider
    self.crashlyticsProcessor = crashlyticsProcessor
  }

  /// Retrieves a tracer configured with Crashlytics persistence tracking.
  ///
  /// This method retrieves a standard tracer from the underlying provider and wraps it in a
  /// `CrashlyticsTracer`, ensuring the persistence processor is successfully passed down the pipeline.
  ///
  /// - Parameters:
  ///   - instrumentationName: The name of the instrumentation library requesting the tracer.
  ///   - instrumentationVersion: The version of the instrumentation library, if available.
  ///   - schemaUrl: The schema URL associated with the telemetry data, if available.
  ///   - attributes: The default attributes to associate with the tracer.
  /// - Returns: A `CrashlyticsTracer` instance configured with the active processor.
  func get(
    instrumentationName: String,
    instrumentationVersion: String?,
    schemaUrl: String?,
    attributes: [String: AttributeValue]?
  ) -> Tracer {
    let tracer = self.otelTracerProvider.get(
      instrumentationName: instrumentationName,
      instrumentationVersion: instrumentationVersion,
      schemaUrl: schemaUrl,
      attributes: attributes)

    return CrashlyticsTracer(
      tracer: tracer,
      crashlyticsProcessor: self.crashlyticsProcessor
    )
  }
}
