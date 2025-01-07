// Copyright 2025 Google LLC
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
import FirebaseInstallations
import Foundation
@_implementationOnly import GoogleUtilities

#if canImport(UIKit) // iOS/tvOS/watchOS
  import UIKit
#endif
#if canImport(AppKit) // macOS
  import AppKit
#endif

// URL params
private let serverURLDomain = "firebaseremoteconfigrealtime.googleapis.com"

// Realtime API enablement
private let serverForbiddenStatusCode = "\"code\": 403"

// Header names
private let httpMethodPost = "POST"
private let contentTypeHeaderName = "Content-Type"
private let contentEncodingHeaderName = "Content-Encoding"
private let acceptEncodingHeaderName = "Accept"
private let etagHeaderName = "etag"
private let ifNoneMatchETagHeaderName = "if-none-match"
private let installationsAuthTokenHeaderName = "x-goog-firebase-installations-auth"
// Sends the bundle ID. Refer to b/130301479 for details.
private let iOSBundleIdentifierHeaderName = "X-Ios-Bundle-Identifier"

// Retryable HTTP status code.
private let fetchResponseHTTPStatusOK = 200
private let fetchResponseHTTPStatusTooManyRequests = 429
private let fetchResponseHTTPStatusCodeBadGateway = 502
private let fetchResponseHTTPStatusCodeServiceUnavailable = 503
private let fetchResponseHTTPStatusCodeGatewayTimeout = 504

// Invalidation message field names.
private let templateVersionNumberKey = "latestTemplateVersionNumber"
private let featureDisabledKey = "featureDisabled"

private let timeoutSeconds: TimeInterval = 330
private let fetchAttempts = 3
private let applicationJSON = "application/json"
private let gzip = "gzip"
private let canRetry = "X-Google-GFE-Can-Retry"
// Retry parameters
private let maxRetries = 7

/// Listener registration returned by `addOnConfigUpdateListener`. Calling its method `remove` stops
/// the associated listener from receiving config updates and unregisters itself.
///
/// If `remove` is called and no other listener registrations remain, the connection to the
/// real-time connection.
@objc(FIRConfigUpdateListenerRegistration) public
final class ConfigUpdateListenerRegistration: NSObject, Sendable {
  let completionHandler: @Sendable (RemoteConfigUpdate?, Error?) -> Void
  private let realtimeClient: ConfigRealtime?

  @objc public
  init(client: ConfigRealtime,
       completionHandler: @escaping @Sendable (RemoteConfigUpdate?, Error?) -> Void) {
    realtimeClient = client
    self.completionHandler = completionHandler
  }

  @objc public
  func remove() {
    realtimeClient?.removeConfigUpdateListener(completionHandler)
  }
}

@objc(RCNConfigRealtime) public
class ConfigRealtime: NSObject, URLSessionDataDelegate {
  private var listeners = NSOrderedSet()
  private let realtimeLockQueue = DispatchQueue(label: "com.google.firebase.remoteconfig.realtime")
  private let notificationCenter = NotificationCenter.default
  private let request: URLRequest
  private var session: URLSession?
  private var dataTask: URLSessionDataTask?
  private let configFetch: ConfigFetch
  private let settings: ConfigSettings
  private let options: FirebaseOptions
  private let namespace: String
  var remainingRetryCount: Int
  private var isRequestInProgress: Bool
  var isInBackground: Bool
  var isRealtimeDisabled: Bool

  public var installations: (any InstallationsProtocol)?

  @objc public
  init(configFetch: ConfigFetch,
       settings: ConfigSettings,
       namespace: String,
       options: FirebaseOptions,
       installations: InstallationsProtocol? = nil) {
    self.configFetch = configFetch
    self.settings = settings
    self.options = options
    self.namespace = namespace
    remainingRetryCount = max(maxRetries - settings.realtimeRetryCount, 1)
    isRequestInProgress = false
    isRealtimeDisabled = false
    isInBackground = false

    self.installations = if let installations {
      installations
    } else if
      let appName = namespace.components(separatedBy: ":").last,
      let app = FirebaseApp.app(name: appName) {
      Installations.installations(app: app)
    } else {
      nil as InstallationsProtocol?
    }
    request = ConfigRealtime.setupHTTPRequest(options, namespace)
    super.init()
    session = setupSession()
    backgroundChangeListener()
  }

  deinit {
    dataTask?.cancel() // Ensure the task is cancelled when the object is deallocated
    session?.invalidateAndCancel()
  }

