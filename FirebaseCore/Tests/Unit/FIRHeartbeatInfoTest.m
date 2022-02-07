// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <GoogleUtilities/GULHeartbeatDateStorable.h>
#import <GoogleUtilities/GULHeartbeatDateStorage.h>
#import <GoogleUtilities/GULHeartbeatDateStorageUserDefaults.h>
#import <XCTest/XCTest.h>
#import "FirebaseCore/Internal/FIRHeartbeatInfo.h"

/// Taken from the implementation of `FIRHeartbeatInfo.m`.
NSString *const kFIRCoreSuiteName = @"com.firebase.core";

@interface FIRHeartbeatInfoTest : XCTestCase

@property(nonatomic, strong) id<GULHeartbeatDateStorable> dataStorage;

#if TARGET_OS_TV
@property(nonatomic, strong) NSUserDefaults *defaults;
#endif  // TARGET_OS_TV

@end

@implementation FIRHeartbeatInfoTest

- (void)setUp {
  NSString *const kHeartbeatStorageName = @"HEARTBEAT_INFO_STORAGE";
#if TARGET_OS_TV
  self.defaults = [[NSUserDefaults alloc] initWithSuiteName:kFIRCoreSuiteName];
  self.dataStorage =
      [[GULHeartbeatDateStorageUserDefaults alloc] initWithDefaults:self.defaults
                                                                key:kHeartbeatStorageName];
#else
  self.dataStorage = [[GULHeartbeatDateStorage alloc] initWithFileName:kHeartbeatStorageName];
#endif  // TARGET_OS_TV
  NSDateComponents *componentsToAdd = [[NSDateComponents alloc] init];
  componentsToAdd.day = -1;

  NSDate *dayAgo = [[NSCalendar currentCalendar] dateByAddingComponents:componentsToAdd
                                                                 toDate:[NSDate date]
                                                                options:0];

  [self.dataStorage setHearbeatDate:dayAgo forTag:@"fire-iid"];
  [self.dataStorage setHearbeatDate:dayAgo forTag:@"GLOBAL"];
}

#if TARGET_OS_TV
- (void)tearDown {
  // Delete any residual storage.
  [self.defaults removePersistentDomainForName:kFIRCoreSuiteName];
  self.defaults = nil;

  [super tearDown];
}
#endif  // TARGET_OS_TV

- (void)testCombinedHeartbeat {
  FIRHeartbeatInfoCode heartbeatCode = [FIRHeartbeatInfo heartbeatCodeForTag:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, FIRHeartbeatInfoCodeCombined);
}

- (void)testSdkOnlyHeartbeat {
  [self.dataStorage setHearbeatDate:[NSDate date] forTag:@"GLOBAL"];
  FIRHeartbeatInfoCode heartbeatCode = [FIRHeartbeatInfo heartbeatCodeForTag:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, FIRHeartbeatInfoCodeSDK);
}

- (void)testGlobalOnlyHeartbeat {
  [self.dataStorage setHearbeatDate:[NSDate date] forTag:@"fire-iid"];
  FIRHeartbeatInfoCode heartbeatCode = [FIRHeartbeatInfo heartbeatCodeForTag:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, FIRHeartbeatInfoCodeGlobal);
}

- (void)testNoHeartbeat {
  [self.dataStorage setHearbeatDate:[NSDate date] forTag:@"fire-iid"];
  [self.dataStorage setHearbeatDate:[NSDate date] forTag:@"GLOBAL"];
  FIRHeartbeatInfoCode heartbeatCode = [FIRHeartbeatInfo heartbeatCodeForTag:@"fire-iid"];
  XCTAssertEqual(heartbeatCode, FIRHeartbeatInfoCodeNone);
}

@end
