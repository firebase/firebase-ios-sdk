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

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenDeleteOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenFetchOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenOperation.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenStore.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

static NSString *kDeviceID = @"fakeDeviceID";
static NSString *kSecretToken = @"fakeSecretToken";
static NSString *kDigestString = @"test-digest";
static NSString *kVersionInfoString = @"version_info-1.0.0";
static NSString *kAuthorizedEntity = @"sender-1234567";
static NSString *kScope = @"fcm";
static NSString *kRegistrationToken = @"token-12345";

@interface FIRMessagingTokenOperation (ExposedForTest)
- (void)performTokenOperation;
+ (NSString *)HTTPAuthHeaderFromCheckin:(FIRMessagingCheckinPreferences *)checkin;
@end

@interface FIRInstallationsAuthTokenResult (Tests)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

// A Fake operation that allows us to check that perform was called.
// We are not using mocks here because we have no way of forcing NSOperationQueues to release
// their operations, and this means that there is always going to be a race condition between
// when we "stop" our partial mock vs when NSOperationQueue attempts to access the mock object on a
// separate thread. We had mocks previously.
@interface FIRMessagingTokenOperationFake : FIRMessagingTokenOperation
@property(nonatomic, assign) BOOL performWasCalled;
@end

@implementation FIRMessagingTokenOperationFake

- (void)performTokenOperation {
  self.performWasCalled = YES;
}

@end

@interface FIRMessagingTokenOperationsTest : XCTestCase

@property(nonatomic) id URLSessionMock;
@property(strong, readonly, nonatomic) FIRMessagingAuthService *authService;
@property(strong, readonly, nonatomic) id mockAuthService;

@property(strong, readonly, nonatomic) id mockTokenStore;
@property(strong, readonly, nonatomic) FIRMessagingCheckinService *checkinService;
@property(strong, readonly, nonatomic) id mockCheckinService;
@property(strong, readonly, nonatomic) id mockInstallations;
@property(strong, readonly, nonatomic) id mockHeartbeatInfo;

@property(strong, readonly, nonatomic) NSString *instanceID;

@property(nonatomic, readwrite, strong) FIRMessagingCheckinPreferences *checkinPreferences;

@end

@implementation FIRMessagingTokenOperationsTest

- (void)setUp {
  [super setUp];
  // Stub NSURLSession constructor before instantiating FIRMessagingCheckinService to inject
  // URLSessionMock.
  self.URLSessionMock = OCMClassMock([NSURLSession class]);
  OCMStub(ClassMethod([self.URLSessionMock sessionWithConfiguration:[OCMArg any]]))
      .andReturn(self.URLSessionMock);

  _mockTokenStore = OCMClassMock([FIRMessagingTokenStore class]);
  _checkinService = [[FIRMessagingCheckinService alloc] init];
  _mockCheckinService = OCMPartialMock(_checkinService);

  _authService = [[FIRMessagingAuthService alloc] init];
  _instanceID = @"instanceID";

  // `FIRMessagingTokenOperation` uses `FIRInstallations` under the hood to get FIS auth token.
  // Stub `FIRInstallations` to avoid using a real object.
  [self stubInstallations];

  // `FIRMessagingTokenFetchOperation` uses `FIRHeartbeatInfo` to retrieve a heartbeat code.
  // Stub `FIRHeartbeatInfo` to avoid using a real object.
  [self stubHeartbeatInfo];
}

- (void)tearDown {
  _authService = nil;
  [_mockCheckinService stopMocking];
  _mockCheckinService = nil;
  _checkinService = nil;
  _mockTokenStore = nil;
  [_mockInstallations stopMocking];
  [_mockHeartbeatInfo stopMocking];
}

