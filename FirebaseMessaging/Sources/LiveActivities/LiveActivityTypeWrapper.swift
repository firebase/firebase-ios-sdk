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
 Protocol class invalidate and fetch details of Live activity instance fir a specific live activity type.
 */
protocol LiveActivityTypeWrapper {
    /**
    Invalidate the local live activity records by syncing with Activitykit apis.
     */
    func invalidateActivities()
    /**
     Gets the list of active live activity ids
     */
    func getActiveActivityIds() -> [String]
    /**
     Initializes PTS token
     */
    func initPTSToken(ptsTokenId:String?)
    /**
     Listens for live activity updates
     */
    func listenForActivityUpdates()
}
