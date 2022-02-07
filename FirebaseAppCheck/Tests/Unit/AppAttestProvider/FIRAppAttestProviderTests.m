/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppAttestProvider.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAttestationResponse.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/FIRAppAttestService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"
#import "FirebaseAppCheck/Sources/Core/Utils/FIRAppCheckCryptoUtils.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/Errors/FIRAppAttestRejectionError.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckHTTPError.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

#import "SharedTestUtilities/AppCheckBackoffWrapperFake/FIRAppCheckBackoffWrapperFake.h"

#if FIR_APP_ATTEST_SUPPORTED_TARGETS

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppAttestProvider (Tests)
- (instancetype)initWithAppAttestService:(id<FIRAppAttestService>)appAttestService
                              APIService:(id<FIRAppAttestAPIServiceProtocol>)APIService
                            keyIDStorage:(id<FIRAppAttestKeyIDStorageProtocol>)keyIDStorage
                         artifactStorage:(id<FIRAppAttestArtifactStorageProtocol>)artifactStorage
                          backoffWrapper:(id<FIRAppCheckBackoffWrapperProtocol>)backoffWrapper;
@end

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
@interface FIRAppAttestProviderTests : XCTestCase

@property(nonatomic) FIRAppAttestProvider *provider;

@property(nonatomic) OCMockObject<FIRAppAttestService> *mockAppAttestService;
@property(nonatomic) OCMockObject<FIRAppAttestAPIServiceProtocol> *mockAPIService;
@property(nonatomic) OCMockObject<FIRAppAttestKeyIDStorageProtocol> *mockStorage;
@property(nonatomic) OCMockObject<FIRAppAttestArtifactStorageProtocol> *mockArtifactStorage;

@property(nonatomic) NSData *randomChallenge;
@property(nonatomic) NSData *randomChallengeHash;

@property(nonatomic) FIRAppCheckBackoffWrapperFake *fakeBackoffWrapper;

@end

@implementation FIRAppAttestProviderTests

- (void)setUp {
  [super setUp];

  self.mockAppAttestService = OCMProtocolMock(@protocol(FIRAppAttestService));
  self.mockAPIService = OCMProtocolMock(@protocol(FIRAppAttestAPIServiceProtocol));
  self.mockStorage = OCMProtocolMock(@protocol(FIRAppAttestKeyIDStorageProtocol));
  self.mockArtifactStorage = OCMProtocolMock(@protocol(FIRAppAttestArtifactStorageProtocol));

  self.fakeBackoffWrapper = [[FIRAppCheckBackoffWrapperFake alloc] init];
  // Don't backoff by default.
  self.fakeBackoffWrapper.isNextOperationAllowed = YES;

  self.provider = [[FIRAppAttestProvider alloc] initWithAppAttestService:self.mockAppAttestService
                                                              APIService:self.mockAPIService
                                                            keyIDStorage:self.mockStorage
                                                         artifactStorage:self.mockArtifactStorage
                                                          backoffWrapper:self.fakeBackoffWrapper];

  self.randomChallenge = [@"random challenge" dataUsingEncoding:NSUTF8StringEncoding];
  self.randomChallengeHash =
      [[NSData alloc] initWithBase64EncodedString:@"vEq8yE9g+WwfifNqC2wsXN9M3NIDeOKpDBVYLpGbUDY="
                                          options:0];
}

- (void)tearDown {
  self.provider = nil;
  self.mockArtifactStorage = nil;
  self.mockStorage = nil;
  self.mockAPIService = nil;
  self.mockAppAttestService = nil;
  self.fakeBackoffWrapper = nil;
}

#pragma mark - Init tests

#if !TARGET_OS_MACCATALYST
// Keychain dependent logic require additional configuration on Catalyst (enabling Keychain
// sharing). For now, keychain dependent tests are disabled for Catalyst.
- (void)testInitWithValidApp {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"app_id" GCMSenderID:@"sender_id"];
  options.APIKey = @"api_key";
  options.projectID = @"project_id";
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:@"testInitWithValidApp" options:options];

  XCTAssertNotNil([[FIRAppAttestProvider alloc] initWithApp:app]);
}
#endif  // !TARGET_OS_MACCATALYST

#pragma mark - Initial handshake (attestation)

