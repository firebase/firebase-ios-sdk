import Foundation
import FirebaseABTesting

class RCNConfigExperiment {
    var experimentPayloads: [Data] = []
    var experimentMetadata: [String: Any] = [:]
    var activeExperimentPayloads: [Data] = []
    var DBManager: RCNConfigDBManager?
    var experimentController: FIRExperimentController
    var experimentStartTimeDateFormatter: DateFormatter
    
    init(DBManager: RCNConfigDBManager, experimentController: FIRExperimentController) {
        self.experimentPayloads = []
        self.experimentMetadata = [:]
        self.activeExperimentPayloads = []
        self.experimentStartTimeDateFormatter = DateFormatter()
        self.experimentStartTimeDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        self.experimentStartTimeDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        // Locale needs to be hardcoded. See
        // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
        self.experimentStartTimeDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.experimentStartTimeDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        self.DBManager = DBManager
        self.experimentController = experimentController
        loadExperimentFromTable()
    }
    
    func loadExperimentFromTable() {
        if DBManager == nil {
          return
        }
      
        _DBManager?.loadExperimentWithCompletionHandler(completionHandler: {
          (success, result) in
            if result[RCNExperimentTableKeyPayload] != nil {
                for experiment in result[RCNExperimentTableKeyPayload] as! [NSData] {
                    var experimentPayloadJSON = [:] as NSDictionary
                    do {
                        let experimentPayloadJSONData = try JSONSerialization.jsonObject(with: experiment as Data, options: .allowFragments)
                        if experimentPayloadJSONData == nil {
                          FIRLogWarning(RCNRemoteConfigQueueLabel, "I-RCN000031",
                                        "Experiment payload could not be parsed as JSON.")
                        }
                    } catch let error {
                      FIRLogWarning(RCNRemoteConfigQueueLabel, "I-RCN000031",
                                    "Experiment payload could not be parsed as JSON.")
                    }
                    
                }
            }
            if (result[RCNExperimentTableKeyMetadata] != nil) {
              self.experimentMetadata = result[RCNExperimentTableKeyMetadata] as! [String : Any]
            }

            /// Load activated experiments payload and metadata.
            if (result[RCNExperimentTableKeyActivePayload] != nil) {
              self.activeExperimentPayloads = []
              for experiment in result[RCNExperimentTableKeyActivePayload] as! [NSData] {
                
              }
            }
            
        })
    }
    
    func updateExperimentsWithResponse(response: [[String: Any]]){
        
    }
    
    func updateExperimentsWithHandler(handler: @escaping ((Error?) -> Void)) {
      
    }
    
    func latestStartTimeWithExistingLastStartTime(existingLastStartTime: TimeInterval) -> TimeInterval {
        return 0.0
    }
}
