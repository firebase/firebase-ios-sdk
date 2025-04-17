import Foundation
import FirebaseCore
import FirebaseInstallations // Required for FIS interaction
// TODO: Import FIRAnalyticsInterop if it's defined in a separate module

// --- Placeholder Types ---
typealias RCNConfigDBManager = AnyObject // Keep placeholder
typealias RCNConfigExperiment = AnyObject // Keep placeholder
typealias FIRAnalyticsInterop = AnyObject // Keep placeholder
typealias RCNDevice = AnyObject // Keep placeholder
// Assume RCNConfigContent, RCNConfigSettingsInternal, RemoteConfigFetchStatus, RemoteConfigError, RemoteConfigUpdate, etc. are defined

// --- Helper Types ---
// Define Completion handler type definition used internally and by Realtime
typealias RCNConfigFetchCompletion = (RemoteConfigFetchStatus, RemoteConfigUpdate?, Error?) -> Void
// Define Key constant used in error dictionary
let RemoteConfigThrottledEndTimeInSecondsKey = "error_throttled_end_time_seconds"


// --- Constants ---
// TODO: Move to central constants file
private enum FetchConstants {
    #if RCN_STAGING_SERVER
    static let serverURLDomain = "https://staging-firebaseremoteconfig.sandbox.googleapis.com"
    #else
    static let serverURLDomain = "https://firebaseremoteconfig.googleapis.com"
    #endif
    static let serverURLVersion = "/v1"
    static let serverURLProjects = "/projects/"
    static let serverURLNamespaces = "/namespaces/"
    static let serverURLQuery = ":fetch?"
    static let serverURLKey = "key="

    static let httpMethodPost = "POST"
    static let contentTypeHeaderName = "Content-Type"
    static let contentEncodingHeaderName = "Content-Encoding"
    static let acceptEncodingHeaderName = "Accept-Encoding"
    static let eTagHeaderName = "etag"
    static let ifNoneMatchETagHeaderName = "if-none-match"
    static let installationsAuthTokenHeaderName = "x-goog-firebase-installations-auth"
    static let iOSBundleIdentifierHeaderName = "X-Ios-Bundle-Identifier"
    static let fetchTypeHeaderName = "X-Firebase-RC-Fetch-Type"
    static let baseFetchType = "BASE"
    static let realtimeFetchType = "REALTIME"

    static let contentTypeValueJSON = "application/json"
    static let contentEncodingGzip = "gzip"

    static let httpStatusOK = 200
    static let httpStatusNotModified = 304 // Added for clarity, though not an error
    static let httpStatusTooManyRequests = 429
    static let httpStatusInternalError = 500
    static let httpStatusServiceUnavailable = 503
    static let httpStatusGatewayTimeout = 504 // Not explicitly handled in ObjC retry logic? Added for completeness

    // Response Keys (assuming defined elsewhere, e.g., RCNConfigConstants)
    static let responseKeyError = "error"
    static let responseKeyErrorCode = "code"
    static let responseKeyErrorStatus = "status"
    static let responseKeyErrorMessage = "message"
    static let responseKeyExperimentDescriptions = "experimentDescriptions"
    static let responseKeyTemplateVersion = "templateVersionNumber" // Match UserDefault key?
    static let responseKeyState = "state"
    static let responseKeyEntries = "entries"
    static let responseKeyPersonalizationMetadata = "personalizationMetadata"
    static let responseKeyRolloutMetadata = "rolloutMetadata"

    // State Values
     static let responseKeyStateNoChange = "NO_CHANGE"
     static let responseKeyStateEmptyConfig = "EMPTY_CONFIG"
     static let responseKeyStateNoTemplate = "NO_TEMPLATE"
     static let responseKeyStateUpdate = "UPDATE_CONFIG"

}


/// Handles the fetching of Remote Config data from the backend server.
class RCNConfigFetch {

    // Dependencies
    private let content: RCNConfigContent
    // DBManager is placeholder only used via Settings placeholder calls for now
    // private let dbManager: RCNConfigDBManager
    private let settings: RCNConfigSettingsInternal
    private let analytics: FIRAnalyticsInterop? // Placeholder
    private let experiment: RCNConfigExperiment? // Placeholder
    private let lockQueue: DispatchQueue // Serial queue for synchronization
    private let firebaseNamespace: String
    private let options: FirebaseOptions

