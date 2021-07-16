// Copyright 2021 Google LLC
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
  extension User {
    /// Associates a user account from a third-party identity provider with this user and
    /// returns additional identity provider data.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter credential: The credential for the identity provider.
    /// - Returns: A publisher that emits an `AuthDataResult` when the association flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    /// - Remark: Possible error codes:
    ///   - `FIRAuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a type
    ///     already linked to this account.
    ///   - `FIRAuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a credential
    ///     that has already been linked with a different Firebase account.
    ///   - `FIRAuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity provider
    ///     represented by the credential are not enabled. Enable them in the Auth section of the Firebase console.
    ///
    ///   See `FIRAuthErrors` for a list of error codes that are common to all FIRUser methods.
    public func link(with credential: AuthCredential) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.link(with: credential) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Renews the user's authentication tokens by validating a fresh set of credentials supplied
    /// by the user and returns additional identity provider data.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter credential: A user-supplied credential, which will be validated by the server. This can be
    ///   a successful third-party identity provider sign-in, or an email address and password.
    /// - Returns: A publisher that emits an `AuthDataResult` when the reauthentication flow completed
    ///   successfully, or an error otherwise.
    /// - Remark: If the user associated with the supplied credential is different from the current user, or if the validation
    ///   of the supplied credentials fails; an error is returned and the current user remains signed in.
    ///
    ///   Possible error codes:
    ///
    ///   - `FIRAuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
    ///     This could happen if it has expired or it is malformed.
    ///   - `FIRAuthErrorCodeOperationNotAllowed` - Indicates that accounts with the
    ///     identity provider represented by the credential are not enabled. Enable them in the
    ///     Auth section of the Firebase console.
    ///   - `FIRAuthErrorCodeEmailAlreadyInUse` -  Indicates the email asserted by the credential
    ///     (e.g. the email in a Facebook access token) is already in use by an existing account,
    ///     that cannot be authenticated with this method. Call fetchProvidersForEmail for
    ///     this user’s email and then prompt them to sign in with any of the sign-in providers
    ///     returned. This error will only be thrown if the "One account per email address"
    ///     setting is enabled in the Firebase console, under Auth settings. Please note that the
    ///     error code raised in this specific situation may not be the same on Web and Android.
    ///   - `FIRAuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    ///   - `FIRAuthErrorCodeWrongPassword` - Indicates the user attempted reauthentication with
    ///     an incorrect password, if credential is of the type EmailPasswordAuthCredential.
    ///   - `FIRAuthErrorCodeUserMismatch` -  Indicates that an attempt was made to
    ///     reauthenticate with a user which is not the current user.
    ///   - `FIRAuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
    ///
    ///   See `FIRAuthErrors` for a list of error codes that are common to all FIRUser methods.
    public func reauthenticate(with credential: AuthCredential) -> Future<AuthDataResult, Error> {
      Future<AuthDataResult, Error> { promise in
        self.reauthenticate(with: credential) { authDataResult, error in
          if let error = error {
            promise(.failure(error))
          } else if let authDataResult = authDataResult {
            promise(.success(authDataResult))
          }
        }
      }
    }

    /// Disassociates a user account from a third-party identity provider with this user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter provider: The provider ID of the provider to unlink.
    /// - Returns: A publisher that emits a `User` when the disassociation flow completed
    ///   successfully, or an error otherwise. The publisher will emit on the *main* thread.
    ///
    ///   Possible error codes:
    ///
    ///   - `FIRAuthErrorCodeNoSuchProvider` - Indicates an attempt to unlink a provider
    ///      that is not linked to the account.
    ///   - `FIRAuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
    ///      operation that requires a recent login from the user. This error indicates the user
    ///      has not signed in recently enough. To resolve, reauthenticate the user by invoking
    ///      reauthenticateWithCredential:completion: on `FIRUser`.
    ///
    ///   See `FIRAuthErrors` for a list of error codes that are common to all `FIRUser` methods.
    public func unlink(fromProvider provider: String) -> Future<User, Error> {
      Future<User, Error> { promise in
        self.unlink(fromProvider: provider) { user, error in
          if let user = user {
            promise(.success(user))
          } else if let error = error {
            promise(.failure(error))
          }
        }
      }
    }

    /// Initiates email verification for the user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Returns: A publisher that emits no type when the verification flow completed
    ///   successfully, or an error otherwise.
    ///
    ///   Possible error codes:
    ///
    ///   - `FIRAuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
    ///      sent in the request.
    ///   - `FIRAuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
    ///      the console for this action.
    ///   - `FIRAuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
    ///      sending update email.
    ///   - `FIRAuthErrorCodeUserNotFound` - Indicates the user account was not found.
    ///
    ///   See `FIRAuthErrors` for a list of error codes that are common to all `FIRUser` methods.
    public func sendEmailVerification() -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.sendEmailVerification { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }

    /// Initiates email verification for the user.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameter actionCodeSettings: An `FIRActionCodeSettings` object containing settings related to
    ///   handling action codes.
    /// - Returns: A publisher that emits no type when the verification flow completed
    ///   successfully, or an error otherwise.
    ///
    ///   Possible error codes:
    ///
    ///   -  `FIRAuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
    ///    sent in the request.
    ///   - `FIRAuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
    ///    the console for this action.
    ///   - `FIRAuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
    ///    sending update email.
    ///   - `FIRAuthErrorCodeUserNotFound` - Indicates the user account was not found.
    ///   - `FIRAuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
    ///    a iOS App Store ID is provided.
    ///   - `FIRAuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
    ///    is missing when the `androidInstallApp` flag is set to true.
    ///   - `FIRAuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
    ///    continue URL is not allowlisted in the Firebase console.
    ///   - `FIRAuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
    ///    continue URI is not valid.
    public func sendEmailVerification(with actionCodeSettings: ActionCodeSettings)
      -> Future<Void, Error> {
      Future<Void, Error> { promise in
        self.sendEmailVerification(with: actionCodeSettings) { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }
  }

#endif // canImport(Combine) && swift(>=5.0)
