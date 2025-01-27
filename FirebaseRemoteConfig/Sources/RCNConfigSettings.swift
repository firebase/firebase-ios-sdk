import Foundation

class RCNConfigSettings {
    var customSignals : [String : String] = [:]
    var minimumFetchInterval : TimeInterval = RCNConstants.RCNDefaultMinimumFetchInterval
    var fetchTimeout : TimeInterval = RCNConstants.RCNHTTPDefaultConnectionTimeout
    var lastETag : String? = ""
    var lastETagUpdateTime: TimeInterval = 0
    var lastFetchTimeInterval : TimeInterval = 0
    var lastFetchStatus : FIRRemoteConfigFetchStatus = .noFetchYet
    var isFetchInProgress: Bool = false
    var exponentialBackoffThrottleEndTime : TimeInterval = 0
    var exponentialBackoffRetryInterval : TimeInterval = 0
    var lastApplyTimeInterval : TimeInterval = 0
    var lastSetDefaultsTimeInterval : TimeInterval = 0
    var lastFetchedTemplateVersion : String? = "0"
    var lastActiveTemplateVersion : String? = "0"
    var configInstallationsToken : String? = ""
    var configInstallationsIdentifier : String? = ""
    var realtimeExponentialBackoffRetryInterval : TimeInterval = 0
    var realtimeExponentialBackoffThrottleEndTime : TimeInterval = 0
    var realtimeRetryCount : Int = 0

    init() {}
    
    func setRealtimeRetryCount(realtimeRetryCount: Int) {
      
    }

    // MARK: - Throttling
    func hasMinimumFetchIntervalElapsed(minimumFetchInterval: TimeInterval) -> Bool {
      
        if lastFetchTimeInterval == 0 {
            return true
        }

        // Check if last config fetch is within minimum fetch interval in seconds.
        let diffInSeconds = Date().timeIntervalSince1970 - lastFetchTimeInterval
        return diffInSeconds > minimumFetchInterval
    }

    func shouldThrottle() -> Bool {
        let now = Date().timeIntervalSince1970
        return (self.lastFetchTimeInterval > 0 &&
                 (self.lastFetchStatus != FIRRemoteConfigFetchStatus.success) &&
                (_exponentialBackoffThrottleEndTime - now > 0))
    }
    
    //MARK: - update
    func updateMetadataWithFetchSuccessStatus(fetchSuccess: Bool, templateVersion: String?) {
        
    }

    func updateMetadataTable(){
        
    }
    
    func updateLastFetchTimeInterval(lastFetchTimeInterval: TimeInterval){
        
    }
    
    func updateLastActiveTemplateVersion() {
        
    }
    
    func updateRealtimeExponentialBackoffTime(){
        
    }
    
    func updateExponentialBackoffTime() {
        
    }
    
    func nextRequestWithUserProperties(userProperties: [String : Any]) -> String {
        return ""
    }
    
    func getRealtimeBackoffInterval() -> TimeInterval {
        return 0.0
    }
}