    // Internal State
    // Making fetchSession internal(set) allows tests to replace it
    internal(set) var fetchSession: URLSession

    // Publicly readable property for Realtime
    var templateVersionNumber: String {
        // Read directly from settings (which reads from UserDefaults)
        return settings.lastFetchedTemplateVersion ?? "0"
    }

    // MARK: - Initialization

    init(content: RCNConfigContent,
         dbManager: RCNConfigDBManager, // Placeholder accepted
         settings: RCNConfigSettingsInternal,
         analytics: FIRAnalyticsInterop?, // Placeholder accepted
         experiment: RCNConfigExperiment?, // Placeholder accepted
         queue: DispatchQueue,
         firebaseNamespace: String,
         options: FirebaseOptions) {
        self.content = content
        // self.dbManager = dbManager // Not directly used by Fetch itself
        self.settings = settings
        self.analytics = analytics
        self.experiment = experiment
        self.lockQueue = queue
        self.firebaseNamespace = firebaseNamespace
        self.options = options
        self.fetchSession = RCNConfigFetch.newFetchSession(settings: settings) // Initial session
        // templateVersionNumber read dynamically from settings
    }

    deinit {
        fetchSession.invalidateAndCancel()
    }

    // MARK: - Session Management

    private static func newFetchSession(settings: RCNConfigSettingsInternal) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = settings.fetchTimeout
        config.timeoutIntervalForResource = settings.fetchTimeout
        return URLSession(configuration: config)
    }

    /// Recreates the network session, typically after settings change.
    @objc func recreateNetworkSession() { // Needs @objc for selector call from RemoteConfig
        let oldSession = fetchSession
        lockQueue.async { // Ensure thread safety if called concurrently
            self.fetchSession = RCNConfigFetch.newFetchSession(settings: self.settings)
            oldSession.invalidateAndCancel() // Invalidate after new one is ready
        }
    }

    // MARK: - Public Fetch Methods

    /// Fetches config data, respecting expiration duration and throttling.
    /// Needs @objc for selector call from RemoteConfig
    @objc func fetchConfig(withExpirationDuration expirationDuration: TimeInterval,
                           completionHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?) {
        // Note: device context check requires RCNDevice translation
        // let hasDeviceContextChanged = RCNDevice.hasDeviceContextChanged(settings.deviceContext, options.googleAppID ?? "")
        let hasDeviceContextChanged = false // Placeholder

        lockQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Check Expiration/Interval
            if !self.settings.hasMinimumFetchIntervalElapsed(minimumInterval: expirationDuration), !hasDeviceContextChanged {
                 // TODO: Log debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000051", ...)
                 self.reportCompletion(status: .success, update: nil, error: nil,
                                       baseHandler: completionHandler, realtimeHandler: nil)
                 return
            }

            // 2. Check Throttling
            if self.settings.shouldThrottle(), !hasDeviceContextChanged {
                 self.settings.lastFetchStatus = .throttled // Update status
                 self.settings.lastFetchError = .throttled
                 let throttledEndTime = self.settings.exponentialBackoffThrottleEndTime
                 let error = NSError(domain: RemoteConfigConstants.errorDomain,
                                     code: RemoteConfigError.throttled.rawValue,
                                     userInfo: [RemoteConfigThrottledEndTimeInSecondsKey: throttledEndTime]) // Use actual key constant
                  self.reportCompletion(status: .throttled, update: nil, error: error,
                                        baseHandler: completionHandler, realtimeHandler: nil)
                 return
            }

            // 3. Check In Progress
            // Note: isFetchInProgress access needs external sync (lockQueue handles it here)
            if self.settings.isFetchInProgress {
                 // TODO: Log appropriately based on whether previous data exists
                 // FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000052", ...) or
                 // FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000053", ...)
                 // Report previous status or failure
                 let status = self.settings.lastFetchTimeInterval > 0 ? self.settings.lastFetchStatus : .failure
                  self.reportCompletion(status: status, update: nil, error: nil, // Report no error for "in progress"
                                        baseHandler: completionHandler, realtimeHandler: nil)
                 return
            }

            // 4. Proceed with fetch
            self.settings.isFetchInProgress = true
            let fetchTypeHeader = "\(FetchConstants.baseFetchType)/1" // Simple count for now
            self.refreshInstallationsToken(fetchTypeHeader: fetchTypeHeader,
                                           baseHandler: completionHandler,
                                           realtimeHandler: nil)
        }
    }

    /// Fetches config immediately for Realtime, respecting throttling but not expiration.
    func realtimeFetchConfig(fetchAttemptNumber: Int,
                             completionHandler: @escaping RCNConfigFetchCompletion) { // Note: Escaping closure
        // Note: device context check requires RCNDevice translation
        // let hasDeviceContextChanged = RCNDevice.hasDeviceContextChanged(settings.deviceContext, options.googleAppID ?? "")
         let hasDeviceContextChanged = false // Placeholder

        lockQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Check Throttling
            if self.settings.shouldThrottle(), !hasDeviceContextChanged {
                self.settings.lastFetchStatus = .throttled
                self.settings.lastFetchError = .throttled
                let throttledEndTime = self.settings.exponentialBackoffThrottleEndTime
                let error = NSError(domain: RemoteConfigConstants.errorDomain,
                                    code: RemoteConfigError.throttled.rawValue,
                                    userInfo: [RemoteConfigThrottledEndTimeInSecondsKey: throttledEndTime])
                self.reportCompletion(status: .throttled, update: nil, error: error,
                                      baseHandler: nil, realtimeHandler: completionHandler)
                return
            }

            // 2. Proceed with fetch (no in-progress check for Realtime?)
            // ObjC logic didn't explicitly check isFetchInProgress here, assuming Realtime manages its own calls.
            // Let's keep isFetchInProgress set for consistency in FIS calls.
             self.settings.isFetchInProgress = true
             let fetchTypeHeader = "\(FetchConstants.realtimeFetchType)/\(fetchAttemptNumber)"
             self.refreshInstallationsToken(fetchTypeHeader: fetchTypeHeader,
                                            baseHandler: nil,
                                            realtimeHandler: completionHandler)
         }
     }


    // MARK: - Private Fetch Flow

    private func getAppNameFromNamespace() -> String {
        return firebaseNamespace.components(separatedBy: ":").last ?? ""
    }

    private func refreshInstallationsToken(fetchTypeHeader: String,
                                           baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                           realtimeHandler: RCNConfigFetchCompletion?) {
        guard let gcmSenderID = options.gcmSenderID, !gcmSenderID.isEmpty else {
             let errorDesc = "Failed to get GCMSenderID"
             // TODO: Log error: FIRLogError(...)
             self.settings.isFetchInProgress = false // Reset flag
             let error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
             self.reportCompletion(status: .failure, update: nil, error: error, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
             return
        }

        let appName = getAppNameFromNamespace()
        guard let app = FirebaseApp.app(name: appName), let installations = Installations.installations(app: app) else {
            let errorDesc = "Failed to get FirebaseApp or Installations instance for app: \(appName)"
            // TODO: Log error: FIRLogError(...)
             self.settings.isFetchInProgress = false // Reset flag
             let error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
             self.reportCompletion(status: .failure, update: nil, error: error, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
             return
        }

        // TODO: Log debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000039", ...)
        installations.authToken { [weak self] tokenResult, error in
             guard let self = self else { return }

             guard let token = tokenResult?.authToken, error == nil else {
                 let errorDesc = "Failed to get installations token. Error: \(error?.localizedDescription ?? "Unknown")"
                 // TODO: Log error: FIRLogError(...)
                 self.lockQueue.async { // Ensure state update is on queue
                     self.settings.isFetchInProgress = false // Reset flag
                      let wrappedError = NSError(domain: RemoteConfigConstants.errorDomain,
                                                code: RemoteConfigError.internalError.rawValue,
                                                userInfo: [NSLocalizedDescriptionKey: errorDesc, NSUnderlyingErrorKey: error as Any])
                      self.reportCompletion(status: .failure, update: nil, error: wrappedError, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
                 }
                 return
             }

             // Get Installation ID
             installations.installationID { [weak self] identifier, error in
                  guard let self = self else { return }

                   // Dispatch back to queue for settings update & next step
                   self.lockQueue.async {
                       guard let identifier = identifier, error == nil else {
                           let errorDesc = "Error getting Installation ID: \(error?.localizedDescription ?? "Unknown")"
                            // TODO: Log error: FIRLogError(...)
                            self.settings.isFetchInProgress = false // Reset flag
                            let wrappedError = NSError(domain: RemoteConfigConstants.errorDomain,
                                                       code: RemoteConfigError.internalError.rawValue,
                                                       userInfo: [NSLocalizedDescriptionKey: errorDesc, NSUnderlyingErrorKey: error as Any])
                            self.reportCompletion(status: .failure, update: nil, error: wrappedError, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
                           return
                       }

                       // TODO: Log info: FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000022", ...)
                       self.settings.configInstallationsToken = token
                       self.settings.configInstallationsIdentifier = identifier

                       // Proceed to get user properties and make fetch call
                       self.doFetchCall(fetchTypeHeader: fetchTypeHeader, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
                   }
             }
        }
    }

    private func doFetchCall(fetchTypeHeader: String,
                             baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                             realtimeHandler: RCNConfigFetchCompletion?) {
        // Get Analytics User Properties (Placeholder interaction)
        getAnalyticsUserProperties { [weak self] userProperties in
             guard let self = self else { return }
             // Ensure next step is on the queue
             self.lockQueue.async {
                 self.performFetch(userProperties: userProperties,
                                   fetchTypeHeader: fetchTypeHeader,
                                   baseHandler: baseHandler,
                                   realtimeHandler: realtimeHandler)
             }
        }
    }

    // Placeholder for Analytics interaction
    private func getAnalyticsUserProperties(completionHandler: @escaping ([String: Any]?) -> Void) {
         // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000060", ...)
         if let analytics = self.analytics {
             // analytics.getUserProperties(callback: completionHandler) // Requires translated interop
             // Placeholder: Simulate async call returning empty properties
              DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { // Simulate delay
                 completionHandler([:])
             }
         } else {
              completionHandler([:]) // No analytics, return empty immediately
         }
     }

     private func performFetch(userProperties: [String: Any]?,
                               fetchTypeHeader: String,
                               baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                               realtimeHandler: RCNConfigFetchCompletion?) {
          // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000061", ...)

          guard let postBodyString = settings.nextRequestWithUserProperties(userProperties) else {
              let errorDesc = "Failed to construct fetch request body."
               self.settings.isFetchInProgress = false // Reset flag
               let error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
               self.reportCompletion(status: .failure, update: nil, error: error, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
              return
          }

          guard let content = postBodyString.data(using: .utf8) else {
               let errorDesc = "Failed to encode fetch request body to UTF8."
               self.settings.isFetchInProgress = false // Reset flag
               let error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
               self.reportCompletion(status: .failure, update: nil, error: error, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
               return
           }


          // Compress data
          let compressedContent: Data?
          do {
               compressedContent = try (content as NSData).gzipped(withCompressionLevel: .defaultCompression) // Requires GULNSData+zlib logic port or library
               // Placeholder for gzipped:
               // compressedContent = content // Remove this line if gzip available
          } catch {
               let errorDesc = "Failed to compress the config request: \(error)"
               // TODO: Log warning: FIRLogWarning(...)
                self.settings.isFetchInProgress = false // Reset flag
                let wrappedError = NSError(domain: RemoteConfigConstants.errorDomain,
                                           code: RemoteConfigError.internalError.rawValue,
                                           userInfo: [NSLocalizedDescriptionKey: errorDesc, NSUnderlyingErrorKey: error])
                self.reportCompletion(status: .failure, update: nil, error: wrappedError, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
               return
           }

           guard let finalContent = compressedContent else {
                let errorDesc = "Compressed content is nil."
                 self.settings.isFetchInProgress = false // Reset flag
                 let error = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
                 self.reportCompletion(status: .failure, update: nil, error: error, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
                return
            }


          // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000040", ...)
          let task = createURLSessionDataTask(content: finalContent, fetchTypeHeader: fetchTypeHeader) {
              [weak self] data, response, error in
              // This completion handler runs on the URLSession's delegate queue (main by default)
              // Ensure subsequent processing happens on our lockQueue
               guard let self = self else { return }
              // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000050", ...)

              self.lockQueue.async { // Dispatch processing to the lock queue
                  self.settings.isFetchInProgress = false // Reset flag regardless of outcome

                  self.handleFetchResponse(data: data, response: response, error: error,
                                           baseHandler: baseHandler, realtimeHandler: realtimeHandler)
              }
          }
          task.resume()
      }

     private func createURLSessionDataTask(content: Data,
                                           fetchTypeHeader: String,
                                           completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
         guard let url = constructServerURL() else {
              // Should not happen if options are valid
              fatalError("Could not construct server URL") // Or handle more gracefully
          }
          // TODO: Log Debug: FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000046", ...)

          var request = URLRequest(url: url,
                                   cachePolicy: .reloadIgnoringLocalCacheData,
                                   timeoutInterval: fetchSession.configuration.timeoutIntervalForRequest) // Use session timeout
         request.httpMethod = FetchConstants.httpMethodPost
         request.setValue(FetchConstants.contentTypeValueJSON, forHTTPHeaderField: FetchConstants.contentTypeHeaderName)
         request.setValue(settings.configInstallationsToken, forHTTPHeaderField: FetchConstants.installationsAuthTokenHeaderName)
         request.setValue(settings.bundleIdentifier, forHTTPHeaderField: FetchConstants.iOSBundleIdentifierHeaderName) // Use settings bundle ID
         request.setValue(FetchConstants.contentEncodingGzip, forHTTPHeaderField: FetchConstants.contentEncodingHeaderName)
         request.setValue(FetchConstants.contentEncodingGzip, forHTTPHeaderField: FetchConstants.acceptEncodingHeaderName)
         request.setValue(fetchTypeHeader, forHTTPHeaderField: FetchConstants.fetchTypeHeaderName)

         if let etag = settings.lastETag {
             request.setValue(etag, forHTTPHeaderField: FetchConstants.ifNoneMatchETagHeaderName)
         }
         request.httpBody = content

         return fetchSession.dataTask(with: request, completionHandler: completionHandler)
     }

    // MARK: - Response Handling (on lockQueue)

    private func handleFetchResponse(data: Data?, response: URLResponse?, error: Error?,
                                     baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                     realtimeHandler: RCNConfigFetchCompletion?) {

        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? -1 // Default to invalid status code

        // 1. Handle Client-Side or HTTP Errors
        if let error = error { // Client-side error (network, timeout, etc.)
            handleFetchError(error: error, statusCode: statusCode, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
            return
        }
        if statusCode != FetchConstants.httpStatusOK {
            // Check for 304 Not Modified *before* treating other non-200 as errors
            if statusCode == FetchConstants.httpStatusNotModified {
                 // TODO: Log info - Not Modified
                 settings.updateMetadataWithFetchSuccessStatus(true, templateVersion: settings.lastFetchedTemplateVersion) // Keep old version
                 let update = content.getConfigUpdate(forNamespace: firebaseNamespace) // Calculate diff anyway?
                 self.reportCompletion(status: .success, update: update, error: nil, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
                 return
            }
            // Handle other non-200, non-304 statuses as errors
            handleFetchError(error: nil, statusCode: statusCode, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
            return
        }

        // 2. Handle Successful Fetch (Status OK - 200)
        guard let responseData = data else {
            // TODO: Log info - No data in successful response
            let update = content.getConfigUpdate(forNamespace: firebaseNamespace) // Still calculate diff
             self.reportCompletion(status: .success, update: update, error: nil, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
            return
        }

        // 3. Parse JSON Response
        let parsedResponse: [String: Any]?
        do {
             parsedResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any]
        } catch let parseError {
             // TODO: Log error - JSON parsing failure
             let wrappedError = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse fetch response JSON.", NSUnderlyingErrorKey: parseError])
             self.reportCompletion(status: .failure, update: nil, error: wrappedError, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
             return
        }

        // 4. Check for Server-Side Error in JSON Payload
        if let responseDict = parsedResponse,
            let serverError = responseDict[FetchConstants.responseKeyError] as? [String: Any] {
             let errorDesc = formatServerError(serverError)
             // TODO: Log error - Server returned error
             let wrappedError = NSError(domain: RemoteConfigConstants.errorDomain, code: RemoteConfigError.internalError.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDesc])
             self.reportCompletion(status: .failure, update: nil, error: wrappedError, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
            return
        }

        // 5. Process Successful Fetch Data
        if let fetchedData = parsedResponse {
            // Update content (triggers DB writes via selectors for now)
            content.updateConfigContentWithResponse(fetchedData, forNamespace: firebaseNamespace)

             // Update experiments (Placeholder interaction)
             if let experimentDescriptions = fetchedData[FetchConstants.responseKeyExperimentDescriptions] {
                 // TODO: Ensure experimentDescriptions is correct type for experiment object
                 experiment?.perform(#selector(RCNConfigExperiment.updateExperiments(response:)), with: experimentDescriptions)
             }

            // Update ETag if changed
            if let latestETag = httpResponse?.allHeaderFields[FetchConstants.eTagHeaderName] as? String {
                 if settings.lastETag != latestETag {
                      settings.setLastETag(latestETag) // Updates UserDefaults
                 }
             } else {
                 // No ETag received? Clear local ETag? ObjC didn't explicitly clear.
                 // settings.setLastETag(nil)
             }

             // Update settings metadata (DB interaction via selector)
             let newVersion = getTemplateVersionNumber(from: fetchedData)
             settings.updateMetadataWithFetchSuccessStatus(true, templateVersion: newVersion)

         } else {
              // TODO: Log Debug - Empty response?
              // Still treat as success, but update metadata? ObjC didn't explicitly handle empty dict case here.
               settings.updateMetadataWithFetchSuccessStatus(true, templateVersion: settings.lastFetchedTemplateVersion) // Keep old version?
         }

         // 6. Report Success
         let update = content.getConfigUpdate(forNamespace: firebaseNamespace)
         self.reportCompletion(status: .success, update: update, error: nil, baseHandler: baseHandler, realtimeHandler: realtimeHandler)
    }

     private func handleFetchError(error: Error?, statusCode: Int,
                                  baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                  realtimeHandler: RCNConfigFetchCompletion?) {
          // Update metadata (DB interaction via selector)
          settings.updateMetadataWithFetchSuccessStatus(false, templateVersion: nil)

          var reportedError = error
          var reportedStatus = RemoteConfigFetchStatus.failure
          var errorDomain = error?.domain ?? RemoteConfigConstants.errorDomain
          var errorCode = error?.code ?? RemoteConfigError.internalError.rawValue

          // Check for retryable HTTP status codes and update throttling/status/error
          let retryableStatusCodes = [
              FetchConstants.httpStatusTooManyRequests,
              FetchConstants.httpStatusInternalError, // 500
              FetchConstants.httpStatusServiceUnavailable // 503
              // Add 504? ObjC didn't include it in backoff trigger check.
          ]
          if retryableStatusCodes.contains(statusCode) {
               settings.updateExponentialBackoffTime() // Update backoff window
               if settings.shouldThrottle() { // Check if *now* we are throttled
                    reportedStatus = .throttled
                    errorCode = RemoteConfigError.throttled.rawValue
                    errorDomain = RemoteConfigConstants.errorDomain // Ensure RC domain
                    let throttledEndTime = settings.exponentialBackoffThrottleEndTime
                    reportedError = NSError(domain: errorDomain, code: errorCode,
                                            userInfo: [NSLocalizedDescriptionKey: "Fetch throttled. Backoff interval has not passed.",
                                                       RemoteConfigThrottledEndTimeInSecondsKey: throttledEndTime])
               }
           }

           // Ensure reported error is constructed if nil
           if reportedError == nil {
               // Handle 304 separately as it's not a true error in the same sense
               if statusCode == FetchConstants.httpStatusNotModified {
                    // This path shouldn't be reached based on logic in handleFetchResponse.
                    // Log a warning if we somehow get here.
                    // TODO: Log warning
                    reportedStatus = .success // Technically not an error, but no update happened.
                    reportedError = nil // Clear any potential error if it was just 304.
               } else {
                   let errorDesc = "Fetch failed with HTTP status code: \(statusCode)"
                   // TODO: Log Error
                   reportedError = NSError(domain: errorDomain, code: errorCode,
                                           userInfo: [NSLocalizedDescriptionKey: errorDesc])
               }
            }

            // Update settings status *after* potential throttling check
            settings.lastFetchStatus = reportedStatus
            settings.lastFetchError = RemoteConfigError(rawValue: errorCode) ?? .unknown

            self.reportCompletion(status: reportedStatus, update: nil, error: reportedError,
                                  baseHandler: baseHandler, realtimeHandler: realtimeHandler)
      }

    // MARK: - Helpers

    private func constructServerURL() -> URL? {
        guard let projectID = options.projectID, !projectID.isEmpty,
              let apiKey = options.apiKey, !apiKey.isEmpty else {
             // TODO: Log error - Missing projectID or apiKey
             return nil
        }

        // Extract namespace part from "namespace:appName"
        let namespacePart = firebaseNamespace.components(separatedBy: ":").first ?? firebaseNamespace

        let urlString = FetchConstants.serverURLDomain +
                        FetchConstants.serverURLVersion +
                        FetchConstants.serverURLProjects + projectID +
                        FetchConstants.serverURLNamespaces + namespacePart +
                        FetchConstants.serverURLQuery +
                        FetchConstants.serverURLKey + apiKey
        return URL(string: urlString)
    }

    private func getTemplateVersionNumber(from fetchedConfig: [String: Any]?) -> String {
        return fetchedConfig?[FetchConstants.responseKeyTemplateVersion] as? String ?? "0"
    }

     private func formatServerError(_ errorDict: [String: Any]) -> String {
         var errStr = "Fetch Failure: Server returned error: "
         if let code = errorDict[FetchConstants.responseKeyErrorCode] { errStr += "Code: \(code). " }
         if let status = errorDict[FetchConstants.responseKeyErrorStatus] { errStr += "Status: \(status). " }
         if let message = errorDict[FetchConstants.responseKeyErrorMessage] { errStr += "Message: \(message)" }
         return errStr
     }

    /// Dispatches completion handlers to the main queue.
    private func reportCompletion(status: RemoteConfigFetchStatus,
                                  update: RemoteConfigUpdate?, // Included for realtime handler
                                  error: Error?,
                                  baseHandler: ((RemoteConfigFetchStatus, Error?) -> Void)?,
                                  realtimeHandler: RCNConfigFetchCompletion?) {
        DispatchQueue.main.async {
             baseHandler?(status, error)
             realtimeHandler?(status, update, error) // Pass update only to realtime handler
         }
    }

    // MARK: - Placeholder Selectors
    // Selectors needed for RemoteConfig interaction via perform(#selector(...))
    @objc private func fetchConfig(withExpirationDuration duration: TimeInterval, completionHandler handler: Any?) {}

    // Selectors for RCNConfigExperiment (placeholder)
    @objc private func updateExperiments(response: Any?) {}
}


// Define GULNSData+zlib methods or include a library
extension NSData {
     @objc func gzipped(withCompressionLevel level: Int32 = -1) throws -> Data {
         // Placeholder - Requires porting or library
         print("Warning: gzipped compression not implemented.")
         return self as Data
     }
 }

// Assume these types are defined elsewhere
// @objc(FIRRemoteConfigFetchStatus) public enum RemoteConfigFetchStatus: Int { ... }
// @objc(FIRRemoteConfigError) public enum RemoteConfigError: Int { ... }
// @objc(FIRRemoteConfigUpdate) public class RemoteConfigUpdate: NSObject { ... }
// class RCNConfigContent { ... }
// class RCNConfigSettingsInternal { ... }
// etc.