- (void)testGetTokenWhenAppAttestIsNotSupported {
  NSError *expectedError =
      [FIRAppCheckErrorUtil unsupportedAttestationProvider:@"AppAttestProvider"];

  // 0.1. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 0.2. Expect default error handler to be used.
  XCTestExpectation *errorHandlerExpectation = [self expectationWithDescription:@"Error handler"];
  self.fakeBackoffWrapper.defaultErrorHandler = ^FIRAppCheckBackoffType(NSError *_Nonnull error) {
    XCTAssertEqualObjects(error, expectedError);
    [errorHandlerExpectation fulfill];
    return FIRAppCheckBackoffType1Day;
  };

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(NO)];

  // 2. Don't expect other operations.
  OCMReject([self.mockStorage getAppAttestKeyID]);
  OCMReject([self.mockAppAttestService generateKeyWithCompletionHandler:OCMOCK_ANY]);
  OCMReject([self.mockArtifactStorage getArtifactForKey:OCMOCK_ANY]);
  OCMReject([self.mockAPIService getRandomChallenge]);
  OCMReject([self.mockStorage setAppAttestKeyID:OCMOCK_ANY]);
  OCMReject([self.mockAppAttestService attestKey:OCMOCK_ANY
                                  clientDataHash:OCMOCK_ANY
                               completionHandler:OCMOCK_ANY]);
  OCMReject([self.mockAPIService attestKeyWithAttestation:OCMOCK_ANY
                                                    keyID:OCMOCK_ANY
                                                challenge:OCMOCK_ANY]);

  // 3. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, expectedError);
      }];

  [self waitForExpectations:@[
    self.fakeBackoffWrapper.backoffExpectation, errorHandlerExpectation, completionExpectation
  ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify mocks.
  [self verifyAllMocks];
}

- (void)testGetToken_WhenNoExistingKey_Success {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  NSError *error = [NSError errorWithDomain:@"testGetToken_WhenNoExistingKey_Success"
                                       code:NSNotFound
                                   userInfo:nil];
  [rejectedPromise reject:error];
  OCMExpect([self.mockStorage getAppAttestKeyID]).andReturn(rejectedPromise);

  // 3. Expect App Attest key to be generated.
  NSString *generatedKeyID = @"generatedKeyID";
  id completionArg = [OCMArg invokeBlockWithArgs:generatedKeyID, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService generateKeyWithCompletionHandler:completionArg]);

  // 4. Expect the key ID to be stored.
  OCMExpect([self.mockStorage setAppAttestKeyID:generatedKeyID])
      .andReturn([FBLPromise resolvedWith:generatedKeyID]);

  // 5. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 6. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  id attestCompletionArg = [OCMArg invokeBlockWithArgs:attestationData, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService attestKey:generatedKeyID
                                  clientDataHash:self.randomChallengeHash
                               completionHandler:attestCompletionArg]);

  // 7. Expect key attestation request to be sent.
  FIRAppCheckToken *FACToken = [[FIRAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[FIRAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:FACToken];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData
                                                    keyID:generatedKeyID
                                                challenge:self.randomChallenge])
      .andReturn([FBLPromise resolvedWith:attestKeyResponse]);

  // 8. Expect the artifact received from Firebase backend to be saved.
  OCMExpect([self.mockArtifactStorage setArtifact:artifactData forKey:generatedKeyID])
      .andReturn([FBLPromise resolvedWith:artifactData]);

  // 9. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 10. Verify mocks.
  [self verifyAllMocks];

  // 11. Verify backoff result.
  XCTAssertEqualObjects(((FIRAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)testGetToken_WhenExistingUnregisteredKey_Success {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Don't expect App Attest key to be generated.
  OCMReject([self.mockAppAttestService generateKeyWithCompletionHandler:OCMOCK_ANY]);

  // 4. Don't expect the key ID to be stored.
  OCMReject([self.mockStorage setAppAttestKeyID:OCMOCK_ANY]);

  // 5. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID]).andReturn(rejectedPromise);

  // 6. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 7. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  id attestCompletionArg = [OCMArg invokeBlockWithArgs:attestationData, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService attestKey:existingKeyID
                                  clientDataHash:self.randomChallengeHash
                               completionHandler:attestCompletionArg]);

  // 8. Expect key attestation request to be sent.
  FIRAppCheckToken *FACToken = [[FIRAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[FIRAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:FACToken];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData
                                                    keyID:existingKeyID
                                                challenge:self.randomChallenge])
      .andReturn([FBLPromise resolvedWith:attestKeyResponse]);

  // 9. Expect the artifact received from Firebase backend to be saved.
  OCMExpect([self.mockArtifactStorage setArtifact:artifactData forKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:artifactData]);

  // 10. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 11. Verify mocks.
  [self verifyAllMocks];

  // 12. Verify backoff result.
  XCTAssertEqualObjects(((FIRAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)testGetToken_WhenUnregisteredKeyAndRandomChallengeError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID]).andReturn(rejectedPromise);

  // 4. Expect random challenge to be requested.
  NSError *challengeError = [self expectRandomChallengeRequestError];

  // 5. Don't expect other steps.
  OCMReject([self.mockStorage setAppAttestKeyID:OCMOCK_ANY]);
  OCMReject([self.mockAppAttestService attestKey:OCMOCK_ANY
                                  clientDataHash:OCMOCK_ANY
                               completionHandler:OCMOCK_ANY]);
  OCMReject([self.mockAPIService attestKeyWithAttestation:OCMOCK_ANY
                                                    keyID:OCMOCK_ANY
                                                challenge:OCMOCK_ANY]);

  // 6. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, challengeError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 7. Verify mocks.
  [self verifyAllMocks];

  // 8. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, challengeError);
}

