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

/**
 Token manager class which is synchronized.
 */
@available(iOS 16.1, *)
actor LiveActivityTokenManager{
    
    private let TOKENS_DEFAULTS_KEY = "TOKENS_DEFAULTS_KEY"
    private var activityTokens : [String:String]
    private let userDefaults = UserDefaults(suiteName: "LAM")!
    private static let shared = LiveActivityTokenManager()
    public let ptsTokenId:String?
    
    /**
     Returns the singleton instance of token manager.
     */
    public static func getInstance() -> LiveActivityTokenManager{
        return shared
    }
    
    private init(){
        self.activityTokens = userDefaults.dictionary(forKey: TOKENS_DEFAULTS_KEY) as? [String: String] ?? [:]
        
        if #available(iOS 17.2, *) {
            //Initializing PTS token id only if iOS 17.2 or above
            let PTS_TOKEN_ID_DEFAULTS_KEY = "PTS_TOKEN_ID_DEFAULTS_KEY"
            var ptsId = userDefaults.string(forKey: PTS_TOKEN_ID_DEFAULTS_KEY)
            if(ptsId == nil || ptsId == ""){
                ptsId = UUID().uuidString
                userDefaults.set(ptsId, forKey: PTS_TOKEN_ID_DEFAULTS_KEY)
            }
            ptsTokenId = ptsId
        }else{
            ptsTokenId = nil
        }
    }

    func getPTSTokenId() -> String?{
        return ptsTokenId
    }
    
    func getTokens() -> [String:String]{
        return activityTokens
    }
    
    func saveTokensToUserDefaults(){
        userDefaults.set(activityTokens, forKey: TOKENS_DEFAULTS_KEY)
    }
    
    func haveTokenFor(activityId:String) -> Bool{
        return activityTokens.keys.contains(activityId)
    }
    
    func checkAndUpdateTokenFor(activityId:String,activityToken:String){
        if(activityId=="" || activityToken == ""){
            return
        }
        
        if (haveTokenFor(activityId: activityId)){
            let oldToken = activityTokens[activityId]
            
            if(oldToken == nil || oldToken == "" || oldToken != activityToken){
                //Token needs update
                updateToken(id: activityId, token: activityToken, reason: .ActivityTokenUpdated)
            }
        }else{
            //New token
            updateToken(id: activityId, token: activityToken, reason: .ActivityTokenAdded)
        }
        
    }
    
    func checkAndRemoveTokenFor(activityId:String){
        if(activityTokens.keys.contains(activityId)){
            // Remove token
            let token = activityTokens[activityId]!
            updateToken(id: activityId, token: token, reason: .ActivityTokenRemoved)
        }
    }
    
    func invalidateWith(activityIds: [String]){
        //Checking and removing ended acitivities
        for acitivtyId in activityTokens.keys{
            if(acitivtyId == ptsTokenId){
                //PTS tokens are meant to be updated and not removed.
                continue
            }
            if(!activityIds.contains(where: {$0==acitivtyId})){
                checkAndRemoveTokenFor(activityId: acitivtyId)
            }
        }
    }
    
    func updateToken(id:String,token:String,reason:TokenUpdateReason){
        NSLog(LiveActivityManager.LOG_TAG + "Token Update : " + String(describing: reason))
        if(reason == .ActivityTokenRemoved){
            activityTokens.removeValue(forKey: id)
            saveTokensToUserDefaults()
            // No need for FCM backend update. So returning.
            return
        }
        
        activityTokens[id] = token
        saveTokensToUserDefaults()
        
        uploadToken(id: id, token: token)
    }
    
    func uploadToken(id:String,token:String){
        NSLog(LiveActivityManager.LOG_TAG + "Token Upload:: Id: " + id + " token: " + token)
        //TODO: Code for token upload to FCM backend.
        
        
    }
    
    /**
     Reasons for token update
     */
    enum TokenUpdateReason {
        case ActivityTokenRemoved
        case ActivityTokenAdded
        case ActivityTokenUpdated
    }
}
