//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 27/09/2022.
//

import Foundation

/** @var kErrorKey
    @brief The key for the "error" value in JSON responses from the server.
 */
private let kErrorKey = "error"

/** @class FIRGetAccountInfoResponseProviderUserInfo
    @brief Represents the provider user info part of the response from the getAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
@objc(FIRGetAccountInfoResponseProviderUserInfo) public class GetAccountInfoResponseProviderUserInfo: NSObject {

    /** @property providerID
     @brief The ID of the identity provider.
     */
    @objc public let providerID: String?

    /** @property displayName
     @brief The user's display name at the identity provider.
     */
    @objc public let displayName: String?

    /** @property photoURL
     @brief The user's photo URL at the identity provider.
     */
    @objc public let photoURL: URL?

    /** @property federatedID
     @brief The user's identifier at the identity provider.
     */
    @objc public let federatedID: String?

    /** @property email
     @brief The user's email at the identity provider.
     */
    @objc public let email: String?

    /** @property phoneNumber
     @brief A phone number associated with the user.
     */
    @objc public let phoneNumber: String?


    /** @fn initWithAPIKey:
     @brief Designated initializer.
     @param dictionary The provider user info data from endpoint.
     */
    init(dictionary: [String: Any]) {
        self.providerID = dictionary["providerId"] as? String
        self.displayName = dictionary["displayName"] as? String
        if let photoURL = dictionary["photoUrl"] as? String {
            self.photoURL = URL(string: photoURL)
        } else {
            self.photoURL = nil
        }
        self.federatedID =
            dictionary["federatedId"] as? String
        self.email = dictionary["email"] as? String
        self.phoneNumber = dictionary["phoneNumber"] as? String
    }
}

/** @class FIRGetAccountInfoResponseUser
    @brief Represents the firebase user info part of the response from the getAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
@objc(FIRGetAccountInfoResponseUser) public class GetAccountInfoResponseUser: NSObject {

    /** @property localID
     @brief The ID of the user.
     */
    @objc public let localID: String?

    /** @property email
     @brief The email or the user.
     */
    @objc public let email: String?

    /** @property emailVerified
     @brief Whether the email has been verified.
     */
    @objc public let emailVerified: Bool

    /** @property displayName
     @brief The display name of the user.
     */
    @objc public let displayName: String?

    /** @property photoURL
     @brief The user's photo URL.
     */
    @objc public let photoURL: URL?

    /** @property creationDate
     @brief The user's creation date.
     */
    @objc public let creationDate: Date?

    /** @property lastSignInDate
     @brief The user's last login date.
     */
    @objc public let lastLoginDate: Date?

    /** @property providerUserInfo
     @brief The user's profiles at the associated identity providers.
     */
    @objc public let providerUserInfo: [GetAccountInfoResponseProviderUserInfo]?

    /** @property passwordHash
     @brief Information about user's password.
     @remarks This is not necessarily the hash of user's actual password.
     */

    @objc public let passwordHash: String?

    /** @property phoneNumber
     @brief A phone number associated with the user.
     */
    @objc public let phoneNumber: String?

    @objc public let MFAEnrollments: [AuthProtoMFAEnrollment]?

    /** @fn initWithAPIKey:
     @brief Designated initializer.
     @param dictionary The provider user info data from endpoint.
     */
    init(dictionary: [String: Any]) {
        if let providerUserInfoData =  dictionary["providerUserInfo"] as? [[String: Any]] {
            self.providerUserInfo = providerUserInfoData.map {
                GetAccountInfoResponseProviderUserInfo(dictionary: $0)
          }
        } else {
            self.providerUserInfo = nil
        }
        self.localID = dictionary["localId"] as? String
        self.displayName = dictionary["displayName"] as? String
        self.email = dictionary["email"] as? String
        if let photoURL = dictionary["photoUrl"] as? String {
            self.photoURL = URL(string: photoURL)
        } else {
            self.photoURL = nil
        }
        if let createdAt = dictionary["createdAt"] as? String {
            // Divide by 1000 in order to convert miliseconds to seconds.
            let timeInterval = (createdAt as NSString).doubleValue / 1000
            self.creationDate = Date(timeIntervalSince1970: timeInterval)
        } else {
            self.creationDate = nil
        }
        if let lastLoginAt = dictionary["lastLoginAt"] as? String {
            // Divide by 1000 in order to convert miliseconds to seconds.
            let timeInterval = (lastLoginAt as NSString).doubleValue / 1000
            self.lastLoginDate = Date(timeIntervalSince1970: timeInterval)
        } else {
            self.lastLoginDate = nil
        }

        self.emailVerified = dictionary["emailVerified"] as? Bool ?? false
        self.passwordHash = dictionary["passwordHash"] as? String
        self.phoneNumber = dictionary["phoneNumber"] as? String
        if let MFAEnrollmentData = dictionary["mfaInfo"] as? [[String: Any]] {
            self.MFAEnrollments = MFAEnrollmentData.map { AuthProtoMFAEnrollment(dictionary: $0)
            }
        } else {
            self.MFAEnrollments = nil
        }
    }
}

/** @class FIRGetAccountInfoResponse
    @brief Represents the response from the setAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
@objc(FIRGetAccountInfoResponse) public class GetAccountInfoResponse: NSObject,  AuthRPCResponse {

    /** @property providerUserInfo
     @brief The requested users' profiles.
     */
    @objc public var users: [GetAccountInfoResponseUser]?
    public func setFields(dictionary: [String : Any]) throws {
        guard let usersData = dictionary["users"] as? [[String: Any]] else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        guard usersData.count == 1 else {
            throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
        }
        self.users = [GetAccountInfoResponseUser(dictionary: usersData[0])]
    }
}