- (void)testGetToken_WhenUnregisteredKeyAndKeyAttestationError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID]).andReturn(rejectedPromise);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Expect the key to be attested with the challenge.
  NSError *attestationError = [NSError errorWithDomain:@"testGetTokenWhenKeyAttestationError"
                                                  code:0
                                              userInfo:nil];
  id attestCompletionArg = [OCMArg invokeBlockWithArgs:[NSNull null], attestationError, nil];
  OCMExpect([self.mockAppAttestService attestKey:existingKeyID
                                  clientDataHash:self.randomChallengeHash
                               completionHandler:attestCompletionArg]);

  // 6. Don't exchange API request.
  OCMReject([self.mockAPIService attestKeyWithAttestation:OCMOCK_ANY
                                                    keyID:OCMOCK_ANY
                                                challenge:OCMOCK_ANY]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, attestationError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 8. Verify mocks.
  [self verifyAllMocks];

  // 9. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, attestationError);
}

- (void)testGetToken_WhenUnregisteredKeyAndKeyAttestationExchangeError {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  __auto_type rejectedPromise = [self rejectedPromiseWithError:[NSError errorWithDomain:self.name
                                                                                   code:NSNotFound
                                                                               userInfo:nil]];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID]).andReturn(rejectedPromise);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Expect the key to be attested with the challenge.
  NSData *attestationData = [@"attestation data" dataUsingEncoding:NSUTF8StringEncoding];
  id attestCompletionArg = [OCMArg invokeBlockWithArgs:attestationData, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService attestKey:existingKeyID
                                  clientDataHash:self.randomChallengeHash
                               completionHandler:attestCompletionArg]);

  // 6. Expect exchange request to be sent.
  NSError *exchangeError = [NSError errorWithDomain:@"testGetTokenWhenKeyAttestationExchangeError"
                                               code:0
                                           userInfo:nil];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData
                                                    keyID:existingKeyID
                                                challenge:self.randomChallenge])
      .andReturn([self rejectedPromiseWithError:exchangeError]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, exchangeError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 8. Verify mocks.
  [self verifyAllMocks];

  // 9. Verify backoff error.
  XCTAssertEqualObjects(self.fakeBackoffWrapper.operationError, exchangeError);
}

#pragma mark Rejected Attestation

