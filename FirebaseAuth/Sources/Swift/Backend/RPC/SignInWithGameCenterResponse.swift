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

class SignInWithGameCenterResponse: AuthRPCResponse {
  required init() {}

  var idToken: String?
  var refreshToken: String?
  var localID: String?
  var playerID: String?
  var teamPlayerID: String?
  var gamePlayerID: String?
  var approximateExpirationDate: Date?
  var isNewUser: Bool = false
  var displayName: String?

  func setFields(dictionary: [String: AnyHashable]) throws {
    idToken = dictionary["idToken"] as? String
    refreshToken = dictionary["refreshToken"] as? String
    localID = dictionary["localId"] as? String
    if let approximateExpirationDate = dictionary["expiresIn"] as? String {
      self
        .approximateExpirationDate =
        Date(timeIntervalSinceNow: (approximateExpirationDate as NSString).doubleValue)
    }
    refreshToken = dictionary["refreshToken"] as? String
    playerID = dictionary["playerId"] as? String
    teamPlayerID = dictionary["teamPlayerId"] as? String
    gamePlayerID = dictionary["gamePlayerId"] as? String
    isNewUser = dictionary["isNewUser"] as? Bool ?? false
    displayName = dictionary["displayName"] as? String
  }
}
