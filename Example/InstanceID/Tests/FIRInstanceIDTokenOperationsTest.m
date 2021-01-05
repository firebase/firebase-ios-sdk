/*
 * Copyright 2019 Google
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

#import "Firebase/InstanceID/Public/FIRInstanceID.h"

#import <OCMock/OCMock.h>

#import "Firebase/InstanceID/FIRInstanceIDAuthService.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinService.h"
#import "Firebase/InstanceID/FIRInstanceIDConstants.h"
#import "Firebase/InstanceID/FIRInstanceIDKeychain.h"
#import "Firebase/InstanceID/FIRInstanceIDStore.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenDeleteOperation.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenFetchOperation.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenOperation+Private.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenOperation.h"
#import "Firebase/InstanceID/NSError+FIRInstanceID.h"

#import <GoogleUtilities/GULHeartbeatDateStorage.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

static NSString *kDeviceID = @"fakeDeviceID";
static NSString *kSecretToken = @"fakeSecretToken";
static NSString *kDigestString = @"test-digest";
static NSString *kVersionInfoString = @"version_info-1.0.0";
static NSString *kAuthorizedEntity = @"sender-1234567";
static NSString *kScope = @"fcm";
static NSString *kRegistrationToken = @"token-12345";

@interface FIRInstanceIDTokenOperation (ExposedForTest)
- (void)performTokenOperation;
@end

@interface FIRInstallationsAuthTokenResult (Tests)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

// A Fake operation that allows us to check that perform was called.
// We are not using mocks here because we have no way of forcing NSOperationQueues to release
// their operations, and this means that there is always going to be a race condition between
// when we "stop" our partial mock vs when NSOperationQueue attempts to access the mock object on a
// separate thread. We had mocks previously.
@interface FIRInstanceIDTokenOperationFake : FIRInstanceIDTokenOperation
@property(nonatomic, assign) BOOL performWasCalled;
@end

@implementation FIRInstanceIDTokenOperationFake

- (void)performTokenOperation {
  self.performWasCalled = YES;
}

@end

@interface FIRInstanceIDTokenOperationsTest : XCTestCase

@property(strong, readonly, nonatomic) FIRInstanceIDAuthService *authService;
@property(strong, readonly, nonatomic) id mockAuthService;

@property(strong, readonly, nonatomic) id mockStore;
@property(strong, readonly, nonatomic) FIRInstanceIDCheckinService *checkinService;
@property(strong, readonly, nonatomic) id mockCheckinService;
@property(strong, readonly, nonatomic) id mockInstallations;

@property(strong, readonly, nonatomic) NSString *instanceID;

@property(nonatomic, readwrite, strong) FIRInstanceIDCheckinPreferences *checkinPreferences;

@end

@implementation FIRInstanceIDTokenOperationsTest

- (void)setUp {
  [super setUp];
  _mockStore = OCMClassMock([FIRInstanceIDStore class]);
  _checkinService = [[FIRInstanceIDCheckinService alloc] init];
  _mockCheckinService = OCMPartialMock(_checkinService);
  _authService = [[FIRInstanceIDAuthService alloc] initWithCheckinService:_mockCheckinService
                                                                    store:_mockStore];
  _instanceID = @"instanceID";

  // `FIRInstanceIDTokenOperation` uses `FIRInstallations` under the hood to get FIS auth token.
  // Stub `FIRInstallations` to avoid using a real object.
  [self stubInstallations];

  NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
  GULHeartbeatDateStorage *dataStorage =
      [[GULHeartbeatDateStorage alloc] initWithFileName:kHeartbeatStorageFile];
  [[NSFileManager defaultManager] removeItemAtURL:[dataStorage fileURL] error:nil];
}

- (void)tearDown {
  [_mockInstallations stopMocking];
  _mockInstallations = nil;
  _authService = nil;
  [_mockCheckinService stopMocking];
  _mockCheckinService = nil;
  _checkinService = nil;
  _mockStore = nil;
}

- (void)testThatTokenOperationsAuthHeaderStringMatchesCheckin {
  int64_t tenHoursAgo = FIRInstanceIDCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRInstanceIDCheckinPreferences *checkin =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  NSString *expectedAuthHeader = [FIRInstanceIDTokenOperation HTTPAuthHeaderFromCheckin:checkin];
  XCTestExpectation *authHeaderMatchesCheckinExpectation =
      [self expectationWithDescription:@"Auth header string in request matches checkin info"];
  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:nil
                                                      checkinPreferences:checkin
                                                              instanceID:self.instanceID];
  operation.testBlock =
      ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock response) {
        NSDictionary<NSString *, NSString *> *headers = request.allHTTPHeaderFields;
        NSString *authHeader = headers[@"Authorization"];
        if ([authHeader isEqualToString:expectedAuthHeader]) {
          [authHeaderMatchesCheckinExpectation fulfill];
        }

        // Return a response (doesnt matter what the response is)
        NSData *responseBody = [self dataForFetchRequest:request returnValidToken:YES];
        NSHTTPURLResponse *responseObject = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                        statusCode:200
                                                                       HTTPVersion:@"HTTP/1.1"
                                                                      headerFields:nil];
        response(responseBody, responseObject, nil);
      };

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
  FIRInstanceIDCheckinPreferences *emptyCheckinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:@"" secretToken:@""];

  FIRInstanceIDTokenOperation *operation =
      [[FIRInstanceIDTokenOperation alloc] initWithAction:FIRInstanceIDTokenActionFetch
                                      forAuthorizedEntity:kAuthorizedEntity
                                                    scope:kScope
                                                  options:nil
                                       checkinPreferences:emptyCheckinPreferences
                                               instanceID:self.instanceID];
  [operation addCompletionHandler:^(FIRInstanceIDTokenOperationResult result,
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

  int64_t tenHoursAgo = FIRInstanceIDCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  FIRInstanceIDTokenOperationFake *operation =
      [[FIRInstanceIDTokenOperationFake alloc] initWithAction:FIRInstanceIDTokenActionFetch
                                          forAuthorizedEntity:kAuthorizedEntity
                                                        scope:kScope
                                                      options:nil
                                           checkinPreferences:checkinPreferences
                                                   instanceID:self.instanceID];
  operation.performWasCalled = NO;
  __weak FIRInstanceIDTokenOperationFake *weakOperation = operation;
  [operation addCompletionHandler:^(FIRInstanceIDTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    if (result == FIRInstanceIDTokenOperationCancelled) {
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
  int64_t tenHoursAgo = FIRInstanceIDCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];
  NSData *fakeDeviceToken = [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  BOOL isSandbox = NO;
  NSString *apnsTupleString =
      FIRInstanceIDAPNSTupleStringForTokenAndServerType(fakeDeviceToken, isSandbox);
  NSDictionary *options = @{
    kFIRInstanceIDTokenOptionsFirebaseAppIDKey : @"fakeGMPAppID",
    kFIRInstanceIDTokenOptionsAPNSKey : fakeDeviceToken,
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(isSandbox),
  };

  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:options
                                                      checkinPreferences:checkinPreferences
                                                              instanceID:self.instanceID];
  operation.testBlock =
      ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock response) {
        NSString *query = [[NSString alloc] initWithData:request.HTTPBody
                                                encoding:NSUTF8StringEncoding];
        NSString *gmpAppIDQueryTuple =
            [NSString stringWithFormat:@"%@=%@", kFIRInstanceIDTokenOptionsFirebaseAppIDKey,
                                       options[kFIRInstanceIDTokenOptionsFirebaseAppIDKey]];
        NSRange gmpAppIDRange = [query rangeOfString:gmpAppIDQueryTuple];

        NSString *apnsQueryTuple = [NSString
            stringWithFormat:@"%@=%@", kFIRInstanceIDTokenOptionsAPNSKey, apnsTupleString];
        NSRange apnsRange = [query rangeOfString:apnsQueryTuple];

        if (gmpAppIDRange.location != NSNotFound && apnsRange.location != NSNotFound) {
          [optionsIncludedExpectation fulfill];
        }

        // Return a response (doesnt matter what the response is)
        NSData *responseBody = [self dataForFetchRequest:request returnValidToken:YES];
        NSHTTPURLResponse *responseObject = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                        statusCode:200
                                                                       HTTPVersion:@"HTTP/1.1"
                                                                      headerFields:nil];
        response(responseBody, responseObject, nil);
      };

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
  int64_t tenHoursAgo = FIRInstanceIDCurrentTimestampInMilliseconds() - 10 * 60 * 60 * 1000;
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:tenHoursAgo];

  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:nil
                                                      checkinPreferences:checkinPreferences
                                                              instanceID:self.instanceID];
  operation.testBlock =
      ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock response) {
        // Return a response with Error=RST
        NSData *responseBody = [self dataForFetchRequest:request returnValidToken:NO];
        NSHTTPURLResponse *responseObject = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                        statusCode:200
                                                                       HTTPVersion:@"HTTP/1.1"
                                                                      headerFields:nil];
        response(responseBody, responseObject, nil);
      };

  [operation addCompletionHandler:^(FIRInstanceIDTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRInstanceIDTokenOperationError);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, kFIRInstanceIDErrorCodeInvalidIdentity);

    [shouldResetIdentityExpectation fulfill];
  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

- (void)testHTTPAuthHeaderGenerationFromCheckin {
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kDeviceID secretToken:kSecretToken];
  NSString *expectedHeader =
      [NSString stringWithFormat:@"AidLogin %@:%@", checkinPreferences.deviceID,
                                 checkinPreferences.secretToken];
  NSString *generatedHeader =
      [FIRInstanceIDTokenOperation HTTPAuthHeaderFromCheckin:checkinPreferences];
  XCTAssertEqualObjects(generatedHeader, expectedHeader);
}

- (void)testTokenFetchOperationFirebaseUserAgentAndHeartbeatHeader {
  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [self setCheckinPreferencesWithLastCheckinTime:0];

  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:nil
                                                      checkinPreferences:checkinPreferences
                                                              instanceID:self.instanceID];
  operation.testBlock =
      ^(NSURLRequest *request, FIRInstanceIDURLRequestTestResponseBlock response) {
        NSString *userAgentValue = request.allHTTPHeaderFields[kFIRInstanceIDFirebaseUserAgentKey];
        XCTAssertEqualObjects(userAgentValue, [FIRApp firebaseUserAgent]);
        NSString *heartBeatCode = request.allHTTPHeaderFields[kFIRInstanceIDFirebaseHeartbeatKey];
        XCTAssertEqualObjects(heartBeatCode, @"3");

        // Return a response with Error=RST
        NSData *responseBody = [self dataForFetchRequest:request returnValidToken:NO];
        NSHTTPURLResponse *responseObject = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                        statusCode:200
                                                                       HTTPVersion:@"HTTP/1.1"
                                                                      headerFields:nil];
        response(responseBody, responseObject, nil);
      };

  [operation addCompletionHandler:^(FIRInstanceIDTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    [completionExpectation fulfill];
  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.25
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error.localizedDescription);
                               }];
}

#pragma mark - Internal Helpers
- (NSData *)dataForFetchRequest:(NSURLRequest *)request returnValidToken:(BOOL)returnValidToken {
  NSString *response;
  if (returnValidToken) {
    response = [NSString stringWithFormat:@"token=%@", kRegistrationToken];
  } else {
    response = @"Error=RST";
  }
  return [response dataUsingEncoding:NSUTF8StringEncoding];
}

- (FIRInstanceIDCheckinPreferences *)setCheckinPreferencesWithLastCheckinTime:(int64_t)time {
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:kDeviceID secretToken:kSecretToken];
  NSDictionary *checkinPlistContents = @{
    kFIRInstanceIDDigestStringKey : kDigestString,
    kFIRInstanceIDVersionInfoStringKey : kVersionInfoString,
    kFIRInstanceIDLastCheckinTimeKey : @(time)
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

@end
