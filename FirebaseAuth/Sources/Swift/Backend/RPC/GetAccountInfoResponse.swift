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

/// Represents the response from the setAccountInfo endpoint.
/// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct GetAccountInfoResponse: AuthRPCResponse {
  /// Represents the provider user info part of the response from the getAccountInfo endpoint.
  /// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
  struct ProviderUserInfo {
    /// The ID of the identity provider.
    let providerID: String?

    /// The user's display name at the identity provider.
    let displayName: String?

    /// The user's photo URL at the identity provider.
    let photoURL: URL?

    /// The user's identifier at the identity provider.
    let federatedID: String?

    /// The user's email at the identity provider.
    let email: String?

    /// A phone number associated with the user.
    let phoneNumber: String?

    /// Designated initializer.
    /// - Parameter dictionary: The provider user info data from endpoint.
    init(dictionary: [String: Any]) {
      providerID = dictionary["providerId"] as? String
      displayName = dictionary["displayName"] as? String
      if let photoURL = dictionary["photoUrl"] as? String {
        self.photoURL = URL(string: photoURL)
      } else {
        photoURL = nil
      }
      federatedID =
        dictionary["federatedId"] as? String
      email = dictionary["email"] as? String
      phoneNumber = dictionary["phoneNumber"] as? String
    }
  }

  /// Represents the firebase user info part of the response from the getAccountInfo endpoint.
  /// See https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
  struct User {
    /// The ID of the user.
    let localID: String?

    /// The email or the user.
    let email: String?

    /// Whether the email has been verified.
    let emailVerified: Bool

    /// The display name of the user.
    let displayName: String?

    /// The user's photo URL.
    let photoURL: URL?

    /// The user's creation date.
    let creationDate: Date?

    /// The user's last login date.
    let lastLoginDate: Date?

    /// The user's profiles at the associated identity providers.
    let providerUserInfo: [GetAccountInfoResponse.ProviderUserInfo]?

    /// Information about user's password.
    /// This is not necessarily the hash of user's actual password.
    let passwordHash: String?

    /// A phone number associated with the user.
    let phoneNumber: String?

    let mfaEnrollments: [AuthProtoMFAEnrollment]?

    /// Designated initializer.
    /// - Parameter dictionary: The provider user info data from endpoint.
    init(dictionary: [String: Any]) {
      if let providerUserInfoData = dictionary["providerUserInfo"] as? [[String: Any]] {
        providerUserInfo = providerUserInfoData
          .map(GetAccountInfoResponse.ProviderUserInfo.init(dictionary:))
      } else {
        providerUserInfo = nil
      }
      localID = dictionary["localId"] as? String
      displayName = dictionary["displayName"] as? String
      email = dictionary["email"] as? String
      if let photoURL = dictionary["photoUrl"] as? String {
        self.photoURL = URL(string: photoURL)
      } else {
        photoURL = nil
      }
      if let createdAt = dictionary["createdAt"] as? String,
         let timeInterval = Double(createdAt) {
        // Divide by 1000 in order to convert milliseconds to seconds.
        creationDate = Date(timeIntervalSince1970: timeInterval / 1000)
      } else {
        creationDate = nil
      }
      if let lastLoginAt = dictionary["lastLoginAt"] as? String,
         let timeInterval = Double(lastLoginAt) {
        // Divide by 1000 in order to convert milliseconds to seconds.
        lastLoginDate = Date(timeIntervalSince1970: timeInterval / 1000)
      } else {
        lastLoginDate = nil
      }

      emailVerified = dictionary["emailVerified"] as? Bool ?? false
      passwordHash = dictionary["passwordHash"] as? String
      phoneNumber = dictionary["phoneNumber"] as? String
      if let mfaEnrollmentData = dictionary["mfaInfo"] as? [[String: AnyHashable]] {
        mfaEnrollments = mfaEnrollmentData.map { AuthProtoMFAEnrollment(dictionary: $0)
        }
      } else {
        mfaEnrollments = nil
      }
    }
  }

  /// The requested users' profiles.
  var users: [Self.User]?

  mutating func setFields(dictionary: [String: AnyHashable]) throws {
    guard let usersData = dictionary["users"] as? [[String: AnyHashable]] else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    guard usersData.count == 1 else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    users = [Self.User(dictionary: usersData[0])]
  }
}
