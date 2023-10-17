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

#import "FirebaseAuth/Sources/Backend/RPC/FIRFinalizePasskeyEnrollmentRequest.h"
NS_ASSUME_NONNULL_BEGIN

/**
 @var kFinalizePasskeyEnrollmentEndPoint
 @brief GCIP endpoint for finalizePasskeyEnrollment rpc
 */
static NSString *const kFinalizePasskeyEnrollmentEndPoint = @"accounts/passkeyEnrollment:finalize";

/**
 @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

/**
 @var kIDTokenKey
 @brief The key for idToken value in the request.
 */
static NSString *const kIDTokenKey = @"idToken";

/**
 @var kAuthRegistrationRespKey
 @brief The key for registration object from the authenticator.
 */
static NSString *const kAuthRegistrationRespKey = @"authenticatorRegistrationResponse";

/**
 @var kNameKey
 @brief The key of passkey name.
 */
static NSString *const kNameKey = @"name";

/**
 @var kCredentialIDKey
 @brief The key for registered credential identifier.
 */
static NSString *const kCredentialIDKey = @"id";

/**
 @var kAuthAttestationRespKey
 @brief The key for attestation response from a FIDO authenticator.
 */
static NSString *const kAuthAttestationRespKey = @"response";

/**
 @var kClientDataJsonKey
 @brief The key for CollectedClientData object from the authenticator.
 */
static NSString *const kClientDataJsonKey = @"clientDataJSON";

/**
 @var kAttestationObject
 @brief The key for the attestation object from the authenticator.
 */
static NSString *const kAttestationObject = @"attestationObject";

@implementation FIRFinalizePasskeyEnrollmentRequest

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                                    name:(NSString *)name
                            credentialID:(NSString *)credentialID
                          clientDataJson:(NSString *)clientDataJson
                       attestationObject:(NSString *)attestationObject
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kFinalizePasskeyEnrollmentEndPoint
            requestConfiguration:requestConfiguration];
  if (self) {
    self.useIdentityPlatform = YES;
    self.useStaging = NO;
    _IDToken = IDToken;
    _name = name;
    _credentialID = credentialID;
    _clientDataJson = clientDataJson;
    _attestationObject = attestationObject;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  NSMutableDictionary *authRegistrationResponse = [NSMutableDictionary dictionary];
  NSMutableDictionary *authAttestationResponse = [NSMutableDictionary dictionary];

  if (_IDToken) {
    postBody[kIDTokenKey] = _IDToken;
  }
  if (_name) {
    postBody[kNameKey] = _name;
  }
  if (_credentialID) {
    authRegistrationResponse[kCredentialIDKey] = _credentialID;
  }
  if (_clientDataJson) {
    authAttestationResponse[kClientDataJsonKey] = _clientDataJson;
  }
  if (_attestationObject) {
    authAttestationResponse[kAttestationObject] = _attestationObject;
  }
  if (self.tenantID) {
    postBody[kTenantIDKey] = self.tenantID;
  }

  authRegistrationResponse[kAuthAttestationRespKey] = authAttestationResponse;
  postBody[kAuthRegistrationRespKey] = authRegistrationResponse;

  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
