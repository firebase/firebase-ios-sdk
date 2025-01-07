// Copyright 2024 Google LLC
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

import FirebaseCore
import Foundation

#if SWIFT_PACKAGE
  @_implementationOnly import GoogleUtilities_NSData
#else
  import FirebaseInstallations
  import FirebaseRemoteConfigInterop
  @_implementationOnly import GoogleUtilities
#endif // SWIFT_PACKAGE

// TODO(ncooke3): Once Obj-C tests are ported, all `public` access modifers can be removed.

#if RCN_STAGING_SERVER
  private let serverURLDomain = "staging-firebaseremoteconfig.sandbox.googleapis.com"
#else
  private let serverURLDomain = "firebaseremoteconfig.googleapis.com"
#endif

private let requestJSONKeyAppID = "app_id"

private let eTagHeaderName = "Etag"

/// Remote Config Error Info End Time Seconds;
private let throttledEndTimeInSecondsKey = "error_throttled_end_time_seconds"

/// Fetch identifier for Base Fetch
private let baseFetchType = "BASE"
/// Fetch identifier for Realtime Fetch
private let realtimeFetchType = "REALTIME"

/// HTTP status codes. Ref: https://cloud.google.com/apis/design/errors#error_retries
private enum FetchResponseStatus: Int {
  case ok = 200
  case tooManyRequests = 429
  case internalError = 500
  case serviceUnavailable = 503
  case gatewayTimeout = 504
}

// MARK: - Dependency Injection Protocols

@objc public protocol RCNURLSessionDataTaskProtocol {
  func resume()
}

extension URLSessionDataTask: RCNURLSessionDataTaskProtocol {}

@objc public protocol RCNConfigFetchSession {
  var configuration: URLSessionConfiguration { get }
  func invalidateAndCancel()
  @preconcurrency
  func dataTask(with request: URLRequest,
                completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void)
    -> RCNURLSessionDataTaskProtocol
}

extension URLSession: RCNConfigFetchSession {
  public func dataTask(with request: URLRequest,
                       completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?)
                         -> Void) -> any RCNURLSessionDataTaskProtocol {
    let dataTask: URLSessionDataTask = dataTask(with: request, completionHandler: completionHandler)
    return dataTask as RCNURLSessionDataTaskProtocol
  }
}

// MARK: - ConfigFetch

@objc(RCNConfigFetch) public class ConfigFetch: NSObject {
  private let content: ConfigContent

  let settings: ConfigSettings

  private let analytics: (any FIRAnalyticsInterop)?

  private let experiment: ConfigExperiment?

  /// Guard the read/write operation.
  private let lockQueue: DispatchQueue

  public var installations: (any InstallationsProtocol)?

  /// Provide fetchSession for tests to override.
  /// - Note: Managed internally by the fetch instance.
  public var fetchSession: any RCNConfigFetchSession

  private let namespace: String

  private let options: FirebaseOptions

  /// Provide config template version number for Realtime config client.
  @objc public var templateVersionNumber: String

  @objc public convenience init(content: ConfigContent,
                                DBManager: ConfigDBManager,
                                settings: ConfigSettings,
                                analytics: (any FIRAnalyticsInterop)?,
                                experiment: ConfigExperiment?,
                                queue: DispatchQueue,
                                namespace: String,
                                options: FirebaseOptions) {
    self.init(
      content: content,
      DBManager: DBManager,
      settings: settings,
      analytics: analytics,
      experiment: experiment,
      queue: queue,
      namespace: namespace,
      options: options,
      fetchSessionProvider: URLSession.init(configuration:),
      installations: nil
    )
  }

  private let configuredFetchSessionProvider: (ConfigSettings) -> RCNConfigFetchSession

