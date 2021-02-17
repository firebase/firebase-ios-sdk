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
#import "OCMock.h"

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenManager.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

@interface FIRMessaging (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingTokenManager *tokenManager;

@end

@interface FIRMessagingTokenManagerTest : XCTestCase {
  FIRMessaging *_messaging;
  id _mockMessaging;
  id _mockPubSub;
  id _mockTokenManager;
  id _mockInstallations;
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
}

- (void)tearDown {
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
@end
