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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthService.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

@interface FIRMessaging (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

@end

@interface FIRMessagingTokenManager (ExposedForTest)

- (void)didDeleteFCMScopedTokensForCheckin:(FIRMessagingCheckinPreferences *)checkin;

- (void)resetCredentialsIfNeeded;

@end

@interface FIRMessagingAuthService (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingCheckinStore *checkinStore;

@end

@interface FIRMessagingTokenManagerTest : XCTestCase {
  FIRMessaging *_messaging;
  id _mockMessaging;
  id _mockPubSub;
  id _mockTokenManager;
  id _mockInstallations;
  id _mockCheckinStore;
  id _mockAuthService;
  FIRMessagingTestUtilities *_testUtil;
}

@end

@implementation FIRMessagingTokenManagerTest

- (void)setUp {
  [super setUp];
  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;
  _mockTokenManager = _testUtil.mockTokenManager;
  _mockAuthService = OCMPartialMock(_messaging.tokenManager.authService);
  _mockCheckinStore = OCMPartialMock(_messaging.tokenManager.authService.checkinStore);
}

- (void)tearDown {
  [_mockCheckinStore stopMocking];
  [_mockAuthService stopMocking];
  [_testUtil cleanupAfterTest:self];
  _messaging = nil;
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain]
      removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  [super tearDown];
}

- (void)testTokenChangeMethod {
  NSString *oldToken = nil;
  NSString *newToken = @"new_token";
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"old_token";
  newToken = nil;
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"old_token";
  newToken = @"new_token";
  XCTAssertTrue([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken toNewToken:newToken]);

  oldToken = @"The_same_token";
  newToken = @"The_same_token";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = nil;
  newToken = nil;
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = @"";
  newToken = @"";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = nil;
  newToken = @"";
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);

  oldToken = @"";
  newToken = nil;
  XCTAssertFalse([_messaging.tokenManager hasTokenChangedFromOldToken:oldToken
                                                           toNewToken:newToken]);
}

- (void)testResetCredentialsWithNoCachedCheckin {
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMReject([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService checkinPreferences]).andReturn(nil);

  [_messaging.tokenManager resetCredentialsIfNeeded];

  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithoutFreshInstall {
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMReject([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService hasCheckinPlist]).andReturn(YES);

  [_messaging.tokenManager resetCredentialsIfNeeded];

  OCMVerifyAll(_mockCheckinStore);
}

- (void)testResetCredentialsWithFreshInstall {
  FIRMessagingCheckinPreferences *checkinPreferences =
      [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:@"test-auth-id"
                                                   secretToken:@"test-secret"];
  // Expect checkin is removed if it's a fresh install.
  id completionArg = [OCMArg invokeBlockWithArgs:[NSNull null], nil];
  OCMExpect([_mockCheckinStore removeCheckinPreferencesWithHandler:completionArg]);
  // Always setting up stub after expect.
  OCMStub([_mockAuthService checkinPreferences]).andReturn(checkinPreferences);
  // Plist file doesn't exist, meaning this is a fresh install.
  OCMStub([_mockCheckinStore hasCheckinPlist]).andReturn(NO);
  // Expect reset operation but do nothing to avoid flakes due to delayed operation queue.
  OCMExpect(
      [_mockTokenManager didDeleteFCMScopedTokensForCheckin:[OCMArg isEqual:checkinPreferences]])
      .andDo(nil);

  [_messaging.tokenManager resetCredentialsIfNeeded];
  OCMVerifyAll(_mockCheckinStore);
}

@end