  /// Designated initializer
  @objc public init(content: ConfigContent,
                    DBManager: ConfigDBManager,
                    settings: ConfigSettings,
                    analytics: (any FIRAnalyticsInterop)?,
                    experiment: ConfigExperiment?,
                    queue: DispatchQueue,
                    namespace: String,
                    options: FirebaseOptions,
                    fetchSessionProvider: @escaping (URLSessionConfiguration)
                      -> RCNConfigFetchSession,
                    installations: InstallationsProtocol?) {
    self.namespace = namespace
    self.settings = settings
    self.analytics = analytics
    self.experiment = experiment
    lockQueue = queue
    self.content = content
    configuredFetchSessionProvider = { settings in
      let config = URLSessionConfiguration.default
      config.timeoutIntervalForRequest = settings.fetchTimeout
      config.timeoutIntervalForResource = settings.fetchTimeout
      return fetchSessionProvider(config)
    }
    fetchSession = configuredFetchSessionProvider(settings)
    self.options = options
    templateVersionNumber = settings.lastFetchedTemplateVersion
    self.installations = if let installations {
      installations
    } else if
      let appName = namespace.components(separatedBy: ":").last,
      let app = FirebaseApp.app(name: appName) {
      Installations.installations(app: app)
    } else {
      nil as InstallationsProtocol?
    }

    super.init()
  }

  public var disableNetworkSessionRecreation: Bool = false

  /// Add the ability to update NSURLSession's timeout after a session has already been created.
  @objc public func recreateNetworkSession() {
    if disableNetworkSessionRecreation {
      return
    }
    fetchSession.invalidateAndCancel()
    fetchSession = configuredFetchSessionProvider(settings)
  }

  /// Return the current session. (Tests).
  @objc public func currentNetworkSession() -> RCNConfigFetchSession {
    fetchSession
  }

  deinit {
    fetchSession.invalidateAndCancel()
  }

  // MARK: - Fetch Config API

