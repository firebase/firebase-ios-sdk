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
 Wrapper class to hold Live activity type.
 
 This class is responsible for listening to live activity updates and token changes.
 */
@available(iOS 16.1, *)
class LiveActivityTypeWrapperImpl<T : ActivityAttributes>: LiveActivityTypeWrapper {
    
    private let tokenManager = LiveActivityTokenManager.getInstance()
    private var listeningStatus = [String:Bool]()
    
    //Helper functions
    
    func getFormatedToken(token:Data) -> String{
        return token.reduce("") {
            $0 + String(format: "%02x", $1)
        }
    }
    
    func checkAndAddActivity(activity:Activity<T>){
        if (hasListenerSetFor(activityId: activity.id)){
            //We have already subscribed to activity and token updates for this live activity instance.
            return
        }
        
        listeningStatus[activity.id] = true
        
        Task{
            Task{
                if(activity.pushToken != nil){
                    let activityToken = getFormatedToken(token: activity.pushToken!)
                    checkAndUpdateToken(activityId: activity.id, activityToken: activityToken)
                }
                for await pushToken in activity.pushTokenUpdates {
                    let activityToken = getFormatedToken(token: pushToken)
                    checkAndUpdateToken(activityId: activity.id, activityToken: activityToken)
                }
            }
            Task{
                for await activityState in activity.activityStateUpdates {
                    if(activityState == ActivityState.ended || activity.activityState==ActivityState.dismissed){
                        checkAndRemoveActivityToken(activityId: activity.id)
                    }
                }
            }
        }
    }
    
    func hasListenerSetFor(activityId:String) -> Bool{
        if(listeningStatus.keys.contains(activityId)){
            return listeningStatus[activityId]!
        }
        
        return false
    }
    
    func checkAndUpdateToken(activityId:String,activityToken:String) {
        Task{
            await tokenManager.checkAndUpdateTokenFor(activityId: activityId, activityToken: activityToken)
        }
    }
    
    func checkAndRemoveActivityToken(activityId:String){
        Task{
            await tokenManager.checkAndRemoveTokenFor(activityId:activityId)
        }
    }
    
    //Protocol Functions
    
    /**
     Requests for Push to start live activity token and listen for its updates.
     */
    func initPTSToken(ptsTokenId:String?){
        if #available(iOS 17.2, *) {
            Task{
                let ptsToken = Activity<T>.pushToStartToken
                if(ptsToken != nil){
                    let ptsTokenString = getFormatedToken(token: ptsToken!)
                    checkAndUpdateToken(activityId: ptsTokenId!, activityToken:  ptsTokenString)
                }
                
                for await pushToken in Activity<T>.pushToStartTokenUpdates {
                    let activityToken = getFormatedToken(token: pushToken)
                    //PTS token is saved against registration id
                    checkAndUpdateToken(activityId: ptsTokenId!, activityToken: activityToken)
                }
            }
        }
    }
    
    /**
     Listens for live activity updates happening in the app for the current type.
     */
    func listenForActivityUpdates(){
        Task{
            for await activity in Activity<T>.activityUpdates {
                if(activity.activityState==ActivityState.ended || activity.activityState==ActivityState.dismissed){
                    checkAndRemoveActivityToken(activityId: activity.id)
                }else if(activity.activityState==ActivityState.active){
                    checkAndAddActivity(activity: activity)
                }
            }
        }
    }
    
    func invalidateActivities() {
        Task{
            let activities = Activity<T>.activities
            
            // Checking and adding new activities
            for activity in activities {
                checkAndAddActivity(activity:activity)
            }
        }
    }
    
    func getActiveActivityIds() -> [String] {
        let activities = Activity<T>.activities
        let activityIds = activities.map { $0.id }
        return activityIds
    }
}
