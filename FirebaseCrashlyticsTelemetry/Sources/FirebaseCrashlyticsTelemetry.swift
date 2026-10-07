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

internal import FirebaseCore
internal import FirebaseCoreExtension

import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter
import URLSessionInstrumentation

@objc(FIRCrashlyticsTelemetry)
final class FirebaseCrashlyticsTelemetry: NSObject, Library, CrashlyticsTelemetryProvider,
  @unchecked Sendable {
  private(set) nonisolated(unsafe) static var instance: FirebaseCrashlyticsTelemetry?

  let tracerProvider: TracerProvider
  let loggerProvider: LoggerProvider
  let tracer: Tracer
  let logger: Logger

  private var recoveryManager: RecoveredTelemetryExporter?
  private var urlInstrumentation: URLSessionInstrumentation?
  private(set) var viewInstrumentation: (any ActiveViewProvider)?
  private var userInteractionInstrumentation: UserInteractionInstrumentation?

  private let scopeName = "Firebase Crashlytics Telemetry"
  private let scopeVersion = "semver:0.1.0"

  // TODO: Remove lock and activeSpans
  private let lock = NSRecursiveLock()
  private var activeSpans = [any Span]()

  // TODO: Remove custom key value
  private let mutableCustomAttributeKey = "firebase.test_attribute"
  private var mutableCustomAttributeValue = 0

  private init(options: FirebaseOptions) {
    let resource = Self.createResource(scopeName: scopeName, projectId: options.projectID)

    recoveryManager = RecoveryManager(
      uploader: TelemetryUploader(options: options),
      scope: InstrumentationScopeInfo(name: scopeName, version: scopeVersion),
      resource: resource
    )

    // Initialize the persistence layer and upload the recovered spans.
    Task.detached(priority: .utility) { [weak recoveryManager] in
      if let recoveryManager = recoveryManager {
        await PersistenceManager.shared.configure(recoveryManager: recoveryManager)
      }
    }

    let tracerProvider = Self.createTracerProvider(with: resource)
    let loggerProvider = Self.createLoggerProvider(with: resource)

    tracer = tracerProvider.get(
      instrumentationName: scopeName, instrumentationVersion: scopeVersion
    )
    logger = loggerProvider.get(instrumentationScopeName: scopeName)

    self.tracerProvider = tracerProvider
    self.loggerProvider = loggerProvider

    super.init()

    // MARK: - Instrumentation

    urlInstrumentation = URLSessionInstrumentation(
      configuration: URLSessionInstrumentationConfiguration(
        shouldInstrument: filterNetworkRequests,
        spanCustomization: customizeNetworkSpan,
        tracer: tracer,
        semanticConvention: .stable
      )
    )

    viewInstrumentation = ViewInstrumentation(logger: logger)
    userInteractionInstrumentation = UserInteractionInstrumentation(logger: logger)
  }

  // MARK: - User Interaction Instrumentation

  public func recordTap(on widgetId: String) {
    userInteractionInstrumentation?.record(.tap(widgetId: widgetId))
  }

  // MARK: - Public API for testing

  // TODO: Remove all the testing API.

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

  private static func createResource(scopeName: String, projectId: String?) -> Resource {
    var attributes: [String: AttributeValue] = ["service.name": AttributeValue(scopeName)]

    if let id = projectId {
      attributes["gcp.project_id"] = AttributeValue(id)
    }

    return Resource(attributes: attributes)
  }

  private static func createTracerProvider(with resource: Resource) -> TracerProvider {
    let spanProcessor = SimpleSpanProcessor(spanExporter: StdoutSpanExporter())
    return CrashlyticsTracerProviderBuilder()
      .add(spanProcessors: [spanProcessor])
      .with(resource: resource)
      .build()
  }

  private static func createLoggerProvider(with resource: Resource) -> LoggerProvider {
    let logProcessor = CrashlyticsLogProcessor(logRecordExporter: StdoutLogExporter())

    return LoggerProviderBuilder()
      .with(processors: [logProcessor])
      .with(resource: resource)
      .build()
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

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    return [Component(CrashlyticsTelemetryProvider.self,
                      instantiationTiming: .eagerInDefaultApp) { container, isCacheable in
        // Crashlytics Telemetry SDK only works for the default app
        guard let app = container.app, app.isDefaultApp else { return nil }
        isCacheable.pointee = true

        instance = self.init(options: app.options)
        return instance
      }]
  }
}
