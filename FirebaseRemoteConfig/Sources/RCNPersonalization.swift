import Foundation

class RCNPersonalization: NSObject {
    private var _analytics: FIRAnalyticsInterop?
    private var _loggedChoiceIds: NSMutableDictionary?
    
    init(analytics: FIRAnalyticsInterop?) {
        self._analytics = analytics
        self._loggedChoiceIds = [:]
    }
    
    func logArmActive(rcParameter: String, config: [AnyHashable:Any]) {
        guard let ids = config[RCNFetchResponseKeyPersonalizationMetadata] as? [String: Any],
            let values = config[RCNFetchResponseKeyEntries] as? [String: FIRRemoteConfigValue] else { return }

        guard let metadata = ids[rcParameter] as? [String : Any] else { return }
        
        guard let choiceId = metadata[kChoiceId] as? String else { return }
      
      // Listeners like logArmActive() are dispatched to a serial queue, so loggedChoiceIds should
      // contain any previously logged RC parameter / choice ID pairs.
        if self._loggedChoiceIds?[rcParameter] as? String == choiceId {
            return
        }
        
        self._loggedChoiceIds?[rcParameter] = choiceId

        self._analytics?.logEventWithOrigin(origin: kAnalyticsOriginPersonalization, name: kExternalEvent, parameters: [kExternalRcParameterParam: rcParameter, kExternalArmValueParam: values[rcParameter]!.stringValue, kExternalPersonalizationIdParam: metadata[kPersonalizationId] ?? "" , kExternalArmIndexParam: metadata[kArmIndex] ?? "", kExternalGroupParam: metadata[kGroup] ?? ""])

        self._analytics?.logEvent(withOrigin: kAnalyticsOriginPersonalization, name: kInternalEvent, parameters: [kInternalChoiceIdParam : choiceId])
    }
}
