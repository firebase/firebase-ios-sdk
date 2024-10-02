// Copyright 2022 Google LLC
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

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension
@_implementationOnly import FirebaseInstallations
@_implementationOnly import GoogleDataTransport

#if swift(>=6.0)
  internal import Promises
#elseif swift(>=5.10)
  import Promises
#else
  @_implementationOnly import Promises
#endif

private enum GoogleDataTransportConfig {
  static let sessionsLogSource = "1974"
  static let sessionsTarget = GDTCORTarget.FLL
}

@objc(FIRSessions) final class Sessions: NSObject, Library, SessionsProvider {
  // MARK: - Private Variables

  /// The Firebase App ID associated with Sessions.
  private let appID: String

  /// Top-level Classes in the Sessions SDK
  private let coordinator: SessionCoordinatorProtocol
  private let initiator: SessionInitiator
  private let sessionGenerator: SessionGenerator
  private let appInfo: ApplicationInfoProtocol
  private let settings: SettingsProtocol

  /// Subscribers
  /// `subscribers` are used to determine the Data Collection state of the Sessions SDK.
  /// If any Subscribers has Data Collection enabled, the Sessions SDK will send events
  private var subscribers: [SessionsSubscriber] = []
  /// `subscriberPromises` are used to wait until all Subscribers have registered
  /// themselves. Subscribers must have Data Collection state available upon registering.
  private var subscriberPromises: [SessionsSubscriberName: Promise<Void>] = [:]

  /// Notifications
  static let SessionIDChangedNotificationName = Notification
    .Name("SessionIDChangedNotificationName")
  let notificationCenter = NotificationCenter()

  // MARK: - Initializers

