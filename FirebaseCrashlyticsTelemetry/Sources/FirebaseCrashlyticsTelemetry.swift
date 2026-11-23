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
import FirebaseCrashlytics
internal import FirebaseSessions

import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter

@objc(FIRCrashlyticsTelemetry)
final class FirebaseCrashlyticsTelemetry: NSObject, Library, CrashlyticsTelemetryProvider,
  SessionsSubscriber, @unchecked Sendable {
  private(set) nonisolated(unsafe) static var instance: FirebaseCrashlyticsTelemetry?

  static let scopeName = "FirebaseCrashlyticsTelemetry"

  let tracerProvider: TracerProvider
  let loggerProvider: LoggerProvider
  let tracer: Tracer
  let logger: Logger
  let resource: Resource
  let scopeInfo: InstrumentationScopeInfo

  private var recoveryManager: RecoveredTelemetryExporter?
  private var networkInstrumentation: NetworkInstrumentation?
  private var screenInstrumentation: ScreenInstrumentation?
  private var userInteractionInstrumentation: UserInteractionInstrumentation?

  // TODO: Remove lock and activeSpans
  private let lock = NSRecursiveLock()
  private var activeSpans = [any Span]()

  // TODO: Remove custom key value
  private let mutableCustomAttributeKey = "firebase.test_attribute"
  private var mutableCustomAttributeValue = 0

  init(options: FirebaseOptions,
       sessions: SessionsProvider,
       environment: any TelemetryEnvironmentInfo = TelemetryEnvironment()) {
    let scopeVersion = environment.sdkVersion
    let scopeAttributes = AttributeStore.instrumentationScopeAttributes(environment: environment)
    let scopeInfo = InstrumentationScopeInfo(
      name: Self.scopeName,
      version: scopeVersion,
      schemaUrl: nil,
      attributes: scopeAttributes
    )
    let resource = Resource(
      attributes: AttributeStore.resourceAttributes(
        options: options,
        environment: environment
      )
    )

    self.resource = resource
    self.scopeInfo = scopeInfo

    recoveryManager = RecoveryManager(
      uploader: TelemetryUploader(options: options),
      scope: scopeInfo,
      resource: resource
    )

    // Initialize the persistence layer and upload the recovered spans.
    Task.detached(priority: .utility) { [weak recoveryManager] in
      if let recoveryManager = recoveryManager {
        PersistenceManager.shared.configure(recoveryManager: recoveryManager)
      }
    }

    let tracerProvider = Self.createTracerProvider(with: resource)
    let loggerProvider = Self.createLoggerProvider(with: resource)

    tracer = tracerProvider.get(
      instrumentationName: Self.scopeName,
      instrumentationVersion: scopeVersion,
      schemaUrl: nil,
      attributes: scopeAttributes
    )
    logger = loggerProvider
      .loggerBuilder(instrumentationScopeName: Self.scopeName)
      .setInstrumentationVersion(scopeVersion)
      .setAttributes(scopeAttributes)
      .build()

    self.tracerProvider = tracerProvider
    self.loggerProvider = loggerProvider

    super.init()

    LoggingHelper.logger.debug("Registering Sessions SDK subscription for session data")
    sessions.register(subscriber: self)

    // MARK: - Instrumentation

    networkInstrumentation = NetworkInstrumentation(tracer: tracer) { [weak self] in
      self?.latestActiveSpan()
    }

    screenInstrumentation = ScreenInstrumentation(logger: logger) { screen in
      AttributeStore.setScreenName(screen)
    }
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

  func latestActiveSpan() -> (any Span)? {
    lock.lock()
    defer { lock.unlock() }
    return activeSpans.last
  }

  // MARK: - Private Helpers

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

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    return [Component(CrashlyticsTelemetryProvider.self,
                      instantiationTiming: .eagerInDefaultApp) { container, isCacheable in
        // Crashlytics Telemetry SDK only works for the default app
        guard let app = container.app, app.isDefaultApp else { return nil }
        guard let sessions = ComponentType<SessionsProvider>.instance(
          for: SessionsProvider.self,
          in: container
        ) else {
          LoggingHelper.logger.error(
            "Failed to retrieve SessionsProvider from ComponentContainer. Crashlytics Telemetry will not initialize."
          )
          return nil
        }
        // TODO: Add a direct dependency on Firebase Crashlytics

        isCacheable.pointee = true

        self.instance = self.init(options: app.options, sessions: sessions)
        return self.instance
      }]
  }

  // MARK: - SessionsSubscriber conformance

  func onSessionChanged(_ session: SessionDetails) {
    LoggingHelper.logger.debug("Session ID changed: \(session.sessionId ?? "nil")")
    AttributeStore.setSessionId(session.sessionId)
  }

  var isDataCollectionEnabled: Bool {
    return Crashlytics.crashlytics().isCrashlyticsCollectionEnabled()
  }

  var sessionsSubscriberName: SessionsSubscriberName {
    return .CrashlyticsTelemetry
  }
}
