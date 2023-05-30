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
import CommonCrypto

/**
 @brief Utility class for constructing OAuth Sign In credentials.
 */
@objc(FIROAuthProvider) open class OAuthProvider: NSObject, FederatedAuthProvider {
  @objc public static let id = "OAuth"

  /** @property scopes
      @brief Array used to configure the OAuth scopes.
   */
  @objc public var scopes: [String]

  /** @property customParameters
      @brief Dictionary used to configure the OAuth custom parameters.
   */
  @objc public var customParameters: [String: String]

  /** @property providerID
      @brief The provider ID indicating the specific OAuth provider this OAuthProvider instance
            represents.
   */
  @objc public let providerID: String

  /**
      @param providerID The provider ID of the IDP for which this auth provider instance will be
          configured.
      @return An instance of `OAuthProvider` corresponding to the specified provider ID.
   */
  @objc(providerWithProviderID:) public class func provider(providerID: String) -> OAuthProvider {
    return OAuthProvider(providerID: providerID, auth: Auth.auth())
  }

  /**
      @param providerID The provider ID of the IDP for which this auth provider instance will be
          configured.
      @param auth The auth instance to be associated with the `OAuthProvider` instance.
      @return An instance of `OAuthProvider` corresponding to the specified provider ID.
   */
  @objc(providerWithProviderID:auth:) public class func provider(providerID: String,
                                                                 auth: Auth) -> OAuthProvider {
    return OAuthProvider(providerID: providerID, auth: auth)
  }

  /**
      @param providerID The provider ID of the IDP for which this auth provider instance will be
          configured.
      @return An instance of `OAuthProvider` corresponding to the specified provider ID.
   */
  @objc(providerWithProviderID:) public convenience init(providerID: String) {
    self.init(providerID: providerID, auth: Auth.auth())
  }

