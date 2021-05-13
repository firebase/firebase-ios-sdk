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

#import <GoogleUtilities/GULURLSessionDataResponse.h>

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"
#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAttestationResponse.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFixtureLoader.h"
#import "SharedTestUtilities/Date/FIRDateTestUtils.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

@interface FIRAppAttestAPIServiceTests : XCTestCase

@property(nonatomic) FIRAppAttestAPIService *appAttestAPIService;

@property(nonatomic) id mockAPIService;

@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@end

@implementation FIRAppAttestAPIServiceTests

- (void)setUp {
  [super setUp];

  self.projectID = @"project_id";
  self.appID = @"app_id";

  self.mockAPIService = OCMProtocolMock(@protocol(FIRAppCheckAPIServiceProtocol));
  OCMStub([self.mockAPIService baseURL]).andReturn(@"https://test.appcheck.url.com/beta");

  self.appAttestAPIService = [[FIRAppAttestAPIService alloc] initWithAPIService:self.mockAPIService
                                                                      projectID:self.projectID
                                                                          appID:self.appID];
}

- (void)tearDown {
  [super tearDown];

  self.appAttestAPIService = nil;
  [self.mockAPIService stopMocking];
  self.mockAPIService = nil;
}

#pragma mark - Random challenge request

- (void)testGetRandomChallengeWhenAPIResponseValid {
  // 1. Prepare API response.
  NSData *responseBody = [FIRFixtureLoader loadFixtureNamed:@"AppAttestResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isFulfilled);
  XCTAssertNotNil(promise.value);
  XCTAssertNil(promise.error);

  NSString *challengeString = [[NSString alloc] initWithData:promise.value
                                                    encoding:NSUTF8StringEncoding];
  // The challenge stored in `AppAttestResponseSuccess.json` is a valid base64 encoding of
  // the string "random_challenge".
  XCTAssert([challengeString isEqualToString:@"random_challenge"]);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIError {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  GULURLSessionDataResponse *invalidAPIResponse = [self APIResponseWithCode:300
                                                               responseBody:responseBody];
  NSError *APIError = [FIRAppCheckErrorUtil APIErrorWithHTTPResponse:invalidAPIResponse.HTTPResponse
                                                                data:invalidAPIResponse.HTTPBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:APIError];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertTrue([failureReason containsString:@"300"]);
  XCTAssertTrue([failureReason containsString:responseBodyString]);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIResponseEmpty {
  // 1. Prepare API response.
  NSData *responseBody = [NSData data];
  GULURLSessionDataResponse *emptyAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:emptyAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"Empty server response body.");

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIResponseInvalidFormat {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"JSON serialization error.");

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenResponseMissingField {
  [self assertMissingFieldErrorWithFixture:@"AppAttestResponseMissingChallenge.json"
                              missingField:@"challenge"];
}

- (void)assertMissingFieldErrorWithFixture:(NSString *)fixtureName
                              missingField:(NSString *)fieldName {
  // 1. Prepare API response.
  NSData *missingFieldBody = [FIRFixtureLoader loadFixtureNamed:fixtureName];
  GULURLSessionDataResponse *incompleteAPIResponse = [self APIResponseWithCode:200
                                                                  responseBody:missingFieldBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestForChallengeRequestWithResponse:incompleteAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect missing field name to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  NSString *fieldNameString = [NSString stringWithFormat:@"`%@`", fieldName];
  XCTAssertTrue([failureReason containsString:fieldNameString],
                @"Fixture `%@`: expected missing field %@ error not found", fixtureName,
                fieldNameString);
}

#pragma mark - Assertion request

- (void)testGetAppCheckTokenSuccess {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"AttestationTokenResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                                 response:validAPIResponse
                                    error:nil];
  // 2.2. Return token from parsed response.
  FIRAppCheckToken *expectedToken = [[FIRAppCheckToken alloc] initWithToken:@"app_check_token"
                                                             expirationDate:[NSDate date]];
  [self expectTokenWithAPIReponse:validAPIResponse toReturnToken:expectedToken];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  XCTAssertEqualObjects(promise.value, expectedToken);
  XCTAssertEqualObjects(promise.value.token, expectedToken.token);
  XCTAssertEqualObjects(promise.value.expirationDate, expectedToken.expirationDate);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetAppCheckTokenNetworkError {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"AttestationTokenResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  NSError *networkError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                                 response:validAPIResponse
                                    error:networkError];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertEqualObjects(promise.error, networkError);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetAppCheckTokenUnexpectedResponse {
  NSData *artifact = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSData *assertion = [self generateRandomData];

  // 1. Prepare response.
  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"DeviceCheckResponseMissingToken.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectTokenAPIRequestWithArtifact:artifact
                                challenge:challenge
                                assertion:assertion
                                 response:validAPIResponse
                                    error:nil];
  // 2.2. Return token from parsed response.
  [self expectTokenWithAPIReponse:validAPIResponse toReturnToken:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService getAppCheckTokenWithArtifact:artifact
                                                                     challenge:challenge
                                                                     assertion:assertion];
  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertNotNil(promise.error);

  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Attestation request

- (void)testAttestKeySuccess {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Prepare response.
  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"AppAttestAttestationResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                     response:validAPIResponse
                                        error:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge];

  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  NSData *expectedArtifact =
      [@"valid Firebase app attest artifact" dataUsingEncoding:NSUTF8StringEncoding];

  XCTAssertEqualObjects(promise.value.artifact, expectedArtifact);
  XCTAssertEqualObjects(promise.value.token.token, @"valid_app_check_token");
  XCTAssertTrue([FIRDateTestUtils isDate:promise.value.token.expirationDate
      approximatelyEqualCurrentPlusTimeInterval:1800
                                      precision:10]);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAttestKeyNetworkError {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Stub API Service
  // 1.1. Return prepared response.
  NSError *networkError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                     response:nil
                                        error:networkError];

  // 2. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertEqualObjects(promise.error, networkError);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAttestKeyUnexpectedResponse {
  NSData *attestation = [self generateRandomData];
  NSData *challenge = [self generateRandomData];
  NSString *keyID = [NSUUID UUID].UUIDString;

  // 1. Prepare unexpected response.
  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"AttestationTokenResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];

  // 2. Stub API Service
  // 2.1. Return prepared response.
  [self expectAttestAPIRequestWithAttestation:attestation
                                        keyID:keyID
                                    challenge:challenge
                                     response:validAPIResponse
                                        error:nil];

  // 3. Send request.
  __auto_type promise = [self.appAttestAPIService attestKeyWithAttestation:attestation
                                                                     keyID:keyID
                                                                 challenge:challenge];

  // 4. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertNotNil(promise.error);

  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Helpers

- (GULURLSessionDataResponse *)APIResponseWithCode:(NSInteger)code
                                      responseBody:(NSData *)responseBody {
  XCTAssertNotNil(responseBody);
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:code];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:responseBody];
  return APIResponse;
}

- (void)stubMockAPIServiceRequestForChallengeRequestWithResponse:(id)response {
  id URLValidationArg = [self URLValidationArgumentWithResource:@"generateAppAttestChallenge"];
  OCMStub([self.mockAPIService sendRequestWithURL:URLValidationArg
                                       HTTPMethod:@"POST"
                                             body:nil
                                additionalHeaders:nil])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertFalse([NSThread isMainThread]);
      })
      .andReturn([FBLPromise resolvedWith:response]);
}

