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

extension AdditionalUserInfo: NSSecureCoding {}
@objc(FIRAdditionalUserInfo) open class AdditionalUserInfo: NSObject {
  /// The provider identifier.
  @objc public let providerID: String

  /// Dictionary containing the additional IdP specific information.
  @objc public let profile: [String: Any]?

  /// The name of the user.
  @objc public let username: String?

  /// Indicates whether or not the current user was signed in for the first time.
  @objc public let isNewUser: Bool

  // Maintain newUser for Objective-C API.

  /// Indicates whether or not the current user was signed in for the first time.
  @objc open func newUser() -> Bool {
    return isNewUser
  }

  init(providerID: String, profile: [String: Any]?, username: String?, isNewUser: Bool) {
    self.providerID = providerID
    self.profile = profile
    self.username = username
    self.isNewUser = isNewUser
  }

  // MARK: Secure Coding

  private static let providerIDCodingKey = "providerID"
  private static let profileCodingKey = "profile"
  private static let usernameCodingKey = "username"
  private static let newUserKey = "newUser"

  public static let supportsSecureCoding = true

  public required init?(coder aDecoder: NSCoder) {
    guard let providerID = aDecoder.decodeObject(
      of: NSString.self,
      forKey: AdditionalUserInfo.providerIDCodingKey
    ) as? String else {
      return nil
    }
    self.providerID = providerID
    profile = aDecoder.decodeObject(
      of: [NSDictionary.self, NSString.self],
      forKey: AdditionalUserInfo.profileCodingKey
    ) as? [String: Any]
    username = aDecoder.decodeObject(
      of: NSString.self,
      forKey: AdditionalUserInfo.usernameCodingKey
    ) as String?
    if let newUser = aDecoder.decodeObject(
      of: NSNumber.self,
      forKey: AdditionalUserInfo.newUserKey
    ) {
      isNewUser = newUser.intValue == 1
    } else {
      isNewUser = false
    }
  }

  public func encode(with aCoder: NSCoder) {
    aCoder.encode(providerID, forKey: AdditionalUserInfo.providerIDCodingKey)
    aCoder.encode(profile, forKey: AdditionalUserInfo.profileCodingKey)
    aCoder.encode(username, forKey: AdditionalUserInfo.usernameCodingKey)
    aCoder.encode(isNewUser ? NSNumber(1) : NSNumber(0), forKey: AdditionalUserInfo.newUserKey)
  }
}
