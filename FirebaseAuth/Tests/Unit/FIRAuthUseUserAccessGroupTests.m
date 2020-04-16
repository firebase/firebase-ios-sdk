/*
* Copyright 2020 Google LLC
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
#import <FirebaseAuth/FirebaseAuth.h>
#import <OCMock/OCMock.h>

#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

@interface UseUserAccessGroupTests : XCTestCase
/// A partial mock of `[FIRAuth auth].mockUserAccessGroup
@property(nonatomic, strong) id mockUserAccessGroup;
@end

@implementation UseUserAccessGroupTests

- (void)setUp {
      [super setUp];

 //     _mockBackend = OCMProtocolMock(@protocol(FIRAuthBackendImplementation));
 //     [FIRAuthBackend setBackendImplementation:_mockBackend];
     [FIRApp resetAppForAuthUnitTests];
  if ([FIRAuth auth].userAccessGroup != nil) {
//  self.mockUserAccessGroup = OCMPartialMock([FIRAuth auth].userAccessGroup);
  }

      // Set FIRAuthDispatcher implementation in order to save the token refresh task for later
      // execution.
//      [[FIRAuthDispatcher sharedInstance]
//          setDispatchAfterImplementation:^(NSTimeInterval delay, dispatch_queue_t _Nonnull queue,
//                                           void (^task)(void)) {
//            XCTAssertNotNil(task);
//            XCTAssert(delay > 0);
//            XCTAssertEqualObjects(FIRAuthGlobalWorkQueue(), queue);
//            self->_FIRAuthDispatcherCallback = task;
//          }];

    #if TARGET_OS_IOS
      // Wait until FIRAuth initialization completes
      // [self waitForAuthGlobalWorkQueueDrain];
//      self.mockTokenManager = OCMPartialMock([FIRAuth auth].tokenManager);
//      self.mockNotificationManager = OCMPartialMock([FIRAuth auth].notificationManager);
//      self.mockAuthURLPresenter = OCMPartialMock([FIRAuth auth].authURLPresenter);
    #endif  // TARGET_OS_IOS
}

- (void)tearDown {
    [self.mockUserAccessGroup stopMocking];
    self.mockUserAccessGroup = nil;
}

- (void)testUseUserAccessGroup {
  FIRAuth *auth = [FIRAuth auth];
  XCTAssertNotNil(auth);
  XCTAssertTrue([auth useUserAccessGroup:@"id.com.example.group1" error:nil]);
  XCTAssertTrue([auth useUserAccessGroup:@"id.com.example.group2" error:nil]);
  XCTAssertTrue([auth useUserAccessGroup:nil error:nil]);
}

@end
