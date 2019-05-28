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

#import <OCMock/OCMock.h>
#import "FIRInstanceIDFakeKeychain.h"
#import "FIRInstanceIDTokenManager+Test.h"
#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinStore.h"
#import "Firebase/InstanceID/FIRInstanceIDStore.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenDeleteOperation.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenFetchOperation.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenInfo.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenManager.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenOperation.h"
#import "Firebase/InstanceID/FIRInstanceIDTokenStore.h"

static NSString *const kSubDirectoryName = @"FirebaseInstanceIDTokenManagerTest";

static NSString *const kAuthorizedEntity = @"test-authorized-entity";
static NSString *const kScope = @"test-scope";
static NSString *const kToken = @"test-token";

// Use a string (which is converted to NSData) as a placeholder for an actual APNs device token.
static NSString *const kNewAPNSTokenString = @"newAPNSData";

@interface FIRInstanceIDTokenOperation ()

- (void)performTokenOperation;
- (void)finishWithResult:(FIRInstanceIDTokenOperationResult)result
                   token:(nullable NSString *)token
                   error:(nullable NSError *)error;

@end

@interface FIRInstanceIDTokenManager (ExposedForTests)

- (BOOL)checkForTokenRefreshPolicy;
- (void)updateToAPNSDeviceToken:(NSData *)deviceToken isSandbox:(BOOL)isSandbox;
/**
 *  Create a fetch operation. This method can be stubbed to return a particular operation instance,
 *  which makes it easier to unit test different behaviors.
 */
- (FIRInstanceIDTokenFetchOperation *)
    createFetchOperationWithAuthorizedEntity:(NSString *)authorizedEntity
                                       scope:(NSString *)scope
                                     options:(NSDictionary<NSString *, NSString *> *)options
                                     keyPair:(FIRInstanceIDKeyPair *)keyPair;

/**
 *  Create a delete operation. This method can be stubbed to return a particular operation instance,
 *  which makes it easier to unit test different behaviors.
 */
- (FIRInstanceIDTokenDeleteOperation *)
    createDeleteOperationWithAuthorizedEntity:(NSString *)authorizedEntity
                                        scope:(NSString *)scope
                           checkinPreferences:(FIRInstanceIDCheckinPreferences *)checkinPreferences
                                      keyPair:(FIRInstanceIDKeyPair *)keyPair
                                       action:(FIRInstanceIDTokenAction)action;
@end

@interface FIRInstanceIDTokenManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceIDTokenManager *tokenManager;
@property(nonatomic, readwrite, strong) id mockTokenManager;

@property(nonatomic, readwrite, strong) FIRInstanceIDBackupExcludedPlist *checkinPlist;
@property(nonatomic, readwrite, strong) FIRInstanceIDFakeKeychain *fakeKeyChain;
@property(nonatomic, readwrite, strong) FIRInstanceIDTokenStore *tokenStore;

@property(nonatomic, readwrite, strong) FIRInstanceIDCheckinPreferences *fakeCheckin;

@end

@implementation FIRInstanceIDTokenManagerTest

- (void)setUp {
  [super setUp];
  [FIRInstanceIDStore createSubDirectory:kSubDirectoryName];

  NSString *checkinPlistFilename = @"com.google.test.IIDCheckinTest";
  self.checkinPlist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:checkinPlistFilename
                                                    subDirectory:kSubDirectoryName];

  // checkin store
  FIRInstanceIDFakeKeychain *fakeCheckinKeychain = [[FIRInstanceIDFakeKeychain alloc] init];
  FIRInstanceIDCheckinStore *checkinStore =
      [[FIRInstanceIDCheckinStore alloc] initWithCheckinPlist:self.checkinPlist
                                                     keychain:fakeCheckinKeychain];

  // token store
  self.fakeKeyChain = [[FIRInstanceIDFakeKeychain alloc] init];
  self.tokenStore = [[FIRInstanceIDTokenStore alloc] initWithKeychain:_fakeKeyChain];

  self.tokenManager = [[FIRInstanceIDTokenManager alloc] initWithCheckinStore:checkinStore
                                                                   tokenStore:self.tokenStore];
  self.mockTokenManager = OCMPartialMock(self.tokenManager);

  self.fakeCheckin = [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:@"fakeDeviceID"
                                                                   secretToken:@"fakeSecretToken"];
}

