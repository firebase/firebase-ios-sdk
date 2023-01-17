//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 26/06/2022.
//

import Foundation

/** @var kExpirationDateKey
    @brief The key used to encode the expirationDate property for NSSecureCoding.
 */
// XXX TODO: TYPO IN ORIGINAL KEY. TO FIX OR NOT?
private let kExpirationDateKey = "expiratinDate"

/** @var kTokenKey
    @brief The key used to encode the token property for NSSecureCoding.
 */
private let kTokenKey = "token"

/** @var kAuthDateKey
    @brief The key used to encode the authDate property for NSSecureCoding.
 */
private let kAuthDateKey = "authDate"

/** @var kIssuedDateKey
    @brief The key used to encode the issuedDate property for NSSecureCoding.
 */
private let kIssuedDateKey = "issuedDate"

/** @var kSignInProviderKey
    @brief The key used to encode the signInProvider property for NSSecureCoding.
 */
private let kSignInProviderKey = "signInProvider"

/** @var kSignInSecondFactorKey
 @brief The key used to encode the signInSecondFactor property for NSSecureCoding.
 */
private let kSignInSecondFactorKey = "signInSecondFactor"

/** @var kClaimsKey
    @brief The key used to encode the claims property for NSSecureCoding.
 */
private let kClaimsKey = "claims"

/** @class FIRAuthTokenResult
    @brief A data class containing the ID token JWT string and other properties associated with the
    token including the decoded payload claims.
 */
@objc(FIRAuthTokenResult) public class AuthTokenResult: NSObject {


/** @property token
    @brief Stores the JWT string of the ID token.
 */
    @objc public var token: String

/** @property expirationDate
    @brief Stores the ID token's expiration date.
 */
    @objc public var expirationDate: Date

/** @property authDate
    @brief Stores the ID token's authentication date.
    @remarks This is the date the user was signed in and NOT the date the token was refreshed.
 */
    @objc public var authDate: Date

/** @property issuedAtDate
    @brief Stores the date that the ID token was issued.
    @remarks This is the date last refreshed and NOT the last authentication date.
 */
    @objc public var issuedAtDate: Date

/** @property signInProvider
    @brief Stores sign-in provider through which the token was obtained.
    @remarks This does not necessarily map to provider IDs.
 */
    @objc public var signInProvider: String

/** @property signInSecondFactor
    @brief Stores sign-in second factor through which the token was obtained.
 */
    @objc public var signInSecondFactor: String

/** @property claims
    @brief Stores the entire payload of claims found on the ID token. This includes the standard
        reserved claims as well as custom claims set by the developer via the Admin SDK.
 */
    @objc public var claims: Dictionary<String, Any>

    /** @fn tokenResultWithToken:
        @brief Parse a token string to a structured token.
        @param token The token string to parse.
        @return A structured token result.
    */
    @objc public class func tokenResult(token: String) -> AuthTokenResult? {
        let tokenStringArray = token.components(separatedBy: ".")

        // The JWT should have three parts, though we only use the second in this method.
        if tokenStringArray.count != 3 {
          return nil
        }

        // The token payload is always the second index of the array.
        let IDToken = tokenStringArray[1]

        // Convert the base64URL encoded string to a base64 encoded string.
        // Replace "_" with "/"
        // Replace "-" with "+"
        var tokenPayload = IDToken.replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")

        // Pad the token payload with "=" signs if the payload's length is not a multiple of 4.
        if tokenPayload.count % 4 != 0 {
            let length = tokenPayload.count + (4 - tokenPayload.count % 4)
            tokenPayload = tokenPayload.padding(toLength: length, withPad: "=", startingAt: 0)
        }

        guard let decodedTokenPayloadData = Data(base64Encoded: tokenPayload, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        guard let tokenPayloadDictionary = try? JSONSerialization.jsonObject(with: decodedTokenPayloadData, options: [.mutableContainers, .allowFragments]) as? [String: Any] else {
            return nil
        }
        // These are dates since 00:00:00 January 1 1970, as described by the Terminology section in
        // the JWT spec. https://tools.ietf.org/html/rfc7519
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let jwt = try? decoder.decode(JWT.self, from: decodedTokenPayloadData) else {
            return nil
        }

        let tokenResult = AuthTokenResult(token: token,
                                          expirationDate: jwt.exp,
                                          authDate: jwt.authTime,
                                          issuedAtDate: jwt.iat,
                                          signInProvider: jwt.firebase.signInProvider,
                                          signInSecondFactor: jwt.firebase.signInSecondFactor,
                                          claims: tokenPayloadDictionary)
        return tokenResult;
    }

    init(token: String,
         expirationDate: Date,
         authDate: Date,
         issuedAtDate: Date,
         signInProvider: String,
         signInSecondFactor: String,
         claims: Dictionary<String, Any>) {
        self.token = token
        self.expirationDate = expirationDate
        self.authDate = authDate
        self.issuedAtDate = issuedAtDate
        self.signInProvider = signInProvider
        self.signInSecondFactor = signInSecondFactor
        self.claims = claims
    }
}

struct JWT: Decodable {
    struct FirebasePayload: Decodable {
        let signInProvider: String
        let signInSecondFactor: String
    }
    let exp: Date
    let authTime: Date
    let iat: Date
    let firebase: FirebasePayload
}

/*
 @implementation FIRAuthTokenResult


 + (nullable FIRAuthTokenResult *)tokenResultWithToken:(NSString *)token {

 }

 #pragma mark - NSSecureCoding

 + (BOOL)supportsSecureCoding {
   return YES;
 }

 - (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
   NSString *token = [aDecoder decodeObjectOfClass:[NSDate class] forKey:kTokenKey];
   return [FIRAuthTokenResult tokenResultWithToken:token];
 }

 - (void)encodeWithCoder:(NSCoder *)aCoder {
   [aCoder encodeObject:_token forKey:kTokenKey];
 }

 @end

 */