  /**
      @param providerID The provider ID of the IDP for which this auth provider instance will be
          configured.
      @param auth The auth instance to be associated with the `OAuthProvider` instance.
      @return An instance of `OAuthProvider` corresponding to the specified provider ID.
   */
  @objc(providerWithProviderID:auth:) public init(providerID: String, auth: Auth) {
    if auth.requestConfiguration.emulatorHostAndPort == nil {
      if providerID == FacebookAuthProvider.id {
        fatalError("Sign in with Facebook is not supported via generic IDP; the Facebook TOS " +
          "dictate that you must use the Facebook iOS SDK for Facebook login.")
      }
      if providerID == AuthProviderString.apple.rawValue {
        fatalError("Sign in with Apple is not supported via generic IDP; You must use the Apple SDK" +
          " for Sign in with Apple.")
      }
    }
    self.auth = auth
    self.providerID = providerID
    scopes = [""]
    customParameters = [:]

    if let clientID = auth.app?.options.clientID {
      let reverseClientIDScheme = clientID.components(separatedBy: ".").reversed()
        .joined(separator: ".")
      if let urlTypes = auth.mainBundleUrlTypes,
         AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: reverseClientIDScheme,
                                                 urlTypes: urlTypes) {
        callbackScheme = reverseClientIDScheme
        usingClientIDScheme = true
        return
      }
    }
    usingClientIDScheme = false
    if let appID = auth.app?.options.googleAppID {
      callbackScheme = "app-\(appID.replacingOccurrences(of: ":", with: "-"))"
    } else {
      fatalError("Missing googleAppID for constructing callbackScheme")
    }
  }

  /**
      @brief Creates an `AuthCredential` for the OAuth 2 provider identified by provider ID, ID
          token, and access token.

      @param providerID The provider ID associated with the Auth credential being created.
      @param idToken The IDToken associated with the Auth credential being created.
      @param accessToken The access token associated with the Auth credential be created, if
          available.
      @return A `AuthCredential` for the specified provider ID, ID token and access token.
   */
  @objc(credentialWithProviderID:IDToken:accessToken:)
  public static func credential(withProviderID providerID: String,
                                idToken: String,
                                accessToken: String?) -> OAuthCredential {
    return OAuthCredential(withProviderID: providerID, idToken: idToken, accessToken: accessToken)
  }

  /**
      @brief Creates an `AuthCredential` for the OAuth 2 provider identified by provider ID using
        an ID token.

      @param providerID The provider ID associated with the Auth credential being created.
      @param accessToken The access token associated with the Auth credential be created
      @return An `AuthCredential`.
   */
  @objc(credentialWithProviderID:accessToken:)
  public static func credential(withProviderID providerID: String,
                                accessToken: String) -> OAuthCredential {
    return OAuthCredential(withProviderID: providerID, accessToken: accessToken)
  }

  /**
      @brief Creates an `AuthCredential` for that OAuth 2 provider identified by provider ID, ID
          token, raw nonce, and access token.

      @param providerID The provider ID associated with the Auth credential being created.
      @param idToken The IDToken associated with the Auth credential being created.
      @param rawNonce The raw nonce associated with the Auth credential being created.
      @param accessToken The access token associated with the Auth credential be created, if
          available.
      @return A `AuthCredential` for the specified provider ID, ID token and access token.
   */
  @objc(credentialWithProviderID:IDToken:rawNonce:accessToken:)
  public static func credential(withProviderID providerID: String, idToken: String,
                                rawNonce: String,
                                accessToken: String) -> OAuthCredential {
    return OAuthCredential(
      withProviderID: providerID,
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: accessToken
    )
  }

  /**
      @brief Creates an `AuthCredential` for that OAuth 2 provider identified by providerID using
        an ID token and raw nonce.

      @param providerID The provider ID associated with the Auth credential being created.
      @param idToken The IDToken associated with the Auth credential being created.
      @param rawNonce The raw nonce associated with the Auth credential being created.
      @return A `AuthCredential`.
   */
  @objc(credentialWithProviderID:IDToken:rawNonce:)
  public static func credential(withProviderID providerID: String, idToken: String,
                                rawNonce: String) -> OAuthCredential {
    return OAuthCredential(withProviderID: providerID, idToken: idToken, rawNonce: rawNonce)
  }

  #if os(iOS)
    /** @fn getCredentialWithUIDelegate:completion:
        @brief Used to obtain an auth credential via a mobile web flow.
            This method is available on iOS only.
        @param UIDelegate An optional UI delegate used to present the mobile web flow.
        @param completion Optionally; a block which is invoked asynchronously on the main thread when
            the mobile web flow is completed.
     */
    @objc(getCredentialWithUIDelegate:completion:)
    public func getCredentialWith(_ UIDelegate: AuthUIDelegate?,
                                  completion: ((AuthCredential?, Error?) -> Void)? = nil) {
      guard let urlTypes = auth.mainBundleUrlTypes,
            AuthWebUtils.isCallbackSchemeRegistered(forCustomURLScheme: callbackScheme,
                                                    urlTypes: urlTypes) else {
        fatalError(
          "Please register custom URL scheme \(callbackScheme) in the app's Info.plist file."
        )
      }
      kAuthGlobalWorkQueue.async { [weak self] in
        guard let self = self else { return }
        let eventID = AuthWebUtils.randomString(withLength: 10)
        let sessionID = AuthWebUtils.randomString(withLength: 10)

        let callbackOnMainThread: ((AuthCredential?, Error?) -> Void) = { credential, error in
          if let completion {
            DispatchQueue.main.async {
              completion(credential, error)
            }
          }
        }
        self.getHeadfulLiteUrl(eventID: eventID, sessionID: sessionID) { headfulLiteURL, error in
          if let error {
            callbackOnMainThread(nil, error)
            return
          }
          guard let headfulLiteURL else {
            fatalError("FirebaseAuth Internal Error: Both error and headfulLiteURL return are nil")
          }
          let callbackMatcher: (URL?) -> Bool = { callbackURL in
            AuthWebUtils.isExpectedCallbackURL(callbackURL,
                                               eventID: eventID,
                                               authType: "signInWithRedirect",
                                               callbackScheme: self.callbackScheme)
          }
          self.auth.authURLPresenter.present(headfulLiteURL,
                                             uiDelegate: UIDelegate,
                                             callbackMatcher: callbackMatcher) { callbackURL, error in
            if let error {
              callbackOnMainThread(nil, error)
              return
            }
            guard let callbackURL else {
              fatalError("FirebaseAuth Internal Error: Both error and callbackURL return are nil")
            }
            let (oAuthResponseURLString, error) = self.oAuthResponseForURL(url: callbackURL)
            if let error {
              callbackOnMainThread(nil, error)
              return
            }
            guard let oAuthResponseURLString else {
              fatalError(
                "FirebaseAuth Internal Error: Both error and oAuthResponseURLString return are nil"
              )
            }
            let credential = OAuthCredential(withProviderID: self.providerID,
                                             sessionID: sessionID,
                                             OAuthResponseURLString: oAuthResponseURLString)
            callbackOnMainThread(credential, nil)
          }
        }
      }
    }

    /** @fn getCredentialWithUIDelegate:completion:
        @brief Used to obtain an auth credential via a mobile web flow.
            This method is available on iOS only.
        @param UIDelegate An optional UI delegate used to present the mobile web flow.
        @return An `AuthCredential`.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    public func credential(with UIDelegate: AuthUIDelegate?) async throws -> AuthCredential {
      return try await withCheckedThrowingContinuation { continuation in
        getCredentialWith(UIDelegate) { credential, error in
          if let credential = credential {
            continuation.resume(returning: credential)
          } else {
            continuation.resume(throwing: error!) // TODO: Change to ?? and generate unknown error
          }
        }
      }
    }
  #endif

  /** @fn appleCredentialWithIDToken:rawNonce:fullName:
   *  @brief Creates an `AuthCredential` for the Sign in with Apple OAuth 2 provider identified by ID
   * token, raw nonce, and full name. This method is specific to the Sign in with Apple OAuth 2
   * provider as this provider requires the full name to be passed explicitly.
   *
   *  @param idToken The IDToken associated with the Sign in with Apple Auth credential being created.
   *  @param rawNonce The raw nonce associated with the Sign in with Apple Auth credential being
   * created.
   *  @param fullName The full name associated with the Sign in with Apple Auth credential being
   * created.
   *  @return An `AuthCredential`.
   */
  @objc(appleCredentialWithIDToken:rawNonce:fullName:)
  public static func appleCredential(withIDToken idToken: String,
                                     rawNonce: String?,
                                     fullName: PersonNameComponents?) -> OAuthCredential {
    return OAuthCredential(withProviderID: AuthProviderString.apple.rawValue,
                           idToken: idToken,
                           rawNonce: rawNonce,
                           fullName: fullName)
  }

  // MARK: - Private Methods

  /** @fn OAuthResponseForURL:error:
      @brief Parses the redirected URL and returns a string representation of the OAuth response URL.
      @param URL The url to be parsed for an OAuth response URL.
      @param error The error that occurred if any.
      @return The OAuth response if successful.
   */
  private func oAuthResponseForURL(url: URL) -> (String?, Error?) {
    var urlQueryItems = AuthWebUtils.dictionary(withHttpArgumentsString: url.query)
    if let item = urlQueryItems["deep_link_id"],
       let deepLinkURL = URL(string: item) {
      urlQueryItems = AuthWebUtils.dictionary(withHttpArgumentsString: deepLinkURL.query)
      if let queryItemLink = urlQueryItems["link"] {
        return (queryItemLink, nil)
      }
    }
    if let errorData = urlQueryItems["firebaseError"]?.data(using: .utf8) {
      do {
        let error = try JSONSerialization.jsonObject(with: errorData) as? [String: Any]
        let code = (error?["code"] as? String) ?? "missing code"
        let message = (error?["message"] as? String) ?? "missing message"
        return (nil, AuthErrorUtils.urlResponseError(code: code, message: message))
      } catch {
        return (nil, AuthErrorUtils.JSONSerializationError(underlyingError: error))
      }
    }
    return (nil, AuthErrorUtils.webSignInUserInteractionFailure(
      reason: "SignIn failed with unparseable firebaseError"
    ))
  }

  /** @fn getHeadfulLiteURLWithEventID
      @brief Constructs a URL used for opening a headful-lite flow using a given event
          ID and session ID.
      @param eventID The event ID used for this purpose.
      @param sessionID The session ID used when completing the headful lite flow.
      @param completion The callback invoked after the URL has been constructed or an error
          has been encountered.
   */
  private func getHeadfulLiteUrl(eventID: String,
                                 sessionID: String,
                                 completion: @escaping ((URL?, Error?) -> Void)) {
    weak var weakSelf = self
    AuthWebUtils
      .fetchAuthDomain(withRequestConfiguration: auth.requestConfiguration) { authDomain, error in
        if let error = error {
          completion(nil, error)
          return
        }
        let strongSelf = weakSelf
        let bundleID = Bundle.main.bundleIdentifier
        let clientID = strongSelf?.auth.app?.options.clientID
        let appID = strongSelf?.auth.app?.options.googleAppID
        let apiKey = strongSelf?.auth.requestConfiguration.apiKey
        let tenantID = strongSelf?.auth.tenantID
        let appCheck = strongSelf?.auth.requestConfiguration.appCheck

        // TODO: Should we fail if these strings are empty? Only ibi was explicit in ObjC.
        var urlArguments = ["apiKey": apiKey ?? "",
                            "authType": "signInWithRedirect",
                            "ibi": bundleID ?? "",
                            "sessionId": strongSelf?.hash(forString: sessionID) ?? "",
                            "v": AuthBackend.authUserAgent(),
                            "eventId": eventID,
                            "providerId": strongSelf?.providerID ?? ""]

        if let usingClientIDScheme = strongSelf?.usingClientIDScheme, usingClientIDScheme {
          urlArguments["clientId"] = clientID
        } else {
          urlArguments["appId"] = appID
        }
        if let tenantID {
          urlArguments["tid"] = tenantID
        }
        if let scopes = strongSelf?.scopes, scopes.count > 0 {
          urlArguments["scopes"] = scopes.joined(separator: ",")
        }
        if let customParameters = strongSelf?.customParameters, customParameters.count > 0 {
          do {
            let customParametersJSONData = try JSONSerialization
              .data(withJSONObject: customParameters)
            let rawJson = String(decoding: customParametersJSONData, as: UTF8.self)
            urlArguments["customParameters"] = rawJson
          } catch {
            completion(nil, AuthErrorUtils.JSONSerializationError(underlyingError: error))
          }
        }
        if let languageCode = strongSelf?.auth.requestConfiguration.languageCode {
          urlArguments["hl"] = languageCode
        }
        let argumentsString = strongSelf?
          .httpArgumentsString(forArgsDictionary: urlArguments) ?? ""
        var urlString: String
        if (strongSelf?.auth.requestConfiguration.emulatorHostAndPort) != nil {
          urlString = "http://\(authDomain ?? "")/emulator/auth/handler?\(argumentsString)"
        } else {
          urlString = "https://\(authDomain ?? "")/__/auth/handler?\(argumentsString)"
        }
        guard let percentEncoded = urlString.addingPercentEncoding(
          withAllowedCharacters: CharacterSet.urlFragmentAllowed
        ) else {
          fatalError("Internal Auth Error: failed to percent encode a string")
        }
        var components = URLComponents(string: percentEncoded)
        if let appCheck {
          appCheck.getToken(forcingRefresh: false) { tokenResult in
            if let error = tokenResult.error {
              AuthLog.logWarning(code: "I-AUT000018",
                                 message: "Error getting App Check token; using placeholder " +
                                   "token instead. Error: \(error)")
            }
            let appCheckTokenFragment = "fac=\(tokenResult.token)"
            components?.fragment = appCheckTokenFragment
            completion(components?.url, nil)
          }
        } else {
          completion(components?.url, nil)
        }
      }
  }

  /** @fn hashforString:
      @brief Returns the SHA256 hash representation of a given string object.
      @param string The string for which a SHA256 hash is desired.
      @return An hexadecimal string representation of the SHA256 hash.
   */
  private func hash(forString string: String) -> String {
    guard let sessionIdData = string.data(using: .utf8) as? NSData else {
      fatalError("FirebaseAuth Internal error: Failed to create hash for sessionID")
    }
    let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA256(sessionIdData.bytes, UInt32(sessionIdData.length), &hash)
    let dataHash = NSData(bytes: hash, length: digestLength)
    var bytes = [UInt8](repeating: 0, count: digestLength)
    dataHash.getBytes(&bytes, length: digestLength)

    var hexString = ""
    for byte in bytes {
      hexString += String(format: "%02x", UInt8(byte))
    }
    return hexString
  }

  private func httpArgumentsString(forArgsDictionary argsDictionary: [String: String]) -> String {
    var argsString: [String] = []
    for (key, value) in argsDictionary {
      let keyString = AuthWebUtils.string(byUnescapingFromURLArgument: key)
      let valueString = AuthWebUtils.string(byUnescapingFromURLArgument: value.description)
      argsString.append("\(keyString)=\(valueString)")
    }
    return argsString.joined(separator: "&")
  }

  private let auth: Auth
  private let callbackScheme: String
  private let usingClientIDScheme: Bool
}