- (void)tearDown {
  self.fakeCheckin = nil;

  [self.mockTokenManager stopMocking];
  self.mockTokenManager = nil;

  self.tokenManager = nil;
  self.tokenStore = nil;
  self.fakeKeyChain = nil;

  NSError *error;
  if (![self.checkinPlist deleteFile:&error]) {
    XCTFail(@"Failed to delete checkin plist %@", error);
  }
  self.checkinPlist = nil;

  [FIRInstanceIDStore removeSubDirectory:kSubDirectoryName error:nil];
  [super tearDown];
}

/**
 *  Tests that when a new InstanceID token is successfully produced,
 *  the callback is invoked with a token that is not an empty string and with no error.
 */
- (void)testNewTokenSuccess {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = [NSDictionary dictionary];

  // Create a fake operation that always returns success
  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:tokenOptions
                                                      checkinPreferences:self.fakeCheckin
                                                                 keyPair:[OCMArg any]];
  id mockOperation = OCMPartialMock(operation);
  [[[mockOperation stub] andDo:^(NSInvocation *invocation) {
    [invocation.target finishWithResult:FIRInstanceIDTokenOperationSucceeded
                                  token:kToken
                                  error:nil];
  }] performTokenOperation];

  XCTestExpectation *operationFinishExpectation =
      [self expectationWithDescription:@"operationFinishExpectation"];
  operation.completionBlock = ^{
    [operationFinishExpectation fulfill];
  };

  // Return our fake operation when asked for an operation
  [[[self.mockTokenManager stub] andReturn:operation]
      createFetchOperationWithAuthorizedEntity:[OCMArg any]
                                         scope:[OCMArg any]
                                       options:[OCMArg any]
                                       keyPair:[OCMArg any]];

  [self.tokenManager fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                                 scope:kScope
                                               keyPair:[OCMArg any]
                                               options:tokenOptions
                                               handler:^(NSString *token, NSError *error) {
                                                 XCTAssertNotNil(token);
                                                 XCTAssertGreaterThan(token.length, 0);
                                                 XCTAssertNil(error);
                                                 [tokenExpectation fulfill];
                                               }];

  [self waitForExpectations:@[ tokenExpectation, operationFinishExpectation ] timeout:1];

  // Make sure the partial mock stops mocking before `operation` is deallocated to avoid crash.
  [mockOperation stopMocking];
  // Keep 'operation' alive, so it's not prematurely destroyed
  XCTAssertNotNil(operation);
}

/**
 *  Tests that when a new InstanceID token is fetched from the server but unsuccessfully
 *  saved on the client we should return an error instead of the fetched token.
 */
