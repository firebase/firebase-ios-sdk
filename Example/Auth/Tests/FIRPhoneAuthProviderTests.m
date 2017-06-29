/*
 * Copyright 2017 Google
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

#import "FIRPhoneAuthProvider.h"
#import "Phone/FIRPhoneAuthCredential_Internal.h"
#import "Phone/NSString+FIRAuth.h"
#import "FIRAuthAPNSToken.h"
#import "FIRAuthAPNSTokenManager.h"
#import "FIRAuthAppCredential.h"
#import "FIRAuthAppCredentialManager.h"
#import "FIRAuthNotificationManager.h"
#import "FIRAuth_Internal.h"
#import "FIRAuthCredential_Internal.h"
#import "FIRAuthErrorUtils.h"
#import "FIRAuthGlobalWorkQueue.h"
#import "FIRAuthBackend.h"
#import "FIRSendVerificationCodeRequest.h"
#import "FIRSendVerificationCodeResponse.h"
#import "FIRVerifyClientRequest.h"
#import "FIRVerifyClientResponse.h"
#import "FIRApp+FIRAuthUnitTests.h"
#import "OCMStubRecorder+FIRAuthUnitTests.h"
#import <OCMock/OCMock.h>

NS_ASSUME_NONNULL_BEGIN

/** @var kTestPhoneNumber
    @brief A testing phone number.
 */
static NSString *const kTestPhoneNumber = @"55555555";

/** @var kTestInvalidPhoneNumber
    @brief An invalid testing phone number.
 */
static NSString *const kTestInvalidPhoneNumber = @"555+!*55555";

/** @var kTestVerificationID
    @brief A testing verfication ID.
 */
static NSString *const kTestVerificationID = @"verificationID";

/** @var kTestReceipt
    @brief A fake receipt for testing.
 */
static NSString *const kTestReceipt = @"receipt";

/** @var kTestSecret
    @brief A fake secret for testing.
 */
static NSString *const kTestSecret = @"secret";

/** @var kTestOldReceipt
    @brief A fake old receipt for testing.
 */
static NSString *const kTestOldReceipt = @"old_receipt";

/** @var kTestOldSecret
    @brief A fake old secret for testing.
 */
static NSString *const kTestOldSecret = @"old_secret";


/** @var kTestVerificationCode
    @brief A fake verfication code.
 */
static NSString *const kTestVerificationCode = @"verificationCode";

/** @var kTestTimeout
    @brief A fake timeout value for waiting for push notification.
 */
static const NSTimeInterval kTestTimeout = 5;

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 1;

/** @class FIRPhoneAuthProviderTests
    @brief Tests for @c FIRPhoneAuthProvider
 */
@interface FIRPhoneAuthProviderTests : XCTestCase
@end

@implementation FIRPhoneAuthProviderTests {
  /** @var _mockBackend
      @brief The mock @c FIRAuthBackendImplementation .
   */
  id _mockBackend;

  /** @var _provider
      @brief The @c FIRPhoneAuthProvider instance under test.
   */
  FIRPhoneAuthProvider *_provider;

  /** @var _mockAuth
      @brief The mock @c FIRAuth instance associated with @c _provider .
   */
  id _mockAuth;

  /** @var _mockAPNSTokenManager
      @brief The mock @c FIRAuthAPNSTokenManager instance associated with @c _mockAuth .
   */
  id _mockAPNSTokenManager;

  /** @var _mockAppCredentialManager
      @brief The mock @c FIRAuthAppCredentialManager instance associated with @c _mockAuth .
   */
  id _mockAppCredentialManager;

  /** @var _mockNotificationManager
      @brief The mock @c FIRAuthNotificationManager instance associated with @c _mockAuth .
   */
  id _mockNotificationManager;
}

- (void)setUp {
  [super setUp];
  _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
  [FIRAuthBackend setBackendImplementation:_mockBackend];
  _mockAuth = OCMClassMock([FIRAuth class]);
  _mockAPNSTokenManager = OCMClassMock([FIRAuthAPNSTokenManager class]);
  OCMStub([_mockAuth tokenManager]).andReturn(_mockAPNSTokenManager);
  _mockAppCredentialManager = OCMClassMock([FIRAuthAppCredentialManager class]);
  OCMStub([_mockAuth appCredentialManager]).andReturn(_mockAppCredentialManager);
  _mockNotificationManager = OCMClassMock([FIRAuthNotificationManager class]);
  OCMStub([_mockAuth notificationManager]).andReturn(_mockNotificationManager);
  _provider = [FIRPhoneAuthProvider providerWithAuth:_mockAuth];
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testCredentialWithVerificationID
    @brief Tests the @c credentialWithToken method to make sure that it returns a valid
        FIRAuthCredential instance.
 */
- (void)testCredentialWithVerificationID {
  FIRPhoneAuthCredential *credential =
      [_provider credentialWithVerificationID:kTestVerificationID
                             verificationCode:kTestVerificationCode];
  XCTAssertEqualObjects(credential.verificationID, kTestVerificationID);
  XCTAssertEqualObjects(credential.verificationCode, kTestVerificationCode);
  XCTAssertNil(credential.temporaryProof);
  XCTAssertNil(credential.phoneNumber);
}

/** @fn testVerifyEmptyPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an empty phone
        number was provided.
 */
- (void)testVerifyEmptyPhoneNumber {
  // Empty phone number is checked on the client side so no backend RPC is mocked.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:@""
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRAuthErrorCodeMissingPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testVerifyInvalidPhoneNumber
    @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an invalid phone
        number was provided.
 */
- (void)testVerifyInvalidPhoneNumber {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });
  OCMStub([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback(nil, [FIRAuthErrorUtils invalidPhoneNumberErrorWithMessage:nil]);
    });
  });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(verificationID);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testVerifyPhoneNumber
    @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
 */
