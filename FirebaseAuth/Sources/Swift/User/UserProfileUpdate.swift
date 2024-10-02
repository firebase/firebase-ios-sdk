// Copyright 2024 Google LLC
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

/// Actor to serialize the update profile calls.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
actor UserProfileUpdate {
  func link(user: User, with credential: AuthCredential) async throws -> AuthDataResult {
    let accessToken = try await user.internalGetTokenAsync()
    let request = VerifyAssertionRequest(providerID: credential.provider,
                                         requestConfiguration: user.requestConfiguration)
    credential.prepare(request)
    request.accessToken = accessToken
    do {
      let response = try await AuthBackend.call(with: request)
      guard let idToken = response.idToken,
            let refreshToken = response.refreshToken,
            let providerID = response.providerID else {
        fatalError("Internal Auth Error: missing token in EmailLinkSignInResponse")
      }
      try await updateTokenAndRefreshUser(user: user,
                                          idToken: idToken,
                                          refreshToken: refreshToken,
                                          expirationDate: response.approximateExpirationDate)
      let updatedOAuthCredential = OAuthCredential(withVerifyAssertionResponse: response)
      let additionalUserInfo = AdditionalUserInfo(providerID: providerID,
                                                  profile: response.profile,
                                                  username: response.username,
                                                  isNewUser: response.isNewUser)
      return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo,
                            credential: updatedOAuthCredential)
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
  }

  func unlink(user: User, fromProvider provider: String) async throws -> User {
    let accessToken = try await user.internalGetTokenAsync()
    let request = SetAccountInfoRequest(requestConfiguration: user.requestConfiguration)
    request.accessToken = accessToken

    if user.providerDataRaw[provider] == nil {
      throw AuthErrorUtils.noSuchProviderError()
    }
    request.deleteProviders = [provider]
    do {
      let response = try await AuthBackend.call(with: request)

      // We can't just use the provider info objects in SetAccountInfoResponse
      // because they don't have localID and email fields. Remove the specific
      // provider manually.
      user.providerDataRaw.removeValue(forKey: provider)

      if provider == EmailAuthProvider.id {
        user.hasEmailPasswordCredential = false
      }
      #if os(iOS)
        // After successfully unlinking a phone auth provider, remove the phone number
        // from the cached user info.
        if provider == PhoneAuthProvider.id {
          user.phoneNumber = nil
        }
      #endif
      if let idToken = response.idToken,
         let refreshToken = response.refreshToken {
        let tokenService = SecureTokenService(
          withRequestConfiguration: user.requestConfiguration,
          accessToken: idToken,
          accessTokenExpirationDate: response.approximateExpirationDate,
          refreshToken: refreshToken
        )
        try await setTokenService(user: user, tokenService: tokenService)
        return user
      }
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }

    if let error = user.updateKeychain() {
      throw error
    }
    return user
  }

  /// Performs a setAccountInfo request by mutating the results of a getAccountInfo response,
  /// atomically in regards to other calls to this method.
  /// - Parameter changeBlock: A block responsible for mutating a template `SetAccountInfoRequest`
  func executeUserUpdateWithChanges(user: User,
                                    changeBlock: @escaping (GetAccountInfoResponseUser,
                                                            SetAccountInfoRequest)
                                      -> Void) async throws {
    let userAccountInfo = try await getAccountInfoRefreshingCache(user)
    let accessToken = try await user.internalGetTokenAsync()

    // Mutate setAccountInfoRequest in block
    let setAccountInfoRequest =
      SetAccountInfoRequest(requestConfiguration: user.requestConfiguration)
    setAccountInfoRequest.accessToken = accessToken
    changeBlock(userAccountInfo, setAccountInfoRequest)
    do {
      let accountInfoResponse = try await AuthBackend.call(with: setAccountInfoRequest)
      if let idToken = accountInfoResponse.idToken,
         let refreshToken = accountInfoResponse.refreshToken {
        let tokenService = SecureTokenService(
          withRequestConfiguration: user.requestConfiguration,
          accessToken: idToken,
          accessTokenExpirationDate: accountInfoResponse.approximateExpirationDate,
          refreshToken: refreshToken
        )
        try await setTokenService(user: user, tokenService: tokenService)
      }
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
  }

  // Update the new token and refresh user info again.
  func updateTokenAndRefreshUser(user: User,
                                 idToken: String,
                                 refreshToken: String,
                                 expirationDate: Date?) async throws {
    user.tokenService = SecureTokenService(
      withRequestConfiguration: user.requestConfiguration,
      accessToken: idToken,
      accessTokenExpirationDate: expirationDate,
      refreshToken: refreshToken
    )
    let accessToken = try await user.internalGetTokenAsync()
    let getAccountInfoRequest = GetAccountInfoRequest(
      accessToken: accessToken,
      requestConfiguration: user.requestConfiguration
    )
    do {
      let response = try await AuthBackend.call(with: getAccountInfoRequest)
      user.isAnonymous = false
      user.update(withGetAccountInfoResponse: response)
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
    if let error = user.updateKeychain() {
      throw error
    }
  }

  /// Sets a new token service for the `User` instance.
  ///
  /// The method makes sure the token service has access and refresh token and the new tokens
  /// are saved in the keychain before calling back.
  /// - Parameter tokenService: The new token service object.
  /// - Parameter callback: The block to be called in the global auth working queue once finished.
  func setTokenService(user: User, tokenService: SecureTokenService) async throws {
    _ = try await tokenService.fetchAccessToken(forcingRefresh: false)
    user.tokenService = tokenService
    if let error = user.updateKeychain() {
      throw error
    }
  }

  /// Gets the users' account data from the server, updating our local values.
  /// - Parameter callback: Invoked when the request to getAccountInfo has completed, or when an
  /// error has been detected. Invoked asynchronously on the auth global work queue in the future.
  func getAccountInfoRefreshingCache(_ user: User) async throws
    -> GetAccountInfoResponseUser {
    let token = try await user.internalGetTokenAsync()
    let request = GetAccountInfoRequest(accessToken: token,
                                        requestConfiguration: user.requestConfiguration)
    do {
      let accountInfoResponse = try await AuthBackend.call(with: request)
      user.update(withGetAccountInfoResponse: accountInfoResponse)
      if let error = user.updateKeychain() {
        throw error
      }
      return (accountInfoResponse.users?.first)!
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
  }
}