- (void)testNewTokenSaveFailure {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = [NSDictionary dictionary];
  // Simulate write to keychain failure.
  self.fakeKeyChain.cannotWriteToKeychain = YES;

  // Create a fake operation that always returns success
  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:tokenOptions
                                                      checkinPreferences:self.fakeCheckin
                                                                 keyPair:[OCMArg any]];
  id mockOperation = OCMPartialMock(operation);
  [[[mockOperation stub] andDo:^(NSInvocation *invocation) {
    [invocation.target finishWithResult:FIRInstanceIDTokenOperationSucceeded
                                  token:kToken
                                  error:nil];
  }] performTokenOperation];

  XCTestExpectation *operationFinishExpectation =
      [self expectationWithDescription:@"operationFinishExpectation"];
  operation.completionBlock = ^{
    [operationFinishExpectation fulfill];
  };

  // Return our fake operation when asked for an operation
  [[[self.mockTokenManager stub] andReturn:operation]
      createFetchOperationWithAuthorizedEntity:[OCMArg any]
                                         scope:[OCMArg any]
                                       options:[OCMArg any]
                                       keyPair:[OCMArg any]];

  [self.tokenManager fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                                 scope:kScope
                                               keyPair:[OCMArg any]
                                               options:tokenOptions
                                               handler:^(NSString *token, NSError *error) {
                                                 XCTAssertNil(token);
                                                 XCTAssertNotNil(error);
                                                 [tokenExpectation fulfill];
                                               }];

  [self waitForExpectations:@[ tokenExpectation, operationFinishExpectation ] timeout:1];

  // Make sure the partial mock stops mocking before `operation` is deallocated to avoid crash.
  [mockOperation stopMocking];
  // Keep 'operation' alive, so it's not prematurely destroyed
  XCTAssertNotNil(operation);
}

/**
 *  Tests that when there is a failure in producing a new InstanceID token,
 *  the callback is invoked with an error and a nil token.
 */
- (void)testNewTokenFailure {
  XCTestExpectation *tokenExpectation =
      [self expectationWithDescription:@"New token handler invoked."];

  NSDictionary *tokenOptions = [NSDictionary dictionary];

  // Create a fake operation that always returns failure
  FIRInstanceIDTokenFetchOperation *operation =
      [[FIRInstanceIDTokenFetchOperation alloc] initWithAuthorizedEntity:kAuthorizedEntity
                                                                   scope:kScope
                                                                 options:tokenOptions
                                                      checkinPreferences:self.fakeCheckin
                                                                 keyPair:[OCMArg any]];
  id mockOperation = OCMPartialMock(operation);
  [[[mockOperation stub] andDo:^(NSInvocation *invocation) {
    NSError *someError = [[NSError alloc] initWithDomain:@"InstanceIDUnitTest" code:0 userInfo:nil];
    [invocation.target finishWithResult:FIRInstanceIDTokenOperationError token:nil error:someError];
  }] performTokenOperation];

  XCTestExpectation *operationFinishExpectation =
      [self expectationWithDescription:@"operationFinishExpectation"];
  operation.completionBlock = ^{
    [operationFinishExpectation fulfill];
  };

  // Return our fake operation when asked for an operation
  [[[self.mockTokenManager stub] andReturn:operation]
      createFetchOperationWithAuthorizedEntity:[OCMArg any]
                                         scope:[OCMArg any]
                                       options:[OCMArg any]
                                       keyPair:[OCMArg any]];

  [self.tokenManager fetchNewTokenWithAuthorizedEntity:kAuthorizedEntity
                                                 scope:kScope
                                               keyPair:[OCMArg any]
                                               options:tokenOptions
                                               handler:^(NSString *token, NSError *error) {
                                                 XCTAssertNil(token);
                                                 XCTAssertNotNil(error);
                                                 [tokenExpectation fulfill];
                                               }];

  [self waitForExpectations:@[ tokenExpectation, operationFinishExpectation ] timeout:1];

  // Make sure the partial mock stops mocking before `operation` is deallocated to avoid crash.
  [mockOperation stopMocking];
  // Keep 'operation' alive, so it's not prematurely destroyed
  XCTAssertNotNil(operation);
}

/**
 *  Tests that when a token is deleted successfully, the callback is invoked with no error.
 */
