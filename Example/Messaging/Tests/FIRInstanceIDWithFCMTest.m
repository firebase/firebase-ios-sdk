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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <OCMock/OCMock.h>
#import "FIRMessaging_Private.h"
#import "FIRMessaging.h"
#import "FIRMessagingTestUtilities.h"
#import <GoogleUtilities/GULUserDefaults.h>

@interface FIRInstanceID (ExposedForTest)
- (BOOL)isFCMAutoInitEnabled;
- (instancetype)initPrivately;
- (void)start;
@end

@interface FIRMessaging ()
+ (FIRMessaging *)messagingForTests;
@end

@interface FIRInstanceIDTest : XCTestCase

@property(nonatomic, readwrite, strong) id mockInstanceID;
@property(nonatomic, readwrite, strong) id mockFirebaseApp;

@end

@implementation FIRInstanceIDTest

- (void)setUp {
  [super setUp];
  _mockInstanceID = OCMClassMock([FIRInstanceID class]);
  _mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
}

- (void)tearDown {
  self.mockInstanceID = nil;
  [_mockFirebaseApp stopMocking];
  [super tearDown];
}

- (void)testFCMAutoInitEnabled {
  NSString *const kFIRMessagingTestsAutoInit = @"com.messaging.test_autoInit";
  GULUserDefaults *defaults = [[GULUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsAutoInit];
  FIRMessaging *messaging = [FIRMessagingTestUtilities messagingForTestsWithUserDefaults:defaults mockInstanceID:_mockInstanceID];
  id classMock = OCMClassMock([FIRMessaging class]);
  OCMStub([classMock messaging]).andReturn(messaging);
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  messaging.autoInitEnabled = YES;
  XCTAssertTrue(
      [_mockInstanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  messaging.autoInitEnabled = NO;
  XCTAssertFalse(
      [_mockInstanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  messaging.autoInitEnabled = YES;
  XCTAssertTrue([_mockInstanceID isFCMAutoInitEnabled]);
  [classMock stopMocking];
}

@end
