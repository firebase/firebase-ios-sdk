// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

@objc(FIRSignInWithGameCenterResponse) public class SignInWithGameCenterResponse: NSObject, AuthRPCResponse {
    @objc public var IDToken: String?
    @objc public var refreshToken: String?
    @objc public var localID: String?
    @objc public var playerID: String?
    @objc public var approximateExpirationDate: Date?
    @objc public var isNewUser: Bool = false
    @objc public var displayName: String?

    public func setFields(dictionary: [String : Any]) throws {
        self.IDToken = dictionary["idToken"] as? String
        self.refreshToken = dictionary["refreshToken"] as? String
        self.localID = dictionary["localId"] as? String
        if let approximateExpirationDate = dictionary["expiresIn"] as? String {
            self.approximateExpirationDate = Date(timeIntervalSinceNow: (approximateExpirationDate as NSString).doubleValue)
        }
        self.refreshToken = dictionary["refreshToken"] as? String
        self.playerID = dictionary["playerId"] as? String
        self.isNewUser = dictionary["isNewUser"] as? Bool ?? false
        self.displayName = dictionary["displayName"] as? String
    }
}