  /// Fetches config data keyed by namespace. Completion block will be called on the main queue.
  /// - Parameters:
  ///   - expirationDuration: Expiration duration, in seconds.
  ///   - completionHandler: Callback handler.
  @objc public func fetchConfig(withExpirationDuration expirationDuration: TimeInterval,
                                completionHandler: ((RemoteConfigFetchStatus, (any Error)?)
                                  -> Void)?) {
    // Note: We expect the googleAppID to always be available.
    let hasDeviceContextChanged = Device.remoteConfigHasDeviceContextChanged(
      settings.deviceContext,
      projectIdentifier: options.googleAppID
    )

    lockQueue.async { [weak self] in
      guard let strongSelf = self else { return }

      // Check whether we are outside of the minimum fetch interval.
      if !strongSelf.settings
        .hasMinimumFetchIntervalElapsed(expirationDuration) && !hasDeviceContextChanged {
        RCLog.debug("I-RCN000051", "Returning cached data.")
        strongSelf.reportCompletion(on: completionHandler, status: .success, error: nil)
        return
      }

      // Check if a fetch is already in progress.
      if strongSelf.settings.isFetchInProgress {
        // Check if we have some fetched data.
        if strongSelf.settings.lastFetchTimeInterval > 0 {
          RCLog.debug(
            "I-RCN000052",
            "A fetch is already in progress. Using previous fetch results."
          )
          strongSelf
            .reportCompletion(
              on: completionHandler,
              status: strongSelf.settings.lastFetchStatus,
              error: nil
            )
          return
        } else {
          RCLog.error("I-RCN000053", "A fetch is already in progress. Ignoring duplicate request.")
          strongSelf.reportCompletion(on: completionHandler, status: .failure, error: nil)
          return
        }
      }

      // Check whether cache data is within throttle limit.
      if strongSelf.settings.shouldThrottle() && !hasDeviceContextChanged {
        // Must set lastFetchStatus before FailReason.
        strongSelf.settings.lastFetchStatus = .throttled
        strongSelf.settings.lastFetchError = RemoteConfigError.throttled
        let throttledEndTime = strongSelf.settings.exponentialBackoffThrottleEndTime

        let error = NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.throttled.rawValue,
          userInfo: [throttledEndTimeInSecondsKey: throttledEndTime]
        )
        strongSelf
          .reportCompletion(
            on: completionHandler,
            status: strongSelf.settings.lastFetchStatus,
            error: error
          )
        return
      }
      strongSelf.settings.isFetchInProgress = true
      let fetchTypeHeader = "\(baseFetchType)/1"
      strongSelf
        .refreshInstallationsToken(
          withFetchHeader: fetchTypeHeader,
          completionHandler: completionHandler,
          updateCompletionHandler: nil
        )
    }
  }

  // MARK: - Fetch Helpers

  /// Fetches config data immediately, keyed by namespace. Completion block will be called on the
  /// main queue.
  /// - Parameters:
  ///   - fetchAttemptNumber: The number of the fetch attempt.
  ///   - completionHandler: Callback handler.
  @objc public func realtimeFetchConfig(fetchAttemptNumber: Int,
                                        completionHandler: @escaping (RemoteConfigFetchStatus,
                                                                      RemoteConfigUpdate?,
                                                                      Error?) -> Void) {
    // Note: We expect the googleAppID to always be available.
    let hasDeviceContextChanged = Device.remoteConfigHasDeviceContextChanged(
      settings.deviceContext,
      projectIdentifier: options.googleAppID
    )

    lockQueue.async { [weak self] in
      guard let strongSelf = self else { return }
      // Check whether cache data is within throttle limit.
      if strongSelf.settings.shouldThrottle() && !hasDeviceContextChanged {
        // Must set lastFetchStatus before FailReason.
        strongSelf.settings.lastFetchStatus = .throttled
        strongSelf.settings.lastFetchError = RemoteConfigError.throttled
        let throttledEndTime = strongSelf.settings.exponentialBackoffThrottleEndTime

        let error = NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.throttled.rawValue,
          userInfo: [throttledEndTimeInSecondsKey: throttledEndTime]
        )
        strongSelf
          .reportCompletion(
            status: .failure,
            update: nil,
            error: error,
            completionHandler: nil,
            updateCompletionHandler: completionHandler
          )
        return
      }
      strongSelf.settings.isFetchInProgress = true

      let fetchTypeHeader = "\(realtimeFetchType)/\(fetchAttemptNumber)"
      strongSelf
        .refreshInstallationsToken(
          withFetchHeader: fetchTypeHeader,
          completionHandler: nil,
          updateCompletionHandler: completionHandler
        )
    }
  }

  /// Refresh installation ID token before fetching config. installation ID is now mandatory for
  /// fetch requests to work.(b/14751422).
  private func refreshInstallationsToken(withFetchHeader fetchTypeHeader: String,
                                         completionHandler: (
                                           (RemoteConfigFetchStatus, Error?) -> Void
                                         )?,
                                         updateCompletionHandler: (
                                           (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?)
                                             -> Void
                                         )?) {
    guard let installations, !options.gcmSenderID.isEmpty else {
      let errorDescription = "Failed to get GCMSenderID"
      RCLog.error("I-RCN000074", errorDescription)
      settings.isFetchInProgress = false
      reportCompletion(
        on: completionHandler,
        status: .failure,
        error: NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.internalError.rawValue,
          userInfo: [NSLocalizedDescriptionKey: errorDescription]
        )
      )
      return
    }

    let installationsTokenHandler: (InstallationsAuthTokenResult?, (any Error)?)
      -> Void = { [weak self] tokenResult, error in
        guard let strongSelf = self else { return }

        // NOTE(ncooke3): Confirmed that tokenResult is nil.
        if let error {
          let errorDescription = "Failed to get installations token. Error : \(error)."
          RCLog.error("I-RCN000073", errorDescription)
          strongSelf.settings.isFetchInProgress = false

          let userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: errorDescription,
            NSUnderlyingErrorKey: (error as NSError).userInfo[NSUnderlyingErrorKey] as Any,
          ]

          strongSelf.reportCompletion(
            on: completionHandler,
            status: .failure,
            error: NSError(
              domain: ConfigConstants.RemoteConfigErrorDomain,
              code: RemoteConfigError.internalError.rawValue,
              userInfo: userInfo
            )
          )
          return
        }

        // We have a valid token. Get the backing installationID.
        installations.installationID { [weak self] identifier, error in
          guard let strongSelf = self else { return }

          // Dispatch to the RC serial queue to update settings on the queue.
          strongSelf.lockQueue.async { [weak self] in
            guard let strongSelf = self else { return }

            // Update config settings with the IID and token.
            strongSelf.settings.configInstallationsToken = tokenResult?.authToken
            strongSelf.settings.configInstallationsIdentifier = identifier ?? ""

            // NOTE(ncooke3): Confirmed that identifier is nil.
            if let error {
              let errorDescription = "Error getting iid : \(error.localizedDescription)"
              let userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: errorDescription,
                NSUnderlyingErrorKey: (error as NSError).userInfo[NSUnderlyingErrorKey] as Any,
              ]

              RCLog.error("I-RCN000055", errorDescription)
              strongSelf.settings.isFetchInProgress = false
              strongSelf.reportCompletion(
                on: completionHandler,
                status: .failure,
                error: NSError(
                  domain: ConfigConstants.RemoteConfigErrorDomain,
                  code: RemoteConfigError.internalError.rawValue,
                  userInfo: userInfo
                )
              )
              return
            }

            RCLog
              .info(
                "I-RCN000022",
                "Success to get iid : \(strongSelf.settings.configInstallationsIdentifier)."
              )
            strongSelf.doFetchCall(
              fetchTypeHeader: fetchTypeHeader,
              completionHandler: completionHandler,
              updateCompletionHandler: updateCompletionHandler
            )
          }
        }
      }

    RCLog.debug("I-RCN000039", "Starting requesting token.")
    installations.authToken(completion: installationsTokenHandler)
  }

  private func doFetchCall(fetchTypeHeader: String,
                           completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                           updateCompletionHandler: (
                             (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?) -> Void
                           )?) {
    getAnalyticsUserProperties { userProperties in
      self.lockQueue.async {
        self.fetch(
          userProperties: userProperties,
          fetchTypeHeader: fetchTypeHeader,
          completionHandler: completionHandler,
          updateCompletionHandler: updateCompletionHandler
        )
      }
    }
  }

  private func getAnalyticsUserProperties(completionHandler: @escaping ([String: Any]) -> Void) {
    RCLog.debug("I-RCN000060", "Fetch with user properties completed.")
    if analytics == nil {
      completionHandler([:])
    } else {
      analytics?.getUserProperties(callback: completionHandler)
    }
  }

  private func reportCompletion(on handler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                status: RemoteConfigFetchStatus,
                                error: Error?) {
    reportCompletion(
      status: status,
      update: nil,
      error: error,
      completionHandler: handler,
      updateCompletionHandler: nil
    )
  }

  private func reportCompletion(status: RemoteConfigFetchStatus,
                                update: RemoteConfigUpdate?,
                                error: Error?,
                                completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                updateCompletionHandler: (
                                  (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?) -> Void
                                )?) {
    if let completionHandler {
      DispatchQueue.main.async {
        completionHandler(status, error)
      }
    }
    // if completion handler expects a config update response
    if let updateCompletionHandler {
      DispatchQueue.main.async {
        updateCompletionHandler(status, update, error)
      }
    }
  }

  private func fetch(userProperties: [String: Any],
                     fetchTypeHeader: String,
                     completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                     updateCompletionHandler: (
                       (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?) -> Void
                     )?) {
    RCLog.debug("I-RCN000061", "Fetch with user properties initiated.")

    let postRequestString = settings.nextRequest(withUserProperties: userProperties)

    // Get POST request content.
    guard
      let content = postRequestString.data(using: .utf8),
      let compressedContent = try? NSData.gul_data(byGzippingData: content)
    else {
      let errorString = "Failed to compress the config request."
      RCLog.warning("I-RCN000033", errorString)
      let error = NSError(
        domain: ConfigConstants.RemoteConfigErrorDomain,
        code: RemoteConfigError.internalError.rawValue,
        userInfo: [NSLocalizedDescriptionKey: errorString]
      )
      settings.isFetchInProgress = false
      reportCompletion(
        status: .failure,
        update: nil,
        error: error,
        completionHandler: completionHandler,
        updateCompletionHandler: updateCompletionHandler
      )
      return
    }

    RCLog.debug("I-RCN000040", "Start config fetch.")

    let fetcherCompletion: (Data?, URLResponse?, Error?) -> Void = {
      [weak self] data,
        response,
        error in
      RCLog.debug(
        "I-RCN000050",
        "Config fetch completed. Error: \(error?.localizedDescription ?? "nil") StatusCode: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
      )

      guard let strongSelf = self else { return }

      // The fetch has completed.
      strongSelf.settings.isFetchInProgress = false

      strongSelf.lockQueue.async { [weak self] in
        guard let strongSelf = self else { return }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if error != nil || statusCode != FetchResponseStatus.ok.rawValue {
          // Update metadata about fetch failure.
          strongSelf.settings.updateMetadata(withFetchSuccessStatus: false, templateVersion: nil)

          if let error {
            if strongSelf.settings.lastFetchStatus == .success {
              RCLog.error(
                "I-RCN000025",
                "RCN Fetch failure: \(error.localizedDescription). Using cached config result."
              )
            } else {
              RCLog.error(
                "I-RCN000026",
                "RCN Fetch failure: \(error.localizedDescription). No cached config result."
              )
            }
          }

          if statusCode != FetchResponseStatus.ok.rawValue {
            RCLog.error("I-RCN000026", "RCN Fetch failure. Response HTTP error code: \(statusCode)")
            if statusCode == FetchResponseStatus.tooManyRequests
              .rawValue || statusCode == FetchResponseStatus.internalError
              .rawValue || statusCode == FetchResponseStatus.serviceUnavailable
              .rawValue || statusCode == FetchResponseStatus.gatewayTimeout.rawValue {
              strongSelf.settings.updateExponentialBackoffTime()
              if strongSelf.settings.shouldThrottle() {
                // Must set lastFetchStatus before FailReason.
                strongSelf.settings.lastFetchStatus = .throttled
                strongSelf.settings.lastFetchError = RemoteConfigError.throttled
                let throttledEndTime = strongSelf.settings.exponentialBackoffThrottleEndTime

                let error = NSError(
                  domain: ConfigConstants.RemoteConfigErrorDomain,
                  code: RemoteConfigError.throttled.rawValue,
                  userInfo: [throttledEndTimeInSecondsKey: throttledEndTime]
                )
                strongSelf
                  .reportCompletion(
                    status: strongSelf.settings.lastFetchStatus,
                    update: nil,
                    error: error,
                    completionHandler: completionHandler,
                    updateCompletionHandler: updateCompletionHandler
                  )
                return
              }
            }
          }
          // Return back the received error.
          // Must set lastFetchStatus before setting Fetch Error.
          strongSelf.settings.lastFetchStatus = .failure
          strongSelf.settings.lastFetchError = .internalError
          let userInfo: [String: Any] = [
            NSUnderlyingErrorKey: error ?? "Missing error.",
            NSLocalizedDescriptionKey: error?
              .localizedDescription ?? "Internal Error. Status code: \(statusCode)",
          ]

          strongSelf.reportCompletion(
            status: .failure,
            update: nil,
            error: NSError(
              domain: ConfigConstants.RemoteConfigErrorDomain,
              code: RemoteConfigError.internalError.rawValue,
              userInfo: userInfo
            ),
            completionHandler: completionHandler,
            updateCompletionHandler: updateCompletionHandler
          )
          return
        }

        // Fetch was successful. Check if we have data.
        guard let data else {
          RCLog.info("I-RCN000043", "RCN Fetch: No data in fetch response")
          // There may still be a difference between fetched and active config
          let update = strongSelf.content.getConfigUpdate(forNamespace: strongSelf.namespace)
          strongSelf
            .reportCompletion(
              status: .success,
              update: update,
              error: nil,
              completionHandler: completionHandler,
              updateCompletionHandler: updateCompletionHandler
            )
          return
        }

        // Config fetch succeeded.
        // JSONObjectWithData is always expected to return an NSDictionary in our case
        do {
          let fetchedConfig = try JSONSerialization.jsonObject(
            with: data,
            options: .mutableContainers
          ) as? [String: Any]

          // Check and log if we received an error from the server
          if
            let fetchedConfig,
            fetchedConfig.count == 1,
            let errDict = fetchedConfig[ConfigConstants.fetchResponseKeyError] as? [String: Any] {
            var errStr = "RCN Fetch Failure: Server returned error:"
            if let errorCode = errDict[ConfigConstants.fetchResponseKeyErrorCode] {
              errStr = errStr.appending("Code: \(errorCode)")
            }
            if let errorStatus = errDict[ConfigConstants.fetchResponseKeyErrorStatus] {
              errStr = errStr.appending(". Status: \(errorStatus)")
            }
            if let errorMessage = errDict[ConfigConstants.fetchResponseKeyErrorMessage] {
              errStr = errStr.appending(". Message: \(errorMessage)")
            }
            RCLog.error("I-RCN000044", errStr + ".")
            let error = NSError(
              domain: ConfigConstants.RemoteConfigErrorDomain,
              code: RemoteConfigError.internalError.rawValue,
              userInfo: [NSLocalizedDescriptionKey: errStr]
            )
            strongSelf
              .reportCompletion(
                status: .failure,
                update: nil,
                error: error,
                completionHandler: completionHandler,
                updateCompletionHandler: updateCompletionHandler
              )
            return
          }

          // Add the fetched config to the database.
          if let fetchedConfig {
            // Update config content to cache and DB.
            strongSelf.content
              .updateConfigContent(withResponse: fetchedConfig, forNamespace: strongSelf.namespace)
            // Update experiments only for 3p namespace
            let namespace = strongSelf.namespace.components(separatedBy: ":")[0]
            if namespace == RemoteConfigConstants.NamespaceGoogleMobilePlatform {
              let experiments =
                fetchedConfig[ConfigConstants
                  .fetchResponseKeyExperimentDescriptions] as? [[String: Any]]
              strongSelf.experiment?.updateExperiments(withResponse: experiments)
            }

            strongSelf.templateVersionNumber = strongSelf
              .getTemplateVersionNumber(fetchedConfig: fetchedConfig)
          } else {
            RCLog.debug("I-RCN000063", "Empty response with no fetched config.")
          }

          // We had a successful fetch. Update the current Etag in settings if different.
          // Look for "Etag" but fall back to "etag" if needed.
          let latestETag = (response as? HTTPURLResponse)?
            .allHeaderFields[eTagHeaderName] as? String ?? (response as? HTTPURLResponse)?
            .allHeaderFields["etag"] as? String
          if strongSelf.settings.lastETag == nil ||
            strongSelf.settings.lastETag != latestETag {
            strongSelf.settings.lastETag = latestETag
          }
          // Compute config update after successful fetch
          let update = strongSelf.content.getConfigUpdate(forNamespace: strongSelf.namespace)

          strongSelf.settings.updateMetadata(
            withFetchSuccessStatus: true,
            templateVersion: strongSelf.templateVersionNumber
          )
          strongSelf
            .reportCompletion(
              status: .success,
              update: update,
              error: nil,
              completionHandler: completionHandler,
              updateCompletionHandler: updateCompletionHandler
            )
          return
        } catch {
          RCLog.error(
            "I-RCN000042",
            "RCN Fetch failure: \(error). Could not parse response data as JSON"
          )
        }
      }
    }

    RCLog.debug("I-RCN000061", "Making remote config fetch.")

    let dataTask = urlSessionDataTask(content: compressedContent,
                                      fetchTypeHeader: fetchTypeHeader,
                                      completionHandler: fetcherCompletion)
    dataTask.resume()
  }

  private static func newFetchSession(settings: ConfigSettings) -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = settings.fetchTimeout
    config.timeoutIntervalForResource = settings.fetchTimeout
    let session = URLSession(configuration: config)
    return session
  }

  private func urlSessionDataTask(content: Data,
                                  fetchTypeHeader: String,
                                  completionHandler fetcherCompletion: @escaping (Data?,
                                                                                  URLResponse?,
                                                                                  Error?) -> Void)
    -> RCNURLSessionDataTaskProtocol {
    let url = Utils.constructServerURL(
      domain: serverURLDomain,
      apiKey: options.apiKey,
      optionsID: options.projectID ?? "",
      namespace: namespace
    )
    RCLog.debug("I-RCN000046", "Making config request: \(url.absoluteString)")

    let timeoutInterval = fetchSession.configuration.timeoutIntervalForResource
    var urlRequest = URLRequest(url: url,
                                cachePolicy: .reloadIgnoringLocalCacheData,
                                timeoutInterval: timeoutInterval)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(settings.configInstallationsToken,
                        forHTTPHeaderField: "x-goog-firebase-installations-auth")
    urlRequest.setValue(
      Bundle.main.bundleIdentifier,
      forHTTPHeaderField: "X-Ios-Bundle-Identifier"
    )
    urlRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
    urlRequest.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
    urlRequest.setValue(fetchTypeHeader, forHTTPHeaderField: "X-Firebase-RC-Fetch-Type")
    if let etag = settings.lastETag {
      urlRequest.setValue(etag, forHTTPHeaderField: "if-none-match")
    }
    urlRequest.httpBody = content

    return fetchSession.dataTask(with: urlRequest, completionHandler: fetcherCompletion)
  }

  private func getTemplateVersionNumber(fetchedConfig: [String: Any]) -> String {
    if let templateVersion =
      fetchedConfig[ConfigConstants.fetchResponseKeyTemplateVersion] as? String {
      return templateVersion
    }
    return "0"
  }
}
