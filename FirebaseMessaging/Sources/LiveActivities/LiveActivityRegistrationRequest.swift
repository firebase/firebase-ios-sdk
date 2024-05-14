/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import ActivityKit

/**
 Builder class to accept Live activity Registration requests
 */
@available(iOS 16.1, *)
public class RegistrationRequest{
    
    let tokenManager:LiveActivityTokenManager = LiveActivityTokenManager.getInstance()
    var acitivityDict = [String:LiveActivityTypeWrapper]()
    
    public func add<T: ActivityAttributes>(type: T.Type) -> RegistrationRequest{
        let key = String(describing: type)
        acitivityDict[key] = LiveActivityTypeWrapperImpl<T>()
        return self
    }
    
    /**
     Registers the live activities and returns the Push to start id if supported.
     
     PTS id is returned only if iOS 17.2 or above and atleast one Live activity type is registered with FCM
     */
    public func register() -> String?{
        var wrappers = [LiveActivityTypeWrapper]()
        var ptsTokenId:String? = nil
        
        if(!acitivityDict.isEmpty){
            ptsTokenId = tokenManager.ptsTokenId
            acitivityDict.first?.value.initPTSToken(ptsTokenId: ptsTokenId)
            
            for wrapper in acitivityDict.values{
                wrappers.append(wrapper)
                wrapper.listenForActivityUpdates()
            }
        }
        
        LiveActivityManager.setActivityWrappers(wrappers: wrappers)
        LiveActivityManager.invalidateActivities()
        
        return ptsTokenId
    }
}
