import Foundation

class FIRRemoteConfigUpdate {
    private var _updatedKeys: Set<String>
    
    init(updatedKeys: Set<String>) {
        _updatedKeys = updatedKeys
    }
    
    var updatedKeys: Set<String> {
        return _updatedKeys
    }
}
