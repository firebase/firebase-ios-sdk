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

extension UserInfoImpl: NSSecureCoding {}

@objc(FIRUserInfoImpl) class UserInfoImpl: NSObject, UserInfo {
  /// A convenience factory method for constructing a `UserInfo` instance from data
  /// returned by the getAccountInfo endpoint.
  /// - Parameter providerUserInfo: Data returned by the getAccountInfo endpoint.
  /// - Returns: A new instance of `UserInfo` using data from the getAccountInfo endpoint.
  class func userInfo(withGetAccountInfoResponseProviderUserInfo providerUserInfo: GetAccountInfoResponseProviderUserInfo)
    -> UserInfoImpl {
    guard let providerID = providerUserInfo.providerID else {
      // This was a crash in ObjC implementation. Should providerID be not nullable?
      fatalError("Missing providerID from GetAccountInfoResponseProviderUserInfo")
    }
    return UserInfoImpl(withProviderID: providerID,
                        userID: providerUserInfo.federatedID ?? "",
                        displayName: providerUserInfo.displayName,
                        photoURL: providerUserInfo.photoURL,
                        email: providerUserInfo.email,
                        phoneNumber: providerUserInfo.phoneNumber)
  }

  /// Designated initializer.
  /// - Parameter providerID: The provider identifier.
  /// - Parameter userID: The unique user ID for the user (the value of the uid field in the token.)
  /// - Parameter displayName: The name of the user.
  /// - Parameter photoURL: The URL of the user's profile photo.
  /// - Parameter email: The user's email address.
  /// - Parameter phoneNumber: The user's phone number.
  private init(withProviderID providerID: String,
               userID: String,
               displayName: String?,
               photoURL: URL?,
               email: String?,
               phoneNumber: String?) {
    self.providerID = providerID
    uid = userID
    self.displayName = displayName
    self.photoURL = photoURL
    self.email = email
    self.phoneNumber = phoneNumber
  }

  var providerID: String
  var uid: String
  var displayName: String?
  var photoURL: URL?
  var email: String?
  var phoneNumber: String?

  // MARK: Secure Coding

  private static let kProviderIDCodingKey = "providerID"
  private static let kUserIDCodingKey = "userID"
  private static let kDisplayNameCodingKey = "displayName"
  private static let kPhotoURLCodingKey = "photoURL"
  private static let kEmailCodingKey = "email"
  private static let kPhoneNumberCodingKey = "phoneNumber"

  static var supportsSecureCoding: Bool {
    return true
  }

  func encode(with coder: NSCoder) {
    coder.encode(providerID, forKey: UserInfoImpl.kProviderIDCodingKey)
    coder.encode(uid, forKey: UserInfoImpl.kUserIDCodingKey)
    coder.encode(displayName, forKey: UserInfoImpl.kDisplayNameCodingKey)
    coder.encode(photoURL, forKey: UserInfoImpl.kPhotoURLCodingKey)
    coder.encode(email, forKey: UserInfoImpl.kEmailCodingKey)
    coder.encode(phoneNumber, forKey: UserInfoImpl.kPhoneNumberCodingKey)
  }

  required convenience init?(coder: NSCoder) {
    guard let providerID = coder.decodeObject(
      of: [NSString.self],
      forKey: UserInfoImpl.kProviderIDCodingKey
    ) as? String,
      let userID = coder.decodeObject(
        of: [NSString.self],
        forKey: UserInfoImpl.kUserIDCodingKey
      ) as? String
    else {
      return nil
    }
    let displayName = coder.decodeObject(
      of: [NSString.self],
      forKey: UserInfoImpl.kDisplayNameCodingKey
    ) as? String
    let photoURL = coder.decodeObject(
      of: [NSURL.self],
      forKey: UserInfoImpl.kPhotoURLCodingKey
    ) as? URL
    let email = coder.decodeObject(
      of: [NSString.self],
      forKey: UserInfoImpl.kEmailCodingKey
    ) as? String
    let phoneNumber = coder.decodeObject(
      of: [NSString.self],
      forKey: UserInfoImpl.kPhoneNumberCodingKey
    ) as? String
    self.init(withProviderID: providerID,
              userID: userID,
              displayName: displayName,
              photoURL: photoURL,
              email: email,
              phoneNumber: phoneNumber)
  }
}