- (void)testVerifyPhoneNumber {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });
  OCMStub([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSendVerificationCodeResponse = OCMClassMock([FIRSendVerificationCodeResponse class]);
      OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
      callback(mockSendVerificationCodeResponse, nil);
    });
  });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    XCTAssertEqualObjects(verificationID, kTestVerificationID);
    XCTAssertEqualObjects(verificationID.fir_authPhoneNumber, kTestPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testNotForwardingNotification
    @brief Tests returning an error for the app failing to forward notification.
 */
- (void)testNotForwardingNotification {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(NO); });
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(verificationID);
    XCTAssertEqual(error.code, FIRAuthErrorCodeNotificationNotForwarded);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockNotificationManager);
}

/** @fn testMissingAPNSToken
    @brief Tests returning an error for the app failing to provide an APNS device token.
 */
- (void)testMissingAPNSToken {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) { callback(nil); });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(verificationID);
    XCTAssertEqual(error.code, FIRAuthErrorCodeMissingAppToken);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

/** @fn testVerifyClient
    @brief Tests verifying client before sending verification code.
 */
- (void)testVerifyClient {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });
  OCMExpect([_mockAppCredentialManager credential]).andReturn(nil);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];
  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) { callback(token); });
  // Expect verify client request to the backend.
  OCMExpect([_mockBackend verifyClient:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyClientRequest *request,
                       FIRVerifyClientResponseCallback callback) {
    XCTAssertEqualObjects(request.appToken, @"21402324255E");
    XCTAssertFalse(request.isSandbox);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVerifyClientResponse = OCMClassMock([FIRVerifyClientResponse class]);
      OCMStub([mockVerifyClientResponse receipt]).andReturn(kTestReceipt);
      OCMStub([mockVerifyClientResponse suggestedTimeOutDate])
          .andReturn([NSDate dateWithTimeIntervalSinceNow:kTestTimeout]);
      callback(mockVerifyClientResponse, nil);
    });
  });
  // Mock receiving of push notification.
  OCMExpect([[_mockAppCredentialManager ignoringNonObjectArgs]
      didStartVerificationWithReceipt:OCMOCK_ANY timeout:0 callback:OCMOCK_ANY])
      .andCallIdDoubleIdBlock(^(NSString *receipt,
                                NSTimeInterval timeout,
                                FIRAuthAppCredentialCallback callback) {
    XCTAssertEqualObjects(receipt, kTestReceipt);
    // Unfortunately 'ignoringNonObjectArgs' means the real value for 'timeout' doesn't get passed
    // into the block either, so we can't verify it here.
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
    });
  });
  // Expect send verification code request to the backend.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSendVerificationCodeResponse = OCMClassMock([FIRSendVerificationCodeResponse class]);
      OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
      callback(mockSendVerificationCodeResponse, nil);
    });
  });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(error);
    XCTAssertEqualObjects(verificationID, kTestVerificationID);
    XCTAssertEqualObjects(verificationID.fir_authPhoneNumber, kTestPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

/** @fn testSendVerificationCodeFailedRetry
    @brief Tests failed retry after failing to send verification code.
 */
- (void)testSendVerificationCodeFailedRetry {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });

  // Expect twice due to null check consumes one expectation.
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];

  // Expect first sendVerificationCode request to the backend, with request containing old app
  // credential.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestOldReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestOldSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
    });
  });

  // Expect send verification code request to the backend, with request containing new app
  // credential data.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
    });
  });

  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) { callback(token); });
  // Expect verify client request to the backend.
  OCMExpect([_mockBackend verifyClient:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyClientRequest *request,
                       FIRVerifyClientResponseCallback callback) {
    XCTAssertEqualObjects(request.appToken, @"21402324255E");
    XCTAssertFalse(request.isSandbox);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVerifyClientResponse = OCMClassMock([FIRVerifyClientResponse class]);
      OCMStub([mockVerifyClientResponse receipt]).andReturn(kTestReceipt);
      OCMStub([mockVerifyClientResponse suggestedTimeOutDate])
          .andReturn([NSDate dateWithTimeIntervalSinceNow:kTestTimeout]);
      callback(mockVerifyClientResponse, nil);
    });
  });

  // Mock receiving of push notification.
  OCMStub([[_mockAppCredentialManager ignoringNonObjectArgs]
      didStartVerificationWithReceipt:OCMOCK_ANY timeout:0 callback:OCMOCK_ANY])
      .andCallIdDoubleIdBlock(^(NSString *receipt,
                                NSTimeInterval timeout,
                                FIRAuthAppCredentialCallback callback) {
    XCTAssertEqualObjects(receipt, kTestReceipt);
    // Unfortunately 'ignoringNonObjectArgs' means the real value for 'timeout' doesn't get passed
    // into the block either, so we can't verify it here.
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
    });
  });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertTrue([NSThread isMainThread]);
    XCTAssertNil(verificationID);
    XCTAssertEqual(error.code, FIRAuthErrorCodeInternalError);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