- (id)URLValidationArgumentWithResource:(NSString *)resource {
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:%@", [self.mockAPIService baseURL],
                                 self.projectID, self.appID, resource];

  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];
  return URLValidationArg;
}

- (void)expectTokenAPIRequestWithArtifact:(NSData *)attestation
                                challenge:(NSData *)challenge
                                assertion:(NSData *)assertion
                                 response:(nullable GULURLSessionDataResponse *)response
                                    error:(nullable NSError *)error {
  id URLValidationArg = [self URLValidationArgumentWithResource:@"exchangeAppAttestAssertion"];

  id bodyValidationArg = [OCMArg checkWithBlock:^BOOL(NSData *requestBody) {
    NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:requestBody
                                                                                options:0
                                                                                  error:nil];

    XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

    // Validate artifact field.
    NSString *base64EncodedArtifact = decodedData[@"artifact"];
    XCTAssert([base64EncodedArtifact isKindOfClass:[NSString class]]);

    NSData *decodedAttestation = [[NSData alloc] initWithBase64EncodedString:base64EncodedArtifact
                                                                     options:0];
    XCTAssertEqualObjects(decodedAttestation, attestation);

    // Validate challenge field.
    NSString *base64EncodedChallenge = decodedData[@"challenge"];
    XCTAssert([base64EncodedChallenge isKindOfClass:[NSString class]]);

    NSData *decodedChallenge = [[NSData alloc] initWithBase64EncodedString:base64EncodedChallenge
                                                                   options:0];
    XCTAssertEqualObjects(decodedChallenge, challenge);

    // Validate assertion field.
    NSString *base64EncodedAssertion = decodedData[@"assertion"];
    XCTAssert([base64EncodedAssertion isKindOfClass:[NSString class]]);

    NSData *decodedAssertion = [[NSData alloc] initWithBase64EncodedString:base64EncodedAssertion
                                                                   options:0];
    XCTAssertEqualObjects(decodedAssertion, assertion);

    return YES;
  }];

  FBLPromise *responsePromise = [FBLPromise pendingPromise];
  if (error) {
    [responsePromise reject:error];
  } else {
    [responsePromise fulfill:response];
  }
  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:bodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn(responsePromise);
}