- (void)testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceSuccess {
  // 1. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 2. Expect the App Attest key pair to be generated and attested.
  NSString *keyID1 = @"keyID1";
  NSData *attestationData1 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID1 attestationData:attestationData1];

  // 3. Expect exchange request to be sent.
  FIRAppCheckHTTPError *APIError = [self attestationRejectionHTTPError];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData1
                                                    keyID:keyID1
                                                challenge:self.randomChallenge])
      .andReturn([self rejectedPromiseWithError:APIError]);

  // 4. Stored attestation to be reset.
  [self expectAttestationReset];

  // 5. Expect the App Attest key pair to be generated and attested.
  NSString *keyID2 = @"keyID2";
  NSData *attestationData2 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID2 attestationData:attestationData2];

  // 6. Expect exchange request to be sent.
  FIRAppCheckToken *FACToken = [[FIRAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  NSData *artifactData = [@"attestation artifact" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type attestKeyResponse =
      [[FIRAppAttestAttestationResponse alloc] initWithArtifact:artifactData token:FACToken];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData2
                                                    keyID:keyID2
                                                challenge:self.randomChallenge])
      .andReturn([FBLPromise resolvedWith:attestKeyResponse]);

  // 7. Expect the artifact received from Firebase backend to be saved.
  OCMExpect([self.mockArtifactStorage setArtifact:artifactData forKey:keyID2])
      .andReturn([FBLPromise resolvedWith:artifactData]);

  // 8. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5 enforceOrder:YES];

  // 8. Verify mocks.
  [self verifyAllMocks];
}

- (void)testGetToken_WhenAttestationIsRejected_ThenAttestationIsResetAndRetriedOnceError {
  // 1. Expect App Attest availability to be requested and stored key ID request to fail.
  [self expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested];

  // 2. Expect the App Attest key pair to be generated and attested.
  NSString *keyID1 = @"keyID1";
  NSData *attestationData1 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID1 attestationData:attestationData1];

  // 3. Expect exchange request to be sent.
  FIRAppCheckHTTPError *APIError = [self attestationRejectionHTTPError];
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData1
                                                    keyID:keyID1
                                                challenge:self.randomChallenge])
      .andReturn([self rejectedPromiseWithError:APIError]);

  // 4. Stored attestation to be reset.
  [self expectAttestationReset];

  // 5. Expect the App Attest key pair to be generated and attested.
  NSString *keyID2 = @"keyID2";
  NSData *attestationData2 = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  [self expectAppAttestKeyGeneratedAndAttestedWithKeyID:keyID2 attestationData:attestationData2];

  // 6. Expect exchange request to be sent.
  OCMExpect([self.mockAPIService attestKeyWithAttestation:attestationData2
                                                    keyID:keyID2
                                                challenge:self.randomChallenge])
      .andReturn([self rejectedPromiseWithError:APIError]);

  // 7. Stored attestation to be reset.
  [self expectAttestationReset];

  // 8. Don't expect the artifact received from Firebase backend to be saved.
  OCMReject([self.mockArtifactStorage setArtifact:OCMOCK_ANY forKey:OCMOCK_ANY]);

  // 9. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        FIRAppAttestRejectionError *expectedError = [[FIRAppAttestRejectionError alloc] init];
        XCTAssertEqualObjects(error, expectedError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5 enforceOrder:YES];

  // 9. Verify mocks.
  [self verifyAllMocks];
}

#pragma mark - FAC token refresh (assertion)

- (void)testGetToken_WhenKeyRegistered_Success {
  [self assertGetToken_WhenKeyRegistered_Success];
}

- (void)testGetToken_WhenKeyRegisteredAndChallengeRequestError {
  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  NSError *challengeError = [self expectRandomChallengeRequestError];

  // 5. Don't expect assertion to be requested.
  OCMReject([self.mockAppAttestService generateAssertion:OCMOCK_ANY
                                          clientDataHash:OCMOCK_ANY
                                       completionHandler:OCMOCK_ANY]);

  // 6. Don't expect assertion request to be sent.
  OCMReject([self.mockAPIService getAppCheckTokenWithArtifact:OCMOCK_ANY
                                                    challenge:OCMOCK_ANY
                                                    assertion:OCMOCK_ANY]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, challengeError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  [self verifyAllMocks];
}

- (void)testGetToken_WhenKeyRegisteredAndGenerateAssertionError {
  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Don't expect assertion to be requested.
  NSError *generateAssertionError =
      [NSError errorWithDomain:@"testGetToken_WhenKeyRegisteredAndGenerateAssertionError"
                          code:0
                      userInfo:nil];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:[NSNull null], generateAssertionError, nil];
  OCMExpect([self.mockAppAttestService
      generateAssertion:existingKeyID
         clientDataHash:[self dataHashForAssertionWithArtifactData:storedArtifact]
      completionHandler:completionBlockArg]);

  // 6. Don't expect assertion request to be sent.
  OCMReject([self.mockAPIService getAppCheckTokenWithArtifact:OCMOCK_ANY
                                                    challenge:OCMOCK_ANY
                                                    assertion:OCMOCK_ANY]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, generateAssertionError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  [self verifyAllMocks];
}

- (void)testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError {
  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Don't expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:assertion, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService
      generateAssertion:existingKeyID
         clientDataHash:[self dataHashForAssertionWithArtifactData:storedArtifact]
      completionHandler:completionBlockArg]);

  // 6. Expect assertion request to be sent.
  NSError *tokenExchangeError =
      [NSError errorWithDomain:@"testGetToken_WhenKeyRegisteredAndTokenExchangeRequestError"
                          code:0
                      userInfo:nil];
  OCMExpect([self.mockAPIService getAppCheckTokenWithArtifact:storedArtifact
                                                    challenge:self.randomChallenge
                                                    assertion:assertion])
      .andReturn([self rejectedPromiseWithError:tokenExchangeError]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, tokenExchangeError);
      }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];

  // 8. Verify mocks.
  [self verifyAllMocks];
}

