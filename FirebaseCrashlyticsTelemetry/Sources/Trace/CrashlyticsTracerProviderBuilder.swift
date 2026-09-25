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

/// A builder for configuring and creating a Crashlytics-aware tracer provider.
///
/// This class serves as the entry point for the custom telemetry pipeline. It provides a standard
/// OpenTelemetry configuration interface while ensuring that the resulting provider is a
/// `CrashlyticsTracerProvider` fully equipped with the necessary persistence processor.
class CrashlyticsTracerProviderBuilder {
  /// The underlying OpenTelemetry tracer provider builder.
  private let otelTracerProviderBuilder: TracerProviderBuilder
  /// The span processor to handle persistence for the trace pipeline.
  private let crashlyticsProcessor: CrashlyticsSpanProcessor

  /// The configured clock for the provider.
  public var clock: Clock? { self.otelTracerProviderBuilder.clock }
  /// The configured ID generator for the provider.
  public var idGenerator: IdGenerator? { self.otelTracerProviderBuilder.idGenerator }
  /// The configured resource for the provider.
  public var resource: Resource? { self.otelTracerProviderBuilder.resource }
  /// The configured span limits for the provider.
  public var spanLimits: SpanLimits? { self.otelTracerProviderBuilder.spanLimits }
  /// The configured sampler for the provider.
  public var sampler: Sampler? { self.otelTracerProviderBuilder.sampler }
  /// The list of standard span processors configured for the provider.
  public var spanProcessors: [SpanProcessor] { self.otelTracerProviderBuilder.spanProcessors }

  /// Initializes a new Crashlytics tracer provider builder.
  ///
  /// This initializer sets up the underlying OpenTelemetry builder and instantiates the
  /// `CrashlyticsSpanProcessor` with its required exporter to ensure persistence tracking is ready.
  public init() {
    self.otelTracerProviderBuilder = TracerProviderBuilder()
    self.crashlyticsProcessor = CrashlyticsSpanProcessor()
  }

  public func build() -> CrashlyticsTracerProvider {
    let tracerProvider = self.otelTracerProviderBuilder.build()

    return CrashlyticsTracerProvider(
      tracerProvider: tracerProvider,
      crashlyticsProcessor: self.crashlyticsProcessor
    )
  }

  // MARK: - Forwarded Configuration Methods

  /// Sets the clock for the underlying tracer provider.
  ///
  /// - Parameter clock: The clock to use.
  /// - Returns: This builder instance, for chaining.
  public func with(clock: Clock) -> Self {
    _ = self.otelTracerProviderBuilder.with(clock: clock)
    return self
  }

  /// Sets the ID generator for the underlying tracer provider.
  ///
  /// - Parameter idGenerator: The ID generator to use.
  /// - Returns: This builder instance, for chaining.
  public func with(idGenerator: IdGenerator) -> Self {
    _ = self.otelTracerProviderBuilder.with(idGenerator: idGenerator)
    return self
  }

  /// Sets the resource for the underlying tracer provider.
  ///
  /// - Parameter resource: The resource to associate with generated spans.
  /// - Returns: This builder instance, for chaining.
  public func with(resource: Resource) -> Self {
    _ = self.otelTracerProviderBuilder.with(resource: resource)
    return self
  }

  /// Sets the span limits for the underlying tracer provider.
  ///
  /// - Parameter spanLimits: The span limits to enforce.
  /// - Returns: This builder instance, for chaining.
  public func with(spanLimits: SpanLimits) -> Self {
    _ = self.otelTracerProviderBuilder.with(spanLimits: spanLimits)
    return self
  }

  /// Sets the sampler for the underlying tracer provider.
  ///
  /// - Parameter sampler: The sampler to use for trace sampling.
  /// - Returns: This builder instance, for chaining.
  public func with(sampler: Sampler) -> Self {
    _ = self.otelTracerProviderBuilder.with(sampler: sampler)
    return self
  }

  /// Adds a standard span processor to the underlying tracer provider.
  ///
  /// - Parameter spanProcessor: The span processor to add.
  /// - Returns: This builder instance, for chaining.
  public func add(spanProcessor: SpanProcessor) -> Self {
    _ = self.otelTracerProviderBuilder.add(spanProcessor: spanProcessor)
    return self
  }

  /// Adds multiple standard span processors to the underlying tracer provider.
  ///
  /// - Parameter spanProcessors: An array of span processors to add.
  /// - Returns: This builder instance, for chaining.
  public func add(spanProcessors: [SpanProcessor]) -> Self {
    _ = self.otelTracerProviderBuilder.add(spanProcessors: spanProcessors)
    return self
  }
}
