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

#import <XCTest/XCTest.h>
#import "FirebaseCore/Sources/Private/FIRHeartbeatInfo.h"
#import "GoogleUtilities/Environment/Private/GULHeartbeatDateStorage.h"

@interface FIRHeartbeatInfoTest : XCTestCase

@property(nonatomic, strong) GULHeartbeatDateStorage *dataStorage;

@property(nonatomic, strong) NSMutableDictionary *dictionary;

@end

@implementation FIRHeartbeatInfoTest

- (void)setUp {
  NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
  self.dataStorage = [[GULHeartbeatDateStorage alloc] initWithFileName:kHeartbeatStorageFile];
  NSDateComponents *componentsToAdd = [[NSDateComponents alloc] init];
  componentsToAdd.day = -1;

  NSDate *dayAgo = [[NSCalendar currentCalendar] dateByAddingComponents:componentsToAdd
                                                                 toDate:[NSDate date]
                                                                options:0];

  [self.dataStorage setHearbeatDate:dayAgo forTag:@"fire-iid"];
  [self.dataStorage setHearbeatDate:dayAgo forTag:@"GLOBAL"];
}

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