#pragma mark - Request merging

- (void)testGetToken_WhenCalledSeveralTimesSuccess_ThenThereIsOnlyOneOngoingHandshake {
  // 0. Expect backoff wrapper to be used only once.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  // 4.1. Create a pending promise to fulfill later.
  FBLPromise<NSData *> *challengeRequestPromise = [FBLPromise pendingPromise];
  // 4.2. Stub getRandomChallenge method.
  OCMExpect([self.mockAPIService getRandomChallenge]).andReturn(challengeRequestPromise);

  // 5. Expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:assertion, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService
      generateAssertion:existingKeyID
         clientDataHash:[self dataHashForAssertionWithArtifactData:storedArtifact]
      completionHandler:completionBlockArg]);

  // 6. Expect assertion request to be sent.
  FIRAppCheckToken *FACToken = [[FIRAppCheckToken alloc] initWithToken:@"FAC token"
                                                        expirationDate:[NSDate date]];
  OCMExpect([self.mockAPIService getAppCheckTokenWithArtifact:storedArtifact
                                                    challenge:self.randomChallenge
                                                    assertion:assertion])
      .andReturn([FBLPromise resolvedWith:FACToken]);

  // 7. Call get token several times.
  NSInteger callsCount = 10;
  NSMutableArray *completionExpectations = [NSMutableArray arrayWithCapacity:callsCount];

  for (NSInteger i = 0; i < callsCount; i++) {
    // 7.1 Expect the completion to be called for each get token method called.
    XCTestExpectation *completionExpectation = [self
        expectationWithDescription:[NSString stringWithFormat:@"completionExpectation%@", @(i)]];
    [completionExpectations addObject:completionExpectation];

    // 7.2. Call get token.
    [self.provider
        getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
          [completionExpectation fulfill];

          XCTAssertEqualObjects(token.token, FACToken.token);
          XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
          XCTAssertNil(error);
        }];
  }

  // 7.3. Resolve get challenge promise to finish the operation.
  [challengeRequestPromise fulfill:self.randomChallenge];

  // 7.4. Wait for all completions to be called.
  NSArray<XCTestExpectation *> *expectations =
      [completionExpectations arrayByAddingObject:self.fakeBackoffWrapper.backoffExpectation];
  [self waitForExpectations:expectations timeout:1];

  // 8. Verify mocks.
  [self verifyAllMocks];

  // 9. Check another get token call after.
  [self assertGetToken_WhenKeyRegistered_Success];
}

