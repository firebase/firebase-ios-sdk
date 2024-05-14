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
import UIKit

/**
 Live activity manager class for FCM SDK

 Functionalities:
 - Keeps track of live activity updates (starting and ending)
 - Keeps track of live activity token updates and push to start token updates.
 - Uploads the updated tokens to FCM backend when needed.

 */
@available(iOS 16.1, *)
public class LiveActivityManager{
    
    // To keep track of registered Live Acitvities so that they can be invalidated
    private static var acitivityWrappers = [LiveActivityTypeWrapper]()

    // Class to manage Live Activity tokens
    private static let tokenManager:LiveActivityTokenManager = LiveActivityTokenManager.getInstance()
    
    // Log tag for printing logs
    public static let LOG_TAG = "LAM# "
    
    public static func liveActivityRegsistration() -> RegistrationRequest{
        return RegistrationRequest()
    }
    
    static func invalidateActivities(){
        Task{
            var refreshedIds :[String] = []
            for activityWrapper in  acitivityWrappers{
                activityWrapper.invalidateActivities()
                refreshedIds.append(contentsOf:activityWrapper.getActiveActivityIds())
            }
            
            await tokenManager.invalidateWith(activityIds: refreshedIds)
            
            NSLog(LOG_TAG + "Invalidated")
        }
    }
    
    static func setActivityWrappers(wrappers: [LiveActivityTypeWrapper]){
        acitivityWrappers = wrappers
    }
    
   public static func getLiveAcitivityTokens() async -> [String:String] {
        let tokens = await tokenManager.getTokens()
        return tokens.mapValues { $0 };
    }
    
}