/** @fn testSendVerificationCodeSuccessFulRetry
    @brief Tests successful retry after failing to send verification code.
 */
- (void)testSendVerificationCodeSuccessFulRetry {
  OCMExpect([_mockNotificationManager checkNotificationForwardingWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthNotificationForwardingCallback callback) { callback(YES); });

  // Expect twice due to null check consumes one expectation.
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  OCMExpect([_mockAppCredentialManager credential])
      .andReturn([[FIRAuthAppCredential alloc] initWithReceipt:kTestOldReceipt
                                                        secret:kTestOldSecret]);
  NSData *data = [@"!@#$%^" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];

  // Expect first sendVerificationCode request to the backend, with request containing old app
  // credential.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestOldReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestOldSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
        callback(nil, [FIRAuthErrorUtils invalidAppCredentialWithMessage:nil]);
    });
  });

  // Expect send verification code request to the backend, with request containing new app
  // credential data.
  OCMExpect([_mockBackend sendVerificationCode:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRSendVerificationCodeRequest *request,
                       FIRSendVerificationCodeResponseCallback callback) {
    XCTAssertEqualObjects(request.phoneNumber, kTestPhoneNumber);
    XCTAssertEqualObjects(request.appCredential.receipt, kTestReceipt);
    XCTAssertEqualObjects(request.appCredential.secret, kTestSecret);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockSendVerificationCodeResponse = OCMClassMock([FIRSendVerificationCodeResponse class]);
      OCMStub([mockSendVerificationCodeResponse verificationID]).andReturn(kTestVerificationID);
      callback(mockSendVerificationCodeResponse, nil);
    });
  });

  OCMExpect([_mockAPNSTokenManager getTokenWithCallback:OCMOCK_ANY])
      .andCallBlock1(^(FIRAuthAPNSTokenCallback callback) { callback(token); });
  // Expect verify client request to the backend.
  OCMExpect([_mockBackend verifyClient:[OCMArg any] callback:[OCMArg any]])
      .andCallBlock2(^(FIRVerifyClientRequest *request,
                       FIRVerifyClientResponseCallback callback) {
    XCTAssertEqualObjects(request.appToken, @"21402324255E");
    XCTAssertFalse(request.isSandbox);
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      id mockVerifyClientResponse = OCMClassMock([FIRVerifyClientResponse class]);
      OCMStub([mockVerifyClientResponse receipt]).andReturn(kTestReceipt);
      OCMStub([mockVerifyClientResponse suggestedTimeOutDate])
          .andReturn([NSDate dateWithTimeIntervalSinceNow:kTestTimeout]);
      callback(mockVerifyClientResponse, nil);
    });
  });

  // Mock receiving of push notification.
  OCMStub([[_mockAppCredentialManager ignoringNonObjectArgs]
      didStartVerificationWithReceipt:OCMOCK_ANY timeout:0 callback:OCMOCK_ANY])
      .andCallIdDoubleIdBlock(^(NSString *receipt,
                                NSTimeInterval timeout,
                                FIRAuthAppCredentialCallback callback) {
    XCTAssertEqualObjects(receipt, kTestReceipt);
    // Unfortunately 'ignoringNonObjectArgs' means the real value for 'timeout' doesn't get passed
    // into the block either, so we can't verify it here.
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback([[FIRAuthAppCredential alloc] initWithReceipt:kTestReceipt secret:kTestSecret]);
    });
  });

  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_provider verifyPhoneNumber:kTestPhoneNumber
                    completion:^(NSString *_Nullable verificationID, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(verificationID, kTestVerificationID);
    XCTAssertEqualObjects(verificationID.fir_authPhoneNumber, kTestPhoneNumber);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockBackend);
  OCMVerifyAll(_mockNotificationManager);
  OCMVerifyAll(_mockAppCredentialManager);
  OCMVerifyAll(_mockAPNSTokenManager);
}

@end

NS_ASSUME_NONNULL_END