- (void)testGetToken_WhenCalledSeveralTimesError_ThenThereIsOnlyOneOngoingHandshake {
  // 0. Expect backoff wrapper to be used only once.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = @"existingKeyID";
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [@"storedArtifact" dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Don't expect assertion to be requested.
  NSData *assertion = [@"generatedAssertion" dataUsingEncoding:NSUTF8StringEncoding];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:assertion, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService
      generateAssertion:existingKeyID
         clientDataHash:[self dataHashForAssertionWithArtifactData:storedArtifact]
      completionHandler:completionBlockArg]);

  // 6. Expect assertion request to be sent.
  // 6.1. Create a pending promise to reject later.
  FBLPromise<FIRAppCheckToken *> *assertionRequestPromise = [FBLPromise pendingPromise];
  // 6.2. Stub assertion request.
  OCMExpect([self.mockAPIService getAppCheckTokenWithArtifact:storedArtifact
                                                    challenge:self.randomChallenge
                                                    assertion:assertion])
      .andReturn(assertionRequestPromise);
  // 6.3. Create an expected error to be rejected with later.
  NSError *assertionRequestError = [NSError errorWithDomain:self.name code:0 userInfo:nil];

  // 7. Call get token several times.
  NSInteger callsCount = 10;
  NSMutableArray *completionExpectations = [NSMutableArray arrayWithCapacity:callsCount];

  for (NSInteger i = 0; i < callsCount; i++) {
    // 7.1 Expect the completion to be called for each get token method called.
    XCTestExpectation *completionExpectation = [self
        expectationWithDescription:[NSString stringWithFormat:@"completionExpectation%@", @(i)]];
    [completionExpectations addObject:completionExpectation];

    // 7.2. Call get token.
    [self.provider
        getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
          [completionExpectation fulfill];

          XCTAssertEqualObjects(error, assertionRequestError);
          XCTAssertNil(token);
        }];
  }

  // 7.3. Reject get challenge promise to finish the operation.
  [assertionRequestPromise reject:assertionRequestError];

  // 7.4. Wait for all completions to be called.
  NSArray<XCTestExpectation *> *expectations =
      [completionExpectations arrayByAddingObject:self.fakeBackoffWrapper.backoffExpectation];
  [self waitForExpectations:expectations timeout:1];

  // 8. Verify mocks.
  [self verifyAllMocks];

  // 9. Check another get token call after.
  [self assertGetToken_WhenKeyRegistered_Success];
}

#pragma mark - Backoff tests

- (void)testGetTokenBackoff {
  // 1. Configure backoff.
  self.fakeBackoffWrapper.isNextOperationAllowed = NO;
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 2. Don't expect any operations.
  OCMReject([self.mockAppAttestService isSupported]);
  OCMReject([self.mockStorage getAppAttestKeyID]);
  OCMReject([self.mockAppAttestService generateKeyWithCompletionHandler:OCMOCK_ANY]);
  OCMReject([self.mockArtifactStorage getArtifactForKey:OCMOCK_ANY]);
  OCMReject([self.mockAPIService getRandomChallenge]);
  OCMReject([self.mockStorage setAppAttestKeyID:OCMOCK_ANY]);
  OCMReject([self.mockAppAttestService attestKey:OCMOCK_ANY
                                  clientDataHash:OCMOCK_ANY
                               completionHandler:OCMOCK_ANY]);
  OCMReject([self.mockAPIService attestKeyWithAttestation:OCMOCK_ANY
                                                    keyID:OCMOCK_ANY
                                                challenge:OCMOCK_ANY]);

  // 3. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertNil(token);
        XCTAssertEqualObjects(error, self.fakeBackoffWrapper.backoffError);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5
               enforceOrder:YES];

  // 4. Verify mocks.
  [self verifyAllMocks];
}

#pragma mark - Helpers

- (NSData *)dataHashForAssertionWithArtifactData:(NSData *)artifact {
  NSMutableData *statement = [artifact mutableCopy];
  [statement appendData:self.randomChallenge];
  return [FIRAppCheckCryptoUtils sha256HashFromData:statement];
}

- (FBLPromise *)rejectedPromiseWithError:(NSError *)error {
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:error];
  return rejectedPromise;
}

- (NSError *)expectRandomChallengeRequestError {
  NSError *challengeError = [NSError errorWithDomain:@"testGetToken_WhenRandomChallengeError"
                                                code:NSNotFound
                                            userInfo:nil];
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([self rejectedPromiseWithError:challengeError]);
  return challengeError;
}

- (void)verifyAllMocks {
  OCMVerifyAll(self.mockAppAttestService);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockStorage);
  OCMVerifyAll(self.mockArtifactStorage);
}

- (FIRAppCheckHTTPError *)attestationRejectionHTTPError {
  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]
                                  statusCode:403
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];
  NSData *responseBody = [@"Could not verify attestation" dataUsingEncoding:NSUTF8StringEncoding];
  return [[FIRAppCheckHTTPError alloc] initWithHTTPResponse:response data:responseBody];
}