- (void)testThatTokenOperationsAuthHeaderStringMatchesCheckin {
  int64_t tenHoursAgo = FIRMessagingCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRMessagingCheckinPreferences *checkin =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  NSString *expectedAuthHeader = [FIRMessagingTokenOperation HTTPAuthHeaderFromCheckin:checkin];
  XCTestExpectation *authHeaderMatchesCheckinExpectation =
      [self expectationWithDescription:@"Auth header string in request matches checkin info"];
  FIRMessagingTokenFetchOperation *operation =
      [[FIRMessagingTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                  scope:kScope
                                                                options:nil
                                                     checkinPreferences:checkin
                                                             instanceID:self.instanceID];

  NSURL *expectedRequestURL = [NSURL URLWithString:FIRMessagingTokenRegisterServer()];
  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                    statusCode:200
                                                                   HTTPVersion:@"HTTP/1.1"
                                                                  headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:[self dataForResponseWithValidToken:YES]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    NSDictionary<NSString *, NSString *> *headers = sentRequest.allHTTPHeaderFields;
                    NSString *authHeader = headers[@"Authorization"];
                    if ([authHeader isEqualToString:expectedAuthHeader]) {
                      [authHeaderMatchesCheckinExpectation fulfill];
                    }
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testThatTokenOperationWithoutCheckInFails {
  // If asserts are enabled, test for the assert to be thrown, otherwise check for the resulting
  // error in the completion handler.
  XCTestExpectation *failedExpectation =
      [self expectationWithDescription:@"Operation failed without checkin info"];

  // This will return hasCheckinInfo == NO
  FIRMessagingCheckinPreferences *emptyCheckinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:@"" secretToken:@""];

  FIRMessagingTokenOperation *operation =
      [[FIRMessagingTokenOperation alloc] initWithAction:FIRMessagingTokenActionFetch
                                     forAuthorizedEntity:kAuthorizedEntity
                                                   scope:kScope
                                                 options:nil
                                      checkinPreferences:emptyCheckinPreferences
                                              instanceID:self.instanceID];
  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    [failedExpectation fulfill];
  }];

  @try {
    [operation start];
  } @catch (NSException *exception) {
    if (exception.name == NSInternalInconsistencyException) {
      [failedExpectation fulfill];
    }
  } @finally {
  }

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testThatAnAlreadyCancelledOperationFinishesWithoutStarting {
  XCTestExpectation *cancelledExpectation =
      [self expectationWithDescription:@"Operation finished as cancelled"];
  XCTestExpectation *didNotCallPerform =
      [self expectationWithDescription:@"Did not call performTokenOperation"];

  int64_t tenHoursAgo = FIRMessagingCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRMessagingCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  FIRMessagingTokenOperationFake *operation =
      [[FIRMessagingTokenOperationFake alloc] initWithAction:FIRMessagingTokenActionFetch
                                         forAuthorizedEntity:kAuthorizedEntity
                                                       scope:kScope
                                                     options:nil
                                          checkinPreferences:checkinPreferences
                                                  instanceID:self.instanceID];
  operation.performWasCalled = NO;
  __weak FIRMessagingTokenOperationFake *weakOperation = operation;
  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    if (result == FIRMessagingTokenOperationCancelled) {
      [cancelledExpectation fulfill];
    }

    if (!weakOperation.performWasCalled) {
      [didNotCallPerform fulfill];
    }
  }];

  [operation cancel];
  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testThatOptionsDictionaryIsIncludedWithFetchRequest {
  XCTestExpectation *optionsIncludedExpectation =
      [self expectationWithDescription:@"Options keys were included in token URL request"];
  int64_t tenHoursAgo = FIRMessagingCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRMessagingCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];
  NSData *fakeDeviceToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  BOOL isSandbox = NO;
  NSString *apnsTupleString =
      FIRMessagingAPNSTupleStringForTokenAndServerType(fakeDeviceToken, isSandbox);
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsFirebaseAppIDKey : @"fakeGMPAppID",
    kFIRMessagingTokenOptionsAPNSKey : fakeDeviceToken,
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @(isSandbox),
  };

  FIRMessagingTokenFetchOperation *operation =
      [[FIRMessagingTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                  scope:kScope
                                                                options:options
                                                     checkinPreferences:checkinPreferences
                                                             instanceID:self.instanceID];

  NSURL *expectedRequestURL = [NSURL URLWithString:FIRMessagingTokenRegisterServer()];
  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                    statusCode:200
                                                                   HTTPVersion:@"HTTP/1.1"
                                                                  headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:[self dataForResponseWithValidToken:YES]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    NSString *query = [[NSString alloc] initWithData:sentRequest.HTTPBody
                                                            encoding:NSUTF8StringEncoding];
                    NSString *gmpAppIDQueryTuple = [NSString
                        stringWithFormat:@"%@=%@", kFIRMessagingTokenOptionsFirebaseAppIDKey,
                                         options[kFIRMessagingTokenOptionsFirebaseAppIDKey]];
                    NSRange gmpAppIDRange = [query rangeOfString:gmpAppIDQueryTuple];

                    NSString *apnsQueryTuple =
                        [NSString stringWithFormat:@"%@=%@", kFIRMessagingTokenOptionsAPNSKey,
                                                   apnsTupleString];
                    NSRange apnsRange = [query rangeOfString:apnsQueryTuple];

                    if (gmpAppIDRange.location != NSNotFound && apnsRange.location != NSNotFound) {
                      [optionsIncludedExpectation fulfill];
                    }
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testServerResetCommand {
  XCTestExpectation *shouldResetIdentityExpectation =
      [self expectationWithDescription:
                @"When server sends down RST error, clients should return reset identity error."];
  int64_t tenHoursAgo = FIRMessagingCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRMessagingCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  FIRMessagingTokenFetchOperation *operation =
      [[FIRMessagingTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                  scope:kScope
                                                                options:nil
                                                     checkinPreferences:checkinPreferences
                                                             instanceID:self.instanceID];
  NSURL *expectedRequestURL = [NSURL URLWithString:FIRMessagingTokenRegisterServer()];
  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                    statusCode:200
                                                                   HTTPVersion:@"HTTP/1.1"
                                                                  headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:[self dataForResponseWithValidToken:NO]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationError);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRMessagingErrorCodeInvalidIdentity);

    [shouldResetIdentityExpectation fulfill];
  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testHTTPAuthHeaderGenerationFromCheckin {
  FIRMessagingCheckinPreferences *checkinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceID secretToken:kSecretToken];
  NSString *expectedHeader =
      [NSString stringWithFormat:@"AidLogin %@:%@", checkinPreferences.deviceID,
                                 checkinPreferences.secretToken];
  NSString *generatedHeader =
      [FIRMessagingTokenOperation HTTPAuthHeaderFromCheckin:checkinPreferences];
  XCTAssertEqualObjects(generatedHeader, expectedHeader);
}