  private static func setupHTTPRequest(_ options: FirebaseOptions,
                                       _ namespace: String) -> URLRequest {
    let url = Utils.constructServerURL(
      domain: serverURLDomain,
      apiKey: options.apiKey,
      optionsID: options.gcmSenderID,
      namespace: namespace
    )
    var request = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: timeoutSeconds)
    request.httpMethod = httpMethodPost
    request.setValue(applicationJSON, forHTTPHeaderField: contentTypeHeaderName)
    request.setValue(applicationJSON, forHTTPHeaderField: acceptEncodingHeaderName)
    request.setValue(gzip, forHTTPHeaderField: contentEncodingHeaderName)
    request.setValue("true", forHTTPHeaderField: canRetry)
    request.setValue(options.apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
    request.setValue(
      Bundle.main.bundleIdentifier,
      forHTTPHeaderField: iOSBundleIdentifierHeaderName
    )
    return request
  }

  private func setupSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForResource = timeoutSeconds
    config.timeoutIntervalForRequest = timeoutSeconds
    return URLSession(configuration: config, delegate: self, delegateQueue: .main)
  }

  private func propagateErrors(_ error: Error) {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      for listener in self.listeners {
        if let listener = listener as? (RemoteConfigUpdate?, Error?) -> Void {
          listener(nil, error)
        }
      }
    }
  }

  // TESTING ONLY
  @objc func triggerListenerForTesting(listener: @escaping (RemoteConfigUpdate?, Error?) -> Void) {
    DispatchQueue.main.async {
      listener(RemoteConfigUpdate(), nil)
    }
  }

  // MARK: - HTTP Helpers

  private func appName(fromFullyQualifiedNamespace fullyQualifiedNamespace: String) -> String {
    return String(fullyQualifiedNamespace.split(separator: ":").last ?? "")
  }

  private func reportCompletion(onHandler completionHandler: (
    (RemoteConfigFetchStatus, Error?) -> Void
  )?,
  withStatus status: RemoteConfigFetchStatus,
  withError error: Error?) {
    guard let completionHandler = completionHandler else { return }
    realtimeLockQueue.async {
      completionHandler(status, error)
    }
  }

  private func refreshInstallationsToken(completionHandler: (
    (RemoteConfigFetchStatus, Error?) -> Void
  )?) {
    guard let installations, !options.gcmSenderID.isEmpty else {
      let errorDescription = "Failed to get GCMSenderID"
      RCLog.error("I-RCN000074", errorDescription)
      settings.isFetchInProgress = false
      reportCompletion(
        onHandler: completionHandler,
        withStatus: .failure,
        withError: NSError(
          domain: ConfigConstants.RemoteConfigErrorDomain,
          code: RemoteConfigError.internalError.rawValue,
          userInfo: [NSLocalizedDescriptionKey: errorDescription]
        )
      )
      return
    }

    RCLog.debug("I-RCN000039", "Starting requesting token.")
    installations.authToken { [weak self] result, error in
      guard let self = self else { return }
      if let error = error {
        let errorDescription = "Failed to get installations token. Error : \(error)."
        RCLog.error("I-RCN000073", errorDescription)
        self.isRequestInProgress = false
        var userInfo = [String: Any]()
        userInfo[NSLocalizedDescriptionKey] = errorDescription
        userInfo[NSUnderlyingErrorKey] = error

        self.reportCompletion(
          onHandler: completionHandler,
          withStatus: .failure,
          withError: NSError(domain: ConfigConstants.RemoteConfigErrorDomain,
                             code: RemoteConfigError.internalError.rawValue,
                             userInfo: userInfo)
        )
        return
      }
      guard let tokenResult = result else {
        let errorDescription = "Failed to get installations token"
        RCLog.error("I-RCN000073", errorDescription)
        self.isRequestInProgress = false
        reportCompletion(onHandler: completionHandler,
                         withStatus: .failure,
                         withError: NSError(domain: ConfigConstants.RemoteConfigErrorDomain,
                                            code: RemoteConfigError.internalError.rawValue,
                                            userInfo: [
                                              NSLocalizedDescriptionKey: errorDescription,
                                            ]))
        return
      }
      /// We have a valid token. Get the backing installationID.
      installations.installationID { [weak self] identifier, error in
        guard let self = self else { return }
        // Dispatch to the RC serial queue to update settings on the queue.
        self.realtimeLockQueue.async {
          /// Update config settings with the IID and token.
          self.settings.configInstallationsToken = tokenResult.authToken
          self.settings.configInstallationsIdentifier = identifier ?? ""
          if let error = error {
            let errorDescription = "Error getting iid : \(error)."
            RCLog.error("I-RCN000055", errorDescription)
            self.isRequestInProgress = false
            var userInfo = [String: Any]()
            userInfo[NSLocalizedDescriptionKey] = errorDescription
            userInfo[NSUnderlyingErrorKey] = error
            self.reportCompletion(
              onHandler: completionHandler,
              withStatus: .failure,
              withError: NSError(domain: ConfigConstants.RemoteConfigErrorDomain,
                                 code: RemoteConfigError.internalError.rawValue,
                                 userInfo: userInfo)
            )
          } else if let identifier = identifier {
            RCLog.info("I-RCN000022", "Success to get iid : \(identifier)")
            self.reportCompletion(onHandler: completionHandler,
                                  withStatus: .noFetchYet,
                                  withError: nil)
          }
        }
      }
    }
  }

  @objc public
  func createRequestBody(completion: @escaping (Data) -> Void) {
    refreshInstallationsToken { status, error in
      if self.settings.configInstallationsIdentifier.isEmpty {
        RCLog.debug(
          "I-RCN000013",
          "Installation token retrieval failed. Realtime connection will not include " +
            "valid installations token."
        )
      }
      var request = self.request
      request.setValue(self.settings.configInstallationsToken,
                       forHTTPHeaderField: installationsAuthTokenHeaderName)
      if let etag = self.settings.lastETag {
        request.setValue(etag, forHTTPHeaderField: ifNoneMatchETagHeaderName)
      }

      let postBody = """
      {
      project:'\(self.options.gcmSenderID)',
      namespace:'\(Utils.namespaceOnly(self.namespace))',
      lastKnownVersionNumber:'\(self.configFetch.templateVersionNumber)',
      appId:'\(self.options.googleAppID)',
      sdkVersion:'\(Device.remoteConfigPodVersion())',
      appInstanceId:'\(self.settings.configInstallationsIdentifier)'
      }
      """
      do {
        if let postData = postBody.data(using: .utf8) {
          let compressedData = try NSData.gul_data(byGzippingData: postData)
          completion(compressedData)
        } else {
          RCLog.error("I-RCN000090", "Error creating fetch body for realtime")
          completion(Data())
        }
      } catch {
        RCLog.error("I-RCN000091", "Error compressing fetch body for realtime \(error)")
        completion(Data())
      }
    }
  }

  // MARK: - Retry Helpers

  func canMakeConnection() -> Bool {
    let noRunningConnection = dataTask == nil || dataTask?.state != .running
    return noRunningConnection && listeners.count > 0 && !isInBackground && !isRealtimeDisabled
  }

  func retryHTTPConnection() {
    realtimeLockQueue.async { [weak self] in
      guard let self, !self.isInBackground else { return }
      guard self.remainingRetryCount > 0 else {
        let error = NSError(domain: ConfigConstants.RemoteConfigUpdateErrorDomain,
                            code: RemoteConfigUpdateError.streamError.rawValue,
                            userInfo: [
                              NSLocalizedDescriptionKey: "Unable to connect to the server. Check your connection and try again.",
                            ])
        RCLog.error("I-RCN000014", "Cannot establish connection. Error: \(error)")
        self.propagateErrors(error)
        return
      }
      if self.canMakeConnection() {
        self.remainingRetryCount -= 1
        self.settings.realtimeRetryCount += 1
        let backoffInterval = self.settings.realtimeBackoffInterval()
        self.realtimeLockQueue.asyncAfter(deadline: .now() + backoffInterval) {
          self.beginRealtimeStream()
        }
      }
    }
  }

  private func backgroundChangeListener() {
    #if canImport(UIKit)
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(willEnterForeground),
                                             name: UIApplication
                                               .willEnterForegroundNotification,
                                             object: nil)
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(didEnterBackground),
                                             name: UIApplication.didEnterBackgroundNotification,
                                             object: nil)
    #elseif canImport(AppKit)
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(willEnterForeground),
                                             name: NSApplication.willBecomeActiveNotification,
                                             object: nil)
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(didEnterBackground),
                                             name: NSApplication.didResignActiveNotification,
                                             object: nil)
    #endif
  }

  @objc private func willEnterForeground() {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      self.isInBackground = false
      self.beginRealtimeStream()
    }
  }

  @objc private func didEnterBackground() {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      self.pauseRealtimeStream()
      self.isInBackground = true
    }
  }

  // MARK: - Autofetch Helpers

  @objc(fetchLatestConfig:targetVersion:) public
  func fetchLatestConfig(remainingAttempts: Int, targetVersion: Int) {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      let attempts = remainingAttempts - 1
      self.configFetch.realtimeFetchConfig(fetchAttemptNumber: fetchAttempts - attempts) {
        status, update, error in
        if let error = error {
          RCLog.error("I-RCN000010",
                      "Failed to retrieve config due to fetch error. Error: \(error)")
          self.propagateErrors(error)
          return
        }
        if status == .success {
          if Int(self.configFetch.templateVersionNumber) ?? 0 >= targetVersion {
            // Only notify listeners if there is a change.
            if let update = update, !update.updatedKeys.isEmpty {
              self.realtimeLockQueue.async { [weak self] in
                guard let self else { return }
                for listener in self.listeners {
                  if let l = listener as? (RemoteConfigUpdate?, Error?) -> Void {
                    l(update, nil)
                  }
                }
              }
            }
          } else {
            RCLog.debug("I-RCN000016",
                        "Fetched config's template version is outdated, re-fetching")
            self.autoFetch(attempts: attempts, targetVersion: targetVersion)
          }
        } else {
          RCLog.debug("I-RCN000016",
                      "Fetched config's template version is outdated, re-fetching")
          self.autoFetch(attempts: attempts, targetVersion: targetVersion)
        }
      }
    }
  }

  @objc(scheduleFetch:targetVersion:) public
  func scheduleFetch(remainingAttempts: Int, targetVersion: Int) {
    // Needs fetch to occur between 0 - 3 seconds. Randomize to not cause DDoS
    // alerts in backend.
    let delay = TimeInterval.random(in: 0 ... 3) // Random delay between 0 and 3 seconds
    realtimeLockQueue.asyncAfter(deadline: .now() + delay) {
      self.fetchLatestConfig(remainingAttempts: remainingAttempts, targetVersion: targetVersion)
    }
  }

  /// Perform fetch and handle developers callbacks.
  @objc(autoFetch:targetVersion:) public
  func autoFetch(attempts: Int, targetVersion: Int) {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      guard attempts > 0 else {
        let error = NSError(domain: ConfigConstants.RemoteConfigUpdateErrorDomain,
                            code: RemoteConfigUpdateError.notFetched.rawValue,
                            userInfo: [
                              NSLocalizedDescriptionKey: "Unable to fetch the latest version of the template.",
                            ])
        RCLog.error("I-RCN000011", "Ran out of fetch attempts, cannot find target config version.")
        self.propagateErrors(error)
        return
      }
      self.scheduleFetch(remainingAttempts: attempts, targetVersion: targetVersion)
    }
  }

  // MARK: - URLSessionDataDelegate

  /// Delegate to asynchronously handle every new notification that comes over
  /// the wire. Auto-fetches and runs callback for each new notification.
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                         didReceive data: Data) {
    let strData = String(data: data, encoding: .utf8) ?? ""
    // If response data contains the API enablement link, return the entire
    // message to the user in the form of a error.
    if strData.contains(serverForbiddenStatusCode) {
      let error = NSError(domain: ConfigConstants.RemoteConfigUpdateErrorDomain,
                          code: RemoteConfigUpdateError.streamError.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: strData])
      RCLog.error("I-RCN000021", "Cannot establish connection. \(error)")
      propagateErrors(error)
      return
    }

    if let beginRange = strData.range(of: "{"),
       let endRange = strData.range(of: "}") {
      RCLog.debug("I-RCN000015", "Received config update message on stream.")
      let msgRange = Range(uncheckedBounds: (lower: beginRange.lowerBound,
                                             upper: strData.index(after: endRange.upperBound)))
      let jsonData = String(strData[msgRange]).data(using: .utf8)!
      do {
        if let response = try JSONSerialization.jsonObject(with: jsonData,
                                                           options: []) as? [String: Any] {
          evaluateStreamResponse(response)
        }
      } catch {
        let wrappedError = NSError(domain: RemoteConfigUpdateErrorDomain,
                                   code: RemoteConfigUpdateError.messageInvalid.rawValue,
                                   userInfo: [
                                     NSLocalizedDescriptionKey: "Unable to parse ConfigUpdate. \(strData)",
                                     NSUnderlyingErrorKey: error,
                                   ])
        propagateErrors(wrappedError)
        return
      }
    }
  }

  @objc public
  func evaluateStreamResponse(_ response: [String: Any]) {
    var updateTemplateVersion = 1
    if let version = response[templateVersionNumberKey] as? Int {
      updateTemplateVersion = version
    }
    if let isDisabled = response[featureDisabledKey] as? Bool {
      isRealtimeDisabled = isDisabled
    }
    if isRealtimeDisabled {
      pauseRealtimeStream()
      let error = NSError(domain: ConfigConstants.RemoteConfigUpdateErrorDomain,
                          code: RemoteConfigUpdateError.unavailable.rawValue,
                          userInfo: [
                            NSLocalizedDescriptionKey: "The server is temporarily unavailable. Try again in a few minutes.",
                          ])
      propagateErrors(error)
    } else {
      let clientTemplateVersion = Int(configFetch.templateVersionNumber) ?? 0
      if updateTemplateVersion > clientTemplateVersion {
        autoFetch(attempts: fetchAttempts, targetVersion: updateTemplateVersion)
      }
    }
  }

  func isStatusCodeRetryable(_ statusCode: Int) -> Bool {
    return statusCode == fetchResponseHTTPStatusTooManyRequests ||
      statusCode == fetchResponseHTTPStatusCodeServiceUnavailable ||
      statusCode == fetchResponseHTTPStatusCodeBadGateway ||
      statusCode == fetchResponseHTTPStatusCodeGatewayTimeout
  }

  /// Delegate to handle initial reply from the server.
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    isRequestInProgress = false
    if let httpResponse = response as? HTTPURLResponse {
      let statusCode = httpResponse.statusCode
      if statusCode == 403 {
        completionHandler(.allow)
        return
      }

      if statusCode != fetchResponseHTTPStatusOK {
        settings.updateRealtimeExponentialBackoffTime()
        pauseRealtimeStream()

        if isStatusCodeRetryable(statusCode) {
          retryHTTPConnection()
        } else {
          let error = NSError(
            domain: ConfigConstants.RemoteConfigUpdateErrorDomain,
            code: RemoteConfigUpdateError.streamError.rawValue,
            userInfo: [
              NSLocalizedDescriptionKey:
                "Unable to connect to the server. Try again in a few minutes. HTTP Status code: \(statusCode)",
            ]
          )
          RCLog.error("I-RCN000021", "Cannot establish connection. Error: \(error)")
          propagateErrors(error)
        }
      } else {
        // On success, reset retry parameters.
        remainingRetryCount = maxRetries
        settings.realtimeRetryCount = 0
      }
      completionHandler(.allow)
    }
  }

  /// Delegate to handle data task completion.
  public func urlSession(_ session: URLSession, task: URLSessionTask,
                         didCompleteWithError error: Error?) {
    if !session.isEqual(self.session) {
      return
    }
    isRequestInProgress = false
    if let error = error, error._code != NSURLErrorCancelled {
      settings.updateRealtimeExponentialBackoffTime()
    }
    pauseRealtimeStream()
    retryHTTPConnection()
  }

  /// Delegate to handle session invalidation.
  public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    if !isRequestInProgress {
      if let _ = error {
        settings.updateRealtimeExponentialBackoffTime()
      }
      pauseRealtimeStream()
      retryHTTPConnection()
    }
  }

  // MARK: - Top Level Methods

  @objc public
  func beginRealtimeStream() {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      guard self.settings.realtimeBackoffInterval() <= 0.0 else {
        self.retryHTTPConnection()
        return
      }
      if self.canMakeConnection() {
        self.createRequestBody { [weak self] requestBody in
          guard let self else { return }
          var request = self.request
          request.httpBody = requestBody
          self.isRequestInProgress = true
          self.dataTask = self.session?.dataTask(with: request)
          self.dataTask?.resume()
        }
      }
    }
  }

  @objc public
  func pauseRealtimeStream() {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      if let task = self.dataTask {
        task.cancel()
        self.dataTask = nil
      }
    }
  }

  @discardableResult
  @objc public func addConfigUpdateListener(_ listener: @Sendable @escaping (RemoteConfigUpdate?,
                                                                             Error?) -> Void)
    -> ConfigUpdateListenerRegistration {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      let temp = self.listeners.mutableCopy() as! NSMutableOrderedSet
      temp.add(listener)
      self.listeners = temp
      self.beginRealtimeStream()
    }
    return ConfigUpdateListenerRegistration(client: self, completionHandler: listener)
  }

  @objc public func removeConfigUpdateListener(_ listener: @escaping (RemoteConfigUpdate?, Error?)
    -> Void) {
    realtimeLockQueue.async { [weak self] in
      guard let self else { return }
      let temp: NSMutableOrderedSet = self.listeners.mutableCopy() as! NSMutableOrderedSet
      temp.remove(listener)
      self.listeners = temp
      if self.listeners.count == 0 {
        self.pauseRealtimeStream()
      }
    }
  }
}
