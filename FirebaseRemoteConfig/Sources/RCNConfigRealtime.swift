import Foundation

class RCNConfigRealtime: NSObject {
  private var _listeners: NSMutableSet<AnyHashable>
  private var _realtimeLockQueue: DispatchQueue
  private var _notificationCenter: NotificationCenter
    
    var session: URLSession?
    var dataTask: URLSessionDataTask?
    var request: NSMutableURLRequest?

  
    private var configFetch: RCNConfigFetch
    private var settings: RCNConfigSettings
    private var options: FIROptions
    private var namespace: String
    private var remainingRetryCount : Int = 0
    private var isRequestInProgress : Bool = false
    private var isInBackground : Bool = false
    private var isRealtimeDisabled : Bool = false

    init(configFetch: RCNConfigFetch, settings: RCNConfigSettings, namespace: String, options: FIROptions) {
        _listeners = NSMutableSet<AnyHashable>()
        _realtimeLockQueue = RCNConfigRealtime.realtimeRemoteConfigSerialQueue()
        _notificationCenter = NotificationCenter.default
        
        self.configFetch = configFetch
        self.settings = settings
        self.options = options
        self.namespace = namespace
        _remainingRetryCount = max(RCNConstants.gMaxRetries - (settings.realtimeRetryCount), 1)
        _isRequestInProgress = false;
        _isRealtimeDisabled = false;
        _isInBackground = false;
        
        setUpHttpRequest()
        setUpHttpSession()
        backgroundChangeListener()
    }
    
    static func realtimeRemoteConfigSerialQueue() -> DispatchQueue {
        return DispatchQueue(label: RCNConstants.RCNRemoteConfigQueueLabel)
    }
    
    func propagateErrors(error: Error) {
        
    }
    
    func retryHTTPConnection() {
      
    }
    
    func addConfigUpdateListener(listener: @escaping (_ update: FIRRemoteConfigUpdate?, _ error: NSError?) -> Void ) -> FIRConfigUpdateListenerRegistration? {
        
        return nil
    }
    
    func removeConfigUpdateListener(listener: @escaping (_ update: FIRRemoteConfigUpdate?, _ error: NSError?) -> Void) {
        
    }
    
    func beginRealtimeStream() {
        
    }
    
    func pauseRealtimeStream() {
        
    }

  func URLSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

    }
    
    func URLSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceiveResponse: URLResponse,
                     completionHandler: @escaping (URLSessionResponseDisposition) -> Void) {
      
    }
    
    func URLSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
      
    }
    
    func evaluateStreamResponse(response: [AnyHashable : Any], error: NSError?) {
      
    }
}