- (void)testTokenFetchOperationFirebaseUserAgentAndHeartbeatHeader {
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  FIRMessagingCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:0];

  FIRMessagingTokenFetchOperation *operation =
      [[FIRMessagingTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                  scope:kScope
                                                                options:nil
                                                     checkinPreferences:checkinPreferences
                                                             instanceID:self.instanceID];

  NSURL *expectedRequestURL = [NSURL URLWithString:FIRMessagingTokenRegisterServer()];
  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:expectedRequestURL
                                                                    statusCode:200
                                                                   HTTPVersion:@"HTTP/1.1"
                                                                  headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:[self dataForResponseWithValidToken:NO]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    NSString *userAgentValue =
                        sentRequest.allHTTPHeaderFields[kFIRMessagingFirebaseUserAgentKey];
                    XCTAssertEqualObjects(userAgentValue, [FIRApp firebaseUserAgent]);
                    NSString *heartBeatCode =
                        sentRequest.allHTTPHeaderFields[kFIRMessagingFirebaseHeartbeatKey];
                    // It is expected that both the SDK and global heartbeat are requested.
                    XCTAssertEqual(heartBeatCode.integerValue, FIRHeartbeatInfoCodeCombined,
                                   @"Heartbeat storage info needed to be updated but was not.");
                    [completionExpectation fulfill];

                    return YES;
                  }];
  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

#pragma mark - Internal Helpers
- (NSData *)dataForResponseWithValidToken:(BOOL)validToken {
  NSString *response;
  if (validToken) {
    response = [NSString stringWithFormat:@"token=%@", kRegistrationToken];
  } else {
    response = @"Error=RST";
  }
  return [response dataUsingEncoding:NSUTF8StringEncoding];
}

- (FIRMessagingCheckinPreferences *)setCheckinPreferencesWithLastCheckinTime:(int64_t)time {
  FIRMessagingCheckinPreferences *checkinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:kDeviceID secretToken:kSecretToken];
  NSDictionary *checkinPlistContents = @{
    kFIRMessagingDigestStringKey : kDigestString,
    kFIRMessagingVersionInfoStringKey : kVersionInfoString,
    kFIRMessagingLastCheckinTimeKey : @(time)
  };
  [checkinPreferences updateWithCheckinPlistContents:checkinPlistContents];
  // manually initialize the checkin preferences
  self.checkinPreferences = checkinPreferences;
  return checkinPreferences;
}

- (void)stubInstallations {
  _mockInstallations = OCMClassMock([FIRInstallations class]);
  OCMStub([_mockInstallations installations]).andReturn(_mockInstallations);
  FIRInstallationsAuthTokenResult *authToken =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];
  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:authToken, [NSNull null], nil];
  OCMStub([_mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);
}

- (void)stubHeartbeatInfo {
  _mockHeartbeatInfo = OCMClassMock([FIRHeartbeatInfo class]);
  OCMStub([_mockHeartbeatInfo heartbeatCodeForTag:@"fire-iid"])
      .andReturn(FIRHeartbeatInfoCodeCombined);
}

@end