  // Initializes the SDK and top-level classes
  required convenience init(appID: String, installations: InstallationsProtocol) {
    let googleDataTransport = GDTCORTransport(
      mappingID: GoogleDataTransportConfig.sessionsLogSource,
      transformers: nil,
      target: GoogleDataTransportConfig.sessionsTarget
    )

    let fireLogger = EventGDTLogger(googleDataTransport: googleDataTransport!)

    let appInfo = ApplicationInfo(appID: appID)
    let settings = SessionsSettings(
      appInfo: appInfo,
      installations: installations
    )

    let sessionGenerator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: settings))
    let coordinator = SessionCoordinator(
      installations: installations,
      fireLogger: fireLogger
    )

    let initiator = SessionInitiator(settings: settings)

    self.init(appID: appID,
              sessionGenerator: sessionGenerator,
              coordinator: coordinator,
              initiator: initiator,
              appInfo: appInfo,
              settings: settings) { result in
      switch result {
      case .success(()):
        Logger.logInfo("Successfully logged Session Start event")
      case let .failure(sessionsError):
        switch sessionsError {
        case let .SessionInstallationsError(error):
          Logger.logError(
            "Error getting Firebase Installation ID: \(error). Skipping this Session Event"
          )
        case let .DataTransportError(error):
          Logger
            .logError(
              "Error logging Session Start event to GoogleDataTransport: \(error)."
            )
        case .NoDependenciesError:
          Logger
            .logError(
              "Sessions SDK did not have any dependent SDKs register as dependencies. Events will not be sent."
            )
        case .SessionSamplingError:
          Logger
            .logDebug(
              "Sessions SDK has sampled this session"
            )
        case .DisabledViaSettingsError:
          Logger
            .logDebug(
              "Sessions SDK is disabled via Settings"
            )
        case .DataCollectionError:
          Logger
            .logDebug(
              "Data Collection is disabled for all subscribers. Skipping this Session Event"
            )
        case .SessionInstallationsTimeOutError:
          Logger.logError(
            "Error getting Firebase Installation ID due to timeout. Skipping this Session Event"
          )
        }
      }
    }
  }

  // Initializes the SDK and begins the process of listening for lifecycle events and logging
  // events
  init(appID: String, sessionGenerator: SessionGenerator, coordinator: SessionCoordinatorProtocol,
       initiator: SessionInitiator, appInfo: ApplicationInfoProtocol, settings: SettingsProtocol,
       loggedEventCallback: @escaping (Result<Void, FirebaseSessionsError>) -> Void) {
    self.appID = appID

    self.sessionGenerator = sessionGenerator
    self.coordinator = coordinator
    self.initiator = initiator
    self.appInfo = appInfo
    self.settings = settings

    super.init()

    for subscriberName in SessionsDependencies.dependencies {
      subscriberPromises[subscriberName] = Promise<Void>.pending()
    }

    Logger
      .logDebug(
        "Version \(FirebaseVersion()). Expecting subscriptions from: \(SessionsDependencies.dependencies)"
      )

    self.initiator.beginListening {
      // Generating a Session ID early is important as Subscriber
      // SDKs will need to read it immediately upon registration.
      let sessionInfo = self.sessionGenerator.generateNewSession()

      // Post a notification so subscriber SDKs can get an updated Session ID
      self.notificationCenter.post(name: Sessions.SessionIDChangedNotificationName,
                                   object: nil)

      let event = SessionStartEvent(sessionInfo: sessionInfo, appInfo: self.appInfo)

      // If there are no Dependencies, then the Sessions SDK can't acknowledge
      // any products data collection state, so the Sessions SDK won't send events.
      guard !self.subscriberPromises.isEmpty else {
        loggedEventCallback(.failure(.NoDependenciesError))
        return
      }

      // Wait until all subscriber promises have been fulfilled before
      // doing any data collection.
      all(self.subscriberPromises.values).then(on: .global(qos: .background)) { _ in
        guard self.isAnyDataCollectionEnabled else {
          loggedEventCallback(.failure(.DataCollectionError))
          return
        }

        Logger.logDebug("Data Collection is enabled for at least one Subscriber")

        // Fetch settings if they have expired. This must happen after the check for
        // data collection because it uses the network, but it must happen before the
        // check for sessionsEnabled from Settings because otherwise we would permanently
        // turn off the Sessions SDK when we disabled it.
        self.settings.updateSettings()

        self.addSubscriberFields(event: event)
        event.setSamplingRate(samplingRate: self.settings.samplingRate)

        guard sessionInfo.shouldDispatchEvents else {
          loggedEventCallback(.failure(.SessionSamplingError))
          return
        }

        guard self.settings.sessionsEnabled else {
          loggedEventCallback(.failure(.DisabledViaSettingsError))
          return
        }

        self.coordinator.attemptLoggingSessionStart(event: event) { result in
          loggedEventCallback(result)
        }
      }
    }
  }

  // MARK: - Sampling

  static func shouldCollectEvents(settings: SettingsProtocol) -> Bool {
    // Calculate whether we should sample events using settings data
    // Sampling rate of 1 means we do not sample.
    let randomValue = Double.random(in: 0 ... 1)
    return randomValue <= settings.samplingRate
  }

  // MARK: - Data Collection

  var isAnyDataCollectionEnabled: Bool {
    for subscriber in subscribers {
      if subscriber.isDataCollectionEnabled {
        return true
      }
    }
    return false
  }

  func addSubscriberFields(event: SessionStartEvent) {
    for subscriber in subscribers {
      event.set(subscriber: subscriber.sessionsSubscriberName,
                isDataCollectionEnabled: subscriber.isDataCollectionEnabled,
                appInfo: appInfo)
    }
  }

  // MARK: - SessionsProvider

  var currentSessionDetails: SessionDetails {
    return SessionDetails(sessionId: sessionGenerator.currentSession?.sessionId)
  }

  func register(subscriber: SessionsSubscriber) {
    Logger
      .logDebug(
        "Registering Sessions SDK subscriber with name: \(subscriber.sessionsSubscriberName), data collection enabled: \(subscriber.isDataCollectionEnabled)"
      )

    notificationCenter.addObserver(
      forName: Sessions.SessionIDChangedNotificationName,
      object: nil,
      queue: nil
    ) { notification in
      subscriber.onSessionChanged(self.currentSessionDetails)
    }
    // Immediately call the callback because the Sessions SDK starts
    // before subscribers, so subscribers will miss the first Notification
    subscriber.onSessionChanged(currentSessionDetails)

    // Fulfil this subscriber's promise
    subscribers.append(subscriber)
    subscriberPromises[subscriber.sessionsSubscriberName]?.fulfill(())
  }

  // MARK: - Library conformance

  static func componentsToRegister() -> [Component] {
    return [Component(SessionsProvider.self,
                      instantiationTiming: .alwaysEager) { container, isCacheable in
        // Sessions SDK only works for the default app
        guard let app = container.app, app.isDefaultApp else { return nil }
        isCacheable.pointee = true
        let installations = Installations.installations(app: app)
        return self.init(appID: app.options.googleAppID, installations: installations)
      }]
  }
}
