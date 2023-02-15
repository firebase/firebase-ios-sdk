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

@objc(FIRAdditionalUserInfo) public class AdditionalUserInfo: NSObject, NSSecureCoding {
  private static let providerIDCodingKey = "providerID"
  private static let profileCodingKey = "profile"
  private static let usernameCodingKey = "username"
  private static let newUserKey = "newUser"

  @objc public var providerID: String?
  @objc public var profile: [String: Any]?
  @objc public var username: String?
  @objc public var isNewUser: Bool = false

  @objc public static func userInfo(verifyAssertionResponse: VerifyAssertionResponse)
    -> AdditionalUserInfo {
    return AdditionalUserInfo(providerID: verifyAssertionResponse.providerID,
                              profile: verifyAssertionResponse.profile,
                              username: verifyAssertionResponse.username,
                              isNewUser: verifyAssertionResponse.isNewUser)
  }

  @objc public init(providerID: String?, profile: [String: Any]?, username: String?,
                    isNewUser: Bool) {
    self.providerID = providerID
    self.profile = profile
    self.username = username
    self.isNewUser = isNewUser
  }

  public static var supportsSecureCoding: Bool {
    return true
  }

  public required init?(coder aDecoder: NSCoder) {
    providerID = aDecoder.decodeObject(
      of: NSString.self,
      forKey: AdditionalUserInfo.providerIDCodingKey
    ) as String?
    profile = aDecoder.decodeObject(
      of: NSDictionary.self,
      forKey: AdditionalUserInfo.profileCodingKey
    ) as? [String: Any]
    username = aDecoder.decodeObject(
      of: NSString.self,
      forKey: AdditionalUserInfo.usernameCodingKey
    ) as String?
    isNewUser = aDecoder.decodeObject(of: NSNumber.self, forKey: AdditionalUserInfo.newUserKey)?
      .boolValue ?? false
  }

  public func encode(with aCoder: NSCoder) {
    aCoder.encode(providerID, forKey: AdditionalUserInfo.providerIDCodingKey)
    aCoder.encode(profile, forKey: AdditionalUserInfo.profileCodingKey)
    aCoder.encode(username, forKey: AdditionalUserInfo.usernameCodingKey)
    aCoder.encode(isNewUser, forKey: AdditionalUserInfo.newUserKey)
  }
}