- (void)expectTokenWithAPIReponse:(nonnull GULURLSessionDataResponse *)response
                    toReturnToken:(nullable FIRAppCheckToken *)token {
  FBLPromise *tokenPromise = [FBLPromise pendingPromise];
  if (token) {
    [tokenPromise fulfill:token];
  } else {
    NSError *tokenError = [NSError errorWithDomain:self.name code:0 userInfo:nil];
    [tokenPromise reject:tokenError];
  }
  OCMExpect([self.mockAPIService appCheckTokenWithAPIResponse:response]).andReturn(tokenPromise);
}

- (void)expectAttestAPIRequestWithAttestation:(NSData *)attestation
                                        keyID:(NSString *)keyID
                                    challenge:(NSData *)challenge
                                     response:(nullable GULURLSessionDataResponse *)response
                                        error:(nullable NSError *)error {
  id URLValidationArg = [self URLValidationArgumentWithResource:@"exchangeAppAttestAttestation"];

  id bodyValidationArg = [OCMArg checkWithBlock:^BOOL(NSData *requestBody) {
    NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:requestBody
                                                                                options:0
                                                                                  error:nil];

    XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

    // Validate attestation field.
    NSString *base64EncodedAttestation = decodedData[@"attestation_statement"];
    XCTAssert([base64EncodedAttestation isKindOfClass:[NSString class]]);

    NSData *decodedAttestation =
        [[NSData alloc] initWithBase64EncodedString:base64EncodedAttestation options:0];
    XCTAssertEqualObjects(decodedAttestation, attestation);

    // Validate challenge field.
    NSString *base64EncodedChallenge = decodedData[@"challenge"];
    XCTAssert([base64EncodedAttestation isKindOfClass:[NSString class]]);

    NSData *decodedChallenge = [[NSData alloc] initWithBase64EncodedString:base64EncodedChallenge
                                                                   options:0];
    XCTAssertEqualObjects(decodedChallenge, challenge);

    // Validate key ID field.
    NSString *keyIDField = decodedData[@"keyId"];
    XCTAssert([base64EncodedAttestation isKindOfClass:[NSString class]]);

    XCTAssertEqualObjects(keyIDField, keyID);

    return YES;
  }];

  FBLPromise *resultPromise = [FBLPromise pendingPromise];
  if (error) {
    [resultPromise reject:error];
  } else {
    [resultPromise fulfill:response];
  }

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:bodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn(resultPromise);
}

- (NSData *)generateRandomData {
  return [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];
}

@end
