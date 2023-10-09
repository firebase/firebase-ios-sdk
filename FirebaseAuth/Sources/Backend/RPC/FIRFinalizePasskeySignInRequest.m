/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeySignInRequest.h"
NS_ASSUME_NONNULL_BEGIN

/**
 @var kFinalizePasskeySignInEndPoint
 @brief GCIP endpoint for finalizePasskeySignIn rpc
 */
static NSString *const kFinalizePasskeySignInEndPoint = @"accounts/passkeySignIn:finalize";

/**
 @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

/**
 @var kAuthenticatorAuthRespKey
 @brief The key for authentication response object from the authenticator.
 */
static NSString *const kAuthenticatorAuthRespKey = @"authenticatorAuthenticationResponse";

/**
 @var kCredentialIDKey
 @brief The key for registered credential identifier.
 */
static NSString *const kCredentialIDKey = @"credentialId";

/**
 @var kAuthAssertionRespKey
 @brief The key for authentication assertion from the authenticator.
 */
static NSString *const kAuthAssertionRespKey = @"authenticatorAssertionResponse";

/**
 @var kClientDataJsonKey
 @brief The key for CollectedClientData object from the authenticator.
 */
static NSString *const kClientDataJsonKey = @"clientDataJson";

/**
 @var kAuthenticatorDataKey
 @brief The key for authenticatorData from the authenticator.
 */
static NSString *const kAuthenticatorDataKey = @"authenticatorData";

/**
 @var kSignatureKey
 @brief The key for the signature from the authenticator.
 */
static NSString *const kSignatureKey = @"signature";

/**
 @var kUserHandleKey
 @brief The key for the user handle. This is the same as user ID.
 */
static NSString *const kUserHandleKey = @"userHandle";

@implementation FIRFinalizePasskeySignInRequest

- (nullable instancetype)initWithCredentialID:(NSString *)credentialID
                               clientDataJson:(NSString *)clientDataJson
                            authenticatorData:(NSString *)authenticatorData
                                    signature:(NSString *)signature
                                       userID:(NSString *)userID
                         requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kFinalizePasskeySignInEndPoint
            requestConfiguration:requestConfiguration];
  if (self) {
    self.useIdentityPlatform = YES;
    _credentialID = credentialID;
    _clientDataJson = clientDataJson;
    _authenticatorData = authenticatorData;
    _signature = signature;
    _userID = userID;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  NSMutableDictionary *authenticatorAuthResponse = [NSMutableDictionary dictionary];
  NSMutableDictionary *authAssertionResponse = [NSMutableDictionary dictionary];

  if (self.tenantID) {
    postBody[kTenantIDKey] = self.tenantID;
  }

  if (_credentialID) {
    authenticatorAuthResponse[kCredentialIDKey] = _credentialID;
  }

  if (_clientDataJson) {
    authAssertionResponse[kClientDataJsonKey] = _clientDataJson;
  }

  if (_authenticatorData) {
    authAssertionResponse[kAuthenticatorDataKey] = _authenticatorData;
  }

  if (_signature) {
    authAssertionResponse[kSignatureKey] = _signature;
  }

  if (_userID) {
    authAssertionResponse[kUserHandleKey] = _userID;
  }

  authenticatorAuthResponse[kAuthAssertionRespKey] = authAssertionResponse;
  postBody[kAuthenticatorAuthRespKey] = authenticatorAuthResponse;

  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
