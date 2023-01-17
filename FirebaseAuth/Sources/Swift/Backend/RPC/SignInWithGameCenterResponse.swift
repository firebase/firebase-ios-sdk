//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 17/01/2023.
//

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
