/*
 * Copyright 2018 Google
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

#import <FirebaseInstanceID/FirebaseInstanceID.h>

#import "FIRMessaging.h"
#import "FIRMessaging_Private.h"

@interface FIRMessaging ()
+ (FIRMessaging *)messagingForTests;
@end

@interface FIRMessagingReceiverTest : XCTestCase
@property(nonatomic, readonly, strong) FIRMessaging *messaging;

@end

@implementation FIRMessagingReceiverTest
- (void)setUp {
  [super setUp];

  _messaging = [FIRMessaging messagingForTests];
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
}

- (void)testUseMessagingDelegate {
  XCTAssertFalse(_messaging.useMessagingDelegateForDirectChannel);

  _messaging.useMessagingDelegateForDirectChannel = YES;
  XCTAssertTrue(_messaging.useMessagingDelegateForDirectChannel);
}

- (void)testUseMessagingDelegateFlagOverridedByPlistWithFalseValue {
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistUseMessagingDelegate])
      .andReturn(nil);
  XCTAssertFalse(_messaging.useMessagingDelegateForDirectChannel);

  [bundleMock stopMocking];
}

- (void)testUseMessagingDelegateFlagOverridedByPlistWithTrueValue {
  id bundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([bundleMock objectForInfoDictionaryKey:kFIRMessagingPlistUseMessagingDelegate])
      .andReturn(@YES);
  XCTAssertTrue(_messaging.useMessagingDelegateForDirectChannel);

  [bundleMock stopMocking];
}
@end
