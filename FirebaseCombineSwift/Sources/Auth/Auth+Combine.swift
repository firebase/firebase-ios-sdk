// Copyright 2020 Google LLC
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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseAuth

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  extension Auth {
    // MARK: - Authentication State Management

    /// Registers a publisher that publishes authentication state changes.
    ///
    /// The publisher emits values when:
    ///
    /// - It is registered,
    /// - a user with a different UID from the current user has signed in, or
    /// - the current user has signed out.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher emitting a `User` instance (if the user has signed in) or `nil` (if the user has signed out).
    /// The publisher will emit on the *main* thread.
    public func authStateDidChangePublisher() -> AnyPublisher<User?, Never> {
      let subject = PassthroughSubject<User?, Never>()
      let handle = addStateDidChangeListener { auth, user in
        subject.send(user)
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeStateDidChangeListener(handle)
        })
        .eraseToAnyPublisher()
    }

    /// Registers a publisher that publishes ID token state changes.
    ///
    /// The publisher emits values when:
    ///
    /// - It is registered,
    /// - a user with a different UID from the current user has signed in,
    /// - the ID token of the current user has been refreshed, or
    /// - the current user has signed out.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher emitting a `User` instance (if a different user is signed in or
    ///   the ID token of the current user has changed) or `nil` (if the user has signed out).
    ///   The publisher will emit on the *main* thread.
    public func idTokenDidChangePublisher() -> AnyPublisher<User?, Never> {
      let subject = PassthroughSubject<User?, Never>()
      let handle = addIDTokenDidChangeListener { auth, user in
        subject.send(user)
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeIDTokenDidChangeListener(handle)
        })
        .eraseToAnyPublisher()
    }

    /// Sets the `currentUser` on the calling Auth instance to the provided `user` object.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter user: The user object to be set as the current user of the calling Auth instance.
    /// - Returns: A publisher that emits when the user of the calling Auth instance has been updated or
    /// an error was encountered. The publisher will emit on the **main** thread.
    @discardableResult
    public func updateCurrentUser(_ user: User) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.updateCurrentUser(user) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    // MARK: - Anonymous Authentication

    /// Asynchronously creates an anonymous user and assigns it as the calling Auth instance's current user.
    ///
    /// If there is already an anonymous user signed in, that user will be returned instead.
    /// If there is any other existing user signed in, that user will be signed out.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher that emits the result of the sign in flow. The publisher will emit on the *main* thread.
    /// - Remark:
    ///   Possible error codes:
    ///   - `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
    ///     not enabled. Enable them in the Auth section of the Firebase console.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func signInAnonymously() -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signInAnonymously { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    // MARK: - Email/Password Authentication

    /// Creates and, on success, signs in a user with the given email address and password.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's desired password.
    /// - Returns: A publisher that emits the result of the sign in flow. The publisher will emit on the *main* thread.
    /// - Remark:
    ///   Possible error codes:
    ///   - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///   - `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
    ///     already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
    ///     used, and prompt the user to sign in with one of those.
    ///   - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
    ///     are not enabled. Enable them in the Auth section of the Firebase console.
    ///   - `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
    ///     considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
    ///     dictionary object will contain more detailed explanation that can be shown to the user.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func createUser(withEmail email: String,
                           password: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.createUser(withEmail: email, password: password) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Signs in a user with the given email address and password.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: A publisher that emits the result of the sign in flow. The publisher will emit on the *main* thread.
    /// - Remark:
    ///   Possible error codes:
    ///   - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
    ///     accounts are not enabled. Enable them in the Auth section of the
    ///     Firebase console.
    ///   - `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    ///   - `AuthErrorCodeWrongPassword` - Indicates the user attempted
    ///     sign in with an incorrect password.
    ///   - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func signIn(withEmail email: String,
                       password: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signIn(withEmail: email, password: password) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    // MARK: - Email/Link Authentication

    /// Signs in using an email address and email sign-in link.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - link: The email sign-in link.
    /// - Returns: A publisher that emits the result of the sign in flow. The publisher will emit on the *main* thread.
    /// - Remark:
    ///   Possible error codes:
    ///   - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
    ///     accounts are not enabled. Enable them in the Auth section of the
    ///     Firebase console.
    ///   - `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    ///   - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @available(watchOS, unavailable)
    @discardableResult
    public func signIn(withEmail email: String,
                       link: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signIn(withEmail: email, link: link) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Sends a sign in with email link to provided email address.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - email: The email address of the user.
    ///   - actionCodeSettings: An `ActionCodeSettings` object containing settings related to
    ///     handling action codes.
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher will emit on the *main* thread.
    @available(watchOS, unavailable)
    @discardableResult
    public func sendSignInLink(toEmail email: String,
                               actionCodeSettings: ActionCodeSettings) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    //  MARK: - Email-based Authentication Helpers

    /// Fetches the list of all sign-in methods previously used for the provided email address.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter email: The email address for which to obtain a list of sign-in methods.
    /// - Returns: A publisher that emits a list of sign-in methods for the specified email
    ///   address, or an error if one occurred. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    public func fetchSignInMethods(forEmail email: String) -> Future<[String], Error> {
      Future<[String], Error> { promise in
        self.fetchSignInMethods(forEmail: email) { signInMethods, error in
          if let error = error {
            promise(.failure(error))
          } else if let signInMethods = signInMethods {
            promise(.success(signInMethods))
          }
        }
      }
    }

    // MARK: - Password Reset

    /// Resets the password given a code sent to the user outside of the app and a new password for the user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - code: Out-of-band (OOB) code given to the user outside of the app.
    ///   - newPassword: The new password.
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is considered too weak.
    ///   - `AuthErrorCodeOperationNotAllowed` - Indicates the admin disabled sign in with the specified identity provider.
    ///   - `AuthErrorCodeExpiredActionCode` - Indicates the OOB code is expired.
    ///   - `AuthErrorCodeInvalidActionCode` - Indicates the OOB code is invalid.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func confirmPasswordReset(withCode code: String,
                                     newPassword: String) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.confirmPasswordReset(withCode: code, newPassword: newPassword) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Checks the validity of a verify password reset code.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter code: The password reset code to be verified.
    /// - Returns: A publisher that emits an error if the code could not be verified. If the code could be
    ///   verified, the publisher will emit the email address of the account the code was issued for.
    ///   The publisher will emit on the *main* thread.
    @discardableResult
    public func verifyPasswordResetCode(_ code: String) -> Future<String, Error> {
      Future<String, Error> { promise in
        self.verifyPasswordResetCode(code) { email, error in
          if let error = error {
            promise(.failure(error))
          } else if let email = email {
            promise(.success(email))
          }
        }
      }
    }

    /// Checks the validity of an out of band code.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter code: The out of band code to check validity.
    /// - Returns: A publisher that emits the email address of the account the code was issued for or an error if
    ///   the code could not be verified. The publisher will emit on the *main* thread.
    @discardableResult
    public func checkActionCode(code: String) -> Future<ActionCodeInfo, Error> {
      Future<ActionCodeInfo, Error> { promise in
        self.checkActionCode(code) { actionCodeInfo, error in
          if let error = error {
            promise(.failure(error))
          } else if let actionCodeInfo = actionCodeInfo {
            promise(.success(actionCodeInfo))
          }
        }
      }
    }

    /// Applies out of band code.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter code: The out-of-band (OOB) code to be applied.
    /// - Returns: A publisher that emits an error if the code could not be applied. The publisher will emit on the *main* thread.
    /// - Remark: This method will not work for out-of-band codes which require an additional parameter,
    ///   such as password reset codes.
    @discardableResult
    public func applyActionCode(code: String) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.applyActionCode(code) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Initiates a password reset for the given email address.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter email: The email address of the user.
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was sent in the request.
    ///   - `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in the console for this action.
    ///   - `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for sending update email.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func sendPasswordReset(withEmail email: String) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.sendPasswordReset(withEmail: email) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Initiates a password reset for the given email address and `ActionCodeSettings`.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter email: The email address of the user.
    /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
    /// handling action codes.
    /// - Returns: A publisher that emits whether the call was successful or not. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was sent in the request.
    ///   - `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in the console for this action.
    ///   - `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for sending update email.
    ///   - `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing
    ///   when `handleCodeInApp` is set to YES.
    ///   - `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name is missing
    ///   when the `androidInstallApp` flag is set to true.
    ///   - `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the continue URL is not whitelisted
    ///    in the Firebase console.
    ///   - `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the continue URI is not valid.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func sendPasswordReset(withEmail email: String,
                                  actionCodeSettings: ActionCodeSettings) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.sendPasswordReset(withEmail: email, actionCodeSettings: actionCodeSettings) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    // MARK: - Other Authentication providers

    #if os(iOS) || targetEnvironment(macCatalyst)
      /// Signs in using the provided auth provider instance.
      ///
      /// The publisher will emit events on the **main** thread.
      ///
      /// - Parameters:
      ///   - provider: An instance of an auth provider used to initiate the sign-in flow.
      ///   - uiDelegate: Optionally, an instance of a class conforming to the `AuthUIDelegate`
      ///   protocol. This is used for presenting the web context. If `nil`, a default `AuthUIDelegate`
      ///   will be used.
      /// - Returns: A publisher that emits an `AuthDataResult` when the sign-in flow completed
      ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
      /// - Remark: Possible error codes:
      ///   - `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts are not enabled.
      ///     Enable them in the Auth section of the Firebase console.
      ///   - `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
      ///   - `AuthErrorCodeWebNetworkRequestFailed` - Indicates that a network request within a
      ///     `SFSafariViewController` or `WKWebView` failed.
      ///   - `AuthErrorCodeWebInternalError` - Indicates that an internal error occurred within a
      ///     `SFSafariViewController` or `WKWebView`.`
      ///   - `AuthErrorCodeWebSignInUserInteractionFailure` - Indicates a general failure during a web sign-in flow.`
      ///   - `AuthErrorCodeWebContextAlreadyPresented` - Indicates that an attempt was made to present a new web
      ///     context while one was already being presented.`
      ///   - `AuthErrorCodeWebContextCancelled` - Indicates that the URL presentation was cancelled prematurely
      ///     by the user.`
      ///   - `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted by the credential
      ///     (e.g. the email in a Facebook access token) is already in use by an existing account that cannot be
      ///     authenticated with this sign-in method. Call `fetchProvidersForEmail` for this user’s email and then
      ///     prompt them to sign in with any of the sign-in providers returned. This error will only be thrown if
      ///     the "One account per email address" setting is enabled in the Firebase console, under Auth settings.
      ///
      ///   See `AuthErrors` for a list of error codes that are common to all API methods
      @discardableResult
      public func signIn(with provider: FederatedAuthProvider,
                         uiDelegate: AuthUIDelegate?) -> Future<AuthDataResult, Error> {
        Future<AuthDataResult, Error> { promise in
          self.signIn(with: provider, uiDelegate: uiDelegate) { authDataResult, error in
            if let error = error {
              promise(.failure(error))
            } else if let authDataResult = authDataResult {
              promise(.success(authDataResult))
            }
          }
        }
      }
    #endif // os(iOS) || targetEnvironment(macCatalyst)

    /// Asynchronously signs in to Firebase with the given Auth token.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter token: A self-signed custom auth token.
    /// - Returns: A publisher that emits an `AuthDataResult` when the sign-in flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `AuthErrorCodeInvalidCustomToken` - Indicates a validation error with the custom token.
    ///   - `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    ///   - `AuthErrorCodeCustomTokenMismatch` - Indicates the service account and the API key
    ///     belong to different projects.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func signIn(withCustomToken token: String) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signIn(withCustomToken: token) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
    /// login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
    /// identity provider data.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter credential: The credential supplied by the IdP.
    /// - Returns: A publisher that emits an `AuthDataResult` when the sign-in flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `FIRAuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
    ///     This could happen if it has expired or it is malformed.
    ///   - `FIRAuthErrorCodeOperationNotAllowed` - Indicates that accounts
    ///     with the identity provider represented by the credential are not enabled.
    ///     Enable them in the Auth section of the Firebase console.
    ///   - `FIRAuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
    ///     by the credential (e.g. the email in a Facebook access token) is already in use by an
    ///     existing account, that cannot be authenticated with this sign-in method. Call
    ///     fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
    ///     the sign-in providers returned. This error will only be thrown if the "One account per
    ///     email address" setting is enabled in the Firebase console, under Auth settings.
    ///   - `FIRAuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    ///   - `FIRAuthErrorCodeWrongPassword` - Indicates the user attempted sign in with an
    ///     incorrect password, if credential is of the type EmailPasswordAuthCredential.
    ///   - `FIRAuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///   - `FIRAuthErrorCodeMissingVerificationID` - Indicates that the phone auth credential was
    ///     created with an empty verification ID.
    ///   - `FIRAuthErrorCodeMissingVerificationCode` - Indicates that the phone auth credential
    ///     was created with an empty verification code.
    ///   - `FIRAuthErrorCodeInvalidVerificationCode` - Indicates that the phone auth credential
    ///     was created with an invalid verification Code.
    ///   - `FIRAuthErrorCodeInvalidVerificationID` - Indicates that the phone auth credential was
    ///     created with an invalid verification ID.
    ///   - `FIRAuthErrorCodeSessionExpired` - Indicates that the SMS code has expired.
    ///
    ///   See `AuthErrors` for a list of error codes that are common to all API methods
    @discardableResult
    public func signIn(with credential: AuthCredential) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.signIn(with: credential) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }
  }

#endif // canImport(Combine) && swift(>=5.0)
