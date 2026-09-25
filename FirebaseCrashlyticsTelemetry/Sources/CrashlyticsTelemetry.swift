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

import Combine
import FirebaseCore
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation

public final class CrashlyticsTelemetry: @unchecked Sendable {
  public static let shared = CrashlyticsTelemetry()

  let tracerProvider: TracerProvider
  let loggerProvider: LoggerProvider
  let tracer: Tracer
  let logger: Logger

  var recoveryManager: RecoveredTelemetryExporter?

  private let lock = NSRecursiveLock()
  private var activeSpans = [any Span]()

  private var urlInstrumentation: URLSessionInstrumentation?
  private var viewInstrumentation: ViewInstrumentation?

  private let scopeName = "Firebase Crashlytics Telemetry"
  private let scopeVersion = "semver:0.1.0"

  private let mutableCustomAttributeKey = "firebase.test_attribute"
  private var mutableCustomAttributeValue = 0

  private init() {
    let resource = Self.createResource(scopeName: scopeName)

    /// When integrating with the firebase-ios-sdk, FirebaseOptions will be injected
    /// directly into this initializer. Firebase Core's component system will handle the
    /// initialization of this package and provide the resolved options, removing the need
    /// to access the global FirebaseApp.app() singleton here.
    if let firebaseOptions = FirebaseApp.app()?.options {
      recoveryManager = RecoveryManager(
        uploader: TelemetryUploader(options: firebaseOptions),
        scope: InstrumentationScopeInfo(name: scopeName, version: scopeVersion),
        resource: resource
      )
      // Initialize the persistence layer and upload recovered spans.
      Task {
        let _ = PersistenceManager.shared
      }
    } else {
      recoveryManager = nil
      LoggingHelper.logger.debug("Failed to initialize RecoveryManager. FirebaseApp not found.")
    }

    let providers = Self.createProviders(resource: resource)
    tracerProvider = providers.0
    loggerProvider = providers.1

    tracer = tracerProvider.get(
      instrumentationName: scopeName, instrumentationVersion: scopeVersion
    )
    logger = loggerProvider.get(instrumentationScopeName: scopeName)
  }

  // MARK: - Public API

  // TODO: Remove the public API methods below.

  public func configure() {
    lock.lock()
    defer { lock.unlock() }

    if urlInstrumentation == nil {
      setupNetworkAutoInstrumentation()
    }

    viewInstrumentation = ViewInstrumentation(logger: logger)
  }

  @discardableResult
  public func startSpan() -> Int {
    lock.lock()
    defer { lock.unlock() }

    let span = tracer.spanBuilder(spanName: "test-span \(activeSpans.count + 1)")
    span.setSpanKind(spanKind: .client)
    span.setAttribute(
      key: mutableCustomAttributeKey, value: "value: \(mutableCustomAttributeValue)"
    )

    if let lastSpan = activeSpans.last {
      span.setParent(lastSpan)
    }

    activeSpans.append(span.startSpan())

    return activeSpans.count
  }

  @discardableResult
  public func incrementCustomAttribute() -> Int {
    lock.lock()
    defer { lock.unlock() }

    mutableCustomAttributeValue += 1

    for span in activeSpans {
      span.setAttribute(
        key: mutableCustomAttributeKey,
        value: AttributeValue("value: \(mutableCustomAttributeValue)")
      )
    }

    return mutableCustomAttributeValue
  }

  @discardableResult
  public func stopSpan() -> Int {
    lock.lock()
    defer { lock.unlock() }

    if !activeSpans.isEmpty {
      let span = activeSpans.removeLast()
      span.status = .ok
      span.end()
    }

    return activeSpans.count
  }

  public func addLog() {
    lock.lock()
    defer { lock.unlock() }

    var log = logger.logRecordBuilder().setEventName("test").setSeverity(.info)
    if let context = activeSpans.last?.context {
      log = log.setSpanContext(context)
    }
    _ = log.emit()
  }

  // MARK: - Private Helpers

  private static func createResource(scopeName: String) -> Resource {
    var attributes: [String: AttributeValue] = ["service.name": AttributeValue(scopeName)]
    if let firebaseOptions = FirebaseApp.app()?.options,
       let projectID = firebaseOptions.projectID {
      attributes["gcp.project_id"] = AttributeValue(projectID)
    }
    return Resource(attributes: attributes)
  }

  private static func createProviders(resource: Resource) -> (TracerProvider, LoggerProvider) {
    // Tracing
    let localSpanProcessor = SimpleSpanProcessor(spanExporter: StdoutSpanExporter())
    let tracerProvider = CrashlyticsTracerProviderBuilder()
      .add(spanProcessors: [localSpanProcessor])
      .with(resource: resource)
      .build()

    // Logging
    let localLogProcessor = SimpleLogRecordProcessor(logRecordExporter: StdoutLogExporter())

    // TODO: Update logic to include logs when spans are also exported. Currently they're a no-op.
    let loggerProvider = LoggerProviderBuilder()
      .with(processors: [localLogProcessor])
      .with(resource: resource)
      .build()

    return (tracerProvider, loggerProvider)
  }

  // MARK: - Network Instrumentation

  private func setupNetworkAutoInstrumentation() {
    urlInstrumentation = URLSessionInstrumentation(
      configuration: URLSessionInstrumentationConfiguration(
        shouldInstrument: filterNetworkRequests,
        spanCustomization: customizeNetworkSpan,
        tracer: tracer,
        semanticConvention: .stable
      )
    )
  }

  private func filterNetworkRequests(urlRequest: URLRequest) -> Bool {
    let urlString = urlRequest.url?.absoluteString.lowercased() ?? ""
    return !urlString.contains("localhost") && !urlString.contains("firebasetelemetry")
  }

  private func customizeNetworkSpan(req: URLRequest, builder: SpanBuilder) {
    if let span = activeSpans.last {
      builder.setParent(span)
    }
  }
}
