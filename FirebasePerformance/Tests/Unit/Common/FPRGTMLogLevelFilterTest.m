// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Common/FPRGTMLogLevelFilter.h"

@interface FPRGTMLogLevelFilterTest : XCTestCase

@property(nonatomic) FPRGTMLogLevelFilter *logFilter;

@end

@implementation FPRGTMLogLevelFilterTest

- (void)setUp {
  [super setUp];
  self.logFilter = [[FPRGTMLogLevelFilter alloc] init];
}

- (void)tearDown {
  [super tearDown];
  self.logFilter = nil;
}

/** Validates that instance creation does not fail. */
- (void)testInstanceCreation {
  XCTAssertNotNil(self.logFilter);
}

/** Validates that PseudonymousIDStore messages are dropped. */
- (void)testPseudonymousIDStoreLogMessagesAreDropped {
  XCTAssertFalse([self.logFilter
      filterAllowsMessage:@"-[GMVGIPPseudonymousIDStore initializeStorage] message"
                    level:kGTMLoggerLevelError]);
}

/** Validates that valid messages are not dropped. */
- (void)testValidLogMessagesAreNotDropped {
  NSString *logMessage = @"<Error> [Firebase/InstanceID][I-IID010003] Unable to generate keypair.";
  XCTAssertTrue([self.logFilter filterAllowsMessage:logMessage level:kGTMLoggerLevelError]);
}

@end
