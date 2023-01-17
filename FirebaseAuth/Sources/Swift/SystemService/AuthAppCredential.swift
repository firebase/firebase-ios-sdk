//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 25/09/2022.
//

import Foundation

/** @var kReceiptKey
    @brief The key used to encode the receipt property for NSSecureCoding.
 */
private let kReceiptKey = "receipt"

/** @var kSecretKey
    @brief The key used to encode the secret property for NSSecureCoding.
 */
private let kSecretKey = "secret"

/** @class FIRAuthAppCredential
    @brief A class represents a credential that proves the identity of the app.
 */
@objc(FIRAuthAppCredential) public class AuthAppCredential: NSObject, NSSecureCoding {

    /** @property receipt
        @brief The server acknowledgement of receiving client's claim of identity.
     */
    @objc public var receipt: String

    /** @property secret
        @brief The secret that the client received from server via a trusted channel, if ever.
     */
    @objc public var secret: String?

    /** @fn initWithReceipt:secret:
        @brief Initializes the instance.
        @param receipt The server acknowledgement of receiving client's claim of identity.
        @param secret The secret that the client received from server via a trusted channel, if ever.
        @return The initialized instance.
     */
    @objc public init(receipt: String, secret: String?) {
        self.secret = secret
        self.receipt = receipt
    }

    // MARK: NSSecureCoding

    public static var supportsSecureCoding: Bool {
        true
    }

    public required convenience init?(coder: NSCoder) {
        guard let receipt = coder.decodeObject(of: [NSString.self], forKey: kReceiptKey) as? String else {
            return nil
        }
        let secret = coder.decodeObject(of: [NSString.self], forKey: kSecretKey) as? String
        self.init(receipt: receipt, secret: secret)
    }


    public func encode(with coder: NSCoder) {
        coder.encode(receipt, forKey: kReceiptKey)
        coder.encode(secret, forKey: kSecretKey)
    }
}
