import Foundation

typealias RCNConfigFetcherCompletion = (_ data: NSData?, _ response: URLResponse?, _ error: NSError?) -> Void
typealias FIRRemoteConfigFetchCompletion = (FIRRemoteConfigFetchStatus, NSError?) -> Void

class RCNConfigFetch: NSObject {
    var settings: RCNConfigSettings
    var analytics: FIRAnalyticsInterop?
    var experiment: RCNConfigExperiment
    var lockQueue: DispatchQueue
    var fetchSession: URLSession?
    var FIRNamespace: String
    var options: FIROptions?
    var templateVersionNumber : String = "0"

    init(content: RCNConfigContent, DBManager: RCNConfigDBManager, settings: RCNConfigSettings,
         analytics: FIRAnalyticsInterop?, experiment: RCNConfigExperiment, queue: DispatchQueue,
         FIRNamespace: String, options: FIROptions?) {
        self.settings = settings
        self.analytics = analytics
        self.experiment = experiment
        self.lockQueue = queue
        self.FIRNamespace = FIRNamespace
        self.options = options
        self.fetchSession = newFetchSession()
        self.templateVersionNumber = ""
    }

    func recreateNetworkSession() {
        if let session = fetchSession {
            session.invalidateAndCancel()
        }
        fetchSession = newFetchSession()
    }

    func currentNetworkSession() -> URLSession? {
        return fetchSession
    }

    func newFetchSession() -> URLSession? {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = settings?.fetchTimeout ?? RCNConstants.RCNHTTPDefaultConnectionTimeout
        config.timeoutIntervalForResource = settings?.fetchTimeout ?? RCNConstants.RCNHTTPDefaultConnectionTimeout
        let session = URLSession(configuration: config)
        return session
    }
    
    func updateExperimentsWithResponse(response: [[String: Any]]){
        
    }
    
    func updateExperimentsWithHandler(handler: @escaping ((Error?) -> Void)) {
      
    }
    
    func latestStartTimeWithExistingLastStartTime(existingLastStartTime: TimeInterval) -> TimeInterval {
        return 0.0
    }
    
    func doFetchCall(fetchTypeHeader: String, completionHandler: @escaping FIRRemoteConfigFetchCompletion, updateCompletionHandler: RCNConfigFetchCompletion){
        
    }

    func fetchConfigWithExpirationDuration(expirationDuration: TimeInterval, completionHandler: ((FIRRemoteConfigFetchStatus, Error?) -> Void)?) {
        
    }
    
    func fetchWithExpirationDuration(expirationDuration: TimeInterval, completionHandler: ((FIRRemoteConfigFetchCompletion) -> Void)? ) {
      
    }
}