- (void)assertGetToken_WhenKeyRegistered_Success {
  // 0. Expect backoff wrapper to be used.
  self.fakeBackoffWrapper.backoffExpectation = [self expectationWithDescription:@"Backoff"];

  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  NSString *existingKeyID = [NSUUID UUID].UUIDString;
  OCMExpect([self.mockStorage getAppAttestKeyID])
      .andReturn([FBLPromise resolvedWith:existingKeyID]);

  // 3. Expect a stored artifact to be requested.
  NSData *storedArtifact = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  OCMExpect([self.mockArtifactStorage getArtifactForKey:existingKeyID])
      .andReturn([FBLPromise resolvedWith:storedArtifact]);

  // 4. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 5. Expect assertion to be requested.
  NSData *assertion = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
  id completionBlockArg = [OCMArg invokeBlockWithArgs:assertion, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService
      generateAssertion:existingKeyID
         clientDataHash:[self dataHashForAssertionWithArtifactData:storedArtifact]
      completionHandler:completionBlockArg]);

  // 6. Expect assertion request to be sent.
  FIRAppCheckToken *FACToken = [[FIRAppCheckToken alloc] initWithToken:[NSUUID UUID].UUIDString
                                                        expirationDate:[NSDate date]];
  OCMExpect([self.mockAPIService getAppCheckTokenWithArtifact:storedArtifact
                                                    challenge:self.randomChallenge
                                                    assertion:assertion])
      .andReturn([FBLPromise resolvedWith:FACToken]);

  // 7. Call get token.
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];
  [self.provider
      getTokenWithCompletion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
        [completionExpectation fulfill];

        XCTAssertEqualObjects(token.token, FACToken.token);
        XCTAssertEqualObjects(token.expirationDate, FACToken.expirationDate);
        XCTAssertNil(error);
      }];

  [self waitForExpectations:@[ self.fakeBackoffWrapper.backoffExpectation, completionExpectation ]
                    timeout:0.5];

  // 8. Verify mocks.
  [self verifyAllMocks];

  // 9. Verify backoff result.
  XCTAssertEqualObjects(((FIRAppCheckToken *)self.fakeBackoffWrapper.operationResult).token,
                        FACToken.token);
}

- (void)expectAppAttestAvailabilityToBeCheckedAndNotExistingStoredKeyRequested {
  // 1. Expect FIRAppAttestService.isSupported.
  [OCMExpect([self.mockAppAttestService isSupported]) andReturnValue:@(YES)];

  // 2. Expect storage getAppAttestKeyID.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  NSError *error = [NSError errorWithDomain:@"testGetToken_WhenNoExistingKey_Success"
                                       code:NSNotFound
                                   userInfo:nil];
  [rejectedPromise reject:error];
  OCMExpect([self.mockStorage getAppAttestKeyID]).andReturn(rejectedPromise);
}

- (void)expectAppAttestKeyGeneratedAndAttestedWithKeyID:(NSString *)keyID
                                        attestationData:(NSData *)attestationData {
  // 1. Expect App Attest key to be generated.
  id completionArg = [OCMArg invokeBlockWithArgs:keyID, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService generateKeyWithCompletionHandler:completionArg]);

  // 2. Expect the key ID to be stored.
  OCMExpect([self.mockStorage setAppAttestKeyID:keyID]).andReturn([FBLPromise resolvedWith:keyID]);

  // 3. Expect random challenge to be requested.
  OCMExpect([self.mockAPIService getRandomChallenge])
      .andReturn([FBLPromise resolvedWith:self.randomChallenge]);

  // 4. Expect the key to be attested with the challenge.
  id attestCompletionArg = [OCMArg invokeBlockWithArgs:attestationData, [NSNull null], nil];
  OCMExpect([self.mockAppAttestService attestKey:keyID
                                  clientDataHash:self.randomChallengeHash
                               completionHandler:attestCompletionArg]);
}

- (void)expectAttestationReset {
  // 1. Expect stored key ID to be reset.
  OCMExpect([self.mockStorage setAppAttestKeyID:nil]).andReturn([FBLPromise resolvedWith:nil]);

  // 2. Expect stored attestation artifact to be reset.
  OCMExpect([self.mockArtifactStorage setArtifact:nil forKey:@""])
      .andReturn([FBLPromise resolvedWith:nil]);
}

@end

#endif  // FIR_APP_ATTEST_SUPPORTED_TARGETS