- (void)testDeleteTokenSuccess {
  XCTestExpectation *deleteExpectation =
      [self expectationWithDescription:@"Delete handler invoked."];

  // Create a fake operation that always succeeds
  FIRInstanceIDTokenDeleteOperation *operation = [[FIRInstanceIDTokenDeleteOperation alloc]
      initWithAuthorizedEntity:kAuthorizedEntity
                         scope:kScope
            checkinPreferences:self.fakeCheckin
                       keyPair:[OCMArg any]
                        action:FIRInstanceIDTokenActionDeleteToken];
  id mockOperation = OCMPartialMock(operation);
  [[[mockOperation stub] andDo:^(NSInvocation *invocation) {
    [invocation.target finishWithResult:FIRInstanceIDTokenOperationSucceeded token:nil error:nil];
  }] performTokenOperation];

  XCTestExpectation *operationFinishExpectation =
      [self expectationWithDescription:@"operationFinishExpectation"];
  operation.completionBlock = ^{
    [operationFinishExpectation fulfill];
  };

  // Return our fake operation when asked for an operation
  [[[self.mockTokenManager stub] andReturn:operation]
      createDeleteOperationWithAuthorizedEntity:[OCMArg any]
                                          scope:[OCMArg any]
                             checkinPreferences:[OCMArg any]
                                        keyPair:[OCMArg any]
                                         action:FIRInstanceIDTokenActionDeleteToken];

  [self.tokenManager deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                                               scope:kScope
                                             keyPair:[OCMArg any]
                                             handler:^(NSError *error) {
                                               XCTAssertNil(error);
                                               [deleteExpectation fulfill];
                                             }];

  [self waitForExpectations:@[ deleteExpectation, operationFinishExpectation ] timeout:1];

  // Make sure the partial mock stops mocking before `operation` is deallocated to avoid crash.
  [mockOperation stopMocking];
  // Keep 'operation' alive, so it's not prematurely destroyed
  XCTAssertNotNil(operation);
}

/**
 *  Tests that when a token deletion fails, the callback is invoked with an error.
 */
- (void)testDeleteTokenFailure {
  XCTestExpectation *deleteExpectation =
      [self expectationWithDescription:@"Delete handler invoked."];

  // Create a fake operation that always fails
  FIRInstanceIDTokenDeleteOperation *operation = [[FIRInstanceIDTokenDeleteOperation alloc]
      initWithAuthorizedEntity:kAuthorizedEntity
                         scope:kScope
            checkinPreferences:self.fakeCheckin
                       keyPair:[OCMArg any]
                        action:FIRInstanceIDTokenActionDeleteToken];
  id mockOperation = OCMPartialMock(operation);
  [[[mockOperation stub] andDo:^(NSInvocation *invocation) {
    NSError *someError = [[NSError alloc] initWithDomain:@"InstanceIDUnitTest" code:0 userInfo:nil];
    [invocation.target finishWithResult:FIRInstanceIDTokenOperationError token:nil error:someError];
  }] performTokenOperation];

  XCTestExpectation *operationFinishExpectation =
      [self expectationWithDescription:@"operationFinishExpectation"];
  operation.completionBlock = ^{
    [operationFinishExpectation fulfill];
  };

  // Return our fake operation when asked for an operation
  [[[self.mockTokenManager stub] andReturn:operation]
      createDeleteOperationWithAuthorizedEntity:[OCMArg any]
                                          scope:[OCMArg any]
                             checkinPreferences:[OCMArg any]
                                        keyPair:[OCMArg any]
                                         action:FIRInstanceIDTokenActionDeleteToken];

  [self.tokenManager deleteTokenWithAuthorizedEntity:kAuthorizedEntity
                                               scope:kScope
                                             keyPair:[OCMArg any]
                                             handler:^(NSError *error) {
                                               XCTAssertNotNil(error);
                                               [deleteExpectation fulfill];
                                             }];

  [self waitForExpectations:@[ deleteExpectation, operationFinishExpectation ] timeout:1];

  // Make sure the partial mock stops mocking before `operation` is deallocated to avoid crash.
  [mockOperation stopMocking];
  // Keep 'operation' alive, so it's not prematurely destroyed
  XCTAssertNotNil(operation);
}

#pragma mark - Cached Token Invalidation

- (void)testCachedTokensInvalidatedOnAppVersionChange {
  // Write some fake tokens to cache with a old app version "0.9"
  NSArray<NSString *> *entities = @[ @"entity1", @"entity2" ];
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *info =
        [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:entity
                                                           scope:kScope
                                                           token:@"abcdef"
                                                      appVersion:@"0.9"
                                                   firebaseAppID:nil];
    [self.tokenStore saveTokenInfo:info handler:nil];
  }

  // Ensure they tokens now exist.
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNotNil(cachedTokenInfo);
  }

  // Trigger a potential reset, the current app version is 1.0 which is newer than
  // the one set in tokenInfo.
  [self.tokenManager checkForTokenRefreshPolicy];

  // Ensure that token data is now missing
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNil(cachedTokenInfo);
  }
}

- (void)testCachedTokensInvalidatedOnAPNSAddition {
  // Write some fake tokens to cache, which have no APNs info
  NSArray<NSString *> *entities = @[ @"entity1", @"entity2" ];
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *info =
        [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:entity
                                                           scope:kScope
                                                           token:@"abcdef"
                                                      appVersion:nil
                                                   firebaseAppID:nil];
    [self.tokenStore saveTokenInfo:info handler:nil];
  }

  // Ensure the tokens now exist.
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNotNil(cachedTokenInfo);
  }

  // Trigger a potential reset.
  [self triggerAPNSTokenChange];

  // Ensure that token data is now missing
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNil(cachedTokenInfo);
  }
}

- (void)testCachedTokensInvalidatedOnAPNSChange {
  // Write some fake tokens to cache
  NSArray<NSString *> *entities = @[ @"entity1", @"entity2" ];
  NSData *oldAPNSData = [@"oldAPNSToken" dataUsingEncoding:NSUTF8StringEncoding];
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *info =
        [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:entity
                                                           scope:kScope
                                                           token:@"abcdef"
                                                      appVersion:nil
                                                   firebaseAppID:nil];
    info.APNSInfo = [[FIRInstanceIDAPNSInfo alloc] initWithDeviceToken:oldAPNSData isSandbox:NO];
    [self.tokenStore saveTokenInfo:info handler:nil];
  }

  // Ensure the tokens now exist.
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNotNil(cachedTokenInfo);
  }

  // Trigger a potential reset.
  [self triggerAPNSTokenChange];

  // Ensure that token data is now missing
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNil(cachedTokenInfo);
  }
}

- (void)testCachedTokensNotInvalidatedIfAPNSSame {
  // Write some fake tokens to cache, with the current APNs token
  NSArray<NSString *> *entities = @[ @"entity1", @"entity2" ];
  NSString *apnsDataString = kNewAPNSTokenString;
  NSData *currentAPNSData = [apnsDataString dataUsingEncoding:NSUTF8StringEncoding];
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *info =
        [[FIRInstanceIDTokenInfo alloc] initWithAuthorizedEntity:entity
                                                           scope:kScope
                                                           token:@"abcdef"
                                                      appVersion:nil
                                                   firebaseAppID:nil];
    info.APNSInfo = [[FIRInstanceIDAPNSInfo alloc] initWithDeviceToken:currentAPNSData
                                                             isSandbox:NO];
    [self.tokenStore saveTokenInfo:info handler:nil];
  }

  // Ensure the tokens now exist.
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNotNil(cachedTokenInfo);
  }

  // Trigger a potential reset.
  [self triggerAPNSTokenChange];

  // Ensure that token data is still there
  for (NSString *entity in entities) {
    FIRInstanceIDTokenInfo *cachedTokenInfo =
        [self.tokenManager cachedTokenInfoWithAuthorizedEntity:entity scope:kScope];
    XCTAssertNotNil(cachedTokenInfo);
  }
}

- (void)triggerAPNSTokenChange {
  // Trigger a potential reset.
  NSData *deviceToken = [kNewAPNSTokenString dataUsingEncoding:NSUTF8StringEncoding];
  [self.tokenManager updateTokensToAPNSDeviceToken:deviceToken isSandbox:NO];
}

@end
